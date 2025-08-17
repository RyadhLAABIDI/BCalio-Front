import 'package:bcalio/controllers/chatbot_controller.dart';
import 'package:bcalio/controllers/conversation_controller.dart';
import 'package:bcalio/controllers/theme_controller.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/routes.dart';
import 'package:bcalio/screens/contacts/all_contacts_screen.dart';
import 'package:bcalio/themes/theme.dart';
import 'package:bcalio/widgets/base_widget/custom_search_bar.dart';
import 'package:bcalio/widgets/chat_bot/chat_bot_modal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

class MapAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ThemeController themeController = Get.find<ThemeController>();
  final UserController userController = Get.find<UserController>();
  final ConversationController conversationController =
      Get.find<ConversationController>();
  final ChatbotController chatbotController = Get.find<ChatbotController>();

  RxBool isSearching = false.obs;
  TextEditingController textController = TextEditingController();
  FocusNode focusNode = FocusNode();

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AppBar(
      flexibleSpace: Container(
        color: isDarkMode ? kDarkBgColor : kLightPrimaryColor,
      ),
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      title: Image.asset(
        "assets/img/logo.png",
        width: 80,
        height: 80,
      ),
      actions: [
        Obx(() {
          if (!isSearching.value) {
            return Row(
              children: [
                IconButton(
                  splashRadius: 24,
                  onPressed: () => Get.to(SafeArea(
                    child: Scaffold(body: AllContactsScreen()),
                  )),
                  icon: Icon(
                    Icons.search,
                    color: isDarkMode ? Colors.white : kDarkBgColor,
                    size: 24,
                  ),
                ),
                SizedBox(
                  width: 10,
                ),
                GestureDetector(
                  onTap: () => _showChatbotModal(context),
                  child: Lottie.asset(
                    'assets/json/robot.json',
                    width: 45,
                  ),
                ),
                SizedBox(
                  width: 16,
                )
              ],
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}