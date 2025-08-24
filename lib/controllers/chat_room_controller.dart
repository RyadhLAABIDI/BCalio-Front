import 'dart:async';
import 'dart:io';

import 'package:bcalio/routes.dart';
import 'package:bcalio/services/permission_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/true_message_model.dart';
import '../services/ai_chabot_service.dart';
import '../services/message_api_service.dart';
import '../services/push_api_service.dart'; // 👈 NEW (push)
import '../controllers/user_controller.dart';
import 'conversation_controller.dart';

class ChatRoomController extends GetxController {
  final MessageApiService messageApiService;
  final AIChatbotService aiChatbotService = AIChatbotService();
  final ConversationController conversationController =
      Get.find<ConversationController>();

  ChatRoomController({required this.messageApiService});

  // 👇 NEW: client pour déclencher la push côté serveur d’appels
  final PushApiService _pushApi = PushApiService();

  /* --------------------- ÉTAT MESSAGES --------------------- */
  RxList<Message> messages = <Message>[].obs;
  RxBool isLoading = false.obs;
  RxBool isRecording = false.obs;
  RxString recordingFilePath = ''.obs;
  RxString sendingStatus = ''.obs;
  final AudioRecorder record = AudioRecorder();
  RxString lastFetchedMessageId = ''.obs;
  Timer? _pollingTimer;
  Function? onMessagesUpdated;

  // --- Anti-doublon / upsert ---
  final Set<String> _seenServerIds = <String>{};

  void _dedupeInPlace() {
    final map = <String, Message>{};
    for (final m in messages) {
      map[m.id] = m; // garde la dernière instance par id
    }
    messages.value = map.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _upsertById(Message m) {
    final i = messages.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      messages[i] = m;
    } else {
      messages.add(m);
    }
    _seenServerIds.add(m.id);
  }

  // Remplace un "local-*" si corps/timestamp match, sinon upsert par id
  void _upsertFromServer(Message server) {
    if (_seenServerIds.contains(server.id)) {
      final i = messages.indexWhere((x) => x.id == server.id);
      if (i >= 0) messages[i] = server;
      return;
    }

    final optimisticIdx = messages.indexWhere((m) =>
        m.id.startsWith('local-') &&
        m.senderId == server.senderId &&
        m.body == server.body &&
        (server.createdAt.difference(m.createdAt).inSeconds).abs() <= 120);
    if (optimisticIdx != -1) {
      messages[optimisticIdx] = server;
      _seenServerIds.add(server.id);
      return;
    }

    _upsertById(server);
  }

  /* --------------------- TYPING INDICATOR --------------------- */
  // Conversation courante (à attacher depuis la page)
  String _currentConversationId = '';
  String _otherUserId = '';
  bool get _isConversationAttached =>
      _currentConversationId.isNotEmpty && _otherUserId.isNotEmpty;

  // “l’autre est en train d’écrire” → à afficher dans l’UI
  final RxBool otherTyping = false.obs;

  // Anti-spam émission typing
  Timer? _typingIdleTimer; // relâche automatique après inactivité
  bool _typingActiveSent = false; // on a déjà envoyé “typing” (évite le spam)
  DateTime _lastKeystroke = DateTime.fromMillisecondsSinceEpoch(0);

  /// Appeler UNE FOIS dans ChatRoomPage :
  void attachConversation(
      {required String conversationId, required String otherUserId}) {
    _currentConversationId = conversationId;
    _otherUserId = otherUserId;

    // écoute des events socket (typing) -> filtre sur la conv courante
    final socket = Get.find<UserController>().socketService;
    socket.onTyping = (convId, fromUserId) {
      if (convId == _currentConversationId && fromUserId == _otherUserId) {
        otherTyping.value = true;
      }
    };
    socket.onStopTyping = (convId, fromUserId) {
      if (convId == _currentConversationId && fromUserId == _otherUserId) {
        otherTyping.value = false;
      }
    };
  }

  /// À brancher sur le TextField.onChanged
  void handleTyping({required String text}) {
    if (!_isConversationAttached) return;

    final socket = Get.find<UserController>().socketService;
    final now = DateTime.now();
    _lastKeystroke = now;

    // Si l’utilisateur commence à taper et qu’on n’a pas encore notifié → envoyer 1 fois
    if (text.trim().isNotEmpty && !_typingActiveSent) {
      _typingActiveSent = true;
      socket.emitTyping(_otherUserId, _currentConversationId);
    }

    // Re-déclenche le timer d’inactivité (stop-typing après X ms sans saisie)
    _typingIdleTimer?.cancel();
    if (text.trim().isEmpty) {
      // si champ vide → stop immédiat
      _sendStopTyping();
    } else {
      _typingIdleTimer = Timer(const Duration(seconds: 2), () {
        final inactiveMs =
            DateTime.now().difference(_lastKeystroke).inMilliseconds;
        if (inactiveMs >= 1800) {
          _sendStopTyping();
        }
      });
    }
  }

  void _sendStopTyping() {
    if (!_isConversationAttached) return;
    if (!_typingActiveSent) return;
    final socket = Get.find<UserController>().socketService;
    socket.emitStopTyping(_otherUserId, _currentConversationId);
    _typingActiveSent = false;
    _typingIdleTimer?.cancel();
    _typingIdleTimer = null;
  }

  /* --------------------- FETCH/POLLING --------------------- */
  Future<void> fetchMessages(String token, String conversationId) async {
    debugPrint('fetchMessages ======================= chat room=');
    isLoading.value = true;
    try {
      final fetched = await messageApiService.getMessages(token, conversationId);

      messages.value = fetched;
      _seenServerIds
        ..clear()
        ..addAll(fetched.map((m) => m.id));
      _dedupeInPlace();

      if (fetched.isNotEmpty) {
        lastFetchedMessageId.value = fetched.last.id;
      }
      debugPrint('isSeen+++++++++++++++++++++++++++++');
    } catch (e) {
      // ⚠️ retiré: Get.snackbar('Error', 'Failed to fetch messages: $e');
      debugPrint('Failed to fetch messages: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void startPolling(String token, String conversationId) {
    debugPrint('start polling ======================= chat room=');
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final fetched =
            await messageApiService.getMessages(token, conversationId);

        for (final msg in fetched) {
          final i = messages.indexWhere((m) => m.id == msg.id);
          if (i >= 0) {
            final old = messages[i];
            final oldSeen = old.seenBy?.length ?? 0;
            final newSeen = msg.seenBy?.length ?? 0;
            if (newSeen > oldSeen ||
                msg.createdAt != old.createdAt ||
                msg.body != old.body) {
              messages[i] = msg;
            }
            _seenServerIds.add(msg.id);
            continue;
          }

          _upsertFromServer(msg);
        }

        _dedupeInPlace();
      } catch (e) {
        debugPrint('Polling error------: $e');
        if (e.toString().contains('404')) {
          _pollingTimer?.cancel();
        } else if (e.toString().contains('401')) {
          _pollingTimer?.cancel();
          Get.offAllNamed(Routes.login);
        } else {
          // ⚠️ retiré: Get.snackbar('Error', 'Failed to fetch messages: $e');
          debugPrint('Failed to fetch messages (polling): $e');
        }
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  @override
  void onInit() {
    super.onInit();
    messages.listen((_) {
      if (onMessagesUpdated != null) {
        onMessagesUpdated!();
      }
    });
  }

  @override
  void onClose() {
    _sendStopTyping();
    _typingIdleTimer?.cancel();
    _typingIdleTimer = null;

    stopPolling();
    super.onClose();
  }

  /* --------------------- ENVOIS --------------------- */

  /// =================== SEND TEXT (optimistic) ===================
  Future<void> sendMessage({
    required String token,
    required String conversationId,
    required String body,
  }) async {
    if (token.isEmpty || conversationId.isEmpty || body.isEmpty) {
      Get.snackbar(
          'Error', 'Token, Conversation ID, and Body cannot be empty.');
      return;
    }

    // 1) insertion optimiste
    final userCtrl = Get.find<UserController>();
    final currentUserId = userCtrl.currentUser.value?.id ?? '';
    final tempId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = Message(
      id: tempId,
      senderId: currentUserId,
      body: body,
      createdAt: DateTime.now(),
      conversationId: conversationId,
    );
    messages.add(optimistic);

    try {
      // 2) envoi serveur
      final sent = await messageApiService.sendMessage(
        token: token,
        conversationId: conversationId,
        body: body,
      );

      // 3) remplacer l’optimiste par la vraie version (ID serveur)
      final idx = messages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        messages[idx] = sent;
      } else {
        messages.add(sent);
      }
      _seenServerIds.add(sent.id);
      _dedupeInPlace();

      // 4) 🔔 Push "chat_message"
      await _notifyPush(
        conversationId: conversationId,
        sent: sent,
        contentType: 'text',
        textForPush: body,
      );

      sendingStatus.value = '';
      _sendStopTyping(); // coupe l’indicateur de saisie
    } catch (e) {
      // 5) échec → petite étiquette “[failed]” locale
      final idx = messages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        messages[idx] = Message(
          id: tempId,
          senderId: currentUserId,
          body: '${body}  ❌',
          createdAt: optimistic.createdAt,
          conversationId: conversationId,
        );
      }
      sendingStatus.value = '';
      Get.snackbar('Error', 'Failed to send message: $e');
    }
  }

  /// Send Image Message
  Future<void> sendImage({
    required String token,
    required String conversationId,
    required File imageFile,
  }) async {
    if (token.isEmpty || conversationId.isEmpty) {
      Get.snackbar('Error', 'Token and Conversation ID cannot be empty.');
      return;
    }

    try {
      final imageUrl =
          await messageApiService.uploadFileToCloudinary(imageFile, false);

      if (imageUrl.isEmpty) {
        sendingStatus.value = '';
        Get.snackbar('Error', 'Image upload failed.');
        return;
      }

      final sent = await messageApiService.sendMessage(
        token: token,
        conversationId: conversationId,
        image: imageUrl,
      );

      // 🔔 Push
      await _notifyPush(
        conversationId: conversationId,
        sent: sent,
        contentType: 'image',
        textForPush: imageUrl, // Android natif peut tenter BigPicture
      );

      sendingStatus.value = '';
      _sendStopTyping();
    } catch (e) {
      sendingStatus.value = '';
      Get.snackbar('Error', 'Failed to send image: $e');
    }
  }

  /// Send Voice Message
  Future<void> sendVoiceMessage({
    required String token,
    required String conversationId,
    required File voiceFile,
  }) async {
    if (token.isEmpty || conversationId.isEmpty) {
      Get.snackbar('Error', 'Token and Conversation ID cannot be empty.');
      return;
    }
    debugPrint('sendVoiceMessage====================================: $voiceFile');
    try {
      final audioUrl =
          await messageApiService.uploadFileToCloudinary(voiceFile, true);

      if (audioUrl.isEmpty) {
        sendingStatus.value = '';
        Get.snackbar('Error', 'Audio upload failed.');
        return;
      }

      final sent = await messageApiService.sendMessage(
        token: token,
        conversationId: conversationId,
        audio: audioUrl,
      );

      // 🔔 Push
      await _notifyPush(
        conversationId: conversationId,
        sent: sent,
        contentType: 'audio',
        textForPush: audioUrl,
      );

      sendingStatus.value = '';
      _sendStopTyping();
    } catch (e) {
      sendingStatus.value = '';
      Get.snackbar('Error', 'Failed to send voice message: $e');
    }
  }

  /// Send Video Message
  Future<void> sendVideo({
    required String token,
    required String conversationId,
    required File videoFile,
  }) async {
    if (token.isEmpty || conversationId.isEmpty) {
      Get.snackbar(
          'Error', 'Token, Conversation ID, and Body cannot be empty.');
      return;
    }
    debugPrint('sendVideo====================================: $videoFile');
    try {
      final videoUrl =
          await messageApiService.uploadFileToCloudinary(videoFile, false);
      debugPrint(
          'sendVideo=====videoUrl===============================: $videoUrl');

      if (videoUrl.isEmpty) {
        sendingStatus.value = '';
        Get.snackbar('Error', 'Video upload failed.');
        return;
      }
      debugPrint(
          'video+++++++++++++++sendMessage+===============================: $videoUrl');

      final sent = await messageApiService.sendMessage(
        token: token,
        conversationId: conversationId,
        video: videoUrl, // ✅ champ "video" géré côté service
      );

      // 🔔 Push
      await _notifyPush(
        conversationId: conversationId,
        sent: sent,
        contentType: 'video',
        textForPush: videoUrl,
      );

      sendingStatus.value = '';
      _sendStopTyping();
    } catch (e) {
      sendingStatus.value = '';
      Get.snackbar('Error', 'Failed to send video: $e');
    }
  }

  /* --------------------- PICKER / PERMISSIONS --------------------- */
  final picker = ImagePicker();
  File pictureClient = File("");
  final PermissionService permissionService = PermissionService();

  Future<void> getImageFromGallery(BuildContext context) async {
    final permissionStatus =
        await permissionService.requestStoragePermission();
    debugPrint('permissionStatus---------------: $permissionStatus');
    if (permissionStatus == true) {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        pictureClient = File(pickedFile.path);
        update();
      }
    }
  }

  Future<void> getImageFromCamera(BuildContext context) async {
    final permissionStatus =
        await permissionService.requestCameraPermission();
    debugPrint('getImageFromCamera---------------: $permissionStatus');
    if (permissionStatus == true) {
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        pictureClient = File(pickedFile.path);
        update();
      }
    }
  }

  getImage(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      builder: (c) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text("gallery".tr),
            onPressed: () {
              Navigator.of(context).pop();
              getImageFromGallery(context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text("camera".tr),
            onPressed: () {
              Navigator.of(context).pop();
              getImageFromCamera(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> deleteMessage(
      String conversationId, String messageid, String token) async {
    try {
      debugPrint(
          'deleteMessage========================: $messageid  conv Id: $conversationId token: $token');
      await messageApiService.deleteMessage(conversationId, messageid, token);
    } catch (e) {
      debugPrint('Error Failed to delete message: $e');
    }
  }

  /* --------------------- Recording --------------------- */

  /// Lance l’enregistrement vocal (AAC LC .m4a dans le dossier temporaire)
  Future<void> startRecording() async {
    try {
      final hasPerm = await record.hasPermission();
      if (!hasPerm) {
        Get.snackbar('Permission', 'Microphone permission denied');
        return;
      }

      final tmpDir = await getTemporaryDirectory();
      final path =
          '${tmpDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await record.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      isRecording.value = true;
      recordingFilePath.value = path;
      debugPrint('[Record] started → $path');
    } catch (e) {
      debugPrint('[Record] start error: $e');
      Get.snackbar('Error', 'Cannot start recording: $e');
    }
  }

  /// Arrête l’enregistrement et envoie le fichier
  Future<void> stopRecording({
    required String token,
    required String conversationId,
  }) async {
    try {
      final path = await record.stop();
      isRecording.value = false;

      if (path == null || path.isEmpty) {
        debugPrint('[Record] stop → no file');
        return;
      }

      final file = File(path);
      if (!file.existsSync()) {
        debugPrint('[Record] file does not exist: $path');
        return;
      }

      // Envoi comme message vocal
      await sendVoiceMessage(
        token: token,
        conversationId: conversationId,
        voiceFile: file,
      );

      // Reset chemin
      recordingFilePath.value = '';
      debugPrint('[Record] sent voice message: $path');
    } catch (e) {
      isRecording.value = false;
      debugPrint('[Record] stop error: $e');
      Get.snackbar('Error', 'Cannot stop recording: $e');
    }
  }

  /// Annule l’enregistrement (stop + suppression fichier si présent)
  Future<void> discardRecording() async {
    try {
      if (await record.isRecording()) {
        await record.stop();
      }
      final p = recordingFilePath.value;
      if (p.isNotEmpty) {
        final f = File(p);
        if (f.existsSync()) {
          await f.delete();
        }
      }
      isRecording.value = false;
      recordingFilePath.value = '';
      debugPrint('[Record] discarded');
    } catch (e) {
      debugPrint('[Record] discard error: $e');
    }
  }

  /* --------------------- AI --------------------- */
  Future<void> sendAIChatbotMessage({
    required String token,
    required String conversationId,
    required String userMessage,
  }) async {
    try {
      final aiResponse = await aiChatbotService.sendMessageToAI(userMessage);

      final aiMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'ai_chatbot',
        body: aiResponse,
        createdAt: DateTime.now(),
        isFromAI: true,
        conversationId: conversationId,
      );
      messages.add(aiMessage);
    } catch (e) {
      Get.snackbar('Error', 'Failed to get AI response: $e');
    }
  }

  /* --------------------- PUSH helper --------------------- */

  /// Déclenche la push “chat_message” vers les autres membres de la conversation.
  Future<void> _notifyPush({
    required String conversationId,
    required Message sent,
    required String contentType, // "text" | "image" | "audio" | "video"
    required String textForPush, // texte ou URL (image/audio/video)
  }) async {
    try {
      final convCtrl = conversationController;
      final userCtrl = Get.find<UserController>();

      // trouve la conv en mémoire
      final conv = convCtrl.conversations.firstWhereOrNull(
        (c) => c.id == conversationId,
      );
      if (conv == null) {
        debugPrint('[push] conversation not in cache, skip notify');
        return;
      }

      final myId = userCtrl.userId;
      final toUserIds = <String>{
        // d’abord via users (objets)
        ...conv.users.map((u) => u.id),
        // fallback via userIds (strings)
        ...conv.userIds,
      }.where((id) => id.isNotEmpty && id != myId).toList();

      if (toUserIds.isEmpty) {
        debugPrint('[push] no recipients to notify');
        return;
      }

      final fromName = userCtrl.userName;
      final avatarUrl = userCtrl.user?.image ?? '';

      await _pushApi.notifyNewMessage(
        toUserIds: toUserIds,
        roomId: conversationId,
        messageId: sent.id,
        fromId: myId,
        fromName: fromName,
        avatarUrl: avatarUrl,
        text: textForPush,
        contentType: contentType,
        isGroup: toUserIds.length > 1,
        sentAtIso: (sent.createdAt).toUtc().toIso8601String(),
      );
    } catch (e) {
      // On ne bloque pas l’UI si la push échoue, l’envoi du message est prioritaire
      debugPrint('[push] notifyNewMessage error: $e');
    }
  }
}
