import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'attachment_options.dart';

class ChatInputArea extends StatefulWidget {
  final void Function(String message) onSend;
  final void Function(File imageFile) onAttachImage;
  final void Function(File videoFile) onAttachVideo;
  final void Function() onStartRecording;
  final void Function() onStopRecording;
  final void Function() onDiscardRecording;
  final RxBool isRecording;
  final RxBool isSending;
  final Color backgroundColor;
  final Color iconColor;
  final OutlineInputBorder inputBorder;
  final Color inputFillColor;
  final TextStyle inputTextStyle;

  // NEW: callback de saisie (pour “typing”)
  final ValueChanged<String>? onChanged;

  ChatInputArea({
    super.key,
    required this.onSend,
    required this.onAttachImage,
    required this.onAttachVideo,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onDiscardRecording,
    required this.isRecording,
    required this.isSending,
    required this.backgroundColor,
    required this.iconColor,
    required this.inputBorder,
    required this.inputFillColor,
    required this.inputTextStyle,
    this.onChanged, // NEW
  });

  @override
  State<ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<ChatInputArea> with SingleTickerProviderStateMixin {
  late AnimationController _waveAnimationController;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isTextEmpty = true;

  @override
  void initState() {
    super.initState();
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _messageController.addListener(() {
      final isEmptyNow = _messageController.text.trim().isEmpty;
      if (isEmptyNow != _isTextEmpty) {
        setState(() => _isTextEmpty = isEmptyNow);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _messageController.dispose();
    _waveAnimationController.dispose();
    super.dispose();
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
          ),
          child: AttachmentOptions(
            onAttachImage: widget.onAttachImage,
            onAttachVideo: widget.onAttachVideo,
            onStartRecording: widget.onStartRecording,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Obx(() {
      if (widget.isRecording.value) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.4).animate(_waveAnimationController),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withOpacity(0.4),
                      ),
                    ),
                  ),
                  const Icon(Iconsax.microphone, color: Colors.red, size: 28),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Recording...".tr,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  widget.isRecording.value = false;
                  widget.onStopRecording();
                },
                icon: Icon(
                  Iconsax.tick_circle,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                tooltip: 'Stop Recording',
              ),
              IconButton(
                onPressed: widget.onDiscardRecording,
                icon: const Icon(
                  Iconsax.close_circle,
                  color: Colors.red,
                  size: 28,
                ),
                tooltip: 'Discard Recording',
              ),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _showAttachmentOptions(context),
              icon: Icon(
                Iconsax.paperclip_2,
                color: widget.iconColor,
                size: 24,
              ),
              tooltip: 'Attach',
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.inputFillColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  focusNode: _focusNode,
                  controller: _messageController,
                  maxLines: null,
                  onChanged: widget.onChanged, // NEW: propage la saisie
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintText: "Type a message".tr,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    border: widget.inputBorder,
                    enabledBorder: widget.inputBorder,
                    focusedBorder: widget.inputBorder,
                  ),
                  style: widget.inputTextStyle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isTextEmpty
                  ? () {
                      widget.isRecording.value = true;
                      widget.onStartRecording();
                    }
                  : () {
                      final message = _messageController.text.trim();
                      if (message.isNotEmpty) {
                        _messageController.clear();
                        // NEW: prévenir controller que le champ est vide → stop-typing
                        widget.onChanged?.call('');
                        widget.onSend(message);
                      }
                    },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.appBarTheme.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: widget.isSending.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _isTextEmpty ? Iconsax.microphone : Iconsax.send_1,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
