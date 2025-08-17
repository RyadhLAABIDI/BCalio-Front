import 'package:bcalio/controllers/theme_controller.dart';
import 'package:bcalio/widgets/base_widget/show_custom_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../controllers/user_controller.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userController = Get.find<UserController>();

    return Container(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          iconAlignment: IconAlignment.start,
          alignment: Alignment.centerLeft,
          backgroundColor:
              theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: Size(double.infinity, 50),
        ),
        onPressed: () async {
          showCustomDialog(
              context, "Logout", "Are you sure you want to log out?", "Yes",
              () async {
            await userController.logout();
          });
        },
        icon: const Icon(Iconsax.logout, size: 24, color: Colors.white),
        label: Row(
          children: [
            // const SizedBox(width: 20),
            Text("Logout".tr),
            Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
