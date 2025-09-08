import 'dart:io';
import 'package:bcalio/models/conversation_model.dart';
import 'package:bcalio/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:screen_capture_event/screen_capture_event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../../../controllers/chat_room_controller.dart';
import '../../../controllers/conversation_controller.dart';
import '../../../controllers/user_controller.dart';
import '../../../services/message_api_service.dart';
import '../../../widgets/chat/chat_room/chatRoomAppBar.dart';
import '../../../widgets/chat/chat_room/chat_input_area.dart';
import '../../../widgets/chat/chat_room/message_list.dart';

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
  final ScrollController _scrollController = ScrollController(initialScrollOffset: 1000000000);
  final RxBool isSending = false.obs;
  final ScreenCaptureEvent screenListener = ScreenCaptureEvent();
  late final ChatRoomController controller;

  // UI colors
  static const Color kLightPrimaryColor = Color(0xFF89C6C9);
  static const Color kDarkBgColor = Color.fromARGB(255, 0, 8, 8);
  static const Color bubbleOutgoingLight = Color(0xFFDCF8C6);
  static const Color bubbleIncomingLight = Color(0xFFFFFFFF);
  static const Color bubbleOutgoingDark = Color(0xFF075E54);
  static const Color bubbleIncomingDark = Color(0xFF1F2C34);
  static const Color chatBackgroundLight = Color(0xFFECE5DD);
  static const Color chatBackgroundDark = Color(0xFF0D1418);

  bool _stickToBottom = true;
  bool _forceScrollNextUpdate = false;
  bool _pendingInitialBottom = true;
  bool _showJumpDownBtn = false;
  int _newMsgBadge = 0;
  int _lastMsgCount = 0;

  bool _typingAttached = false;
  final RxBool _initialLoading = true.obs;

  // helpers scroll
  void _attachScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final distanceFromBottom = pos.maxScrollExtent - pos.pixels;

      final wasSticking = _stickToBottom;
      _stickToBottom = distanceFromBottom < 120;

      final show = !_stickToBottom && pos.maxScrollExtent > 0;
      if (show != _showJumpDownBtn) setState(() => _showJumpDownBtn = show);

      if (_stickToBottom && !wasSticking) {
        if (_newMsgBadge != 0) setState(() => _newMsgBadge = 0);
      }
    });
  }

  void _jumpToBottom({bool smooth = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (smooth) {
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _jumpToBottomHard({int retries = 6}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        if (retries > 0) Future.delayed(const Duration(milliseconds: 16), () => _jumpToBottomHard(retries: retries - 1));
        return;
      }
      try {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent + 100000);
      } catch (_) {}
      if (retries > 0) Future.delayed(const Duration(milliseconds: 16), () => _jumpToBottomHard(retries: retries - 1));
    });
  }

  @override
  void initState() {
    super.initState();
    _attachScrollListener();

    controller = Get.put(ChatRoomController(messageApiService: Get.find<MessageApiService>()), tag: widget.conversationId);

    controller.onMessagesUpdated = () {
      if (!mounted) return;
      final curLen = controller.messages.length;

      if (_pendingInitialBottom) {
        _pendingInitialBottom = false;
        _lastMsgCount = curLen;
        _jumpToBottomHard();
        return;
      }

      final delta = (curLen - _lastMsgCount).clamp(0, 1 << 30);
      _lastMsgCount = curLen;

      if (_forceScrollNextUpdate || _stickToBottom) {
        _jumpToBottom(smooth: !_forceScrollNextUpdate);
        _forceScrollNextUpdate = false;
        if (_newMsgBadge != 0) setState(() => _newMsgBadge = 0);
      } else {
        if (delta > 0) setState(() => _newMsgBadge += delta);
      }
    };

    final userController = Get.find<UserController>();
    Future.delayed(Duration.zero, () async {
      final token = await userController.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          _initialLoading.value = true;
          await controller.fetchMessages(token, widget.conversationId);
          final convCtrl = Get.find<ConversationController>();
          await convCtrl.markAsSeen(token: token, conversationId: widget.conversationId);
          controller.startPolling(token, widget.conversationId);
        } finally {
          _initialLoading.value = false;
        }
      } else {
        Get.snackbar('Error', 'Failed to retrieve token. Please log in again.', backgroundColor: Colors.red, colorText: Colors.white);
        Get.toNamed(Routes.login);
      }
    });

    // "screenshot taken" → message système
    screenListener.addScreenShotListener((_) async {
      final prefs = await SharedPreferences.getInstance();
      final name = await prefs.getString('name');
      final token = await Get.find<UserController>().getToken();
      if (token != null && token.isNotEmpty) {
        await controller.sendMessage(token: token, conversationId: widget.conversationId, body: "[system] ${name ?? "User"} took a screenshot");
      }
    });
    screenListener.watch();
  }

  @override
  void dispose() {
    controller.stopPolling();
    screenListener.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void handleDelete(String messageId) {
    controller.messages.removeWhere((m) => m.id == messageId);
  }

  Future<bool> _confirmMediaSheet({required String title, required File file, required bool isVideo}) async {
    final size = await file.length();
    final kb = (size / 1024).toStringAsFixed(1);
    return await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          maxChildSize: 0.9,
          minChildSize: 0.30,
          builder: (_, controllerSheet) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121416) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 10),
                ListTile(
                  leading: Icon(isVideo ? Icons.videocam_rounded : Icons.image_rounded, size: 28),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('$kb Ko'),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: isVideo
                        ? Center(child: Icon(Icons.ondemand_video_rounded, size: 96, color: theme.colorScheme.primary.withOpacity(0.6)))
                        : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(file, fit: BoxFit.contain)),
                  ),
                ),
                _sheetButtons(),
              ],
            ),
          ),
        );
      },
    ).then((v) => v ?? false);
  }

  Future<bool> _confirmPdfSheet({required File pdf}) async {
    final size = await pdf.length();
    final kb = (size / 1024).toStringAsFixed(1);
    final name = pdf.path.split('/').last;
    return await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121416) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, size: 28),
                title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('PDF • $kb Ko'),
              ),
              const SizedBox(height: 8),
              _sheetButtons(),
            ],
          ),
        );
      },
    ).then((v) => v ?? false);
  }

  Widget _sheetButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close_rounded), label: const Text('Annuler'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(true), icon: const Icon(Icons.send_rounded), label: const Text('Envoyer'))),
        ],
      ),
    );
  }

  bool _looksLikeVideo(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov') || p.endsWith('.avi') || p.endsWith('.mkv') || p.endsWith('.webm');
  }

  bool _looksLikePdf(String path) => path.toLowerCase().endsWith('.pdf');

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

    if (!_typingAttached && recipientID.isNotEmpty) {
      controller.attachConversation(conversationId: widget.conversationId, otherUserId: recipientID);
      _typingAttached = true;
    }

    final ImagePicker picker = ImagePicker();

    return WillPopScope(
      onWillPop: () async {
        controller.stopPolling();
        return true;
      },
      child: Scaffold(
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
            Positioned.fill(
              child: Opacity(
                opacity: 0.9,
                child: Image.asset(isDarkMode ? 'assets/chat_bg_dark.png' : 'assets/chat_bg_light.png', fit: BoxFit.cover),
              ),
            ),
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Obx(() {
                          if (_initialLoading.value) {
                            return _ModernSpinner(
                              primary: theme.colorScheme.primary,
                              secondary: theme.colorScheme.secondary,
                              background: (isDarkMode ? Colors.white10 : Colors.black12),
                            );
                          }
                          if (controller.messages.isEmpty) {
                            return Center(
                              child: Text(
                                "no_messages_yet".tr.isEmpty ? "No messages yet" : "no_messages_yet".tr,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            );
                          }
                          return MessageList(
                            bubbleColorOutgoing: isDarkMode ? bubbleOutgoingDark : bubbleOutgoingLight,
                            bubbleColorIncoming: isDarkMode ? bubbleIncomingDark : bubbleIncomingLight,
                            textColorOutgoing: isDarkMode ? Colors.white : Colors.black,
                            textColorIncoming: isDarkMode ? Colors.white : Colors.black,
                            timeTextStyle: TextStyle(fontSize: 10, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
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
                            recipientId: recipientID,
                          );
                        }),
                      ),

                      Obx(() {
                        if (!controller.otherTyping.value) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 8),
                              Text(
                                "${widget.name} ${"is_typing".tr.isEmpty ? "is typing..." : "is_typing".tr}",
                                style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white70 : Colors.black54, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        );
                      }),

                      ChatInputArea(
                        backgroundColor: isDarkMode ? kDarkBgColor.withOpacity(0.95) : Colors.white,
                        iconColor: isDarkMode ? (Colors.grey[400] ?? Colors.grey) : (Colors.grey[600] ?? Colors.grey),
                        inputBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        inputFillColor: isDarkMode ? Colors.grey[800]!.withOpacity(0.8) : Colors.grey[200]!.withOpacity(0.8),
                        inputTextStyle: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black),
                        isRecording: controller.isRecording,
                        isSending: isSending,
                        onChanged: (txt) => controller.handleTyping(text: txt),

                        // Gallerie (image/vidéo/PDF)
                        onTapGallery: () async {
                          try {
                            final XFile? picked = await picker.pickMedia();
                            if (picked == null) return;
                            final path = picked.path;

                            if (_looksLikePdf(path)) {
                              final ok = await _confirmPdfSheet(pdf: File(path));
                              if (!ok) return;

                              final token = await Get.find<UserController>().getToken();
                              if (token == null || token.isEmpty) {
                                Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                                Get.toNamed(Routes.login);
                                return;
                              }

                              final fileName = path.split('/').last;
                              final uploadedUrl = await controller.uploadPdfAndGetUrl(File(path));
                              if (uploadedUrl == null || uploadedUrl.isEmpty) {
                                Get.snackbar('Error', 'PDF upload failed', backgroundColor: Colors.red, colorText: Colors.white);
                                return;
                              }

                              _forceScrollNextUpdate = true;
                              isSending.value = true;
                              await controller.sendMessage(
                                token: token,
                                conversationId: widget.conversationId,
                                body: "[file] $fileName|$uploadedUrl",
                              );
                              isSending.value = false;
                              return;
                            }

                            final bool isVideo = _looksLikeVideo(path);
                            final ok = await _confirmMediaSheet(
                              title: isVideo ? 'Vidéo sélectionnée' : 'Image sélectionnée',
                              file: File(path),
                              isVideo: isVideo,
                            );
                            if (!ok) return;

                            _forceScrollNextUpdate = true;
                            isSending.value = true;

                            final token = await Get.find<UserController>().getToken();
                            if (token == null || token.isEmpty) {
                              Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                              Get.toNamed(Routes.login);
                              isSending.value = false;
                              return;
                            }

                            if (isVideo) {
                              await controller.sendVideo(token: token, conversationId: widget.conversationId, videoFile: File(path));
                            } else {
                              await controller.sendImage(token: token, conversationId: widget.conversationId, imageFile: File(path));
                            }
                          } catch (e) {
                            Get.snackbar('Error', 'Picker error: $e', backgroundColor: Colors.red, colorText: Colors.white);
                          } finally {
                            isSending.value = false;
                          }
                        },

                        // Envoi texte
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
                                await controller.sendAIChatbotMessage(token: token, conversationId: widget.conversationId, userMessage: userQuery);
                              }
                            } else {
                              await controller.sendMessage(token: token, conversationId: widget.conversationId, body: message);
                            }
                          } else {
                            Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                            Get.toNamed(Routes.login);
                          }
                          isSending.value = false;
                        },

                        // Trombone: IMAGE
                        onAttachImage: (imageFile) async {
                          final path = imageFile.path;
                          if (_looksLikePdf(path)) {
                            final ok = await _confirmPdfSheet(pdf: imageFile);
                            if (!ok) return;

                            final token = await Get.find<UserController>().getToken();
                            if (token == null || token.isEmpty) {
                              Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                              Get.toNamed(Routes.login);
                              return;
                            }

                            final fileName = path.split('/').last;
                            final uploadedUrl = await controller.uploadPdfAndGetUrl(File(path));
                            if (uploadedUrl == null || uploadedUrl.isEmpty) {
                              Get.snackbar('Error', 'PDF upload failed', backgroundColor: Colors.red, colorText: Colors.white);
                              return;
                            }

                            _forceScrollNextUpdate = true;
                            isSending.value = true;
                            await controller.sendMessage(
                              token: token,
                              conversationId: widget.conversationId,
                              body: "[file] $fileName|$uploadedUrl",
                            );
                            isSending.value = false;
                            return;
                          }

                          final ok = await _confirmMediaSheet(title: 'Image sélectionnée', file: imageFile, isVideo: false);
                          if (!ok) return;

                          _forceScrollNextUpdate = true;
                          isSending.value = true;
                          final token = await Get.find<UserController>().getToken();
                          if (token != null && token.isNotEmpty) {
                            await controller.sendImage(token: token, conversationId: widget.conversationId, imageFile: imageFile);
                          } else {
                            Get.snackbar('Error', 'Failed to retrieve token.', backgroundColor: Colors.red, colorText: Colors.white);
                            Get.toNamed(Routes.login);
                          }
                          isSending.value = false;
                        },

                        // Trombone: VIDEO
                        onAttachVideo: (videoFile) async {
                          final ok = await _confirmMediaSheet(title: 'Vidéo sélectionnée', file: videoFile, isVideo: true);
                          if (!ok) return;

                          _forceScrollNextUpdate = true;
                          isSending.value = true;
                          final token = await Get.find<UserController>().getToken();
                          if (token != null && token.isNotEmpty) {
                            await controller.sendVideo(token: token, conversationId: widget.conversationId, videoFile: videoFile);
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
                            await controller.stopRecording(token: token, conversationId: widget.conversationId);
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

                  Positioned(
                    right: 14,
                    bottom: 92,
                    child: IgnorePointer(
                      ignoring: !_showJumpDownBtn,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 140),
                        scale: _showJumpDownBtn ? 1.0 : 0.0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 140),
                          opacity: _showJumpDownBtn ? 1.0 : 0.0,
                          child: FloatingActionButton(
                            heroTag: 'jumpDownBtn_ChatRoomPage',
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
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRecipientId(Conversation? conversation, String? currentUserId) {
    if (conversation != null && conversation.userIds.isNotEmpty) {
      final recipientId = conversation.userIds.firstWhere((id) => id != currentUserId, orElse: () => '');
      return recipientId;
    }
    return '';
  }
}

class _ModernSpinner extends StatelessWidget {
  final Color primary;
  final Color secondary;
  final Color background;

  const _ModernSpinner({required this.primary, required this.secondary, required this.background});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(width: 46, height: 46, child: CircularProgressIndicator(strokeWidth: 4)),
      ),
    );
  }
}
