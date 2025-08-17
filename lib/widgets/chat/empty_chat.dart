import 'package:bcalio/controllers/chatbot_controller.dart';
import 'package:bcalio/widgets/chat_bot/chat_bot_modal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class EmptyChatList extends StatefulWidget {
  const EmptyChatList({super.key});

  @override
  State<EmptyChatList> createState() => _EmptyChatListState();
}

class _EmptyChatListState extends State<EmptyChatList>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isModalOpen = false;
  GlobalKey _robotKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      }
    });
    
    _animationController.repeat(reverse: true);
  }

  void _showChatbotModal(BuildContext context) {
    if (_isModalOpen) return;

    setState(() => _isModalOpen = true);

    // Get robot position for shared element transition
    final RenderBox renderBox = _robotKey.currentContext?.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    Future.delayed(const Duration(milliseconds: 100), () {
      final chatbotController = Get.find<ChatbotController>();
      final textController = TextEditingController();
      final focusNode = FocusNode();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        builder: (context) {
          return ChatbotModal(
            scrollController: ScrollController(),
            chatbotController: chatbotController,
            textController: textController,
            focusNode: focusNode,
            robotPosition: position,
          );
        },
      ).then((_) {
        setState(() => _isModalOpen = false);
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 84,
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 25),
              Text(
                'no_chats_yet'.tr,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 100,
          right: 30,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: () => _showChatbotModal(context),
              child: Container(
                key: _robotKey,
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: Center(
                  child: Lottie.asset(
                    'assets/json/robot.json',
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
