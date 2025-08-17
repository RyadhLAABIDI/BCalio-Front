import 'package:bcalio/controllers/chatbot_controller.dart';
import 'package:bcalio/controllers/conversation_controller.dart';
import 'package:bcalio/controllers/theme_controller.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/screens/contacts/Add_Contact_screen.dart';
import 'package:bcalio/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';

class AllContactAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ThemeController themeController = Get.find<ThemeController>();
  final UserController userController = Get.find<UserController>();
  final ConversationController conversationController =
      Get.find<ConversationController>();
  final ChatbotController chatbotController = Get.find<ChatbotController>();

  AllContactAppBar({super.key});
  
  void _navigateToAddContactWithAdvancedAnimation(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>  AddContactScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Même animation que dans ProfileSection
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: curve));
          
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
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
        "All Contacts".tr,
        style: theme.textTheme.titleLarge?.copyWith(
          color: isDarkMode ? Colors.white : kDarkBgColor,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            Iconsax.user_add,
            color: isDarkMode ? Colors.white : kDarkBgColor,
          ),
          onPressed: () => _navigateToAddContactWithAdvancedAnimation(context),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}