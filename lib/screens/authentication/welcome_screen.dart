import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/user_controller.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/base_widget/primary_button.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final UserController userController = Get.find<UserController>();
  final LocalStorageService localStorageService = Get.find<LocalStorageService>();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    await userController.autoLogin();
    setState(() {
      isLoading = false;
    });
    if (userController.currentUser.value != null) {
      Get.offAllNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.scaffoldBackgroundColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Logo avec animation
                Image.asset(
                  "assets/img/logo.png",
                  width: 180,
                  height: 180,
                )
                    .animate()
                    .fadeIn(duration: 800.ms)
                    .scale(curve: Curves.easeInOut),
                const SizedBox(height: 20),
                // Message de bienvenue
                Text(
                  "welcome_message".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 1000.ms, delay: 200.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 40),
                // Carte des fonctionnalités avec effet glassmorphism
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        theme: theme,
                        imagePath: "assets/3d_icons/lock_icon.png",
                        title: "feature_secure_title".tr,
                        description: "feature_secure_description".tr,
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureItem(
                        theme: theme,
                        imagePath: "assets/3d_icons/phone_icon.png",
                        title: "feature_support_title".tr,
                        description: "feature_support_description".tr,
                      ),
                      const SizedBox(height: 20),
                      _buildFeatureItem(
                        theme: theme,
                        imagePath: "assets/3d_icons/group_icon.png",
                        title: "feature_connected_title".tr,
                        description: "feature_connected_description".tr,
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 1200.ms, delay: 400.ms),
                const SizedBox(height: 40),
                // Bouton "Agree and Continue"
                if (!isLoading && userController.currentUser.value == null)
                  PrimaryButton(
                    title: "agree_and_continue".tr,
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isFirstTime', false);
                      Get.toNamed('/login');
                    },
                  )
                      .animate()
                      .fadeIn(duration: 1400.ms, delay: 600.ms)
                      .scale(),
                const SizedBox(height: 20),
                // Footer
                Text(
                  "footer_powered_by".tr,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 1600.ms, delay: 800.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required ThemeData theme,
    required String imagePath,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Image.asset(
          imagePath,
          width: 40,
          height: 40,
        ).animate().fadeIn(duration: 1000.ms).scale(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}