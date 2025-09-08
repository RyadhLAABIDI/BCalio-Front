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
import '../services/push_api_service.dart';
import '../controllers/user_controller.dart';
import 'conversation_controller.dart';

class ChatRoomController extends GetxController {
  final MessageApiService messageApiService;
  final AIChatbotService aiChatbotService = AIChatbotService();
  final ConversationController conversationController = Get.find<ConversationController>();

  ChatRoomController({required this.messageApiService});

  final PushApiService _pushApi = PushApiService();

  // ----- état -----
  RxList<Message> messages = <Message>[].obs;
  RxBool isLoading = false.obs;
  RxBool isRecording = false.obs;
  RxString recordingFilePath = ''.obs;
  RxString sendingStatus = ''.obs;
  final AudioRecorder record = AudioRecorder();
  RxString lastFetchedMessageId = ''.obs;
  Timer? _pollingTimer;
  Function? onMessagesUpdated;

  final Set<String> _seenServerIds = <String>{};

  void _dedupeInPlace() {
    final map = <String, Message>{};
    for (final m in messages) {
      map[m.id] = m;
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

  // ----- typing indicator -----
  String _currentConversationId = '';
  String _otherUserId = '';
  bool get _isConversationAttached => _currentConversationId.isNotEmpty && _otherUserId.isNotEmpty;

  final RxBool otherTyping = false.obs;

  Timer? _typingIdleTimer;
  bool _typingActiveSent = false;
  DateTime _lastKeystroke = DateTime.fromMillisecondsSinceEpoch(0);

  void attachConversation({required String conversationId, required String otherUserId}) {
    _currentConversationId = conversationId;
    _otherUserId = otherUserId;

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

  void handleTyping({required String text}) {
    if (!_isConversationAttached) return;

    final socket = Get.find<UserController>().socketService;
    final now = DateTime.now();
    _lastKeystroke = now;

    if (text.trim().isNotEmpty && !_typingActiveSent) {
      _typingActiveSent = true;
      socket.emitTyping(_otherUserId, _currentConversationId);
    }

    _typingIdleTimer?.cancel();
    if (text.trim().isEmpty) {
      _sendStopTyping();
    } else {
      _typingIdleTimer = Timer(const Duration(seconds: 2), () {
        final inactiveMs = DateTime.now().difference(_lastKeystroke).inMilliseconds;
        if (inactiveMs >= 1800) _sendStopTyping();
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

  // ----- fetch / polling -----
  Future<void> fetchMessages(String token, String conversationId) async {
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
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void startPolling(String token, String conversationId) {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final fetched = await messageApiService.getMessages(token, conversationId);

        for (final msg in fetched) {
          final i = messages.indexWhere((m) => m.id == msg.id);
          if (i >= 0) {
            final old = messages[i];
            final oldSeen = old.seenBy?.length ?? 0;
            final newSeen = msg.seenBy?.length ?? 0;
            if (newSeen > oldSeen ||
                msg.createdAt != old.createdAt ||
                msg.body != old.body ||
                msg.image != old.image ||
                msg.audio != old.audio ||
                msg.video != old.video) {
              messages[i] = msg;
            }
            _seenServerIds.add(msg.id);
            continue;
          }
          _upsertFromServer(msg);
        }

        _dedupeInPlace();
      } catch (e) {
        debugPrint('Polling error: $e');
        if (e.toString().contains('404')) {
          _pollingTimer?.cancel();
        } else if (e.toString().contains('401')) {
          _pollingTimer?.cancel();
          Get.offAllNamed(Routes.login);
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
      if (onMessagesUpdated != null) onMessagesUpdated!();
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

  // ----- envois -----
  Future<void> sendMessage({
    required String token,
    required String conversationId,
    required String body,
  }) async {
    if (token.isEmpty || conversationId.isEmpty || body.isEmpty) {
      Get.snackbar('Error', 'Token, Conversation ID, and Body cannot be empty.');
      return;
    }

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
      final sent = await messageApiService.sendMessage(
        token: token,
        conversationId: conversationId,
        body: body,
      );

      final idx = messages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        messages[idx] = sent;
      } else {
        messages.add(sent);
      }
      _seenServerIds.add(sent.id);
      _dedupeInPlace();

      await _notifyPush(
        conversationId: conversationId,
        sent: sent,
        contentType: 'text',
        textForPush: body,
      );

      sendingStatus.value = '';
      _sendStopTyping();
    } catch (e) {
      final idx = messages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        messages[idx] = Message(
          id: tempId,
          senderId: currentUserId,
          body: '$body  ❌',
          createdAt: optimistic.createdAt,
          conversationId: conversationId,
        );
      }
      sendingStatus.value = '';
      Get.snackbar('Error', 'Failed to send message: $e');
    }
  }

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
      final imageUrl = await messageApiService.uploadFileToCloudinary(imageFile, false);
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

      await _notifyPush(
        conversationId: conversationId,
        sent: sent,
        contentType: 'image',
        textForPush: imageUrl,
      );

      sendingStatus.value = '';
      _sendStopTyping();
    } catch (e) {
      sendingStatus.value = '';
      Get.snackbar('Error', 'Failed to send image: $e');
    }
  }

  Future<void> sendVoiceMessage({
    required String token,
    required String conversationId,
    required File voiceFile,
  }) async {
    if (token.isEmpty || conversationId.isEmpty) {
      Get.snackbar('Error', 'Token and Conversation ID cannot be empty.');
      return;
    }
    try {
      final audioUrl = await messageApiService.uploadFileToCloudinary(voiceFile, true);
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

  Future<void> sendVideo({
    required String token,
    required String conversationId,
    required File videoFile,
  }) async {
    if (token.isEmpty || conversationId.isEmpty) {
      Get.snackbar('Error', 'Token, Conversation ID, and Body cannot be empty.');
      return;
    }
    try {
      final videoUrl = await messageApiService.uploadFileToCloudinary(videoFile, false);
      if (videoUrl.isEmpty) {
        sendingStatus.value = '';
        Get.snackbar('Error', 'Video upload failed.');
        return;
      }

      // Fallback utile: on met aussi l’URL dans body sous forme de balise
      final sent = await messageApiService.sendMessage(
        token: token,
        conversationId: conversationId,
        video: videoUrl,
        body: '[video] $videoUrl',
      );

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

  // ----- Picker / permissions -----
  final picker = ImagePicker();
  File pictureClient = File("");
  final PermissionService permissionService = PermissionService();

  Future<void> getImageFromGallery(BuildContext context) async {
    final permissionStatus = await permissionService.requestStoragePermission();
    if (permissionStatus == true) {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        pictureClient = File(pickedFile.path);
        update();
      }
    }
  }

  Future<void> getImageFromCamera(BuildContext context) async {
    final permissionStatus = await permissionService.requestCameraPermission();
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

  Future<void> deleteMessage(String conversationId, String messageid, String token) async {
    try {
      await messageApiService.deleteMessage(conversationId, messageid, token);
    } catch (e) {
      debugPrint('Error Failed to delete message: $e');
    }
  }

  // ----- Recording -----
  Future<void> startRecording() async {
    try {
      final hasPerm = await record.hasPermission();
      if (!hasPerm) {
        Get.snackbar('Permission', 'Microphone permission denied');
        return;
      }

      final tmpDir = await getTemporaryDirectory();
      final path = '${tmpDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
    } catch (e) {
      debugPrint('[Record] start error: $e');
      Get.snackbar('Error', 'Cannot start recording: $e');
    }
  }

  Future<void> stopRecording({
    required String token,
    required String conversationId,
  }) async {
    try {
      final path = await record.stop();
      isRecording.value = false;

      if (path == null || path.isEmpty) return;

      final file = File(path);
      if (!file.existsSync()) return;

      await sendVoiceMessage(
        token: token,
        conversationId: conversationId,
        voiceFile: file,
      );

      recordingFilePath.value = '';
    } catch (e) {
      isRecording.value = false;
      debugPrint('[Record] stop error: $e');
      Get.snackbar('Error', 'Cannot stop recording: $e');
    }
  }

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
    } catch (e) {
      debugPrint('[Record] discard error: $e');
    }
  }

  // ----- AI -----
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

  // ----- PDF / DOC -----
  Future<String?> uploadPdfAndGetUrl(File pdf) async {
    try {
      final url = await messageApiService.uploadDocumentToCloudinary(pdf);
      if (url.isEmpty) return null;
      return url;
    } catch (e) {
      debugPrint('[PDF] upload error: $e');
      return null;
    }
  }

  Future<void> sendDocument({
    required String token,
    required String conversationId,
    required File file,
  }) async {
    final url = await uploadPdfAndGetUrl(file);
    if (url == null) {
      Get.snackbar('Error', 'Document upload failed.');
      return;
    }
    final fileName = file.path.split(Platform.pathSeparator).last;
    final body = '[file] $fileName|$url';
    await sendMessage(token: token, conversationId: conversationId, body: body);
  }

  // ----- PUSH helper -----
  Future<void> _notifyPush({
    required String conversationId,
    required Message sent,
    required String contentType, // "text" | "image" | "audio" | "video"
    required String textForPush, // texte ou URL
  }) async {
    try {
      final convCtrl = conversationController;
      final userCtrl = Get.find<UserController>();

      final conv = convCtrl.conversations.firstWhereOrNull((c) => c.id == conversationId);
      if (conv == null) {
        debugPrint('[push] conversation not in cache, skip notify');
        return;
      }

      final myId = userCtrl.userId;
      final toUserIds = <String>{
        ...conv.users.map((u) => u.id),
        ...conv.userIds,
      }.where((id) => id.isNotEmpty && id != myId).toList();

      if (toUserIds.isEmpty) return;

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
        sentAtIso: sent.createdAt.toUtc().toIso8601String(), // ✅ createdAt
      );
    } catch (e) {
      debugPrint('[push] notifyNewMessage error: $e');
    }
  }
}
