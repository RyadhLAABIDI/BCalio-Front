import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_indicator/loading_indicator.dart';
import '../../controllers/theme_controller.dart';
import '../../themes/theme.dart';

class CustomLoadingIndicator extends StatelessWidget {
  final ThemeController themeController = Get.find<ThemeController>();

  CustomLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeController.isDarkMode;

    return Center(
      child: SizedBox(
        height: 60, // Adjust size as needed
        width: 60,
        child: LoadingIndicator(
          indicatorType: Indicator.ballClipRotatePulse,
          colors: [
            isDarkMode ? kDarkPrimaryColor : Colors.black,
          ],
          strokeWidth: 2,
          backgroundColor: isDarkMode ? kDarkBgColor : kLightBgColor,
        ),
      ),
    );
  }
}
