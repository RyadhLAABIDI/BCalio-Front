import 'package:bcalio/controllers/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showCustomDialog(BuildContext context, String? title, String? content,
    String? actionText, Function? action) {
  final theme = Theme.of(context);

  final _themeController = Get.find<ThemeController>();
  final isDarkMode = _themeController.isDarkMode;
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
    ),
    isScrollControlled: true,
    builder: (context) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 22.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
        ),
        width: MediaQuery.sizeOf(context).width,
        height: MediaQuery.sizeOf(context).height * 0.3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                title!.tr,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 37,
            ),
            Expanded(
              child: Text(
                content!.tr,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
              ),
            ),
            SizedBox(
              height: 60,
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: PrimaryButtonText(
                      color: Colors.grey,
                      title: "No".tr,
                      onPressed: () async {
                        Get.back();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  Expanded(
                    child: PrimaryButtonText(
                      title: actionText!.tr,
                      onPressed: () async {
                        action!();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

void showCustomDialogVertical(
    BuildContext context, String? title, String? content, Function? action) {
  final theme = Theme.of(context);

  final _themeController = Get.find<ThemeController>();
  final isDarkMode = _themeController.isDarkMode;
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
    ),
    isScrollControlled: true,
    builder: (context) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 22.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
        ),
        width: MediaQuery.sizeOf(context).width,
        height: MediaQuery.sizeOf(context).height * 0.35,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Text(
              title!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              height: 20,
            ),
            Text(
              content!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 30),
            PrimaryButtonText(
              title: "inviter_par_sms".tr,
              onPressed: () {
                action!();
              },
            ),
            SizedBox(
              height: 20,
            ), // Second Button with "Pas maintenant"
            PrimaryButtonText(
              title: "pas_maintenant".tr,
              color: theme.scaffoldBackgroundColor,
              colorText:
                  theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
              isDisabled: true,
              onPressed: () {
                Get.back();
              },
            ),
          ],
        ),
      );
    },
  );
}

class PrimaryButtonText extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed; // Nullable for disabled state
  final bool isDisabled;
  final bool? isOutlined;
  final Color? color;
  final Color? colorText;
  const PrimaryButtonText({
    super.key,
    required this.title,
    required this.onPressed,
    this.isDisabled = false,
    this.color,
    this.isOutlined = false,
    this.colorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final _themeController = Get.find<ThemeController>();
    final isDarkMode = _themeController.isDarkMode;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ??
            theme.elevatedButtonTheme.style!.backgroundColor!.resolve({}),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        elevation: 4,
      ),
      child: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: colorText ?? (isDarkMode ? Colors.black : Colors.white),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
