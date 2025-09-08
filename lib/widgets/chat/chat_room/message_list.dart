import 'dart:convert';
import 'dart:io';
import 'package:bcalio/screens/chat/ChatRoom/full_screen_video_viewer.dart';
import 'package:chewie/chewie.dart'; // utilisé dans le viewer plein écran
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_player/video_player.dart'; // aperçu figé (pas de lecture inline)
import 'package:url_launcher/url_launcher_string.dart';

// ⬇️⬇️ NOUVEAU: on va distinguer les liens de ton API vs liens publics
import 'package:bcalio/utils/misc.dart'; // pour baseUrl

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RxInt _playingIndex = RxInt(-1);
  final Map<int, bool> _showTimestamp = {};

  // Contrôleurs pour **aperçu vidéo figé** (un par URL)
  final Map<String, VideoPlayerController> _videoPreviews = {};
  final Map<String, Future<void>> _videoInitFutures = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLocalOptimistic(String id) => id.startsWith('local-');

  bool _looksLikeVideoUrl(String url) {
    final u = url.toLowerCase();
    return RegExp(r'\.(mp4|mov|mkv|webm|avi)(\?|$)').hasMatch(u) || u.contains('/video/upload');
  }

  bool _looksLikeAudioUrl(String url) {
    final u = url.toLowerCase();
    return RegExp(r'\.(m4a|mp3|aac|wav|ogg)(\?|$)').hasMatch(u) || (u.contains('/raw/upload') && u.contains('/audio'));
  }

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

  bool _sameSender(Message a, Message b) => a.senderId == b.senderId && a.isFromAI == b.isFromAI;

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
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    // Libère proprement les contrôleurs vidéo d’aperçu
    for (final c in _videoPreviews.values) {
      c.dispose();
    }
    _videoPreviews.clear();
    _videoInitFutures.clear();
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
        _audioPlayer.onPlayerComplete.listen((_) => _playingIndex.value = -1);
      } catch (e) {
        Get.snackbar("Error", "Failed to play audio: $e", snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  String decodeMessage(String body) {
    try {
      return utf8.decode(body.codeUnits);
    } catch (_) {
      return body;
    }
  }

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Iconsax.copy, size: 24),
                title: Text("Copy".tr, style: const TextStyle(fontSize: 16)),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.body));
                  Get.snackbar("Copied".tr, "Message copied to clipboard".tr,
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      colorText: Colors.white);
                  if (context.mounted) Navigator.pop(context);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text("Delete Message".tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to delete this message?".tr),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel".tr)),
            TextButton(
              onPressed: () {
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

  Widget _bubbleStatus({
    required Message message,
    required String? recipientId,
    required bool showVuLabelOnlyHere,
  }) {
    if (_isLocalOptimistic(message.id)) {
      return const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2));
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
            Text('Vu', style: TextStyle(fontSize: 11, color: Colors.blue.withOpacity(0.95), fontWeight: FontWeight.w500)),
          ],
        ],
      );
    }

    if (isDelivered) return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    return const Icon(Icons.done, size: 16, color: Colors.grey);
  }

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
          style: (widget.timeTextStyle).copyWith(fontSize: 11, color: timeColor ?? widget.timeTextStyle.color),
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

  // Assure l'initialisation (unique) d’un contrôleur d’aperçu pour une URL
  Future<void> _ensurePreviewController(String videoUrl) {
    if (_videoInitFutures.containsKey(videoUrl)) {
      return _videoInitFutures[videoUrl]!;
    }
    final ctrl = VideoPlayerController.network(videoUrl);
    _videoPreviews[videoUrl] = ctrl;

    final f = ctrl.initialize().then((_) async {
      // on s’assure d’être à 0, muet, et en pause (aperçu figé)
      await ctrl.setVolume(0);
      await ctrl.pause();
      await ctrl.seekTo(Duration.zero);
    });

    _videoInitFutures[videoUrl] = f;
    return f;
  }

  // ========== TÉLÉCHARGEMENT: pas d’auth pour les liens publics, Bearer uniquement pour ton API ==========
  Future<void> _downloadFile(String url, String suggestedName) async {
    if (url.isEmpty) {
      Get.snackbar('Error', 'Invalid file URL',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    try {
      Get.snackbar('Downloading', 'Please wait…', snackPosition: SnackPosition.BOTTOM);

      final uri = Uri.parse(url);
      final apiHost = Uri.parse(baseUrl).host; // host de l’API (ex: app.b-callio.com)

      // 1) Prépare les headers uniquement si on tape TON API
      Map<String, String> headers = {};
      if (uri.host == apiHost) {
        final token = await Get.find<UserController>().getToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }

      // 2) Requête principale
      http.Response resp = await http.get(uri, headers: headers);

      // 3) Si 401 et on avait mis Authorization, retente SANS Authorization (certains proxys/CDN renvoient 401 dès qu’ils voient ce header)
      if (resp.statusCode == 401 && headers.containsKey('Authorization')) {
        try {
          resp = await http.get(uri); // sans header
        } catch (_) {}
      }

      // 4) Dernier recours: si toujours pas OK (401/403), ouvre dans le navigateur/app externe
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
        return;
      }

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      // Détermine le nom de fichier à partir du header Content-Disposition si dispo
      String fileName = suggestedName.isNotEmpty ? suggestedName : 'file_${DateTime.now().millisecondsSinceEpoch}';
      final cd = resp.headers['content-disposition'] ?? resp.headers['Content-Disposition'];
      if (cd != null) {
        final match = RegExp(r'filename\*?="?([^";]+)"?').firstMatch(cd);
        if (match != null) {
          fileName = match.group(1) ?? fileName;
        }
      }

      // Sauvegarde dans le répertoire app (pas besoin de permissions dangereuses)
      Directory dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(resp.bodyBytes);

      Get.snackbar('Saved', 'Saved to: ${file.path}',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      // Si exception → on laisse l’OS gérer via ouverture externe
      try {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } catch (_) {
        Get.snackbar('Error', 'Download failed: $e',
            snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      }
    }
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
          final m = widget.messages[index];

          // ----- système -----
          if (m.body.startsWith('[system]')) {
            final cleanBody = m.body.replaceFirst('[system]', '').trim();
            return Padding(
              padding: EdgeInsets.fromLTRB(16, _isSameAsPrev(index) ? 8 : 16, 16, _isSameAsNext(index) ? 6 : 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: isDarkMode ? Colors.grey[800] : Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    utf8.decode(cleanBody.runes.toList()),
                    style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.w400),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          final currentUserId = me?.id;
          final isMe = m.senderId == currentUserId && !m.isFromAI;
          final showVuHere = isMe && (index == lastOutgoingSeenIndex);

          final body = decodeMessage(m.body);
          final imageRaw = (m.image ?? '').trim();
          final audioRaw = (m.audio ?? '').trim();
          final videoRaw = (m.video ?? '').trim();

          String pickFirst(String s) => (s.contains(' ')) ? s.split(' ').first : s;

          // vidéo ?
          String videoUrl = '';
          if (videoRaw.isNotEmpty && _looksLikeVideoUrl(pickFirst(videoRaw))) {
            videoUrl = pickFirst(videoRaw);
          } else if (imageRaw.isNotEmpty && _looksLikeVideoUrl(pickFirst(imageRaw))) {
            videoUrl = pickFirst(imageRaw);
          } else if (body.startsWith('[video] ')) {
            final maybe = body.substring(8).trim();
            if (_looksLikeVideoUrl(pickFirst(maybe))) videoUrl = pickFirst(maybe);
          }

          // audio ?
          String audioUrl = '';
          if (audioRaw.isNotEmpty && _looksLikeAudioUrl(pickFirst(audioRaw))) {
            audioUrl = pickFirst(audioRaw);
          } else if (imageRaw.isNotEmpty && _looksLikeAudioUrl(pickFirst(imageRaw))) {
            audioUrl = pickFirst(imageRaw);
          }

          // image ?
          String imageUrl = '';
          if (imageRaw.isNotEmpty) {
            final first = pickFirst(imageRaw);
            if (!_looksLikeVideoUrl(first) && !_looksLikeAudioUrl(first)) {
              imageUrl = first;
            }
          }

          // avatar
          final senderAvatar = isMe ? (me?.image ?? '') : (m.sender?.image ?? '');
          final avatarWidget = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (senderAvatar.isNotEmpty) ? NetworkImage(senderAvatar) : null,
              child: senderAvatar.isEmpty
                  ? Text(
                      (isMe ? (me?.name ?? 'Me') : (m.sender?.name ?? 'U')).trim().characters.first.toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                    )
                  : null,
            ),
          );

          final samePrev = _isSameAsPrev(index);
          final sameNext = _isSameAsNext(index);

          // ----- VIDÉO (aperçu figé, pas de lecture dans la bulle) -----
          if (videoUrl.isNotEmpty) {
            final bubble = GestureDetector(
              onTap: () {
                // 👉 Ouvre le lecteur plein écran qui lit la vidéo
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => FullScreenVideoViewer(videoUrl: videoUrl)),
                );
              },
              onLongPress: () => _showMessageOptions(context, m),
              child: _buildVideoPreviewBubble(
                videoUrl: videoUrl, // ⬅️ on passe l’URL pour afficher la première frame
                isMe: isMe,
                samePrev: samePrev,
                sameNext: sameNext,
                meta: _metaOverlayForMedia(
                  message: m,
                  isMe: isMe,
                  recipientId: oneToOneRecipientId,
                  showVuLabelOnlyHere: showVuHere,
                ),
              ),
            );
            return _messageLine(isMe: isMe, avatar: avatarWidget, bubble: bubble, sameNext: sameNext);
          }

          // ----- AUDIO -----
          if (audioUrl.isNotEmpty) {
            final bubble = GestureDetector(
              onLongPress: () => _showMessageOptions(context, m),
              child: _buildAudioBubble(
                index: index,
                audioUrl: audioUrl,
                isMe: isMe,
                theme: theme,
                samePrev: samePrev,
                sameNext: sameNext,
                meta: _metaRow(
                  message: m,
                  isMe: isMe,
                  recipientId: oneToOneRecipientId,
                  showVuLabelOnlyHere: showVuHere,
                ),
              ),
            );
            return _messageLine(isMe: isMe, avatar: avatarWidget, bubble: bubble, sameNext: sameNext);
          }

          // ----- DOCUMENT "[file] Nom.ext|URL"  → clique = TÉLÉCHARGER -----
          if (body.startsWith('[file] ')) {
            final payload = body.substring(7);
            final sep = payload.indexOf('|');
            final fileName = sep > 0 ? payload.substring(0, sep) : payload;
            final url = sep > 0 ? payload.substring(sep + 1) : '';

            final chip = InkWell(
              onTap: () => _downloadFile(url, fileName),
              onLongPress: () => _showMessageOptions(context, m),
              child: _buildDocBubble(
                fileName: fileName,
                isMe: isMe,
                samePrev: samePrev,
                sameNext: sameNext,
                meta: _metaRow(
                  message: m,
                  isMe: isMe,
                  recipientId: oneToOneRecipientId,
                  showVuLabelOnlyHere: showVuHere,
                ),
              ),
            );
            return _messageLine(isMe: isMe, avatar: avatarWidget, bubble: chip, sameNext: sameNext);
          }

          // ----- IMAGE -----
          if (imageUrl.isNotEmpty) {
            final bubble = GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: imageUrl)));
              },
              onLongPress: () => _showMessageOptions(context, m),
              child: _buildImageBubble(
                imageUrl: imageUrl,
                isMe: isMe,
                samePrev: samePrev,
                sameNext: sameNext,
                meta: _metaRow(
                  message: m,
                  isMe: isMe,
                  recipientId: oneToOneRecipientId,
                  showVuLabelOnlyHere: showVuHere,
                  timeColor: Colors.white.withOpacity(0.95),
                ),
              ),
            );
            return _messageLine(isMe: isMe, avatar: avatarWidget, bubble: bubble, sameNext: sameNext);
          }

          // ----- TEXTE -----
          final bubble = GestureDetector(
            onTap: () {
              setState(() {
                _showTimestamp[index] = !(_showTimestamp[index] ?? false);
                if (_showTimestamp[index] == true) {
                  _animationController.forward();
                } else {
                  _animationController.reverse();
                }
              });
            },
            onLongPress: () => _showMessageOptions(context, m),
            child: _buildTextBubble(
              text: body.isNotEmpty ? body : '[No content]',
              isMe: isMe,
              samePrev: samePrev,
              sameNext: sameNext,
              meta: _metaRow(
                message: m,
                isMe: isMe,
                recipientId: oneToOneRecipientId,
                showVuLabelOnlyHere: showVuHere,
              ),
            ),
          );
          return _messageLine(isMe: isMe, avatar: avatarWidget, bubble: bubble, sameNext: sameNext);
        },
      );
    });
  }

  // ---------- helpers ligne ----------
  Widget _messageLine({required bool isMe, required Widget avatar, required Widget bubble, required bool sameNext}) {
    final line = Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: isMe ? <Widget>[Flexible(child: bubble), const SizedBox(width: 6), avatar] : <Widget>[avatar, Flexible(child: bubble)],
    );

    final topSpace = 14.0;
    final bottomSpace = sameNext ? 6.0 : 10.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, topSpace, 8, bottomSpace),
      child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [line]),
    );
  }

  // ======================================================
  // ===============  BUILDERS DES BULLES  ================
  // ======================================================

  BorderRadius _smartRadius({required bool isMe, required bool samePrev, required bool sameNext}) {
    const rFull = 16.0;
    const rTight = 7.0;
    return BorderRadius.only(
      topLeft: Radius.circular(isMe ? rFull : (samePrev ? rTight : rFull)),
      topRight: Radius.circular(isMe ? (samePrev ? rTight : rFull) : rFull),
      bottomLeft: Radius.circular(isMe ? rFull : (sameNext ? rTight : rFull)),
      bottomRight: Radius.circular(isMe ? (sameNext ? rTight : rFull) : rFull),
    );
  }

  BoxDecoration _bubbleDecoration({required bool isMe, required bool samePrev, required bool sameNext}) {
    final base = isMe ? widget.bubbleColorOutgoing : widget.bubbleColorIncoming;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_lighten(base, 0.10), base, _darken(base, 0.06)],
      ),
      borderRadius: _smartRadius(isMe: isMe, samePrev: samePrev, sameNext: sameNext),
      border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 4)),
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
      ],
    );
  }

  Widget _tail({required bool isMe, required bool show}) {
    if (!show) return const SizedBox.shrink();
    final base = isMe ? widget.bubbleColorOutgoing : widget.bubbleColorIncoming;
    return SizedBox(width: 8, height: 10, child: CustomPaint(painter: _TrianglePainter(color: _darken(base, 0.04), isRight: isMe)));
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
        constraints: const BoxConstraints(maxWidth: 240),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(text, style: TextStyle(fontSize: 15, color: textColor, height: 1.22))),
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
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
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
                return Container(width: 200, height: 200, color: Colors.black12, child: const Center(child: CircularProgressIndicator()));
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(width: 200, height: 200, color: Colors.grey[300], child: const Icon(Iconsax.image, size: 40));
              },
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(10)),
                child: DefaultTextStyle(style: const TextStyle(fontSize: 11, color: Colors.white), child: meta),
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

  Widget _buildDocBubble({
    required String fileName,
    required bool isMe,
    required bool samePrev,
    required bool sameNext,
    required Widget meta,
  }) {
    final deco = _bubbleDecoration(isMe: isMe, samePrev: samePrev, sameNext: sameNext).copyWith(
      gradient: null,
      color: (isMe ? Colors.blue[50] : Colors.grey[100])?.withOpacity(0.9),
    );

    final core = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: deco,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.blue),
                const SizedBox(width: 8),
                Flexible(child: Text(fileName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                const Icon(Icons.download_rounded, color: Colors.blue),
              ],
            ),
            const SizedBox(height: 6),
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
                      icon: Icon(_playingIndex.value == index ? Iconsax.pause : Iconsax.play, color: textColor, size: 22),
                      onPressed: () => _togglePlayPause(index, audioUrl),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    )),
                const SizedBox(width: 6),
                Expanded(child: Text("Voice message", overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: textColor))),
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

  /// 🧊 Bulle vidéo : **aperçu figé** (première frame), pas de lecture inline
  Widget _buildVideoPreviewBubble({
    required String videoUrl,
    required bool isMe,
    required bool samePrev,
    required bool sameNext,
    required Widget meta,
  }) {
    final radius = _smartRadius(isMe: isMe, samePrev: samePrev, sameNext: sameNext);

    final box = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      width: 220,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // FutureBuilder → affiche la première frame quand dispo
            FutureBuilder<void>(
              future: _ensurePreviewController(videoUrl),
              builder: (context, snap) {
                final ctrl = _videoPreviews[videoUrl];
                if (snap.connectionState == ConnectionState.done && ctrl != null && ctrl.value.isInitialized) {
                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: ctrl.value.size.width,
                      height: ctrl.value.size.height,
                      child: VideoPlayer(ctrl), // figé (pause) → première frame visible
                    ),
                  );
                }
                if (snap.hasError) {
                  return Container(
                    color: Colors.black12,
                    child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 40)),
                  );
                }
                return Container(
                  color: Colors.black12,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),
            // Icône Play en surimpression
            const Center(
              child: Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white70),
            ),
            // méta (heure, ticks)
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(10)),
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
        box,
        if (isMe) _tail(isMe: true, show: !sameNext),
      ],
    );
  }
}

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
