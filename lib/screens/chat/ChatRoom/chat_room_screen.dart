import 'dart:convert';
import 'package:bcalio/models/conversation_model.dart';
import 'package:bcalio/models/true_user_model.dart';
import 'package:bcalio/routes.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:screen_capture_event/screen_capture_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import '../../../controllers/call_service_controller.dart';
import '../../../controllers/chat_room_controller.dart';
import '../../../controllers/conversation_controller.dart';
import '../../../controllers/user_controller.dart';
import '../../../services/message_api_service.dart';
import '../../../widgets/chat/chat_room/chatRoomAppBar.dart';
import '../../../widgets/chat/chat_room/chat_input_area.dart';
import '../../../widgets/chat/chat_room/message_list.dart';
import '../../../widgets/chat/chat_room/shimmer_loading_messages.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

class ChatRoomPage extends StatefulWidget {
  final String name;
  final String phoneNumber;
  final String? avatarUrl;
  final String conversationId;
  final DateTime? createdAt;

  const ChatRoomPage({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.conversationId,
    this.avatarUrl,
    this.createdAt,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> with TickerProviderStateMixin {
  // 👉 démarre directement “en bas” (pas de flash du début)
  final ScrollController _scrollController =
      ScrollController(initialScrollOffset: 1000000000);

  final RxBool isSending = false.obs;
  final ScreenCaptureEvent screenListener = ScreenCaptureEvent();
  late final ChatRoomController controller;
  rtc.RTCPeerConnection? _peerConnection;
  bool _isScreenshotProcessing = false;
  bool _localRendererInitialized = false;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isCalling = false;
  bool _isConnected = false;
  bool _isSubscribed = false;
  late String _channelName;
  bool _isInCall = false;
  bool _isVideoCall = false;
  MediaStream? _localStream;
  final PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();

  // Couleurs pour le thème
  static const Color kLightPrimaryColor = Color(0xFF89C6C9);
  static const Color kDarkBgColor = Color.fromARGB(255, 0, 8, 8);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color bubbleOutgoingLight = Color(0xFFDCF8C6);
  static const Color bubbleIncomingLight = Color(0xFFFFFFFF);
  static const Color bubbleOutgoingDark = Color(0xFF075E54);
  static const Color bubbleIncomingDark = Color(0xFF1F2C34);
  static const Color chatBackgroundLight = Color(0xFFECE5DD);
  static const Color chatBackgroundDark = Color(0xFF0D1418);

  /// ----------- SCROLL UX -----------
  bool _stickToBottom = true;          // l’utilisateur est-il proche du bas ?
  bool _forceScrollNextUpdate = false; // forcer le scroll quand toi tu envoies
  bool _pendingInitialBottom = true;   // 1er positionnement confirmé en bas
  bool _showJumpDownBtn = false;       // affichage bouton “⬇︎”
  int  _newMsgBadge = 0;               // badge “N nouveaux”
  int  _lastMsgCount = 0;              // pour calculer les deltas

  // Typing attach (évite d’attacher 10x)
  bool _typingAttached = false;

  Future<String?> getPusherToken(String channelName, String socketId) async {
    try {
      final token = await Get.find<UserController>().getToken();
      var headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      var data = json.encode({
        "socket_id": socketId,
        "channel_name": channelName,
      });

      var dio = Dio();
      var response = await dio.post(
        'https://pusher.b-callio.com/pusher/auth',
        data: data,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        print('Pusher auth response: ${response.data}');
        final auth = response.data['auth'] as String?;
        if (auth == null || !auth.startsWith('bc00b5f6fa3dc2dbbb91:')) {
          print('Invalid Pusher auth token format: $auth');
          return null;
        }
        return auth;
      } else {
        print('Pusher auth failed: ${response.statusCode}, ${response.statusMessage}');
        return null;
      }
    } catch (e) {
      print('Pusher auth error: $e');
      return null;
    }
  }

  /// Jump immédiat (ou court) en bas
  void _jumpToBottom({bool smooth = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (smooth) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  /// Jump “dur” multi-frame (sécurité au 1er rendu si besoin)
  void _jumpToBottomHard({int retries = 6}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        if (retries > 0) {
          Future.delayed(const Duration(milliseconds: 16), () => _jumpToBottomHard(retries: retries - 1));
        }
        return;
      }
      try {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent + 100000);
      } catch (_) {}
      if (retries > 0) {
        Future.delayed(const Duration(milliseconds: 16), () => _jumpToBottomHard(retries: retries - 1));
      }
    });
  }

  void _attachScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final distanceFromBottom = pos.maxScrollExtent - pos.pixels;

      final wasSticking = _stickToBottom;
      _stickToBottom = distanceFromBottom < 120;

      // bouton “⬇︎”
      final show = !_stickToBottom && pos.maxScrollExtent > 0;
      if (show != _showJumpDownBtn) {
        setState(() => _showJumpDownBtn = show);
      }

      // si on revient en bas → clear badge
      if (_stickToBottom && !wasSticking) {
        if (_newMsgBadge != 0) setState(() => _newMsgBadge = 0);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    print('Initializing ChatRoomPage with conversationId=${widget.conversationId}, name=${widget.name}');

    _attachScrollListener();

    try {
      controller = Get.put(
        ChatRoomController(messageApiService: Get.find<MessageApiService>()),
        tag: widget.conversationId,
      );
    } catch (e) {
      print('Error initializing ChatRoomController: $e');
      Get.snackbar('Error', 'Failed to initialize chat: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }

    // Quand la liste des messages change
    controller.onMessagesUpdated = () {
      if (!mounted) return;

      final curLen = controller.messages.length;

      // 1) Premier placement : s’assurer qu’on reste en bas sans flash
      if (_pendingInitialBottom) {
        _pendingInitialBottom = false;
        _lastMsgCount = curLen;
        _jumpToBottomHard();
        return;
      }

      // 2) Calcul du delta nouveaux messages
      final delta = (curLen - _lastMsgCount).clamp(0, 1 << 30);
      _lastMsgCount = curLen;

      if (_forceScrollNextUpdate || _stickToBottom) {
        _jumpToBottom(smooth: !_forceScrollNextUpdate);
        _forceScrollNextUpdate = false;
        if (_newMsgBadge != 0) setState(() => _newMsgBadge = 0);
      } else {
        if (delta > 0) {
          setState(() => _newMsgBadge += delta);
        }
      }
    };

    final userController = Get.find<UserController>();

    Future.delayed(Duration.zero, () async {
      final token = await userController.getToken();
      if (token != null && token.isNotEmpty) {
        print('Fetching messages for conversationId=${widget.conversationId}');
        await controller.fetchMessages(token, widget.conversationId);

        // marquer la conversation comme "vue"
        final convCtrl = Get.find<ConversationController>();
        await convCtrl.markAsSeen(
          token: token,
          conversationId: widget.conversationId,
        );

        controller.startPolling(token, widget.conversationId);
      } else {
        print('Failed to retrieve token. Please log in again.');
        Get.snackbar('Error', 'Failed to retrieve token. Please log in again.', backgroundColor: Colors.red, colorText: Colors.white);
        Get.toNamed(Routes.login);
      }
    });

    // Screenshot → message système
    final screenListener = this.screenListener;
    screenListener.addScreenShotListener((recorded) async {
      if (_isScreenshotProcessing) return;
      _isScreenshotProcessing = true;
      final prefs = await SharedPreferences.getInstance();
      final name = await prefs.getString('name');

      print('Screenshot detected');
      final token = await Get.find<UserController>().getToken();
      if (token != null && token.isNotEmpty) {
        await controller.sendMessage(
          token: token,
          conversationId: widget.conversationId,
          body: "[system] ${name ?? "User"} took a screenshot",
        );
      }

      Future.delayed(const Duration(seconds: 1), () {
        _isScreenshotProcessing = false;
      });
    });

    screenListener.watch();
  }

  @override
  void dispose() {
    controller.stopPolling();
    screenListener.dispose();
    _scrollController.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerConnection?.close();
    _peerConnection = null;
    super.dispose();
  }

  void handleDelete(String messageId) {
    controller.messages.removeWhere((message) => message.id == messageId);
    print('Deleted message with ID: $messageId');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final conversationController = Get.find<ConversationController>();
    final userController = Get.find<UserController>();
    final currentUserId = userController.currentUser.value?.id;
    final recipientID = _getRecipientId(
      conversationController.conversations.firstWhereOrNull((c) => c.id == widget.conversationId),
      currentUserId,
    );

    // 🔗 Attache la conversation pour le “typing” (une seule fois)
    if (!_typingAttached && recipientID.isNotEmpty) {
      controller.attachConversation(
        conversationId: widget.conversationId,
        otherUserId: recipientID,
      );
      _typingAttached = true;
    }

    return WillPopScope(
      onWillPop: () async {
        controller.stopPolling();
        return true;
      },
      child: Scaffold(
        // ⛔️ Empêche le redimensionnement du Scaffold quand le clavier apparaît
        resizeToAvoidBottomInset: false,
        backgroundColor: isDarkMode ? chatBackgroundDark : chatBackgroundLight,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: ChatRoomAppBar(
            userId: currentUserId ?? '',
            name: widget.name,
            phoneNumber: widget.phoneNumber,
            avatarUrl: widget.avatarUrl,
            conversationId: widget.conversationId,
            createdAt: widget.createdAt,
            recipientID: recipientID,
            backgroundColor: isDarkMode ? kDarkBgColor : kLightPrimaryColor,
          ),
        ),
        body: Stack(
          children: [
            // === Fond FIXE (ne bouge plus avec le clavier) ===
            Positioned.fill(
              child: Opacity(
                opacity: 0.9,
                child: Image.asset(
                  isDarkMode ? 'assets/chat_bg_dark.png' : 'assets/chat_bg_light.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // === Contenu qui se décale au-dessus du clavier ===
            Obx(() {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: controller.messages.isEmpty
                              ? Center(
                                  child: Text(
                                    "no_messages_yet".tr,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                )
                              : MessageList(
                                  bubbleColorOutgoing: isDarkMode ? bubbleOutgoingDark : bubbleOutgoingLight,
                                  bubbleColorIncoming: isDarkMode ? bubbleIncomingDark : bubbleIncomingLight,
                                  textColorOutgoing: isDarkMode ? Colors.white : Colors.black,
                                  textColorIncoming: isDarkMode ? Colors.white : Colors.black,
                                  timeTextStyle: TextStyle(
                                    fontSize: 10,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                  onDelete: (messageId) async {
                                    final token = await Get.find<UserController>().getToken();
                                    if (token != null && token.isNotEmpty) {
                                      await controller.deleteMessage(widget.conversationId, messageId, token);
                                      handleDelete(messageId);
                                    } else {
                                      Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                                      Get.toNamed(Routes.login);
                                    }
                                  },
                                  messages: controller.messages,
                                  scrollController: _scrollController,
                                  recipientId: recipientID, // ✓/✓✓/✓✓ bleus
                                ),
                        ),

                        // ⌨️ Bandeau "… est en train d'écrire"
                        Obx(() {
                          if (!controller.otherTyping.value) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 8, height: 8,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${widget.name} ${"is_typing".tr.isEmpty ? "is typing..." : "Entrain d'écrire ...".tr}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.white70 : Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        ChatInputArea(
                          backgroundColor: isDarkMode ? kDarkBgColor.withOpacity(0.95) : Colors.white,
                          iconColor: isDarkMode ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey),
                          inputBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          inputFillColor: isDarkMode ? Colors.grey[800]!.withOpacity(0.8) : Colors.grey[200]!.withOpacity(0.8),
                          inputTextStyle: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          isRecording: controller.isRecording,
                          isSending: isSending,

                          // ⌨️ Typing: onChanged -> controller
                          onChanged: (txt) => controller.handleTyping(text: txt),

                          onSend: (message) async {
                            if (message.trim().isEmpty) return;
                            HapticFeedback.selectionClick();

                            _forceScrollNextUpdate = true;

                            isSending.value = true;
                            final token = await Get.find<UserController>().getToken();
                            if (token != null && token.isNotEmpty) {
                              if (message.startsWith('@aibot')) {
                                final userQuery = message.replaceFirst('@aibot', '').trim();
                                if (userQuery.isNotEmpty) {
                                  await controller.sendAIChatbotMessage(
                                    token: token,
                                    conversationId: widget.conversationId,
                                    userMessage: userQuery,
                                  );
                                }
                              } else {
                                await controller.sendMessage(
                                  token: token,
                                  conversationId: widget.conversationId,
                                  body: message,
                                );
                              }
                            } else {
                              Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                              Get.toNamed(Routes.login);
                            }
                            isSending.value = false;
                          },
                          onAttachImage: (imageFile) async {
                            _forceScrollNextUpdate = true;

                            isSending.value = true;
                            final token = await Get.find<UserController>().getToken();
                            if (token != null && token.isNotEmpty) {
                              await controller.sendImage(
                                token: token,
                                conversationId: widget.conversationId,
                                imageFile: imageFile,
                              );
                            } else {
                              Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                              Get.toNamed(Routes.login);
                            }
                            isSending.value = false;
                          },
                          onAttachVideo: (videoFile) async {
                            _forceScrollNextUpdate = true;

                            isSending.value = true;
                            final token = await Get.find<UserController>().getToken();
                            if (token != null && token.isNotEmpty) {
                              await controller.sendVideo(
                                token: token,
                                conversationId: widget.conversationId,
                                videoFile: videoFile,
                              );
                            } else {
                              Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                              Get.toNamed(Routes.login);
                            }
                            isSending.value = false;
                          },
                          onStartRecording: () => controller.startRecording(),
                          onStopRecording: () async {
                            _forceScrollNextUpdate = true;

                            isSending.value = true;
                            final token = await Get.find<UserController>().getToken();
                            if (token != null && token.isNotEmpty) {
                              await controller.stopRecording(
                                token: token,
                                conversationId: widget.conversationId,
                              );
                            } else {
                              Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                              Get.toNamed(Routes.login);
                            }
                            isSending.value = false;
                          },
                          onDiscardRecording: () => controller.discardRecording(),
                        ),
                      ],
                    ),

                    // ===== Bouton flottant “⬇︎” + badge =====
                    Positioned(
                      right: 14,
                      bottom: 92, // au-dessus de l'input (suit l’AnimatedPadding)
                      child: IgnorePointer(
                        ignoring: !_showJumpDownBtn,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 140),
                          scale: _showJumpDownBtn ? 1.0 : 0.0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 140),
                            opacity: _showJumpDownBtn ? 1.0 : 0.0,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                FloatingActionButton(
                                  heroTag: 'jumpDownBtn_${ChatRoomPage}',
                                  mini: true,
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _newMsgBadge = 0;
                                    setState(() {});
                                    _jumpToBottom(smooth: true);
                                  },
                                  backgroundColor: theme.colorScheme.primary,
                                  child: const Icon(Icons.arrow_downward, color: Colors.white),
                                ),
                                if (_newMsgBadge > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      constraints: const BoxConstraints(minWidth: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _newMsgBadge > 99 ? '99+' : '$_newMsgBadge',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getRecipientId(Conversation? conversation, String? currentUserId) {
    if (conversation != null && conversation.userIds.isNotEmpty) {
      final recipientId = conversation.userIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => '',
      );
      print('RecipientID extracted: $recipientId from userIds: ${conversation.userIds}');
      return recipientId;
    }
    print('No recipientID found: conversation=$conversation, currentUserId=$currentUserId');
    return '';
  }
}
