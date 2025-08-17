import 'package:bcalio/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/theme_controller.dart';
import '../../widgets/base_widget/otp_loading_indicator.dart';
import '../../widgets/base_widget/primary_button.dart';
import '../../widgets/base_widget/custom_snack_bar.dart';
import 'new_password_screen.dart';

class OTPVerificationPage extends StatefulWidget {
  const OTPVerificationPage({super.key});

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final ThemeController themeController = Get.find<ThemeController>();
  final TextEditingController _pinController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "otp_verification".tr,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? theme.colorScheme.onSurface : Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [kDarkBgColor, kDarkBgColor.withOpacity(0.8)]
                : [kLightPrimaryColor.withOpacity(0.9), kLightBgColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Text(
                      "verify_phone".tr,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 800.ms),
                    const SizedBox(height: 10),
                    Text(
                      "enter_otp_message".tr,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(duration: 1000.ms, delay: 200.ms),
                    const SizedBox(height: 40),
                    Pinput(
                      controller: _pinController,
                      length: 6,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                      submittedPinTheme: submittedPinTheme,
                      validator: (pin) {
                        if (pin?.length == 6) return null;
                        return "invalid_OTP".tr;
                      },
                      pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                      onCompleted: (pin) {
                        debugPrint("Completed: $pin");
                      },
                    ).animate().fadeIn(duration: 1200.ms, delay: 400.ms),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _clearOTPFields,
                        child: Text(
                          "clear_code".tr,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 1400.ms, delay: 600.ms),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      title: "verify".tr,
                      onPressed: _verifyOTP,
                    ).animate().fadeIn(duration: 1600.ms, delay: 800.ms),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            if (_loading) const OtpLoadingIndicator(),
          ],
        ),
      ),
    );
  }

  void _clearOTPFields() {
    _pinController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _verifyOTP() async {
    setState(() => _loading = true);
    final enteredOtp = _pinController.text.trim();
    final expectedOtp = Get.arguments['otp'];
    if (enteredOtp == expectedOtp) {
      showSuccessSnackbar("OTP_verified_successfully!".tr);
      final prefs = await SharedPreferences.getInstance();
      final isForgotPassword = prefs.getBool('isForgotPassword') ?? false;
      debugPrint("isForgotPassword: $isForgotPassword");
      isForgotPassword
          ? Get.to(const NewPasswordPage())
          : Get.toNamed('/createProfile', arguments: {'phoneNumber': Get.arguments['phoneNumber']});
    } else {
      showErrorSnackbar("invalid_OTP_please_try_again.".tr);
    }
    setState(() => _loading = false);
  }
}