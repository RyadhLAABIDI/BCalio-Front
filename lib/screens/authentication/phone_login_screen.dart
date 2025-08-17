import 'package:bcalio/themes/theme.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../services/sms_verification_service.dart';
import '../../utils/misc.dart';
import '../../widgets/base_widget/custom_snack_bar.dart';
import '../../widgets/base_widget/primary_button.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<PhoneLoginPage> {
  final _userController = Get.find<UserController>();
  final _themeController = Get.find<ThemeController>();
  final _phoneController = TextEditingController();
  PhoneNumber number = PhoneNumber(countryCode: "216", countryISOCode: "TN", number: '');
  bool _loading = false;
  FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = _themeController.isDarkMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "verify_phone".tr,
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
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Column(
                children: [
                Lottie.asset('assets/json/phone_number.json'),
                const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  Text(
                    "verification_message".tr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(duration: 1000.ms, delay: 200.ms),
                  const SizedBox(height: 30),
                  _buildPhoneNumberInput(theme, isDarkMode)
                      .animate()
                      .fadeIn(duration: 1200.ms, delay: 400.ms),
                  const SizedBox(height: 40),
                  PrimaryButton(
                    title: "next".tr,
                    onPressed: _submitPhoneNumber,
                  ).animate().fadeIn(duration: 1400.ms, delay: 600.ms),
                ],
              ),
            ),
            if (_loading)
              Container(
                color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneNumberInput(ThemeData theme, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IntlPhoneField(
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: "phone_number_hint".tr,
          hintStyle: GoogleFonts.poppins(
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
        ),
        initialCountryCode: "TN",
        onChanged: (phone) {
          print(phone.completeNumber);
        },
        onSaved: (newValue) => number = newValue!,
        onCountryChanged: (country) {
          print('Country changed to: ' + country.name);
        },
        controller: _phoneController,
      ),
    );
  }

  void _submitPhoneNumber() async {
    setState(() => _loading = true);
    final phoneNumber = "+${number.countryCode} ${_phoneController.text.trim()}";
    debugPrint("phone ============$phoneNumber");
    final smsService = SmsVerificationService();
    final otp = smsService.generateOTP();
    final isOTPSent = await smsService.sendOTP(phoneNumber, otp);
    setState(() => _loading = false);
    if (isOTPSent) {
      showSuccessSnackbar("OTP sent to $phoneNumber");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isForgotPassword', false);
      Get.toNamed('/otpVerification', arguments: {'phoneNumber': phoneNumber, 'otp': otp});
    } else {
      showErrorSnackbar("failed_to_send_OTP._please_try_again.".tr);
    }
  }
}