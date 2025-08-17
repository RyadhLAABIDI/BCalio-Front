import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bcalio/controllers/chatbot_controller.dart';
import 'package:bcalio/themes/theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

class ChatbotModal extends StatefulWidget {
  final ScrollController scrollController;
  final ChatbotController chatbotController;
  final TextEditingController textController;
  final FocusNode focusNode;
  final Offset? robotPosition;

  const ChatbotModal({
    Key? key,
    required this.scrollController,
    required this.chatbotController,
    required this.textController,
    required this.focusNode,
    this.robotPosition,
  }) : super(key: key);

  @override
  State<ChatbotModal> createState() => _ChatbotModalState();
}

class _ChatbotModalState extends State<ChatbotModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showOverlay = false;
  String _overlayText = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  void showCustomOverlay(String message) {
    setState(() {
      _showOverlay = true;
      _overlayText = message;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _confirmClearConversation() {
    showDialog(
      context: context,
      builder: (context) {
        return Animate(
          effects: [
            ScaleEffect(
              duration: 300.ms,
              curve: Curves.easeOutBack,
              begin: const Offset(0.8, 0.8),
            ),
            FadeEffect(duration: 200.ms),
          ],
          child: AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text('clear_conversation'.tr,
                style: Theme.of(context).textTheme.titleLarge),
            content: Text('clear_conversation_confirmation'.tr,
                style: Theme.of(context).textTheme.bodyMedium),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr,
                    style: TextStyle(color: Theme.of(context).hintColor)),
              ),
              TextButton(
                onPressed: () {
                  widget.chatbotController.clearConversation();
                  Navigator.pop(context);
                  showCustomOverlay('conversation_cleared'.tr);
                },
                child: Text('clear'.tr,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final modalHeight = screenSize.height * 0.85;

    return Animate(
      effects: [
        ScaleEffect(
          begin: const Offset(0.95, 0.95),
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        ),
        FadeEffect(duration: 300.ms),
      ],
      child: Container(
        height: modalHeight,
        decoration: BoxDecoration(
          color: isDarkMode ? kDarkBgColor : kLightBgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: isDarkMode
                ? const ColorFilter.mode(Colors.black38, BlendMode.darken)
                : const ColorFilter.mode(Colors.white54, BlendMode.lighten),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? kDarkPrimaryColor : kLightPrimaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      // Icône robot dans l'en-tête (conservée avec fond)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDarkMode ? const Color.fromARGB(255, 0, 6, 11) : Colors.blue[100],
                        ),
                        child: Center(
                          child: Lottie.asset(
                            'assets/json/robot.json',
                            width: 30,
                            height: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'BCalio-AI',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Animate(
                        effects: [
                          ScaleEffect(
                            delay: 200.ms,
                            duration: 300.ms,
                            curve: Curves.elasticOut,
                          )
                        ],
                        child: IconButton(
                          icon: Text(
                            '🗑️',
                            style: TextStyle(
                              fontSize: 24,
                              shadows: [
                                Shadow(
                                  color: isDarkMode ? Colors.white24 : Colors.black26,
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          onPressed: _confirmClearConversation,
                        ),
                      ),
                      IconButton(
                        icon: Text(
                          '✕',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                            shadows: [
                              Shadow(
                                color: isDarkMode ? Colors.white24 : Colors.black26,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icône robot dans le message d'introduction (conservée avec fond)
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode ? const Color.fromARGB(255, 108, 110, 113) : Colors.blue[100],
                                ),
                                child: Center(
                                  child: Lottie.asset(
                                    'assets/json/robot.json',
                                    width: 24,
                                    height: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hi! I\'m your AI assistant',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ask me anything, and I\'ll help you find answers',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Obx(() {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (widget.scrollController.hasClients) {
                                widget.scrollController.jumpTo(
                                  widget.scrollController.position.maxScrollExtent,
                                );
                              }
                            });

                            if (widget.chatbotController.messages.isEmpty) {
                              return FadeTransition(
                                opacity: _fadeAnimation,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/img/icons8-image-non-disponible-96.png',
                                        width: 120,
                                        height: 120,
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'conversation_empty'.tr,
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: widget.scrollController,
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: widget.chatbotController.messages.length,
                              itemBuilder: (context, index) {
                                final message =
                                    widget.chatbotController.messages[index];
                                final isUserMessage = message.startsWith("You: ");
                                final messageText = message.replaceFirst(
                                    RegExp(r'You: |AI: '), '');

                                return Animate(
                                  effects: [
                                    SlideEffect(
                                      begin: Offset(isUserMessage ? 0.5 : -0.5, 0),
                                      duration: 300.ms,
                                      curve: Curves.easeOutCubic,
                                    ),
                                    FadeEffect(
                                      duration: 250.ms,
                                      curve: Curves.easeIn,
                                    )
                                  ],
                                  child: _buildMessageBubble(
                                    context,
                                    isUserMessage,
                                    messageText,
                                  ),
                                );
                              },
                            );
                          }),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                            top: 12,
                          ),
                          child: _buildInputField(context),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    bool isUserMessage,
    String messageText,
  ) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUserMessage)
            // Icône robot sans fond ni cercle
            Lottie.asset(
              'assets/json/robot.json',
              width: 36,
              height: 36,
            ),
          if (!isUserMessage) const SizedBox(width: 12),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUserMessage
                    ? (isDarkMode ? const Color(0xFFF5F5DC) : Colors.blue[500])
                    : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUserMessage
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isUserMessage
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    messageText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUserMessage ? (isDarkMode ? Colors.black : Colors.white) : theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: messageText));
                          showCustomOverlay("texte_copié".tr);
                        },
                        child: Icon(
                          Icons.content_copy,
                          size: 16,
                          color: isUserMessage
                              ? (isDarkMode ? Colors.grey[600] : Colors.white70)
                              : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUserMessage) const SizedBox(width: 12),
          if (isUserMessage)
            // Icône utilisateur sans fond ni cercle
            Image.asset(
              'assets/3d_icons/user_icon.png',
              width: 36,
              height: 36,
              filterQuality: FilterQuality.high,
            ),
        ],
      ),
    );
  }

  Widget _buildInputField(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.textController,
              focusNode: widget.focusNode,
              onChanged: (value) =>
                  widget.chatbotController.userInput.value = value,
              decoration: InputDecoration(
                hintText: "type_a_message".tr,
                hintStyle: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.5),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          Obx(() {
            return widget.chatbotController.isLoading.value
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      color: isDarkMode ? kDarkPrimaryColor : kLightPrimaryColor,
                    ),
                  )
                : IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode ? kDarkPrimaryColor : kLightPrimaryColor,
                      ),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                    onPressed: () async {
                      widget.focusNode.unfocus();
                      widget.textController.clear();
                      await widget.chatbotController
                          .sendMessage(widget.chatbotController.userInput.value);
                    },
                  );
          }),
        ],
      ),
    );
  }
}