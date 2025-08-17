import 'dart:convert';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart';

import '../../../controllers/user_controller.dart';
import '../../../models/true_message_model.dart';
import 'full_screen_image_viewer.dart';

class MessageList extends StatefulWidget {
  final RxList<Message> messages;
  final void Function(String messageId) onDelete;
  final ScrollController scrollController;
  final Color bubbleColorOutgoing;
  final Color bubbleColorIncoming;
  final Color textColorOutgoing;
  final Color textColorIncoming;
  final TextStyle timeTextStyle;

  /// NEW: id du destinataire (1:1). Laisse vide/null pour un groupe.
  final String? recipientId;

  const MessageList({
    super.key,
    required this.messages,
    required this.onDelete,
    required this.scrollController,
    required this.bubbleColorOutgoing,
    required this.bubbleColorIncoming,
    required this.textColorOutgoing,
    required this.textColorIncoming,
    required this.timeTextStyle,
    this.recipientId,
  });

  @override
  _MessageListState createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RxInt _playingIndex = RxInt(-1);
  final Map<int, bool> _showTimestamp = {};
  late VideoPlayerController _videoPlayerController;
  late ChewieController _chewieController;
  int? _currentVideoIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLocalOptimistic(String id) => id.startsWith('local-');

  // ---------- UI helpers (couleurs & grouping) ----------
  Color _lighten(Color c, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(c);
    final lighter = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lighter.toColor();
  }

  Color _darken(Color c, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(c);
    final darker = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darker.toColor();
  }

  bool _sameSender(Message a, Message b) =>
      a.senderId == b.senderId && a.isFromAI == b.isFromAI;

  bool _isSameAsPrev(int index) {
    if (index <= 0) return false;
    return _sameSender(widget.messages[index], widget.messages[index - 1]);
  }

  bool _isSameAsNext(int index) {
    if (index >= widget.messages.length - 1) return false;
    return _sameSender(widget.messages[index], widget.messages[index + 1]);
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    if (_currentVideoIndex != null) {
      _videoPlayerController.dispose();
      _chewieController.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  String formatTimestamp(DateTime timestamp) {
    final hours = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    return "$hours:${timestamp.minute.toString().padLeft(2, '0')} $period";
  }

  void _togglePlayPause(int index, String audioUrl) async {
    if (_playingIndex.value == index) {
      await _audioPlayer.pause();
      _playingIndex.value = -1;
    } else {
      await _audioPlayer.stop();
      try {
        await _audioPlayer.setSourceUrl(audioUrl);
        _audioPlayer.play(UrlSource(audioUrl));
        _playingIndex.value = index;
        _audioPlayer.onPlayerComplete.listen((_) {
          _playingIndex.value = -1;
        });
      } catch (e) {
        Get.snackbar("Error", "Failed to play audio: $e",
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  String decodeMessage(String lastMessage) {
    try {
      return utf8.decode(lastMessage.codeUnits);
    } catch (e) {
      return lastMessage;
    }
  }

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Iconsax.copy, size: 24),
                title: Text("Copy".tr, style: const TextStyle(fontSize: 16)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.body));
                  Get.snackbar("Copied".tr, "Message copied to clipboard".tr,
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      colorText: Colors.white);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Iconsax.trash, color: Colors.red, size: 24),
                title: Text("Delete".tr, style: const TextStyle(fontSize: 16, color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, message);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, Message message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text("Delete Message".tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to delete this message?".tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel".tr, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            ),
            TextButton(
              onPressed: () {
                debugPrint("Message ID to delete: ${message.id}");
                widget.onDelete(message.id);
                Navigator.pop(context);
              },
              child: Text("Delete".tr, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// Icône(s) de statut dans la bulle (✓ / ✓✓ gris / ✓✓ bleu) + option “Vu”
  Widget _bubbleStatus({
    required Message message,
    required String? recipientId,
    required bool showVuLabelOnlyHere,
  }) {
    if (_isLocalOptimistic(message.id)) {
      return const SizedBox(
        width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final hasRecipient = recipientId != null && recipientId.isNotEmpty;

    bool isRead = false;
    bool isDelivered = false;

    if (hasRecipient) {
      isRead = (message.seenBy?.any((u) => u.id == recipientId) ?? false);
      final online = Get.find<UserController>().isOnline(recipientId!);
      isDelivered = isRead || online;
    } else {
      final seenCount = message.seenBy?.length ?? 0;
      isRead = seenCount >= 2;
      isDelivered = isRead;
    }

    if (isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.done_all, size: 16, color: Colors.blue),
          if (showVuLabelOnlyHere) ...[
            const SizedBox(width: 4),
            Text(
              'Vu',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.withOpacity(0.95),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
    }

    if (isDelivered) {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    }

    return const Icon(Icons.done, size: 16, color: Colors.grey);
  }

  /// Sous-ligne (heure + status) qui vit **dans** la bulle
  Widget _metaRow({
    required Message message,
    required bool isMe,
    required String? recipientId,
    required bool showVuLabelOnlyHere,
    Color? timeColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          formatTimestamp(message.createdAt),
          style: (widget.timeTextStyle).copyWith(
            fontSize: 11,
            color: timeColor ?? widget.timeTextStyle.color,
          ),
        ),
        const SizedBox(width: 6),
        if (isMe)
          _bubbleStatus(
            message: message,
            recipientId: recipientId,
            showVuLabelOnlyHere: showVuLabelOnlyHere,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final me = Get.find<UserController>().currentUser.value;
    final oneToOneRecipientId = widget.recipientId ?? '';

    return Obx(() {
      if (oneToOneRecipientId.isNotEmpty) {
        // ignore: unused_local_variable
        final _ = Get.find<UserController>().online[oneToOneRecipientId];
      }

      // Dernier message sortant lu (pour afficher “Vu” uniquement là)
      int lastOutgoingSeenIndex = -1;
      for (int i = 0; i < widget.messages.length; i++) {
        final m = widget.messages[i];
        if (m.senderId == me?.id && !m.isFromAI) {
          bool read;
          if (oneToOneRecipientId.isNotEmpty) {
            read = (m.seenBy?.any((u) => u.id == oneToOneRecipientId) ?? false);
          } else {
            read = (m.seenBy?.length ?? 0) >= 2;
          }
          if (read) lastOutgoingSeenIndex = i;
        }
      }

      return ListView.builder(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          final message = widget.messages[index];

          // system
          if (message.body.startsWith('[system]')) {
            final cleanBody = message.body.replaceFirst('[system]', '').trim();
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                _isSameAsPrev(index) ? 8 : 16,
                16,
                _isSameAsNext(index) ? 6 : 12,
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    utf8.decode(cleanBody.runes.toList()),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final currentUserId = me?.id;
          final isMe = message.senderId == currentUserId && !message.isFromAI;
          final showVuHere = isMe && (index == lastOutgoingSeenIndex);

          final body = decodeMessage(message.body);
          final image = message.image;
          String? audio;
          String? video;
          if (message.audio != null &&
              message.audio!.toLowerCase().contains("audio")) {
            audio = message.audio;
          } else {
            video = message.audio;
          }

          void _onMessageTap() {
            setState(() {
              _showTimestamp[index] = !(_showTimestamp[index] ?? false);
              if (_showTimestamp[index] == true) {
                _animationController.forward();
              } else {
                _animationController.reverse();
              }
            });
          }

          // ====== AVATAR ======
          final senderAvatar =
              isMe ? (me?.image ?? '') : (message.sender?.image ?? '');
          final avatarWidget = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (senderAvatar.isNotEmpty)
                  ? NetworkImage(senderAvatar)
                  : null,
              child: senderAvatar.isEmpty
                  ? Text(
                      (isMe ? (me?.name ?? 'Me') : (message.sender?.name ?? 'U'))
                          .trim()
                          .characters
                          .first
                          .toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                    )
                  : null,
            ),
          );

          // ====== Bulle ======
          final samePrev = _isSameAsPrev(index);
          final sameNext = _isSameAsNext(index);

          Widget bubble;
          if (image != null && image.isNotEmpty) {
            bubble = GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(imageUrl: image),
                  ),
                );
              },
              onLongPress: () => _showMessageOptions(context, message),
              child: _buildImageBubble(
                imageUrl: image,
                isMe: isMe,
                samePrev: samePrev,
                sameNext: sameNext,
                meta: _metaRow(
                  message: message,
                  isMe: isMe,
                  recipientId: oneToOneRecipientId,
                  showVuLabelOnlyHere: showVuHere,
                  timeColor: Colors.white.withOpacity(0.95),
                ),
              ),
            );
          } else if (audio != null && audio.isNotEmpty) {
            bubble = GestureDetector(
              onLongPress: () => _showMessageOptions(context, message),
              child: _buildAudioBubble(
                index: index,
                audioUrl: audio,
                isMe: isMe,
                theme: theme,
                samePrev: samePrev,
                sameNext: sameNext,
                meta: _metaRow(
                  message: message,
                  isMe: isMe,
                  recipientId: oneToOneRecipientId,
                  showVuLabelOnlyHere: showVuHere,
                ),
              ),
            );
          } else if (video != null && video.isNotEmpty) {
            bubble = GestureDetector(
              onLongPress: () => _showMessageOptions(context, message),
              child: _buildVideoBubble(
                index: index,
                videoUrl: video,
                isMe: isMe,
                samePrev: samePrev,
                sameNext: sameNext,
                meta: _metaOverlayForMedia(
                  message: message,
                  isMe: isMe,
                  recipientId: oneToOneRecipientId,
                  showVuLabelOnlyHere: showVuHere,
                ),
              ),
            );
          } else {
            bubble = GestureDetector(
              onTap: _onMessageTap,
              onLongPress: () => _showMessageOptions(context, message),
              child: _buildTextBubble(
                text: body.isNotEmpty ? body : '[No content]',
                isMe: isMe,
                samePrev: samePrev,
                sameNext: sameNext,
                meta: _metaRow(
                  message: message,
                  isMe: isMe,
                  recipientId: oneToOneRecipientId,
                  showVuLabelOnlyHere: showVuHere,
                ),
              ),
            );
          }

          // ====== LIGNE message + avatar ======
          final line = Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: isMe
                ? <Widget>[
                    Flexible(child: bubble),
                    const SizedBox(width: 6),
                    avatarWidget,
                  ]
                : <Widget>[
                    avatarWidget,
                    Flexible(child: bubble),
                  ],
          );

          // Espacements : compacts mais lisibles
          final topSpace = samePrev ? 6.0 : 14.0;
          final bottomSpace = sameNext ? 6.0 : 10.0;

          return Padding(
            padding: EdgeInsets.fromLTRB(8, topSpace, 8, bottomSpace),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                line,
              ],
            ),
          );
        },
      );
    });
  }

  // ======================================================
  // ===============  BUILDERS DES BULLES  ================
  // ======================================================

  BorderRadius _smartRadius({
    required bool isMe,
    required bool samePrev,
    required bool sameNext,
  }) {
    // coins serrés quand groupés
    final rFull = 16.0;
    final rTight = 7.0;

    return BorderRadius.only(
      topLeft: Radius.circular(isMe ? rFull : (samePrev ? rTight : rFull)),
      topRight: Radius.circular(isMe ? (samePrev ? rTight : rFull) : rFull),
      bottomLeft: Radius.circular(isMe ? rFull : (sameNext ? rTight : rFull)),
      bottomRight: Radius.circular(isMe ? (sameNext ? rTight : rFull) : rFull),
    );
  }

  Decoration _bubbleDecoration({
    required bool isMe,
    required bool samePrev,
    required bool sameNext,
  }) {
    final base = isMe ? widget.bubbleColorOutgoing : widget.bubbleColorIncoming;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _lighten(base, 0.10),
          base,
          _darken(base, 0.06),
        ],
      ),
      borderRadius: _smartRadius(isMe: isMe, samePrev: samePrev, sameNext: sameNext),
      border: Border.all(
        color: Colors.white.withOpacity(0.06),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget _tail({
    required bool isMe,
    required bool show,
  }) {
    if (!show) return const SizedBox.shrink();
    final base = isMe ? widget.bubbleColorOutgoing : widget.bubbleColorIncoming;
    return SizedBox(
      width: 8,
      height: 10,
      child: CustomPaint(
        painter: _TrianglePainter(
          color: _darken(base, 0.04),
          isRight: isMe,
        ),
      ),
    );
  }

  Widget _buildTextBubble({
    required String text,
    required bool isMe,
    required bool samePrev,
    required bool sameNext,
    required Widget meta,
  }) {
    final textColor = isMe ? widget.textColorOutgoing : widget.textColorIncoming;

    final bubbleCore = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _bubbleDecoration(isMe: isMe, samePrev: samePrev, sameNext: sameNext),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: TextStyle(fontSize: 15, color: textColor, height: 1.22),
              ),
            ),
            const SizedBox(height: 4),
            meta,
          ],
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMe) _tail(isMe: false, show: !sameNext),
        Flexible(child: bubbleCore),
        if (isMe) _tail(isMe: true, show: !sameNext),
      ],
    );
  }

  Widget _buildImageBubble({
    required String imageUrl,
    required bool isMe,
    required bool samePrev,
    required bool sameNext,
    required Widget meta,
  }) {
    final borderRadius = _smartRadius(isMe: isMe, samePrev: samePrev, sameNext: sameNext);

    final imageBox = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Image.network(
              imageUrl,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.black12,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Iconsax.image, size: 40),
                );
              },
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  child: meta,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMe) _tail(isMe: false, show: !sameNext),
        imageBox,
        if (isMe) _tail(isMe: true, show: !sameNext),
      ],
    );
  }

  Widget _buildAudioBubble({
    required int index,
    required String audioUrl,
    required bool isMe,
    required ThemeData theme,
    required bool samePrev,
    required bool sameNext,
    required Widget meta,
  }) {
    final textColor = isMe ? Colors.white : theme.colorScheme.onSurface;

    final core = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _bubbleDecoration(isMe: isMe, samePrev: samePrev, sameNext: sameNext),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Obx(() => IconButton(
                      icon: Icon(
                        _playingIndex.value == index ? Iconsax.pause : Iconsax.play,
                        color: textColor,
                        size: 22,
                      ),
                      onPressed: () => _togglePlayPause(index, audioUrl),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    )),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Voice message",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: textColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            meta,
          ],
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMe) _tail(isMe: false, show: !sameNext),
        Flexible(child: core),
        if (isMe) _tail(isMe: true, show: !sameNext),
      ],
    );
  }

  Widget _metaOverlayForMedia({
    required Message message,
    required bool isMe,
    required String? recipientId,
    required bool showVuLabelOnlyHere,
  }) {
    return _metaRow(
      message: message,
      isMe: isMe,
      recipientId: recipientId,
      showVuLabelOnlyHere: showVuLabelOnlyHere,
      timeColor: Colors.white.withOpacity(0.95),
    );
  }

  Widget _buildVideoBubble({
    required int index,
    required String videoUrl,
    required bool isMe,
    required bool samePrev,
    required bool sameNext,
    required Widget meta,
  }) {
    if (_currentVideoIndex != index) {
      _currentVideoIndex = index;
      _videoPlayerController = VideoPlayerController.network(videoUrl);
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: false,
        looping: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[400]!,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
        autoInitialize: true,
      );
    }

    final videoBox = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      width: 220,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: _smartRadius(isMe: isMe, samePrev: samePrev, sameNext: sameNext),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _smartRadius(isMe: isMe, samePrev: samePrev, sameNext: sameNext),
        child: Stack(
          children: [
            Chewie(controller: _chewieController),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: meta,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMe) _tail(isMe: false, show: !sameNext),
        videoBox,
        if (isMe) _tail(isMe: true, show: !sameNext),
      ],
    );
  }
}

/// Petit painter pour la “queue” de bulle (triangle)
class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool isRight;
  _TrianglePainter({required this.color, required this.isRight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isRight) {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(0, 0);
    } else {
      path.moveTo(size.width, size.height);
      path.lineTo(0, size.height / 2);
      path.lineTo(size.width, 0);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isRight != isRight;
  }
}
