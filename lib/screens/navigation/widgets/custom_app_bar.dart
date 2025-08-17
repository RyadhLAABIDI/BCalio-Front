import 'package:bcalio/controllers/chatbot_controller.dart';
import 'package:bcalio/controllers/conversation_controller.dart';
import 'package:bcalio/controllers/theme_controller.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/screens/chat/group_chat/create_group_chat_screen.dart';
import 'package:bcalio/themes/theme.dart';
import 'package:bcalio/widgets/chat_bot/chat_bot_modal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ThemeController themeController = Get.find<ThemeController>();
  final UserController userController = Get.find<UserController>();
  final ConversationController conversationController =
      Get.find<ConversationController>();
  final ChatbotController chatbotController = Get.find<ChatbotController>();
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  CustomAppBar({
    super.key,
  });

  void _showChatbotModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.3,
            maxChildSize: 1.0,
            expand: false,
            builder: (context, scrollController) {
              return ChatbotModal(
                scrollController: scrollController,
                chatbotController: chatbotController,
                textController: textController,
                focusNode: focusNode,
              );
            },
          ),
        );
      },
    );
  }

  void _navigateToCreateGroupWithAnimation() {
    Get.to(
      () => CreateGroupChatScreen(),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return AppBar(
      flexibleSpace: Container(
        color: isDarkMode ? kDarkBgColor : kLightPrimaryColor,
      ),
      title: Text(
        "Chats".tr,
        style: theme.textTheme.titleLarge?.copyWith(
          color: isDarkMode ? Colors.white : kDarkBgColor,
        ),
      ),
      actions: [
        Row(
          children: [
            IconButton(
              splashRadius: 24,
              onPressed: _navigateToCreateGroupWithAnimation,
              icon: Icon(
                Icons.group_add,
                color: isDarkMode ? Colors.white : kDarkBgColor,
              ),
            ),
            const SizedBox(
              width: 16,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}