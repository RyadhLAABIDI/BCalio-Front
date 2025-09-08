import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:bcalio/screens/authentication/forgot_password_screen.dart';
import 'package:bcalio/screens/authentication/phone_login_screen.dart';
import 'package:bcalio/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../controllers/user_controller.dart';
import '../../utils/misc.dart';
import '../../widgets/base_widget/input_field.dart';
import '../../widgets/base_widget/otp_loading_indicator.dart';
import '../../widgets/base_widget/primary_button.dart';

// 🌐 Onboarding langues
import 'package:bcalio/screens/onboarding/language_onboarding_screen.dart'; // <-- ajuste si besoin

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final UserController userController = Get.find<UserController>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final PageController _featureController = PageController();

  bool isPasswordVisible = false;
  RxBool isChecked = false.obs;

  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late Timer _carouselTimer;

  final List<EmojiParticle> _emojis = [];
  final List<String> emojiList = ['✉️', '📧', '💬', '📱', '🔒', '👤', '🔑', '🌐'];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _createEmojis();
    loadRememberedCredentials();

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_featureController.hasClients) {
        final currentPage = _featureController.page?.round() ?? 0;
        final nextPage = currentPage + 1;
        if (nextPage < 9) {
          _featureController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        } else {
          _featureController.jumpToPage(0);
        }
      }
    });
  }

  void _initAnimations() {
    _waveController = AnimationController(vsync: this, duration: 4.seconds)..repeat(reverse: true);
    _waveAnimation = Tween(begin: -20.0, end: 20.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOutSine),
    );
  }

  void _createEmojis() {
    for (int i = 0; i < 20; i++) {
      _emojis.add(EmojiParticle(emoji: emojiList[i % emojiList.length]));
    }
  }

  @override
  void dispose() {
    _carouselTimer.cancel();
    _waveController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  bool areFieldsValid() => emailController.text.isNotEmpty && passwordController.text.isNotEmpty;

  Future<void> toggleRememberMe(bool? value) async {
    if (!areFieldsValid()) return;
    final prefs = await SharedPreferences.getInstance();
    isChecked.value = value ?? false;
    await prefs.setBool('rememberMe', isChecked.value);
    loadRememberedCredentials();
    setState(() {});
  }

  Future<void> loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    if (rememberMe) {
      if (emailController.text.isEmpty && passwordController.text.isEmpty) {
        emailController.text = prefs.getString('email') ?? '';
        passwordController.text = prefs.getString('password') ?? '';
      }
      isChecked.value = true;
    }
    setState(() {});
  }

  void _navigateToForgotPassword() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: 800.ms,
        reverseTransitionDuration: 500.ms,
        pageBuilder: (_, __, ___) => const ForgotPasswordPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _navigateToSignUp() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: 1000.ms,
        reverseTransitionDuration: 600.ms,
        pageBuilder: (_, __, ___) => const PhoneLoginPage(),
        transitionsBuilder: (_, animation, __, child) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }

  // 🌐 ➜ Transition premium vers LanguageOnboardingPage
  void _goToLanguage() {
    Navigator.of(context).push(_fancyLanguageRoute(const LanguageOnboardingPage()));
  }

  PageRouteBuilder _fancyLanguageRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, anim, secondary) => page,
      transitionsBuilder: (context, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return Stack(
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.95, end: 1).animate(curved),
              child: child,
            ),
            ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final textScale = MediaQuery.textScaleFactorOf(context);

    final headerHeight = clampDouble(screenSize.height * 0.28, 180, 260);
    final pageViewHeight = clampDouble(screenSize.height * 0.16 * min(textScale, 1.3), 110, 170);

    return Obx(() {
      final isLoading = userController.isLoading.value;
      return Scaffold(
        backgroundColor: isDarkMode ? kDarkBgColor : kLightBgColor,
        resizeToAvoidBottomInset: true,
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
              // 1) fond emojis
              AnimatedBuilder(
                animation: _waveController,
                builder: (_, __) => CustomPaint(
                  painter: EmojiPainter(
                    emojis: _emojis,
                    time: DateTime.now().millisecondsSinceEpoch / 1000,
                  ),
                  size: Size.infinite,
                ),
              ),

              // 2) vague basse
              Positioned(
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _waveAnimation,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _waveAnimation.value),
                    child: SizedBox(
                      width: screenSize.width,
                      child: CustomPaint(
                        painter: WavePainter(
                          color: isDarkMode
                              ? kDarkPrimaryColor.withOpacity(0.2)
                              : kLightPrimaryColor.withOpacity(0.5),
                        ),
                        size: Size(screenSize.width, 150),
                      ),
                    ),
                  ),
                ),
              ),

              // 3) contenu principal
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            // HEADER
                            SizedBox(
                              height: headerHeight,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Animate(
                                      child: Lottie.asset(
                                        isDarkMode ? 'assets/json/user_dark.json' : 'assets/json/user.json',
                                        width: screenSize.width * 0.5,
                                        height: headerHeight * 0.6,
                                        fit: BoxFit.contain,
                                      ),
                                    ).scale(duration: 800.ms, delay: 200.ms).shake(duration: 1000.ms),
                                    const SizedBox(height: 8),
                                    Animate(
                                      child: Text(
                                        'Welcome Back!'.tr,
                                        style: GoogleFonts.poppins(
                                          fontSize: clampDouble(screenSize.width * 0.07, 20, 28),
                                          fontWeight: FontWeight.w900,
                                          color: theme.colorScheme.onSurface,
                                          letterSpacing: -1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ).fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: -0.2, end: 0),
                                  ],
                                ),
                              ),
                            ),

                            // FORM
                            Container(
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkMode ? Colors.black.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Email
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                                    ),
                                    child: StyledInputField(
                                      controller: emailController,
                                      label: 'Email'.tr,
                                      hint: 'your@email.com'.tr,
                                      icon: Iconsax.sms,
                                      inputType: TextInputType.emailAddress,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(duration: 1000.ms, delay: 300.ms)
                                      .slideX(begin: -0.5, end: 0),

                                  const SizedBox(height: 16),

                                  // Password
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                                    ),
                                    child: StyledInputField(
                                      controller: passwordController,
                                      label: 'Password'.tr,
                                      hint: '••••••••'.tr,
                                      icon: Iconsax.lock_1,
                                      inputType: TextInputType.visiblePassword,
                                      trailing: IconButton(
                                        icon: Icon(
                                          isPasswordVisible ? Iconsax.eye : Iconsax.eye_slash,
                                          color: theme.colorScheme.primary,
                                        ),
                                        onPressed: () => setState(() {
                                          isPasswordVisible = !isPasswordVisible;
                                        }),
                                      ),
                                      obscureText: !isPasswordVisible,
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(duration: 1200.ms, delay: 400.ms)
                                      .slideX(begin: 0.5, end: 0),

                                  const SizedBox(height: 14),

                                  // Remember + Forgot
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: areFieldsValid()
                                                ? () => toggleRememberMe(!isChecked.value)
                                                : null,
                                            child: AnimatedContainer(
                                              duration: 300.ms,
                                              width: 50,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                color: isChecked.value
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme.onSurface.withOpacity(0.1),
                                              ),
                                              child: AnimatedAlign(
                                                duration: 300.ms,
                                                alignment: isChecked.value
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft,
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  margin: const EdgeInsets.all(2),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isChecked.value
                                                        ? theme.colorScheme.onPrimary
                                                        : theme.colorScheme.onSurface.withOpacity(0.3),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.2),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'remember_me'.tr,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _navigateToForgotPassword,
                                            child: Text(
                                              'Forgot Password?'.tr,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                      .animate()
                                      .fadeIn(duration: 1400.ms, delay: 500.ms)
                                      .scaleXY(begin: 0.9, end: 1),

                                  const SizedBox(height: 10),

                                  // Bouton Login
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDarkMode
                                            ? [kDarkPrimaryColor, kDarkPrimaryColor.withOpacity(0.9)]
                                            : [kLightPrimaryColor, kAccentColor],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isDarkMode ? kDarkPrimaryColor : kLightPrimaryColor)
                                              .withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: PrimaryButton(
                                      title: 'Login'.tr,
                                      onPressed: () async {
                                        final email = emailController.text.trim();
                                        final password = passwordController.text.trim();
                                        if (email.isEmpty || password.isEmpty) {
                                          showSnackbar("Error, Please fill in all fields.".tr);
                                          return;
                                        }
                                        await userController.login(email, password);
                                        await userController.saveCredentials(email, password);
                                      },
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(duration: 1400.ms, delay: 600.ms)
                                      .slideY(begin: 0.5, end: 0),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                          // FONCTIONNALITÉS
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12.0),
  child: Column(
    children: [
      SizedBox(
        height: pageViewHeight,
        child: PageView(
          controller: _featureController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            FeatureCard(
              icon: Iconsax.shield_tick,
              title: 'Secure Encryption'.tr,
              description: 'All your data is end-to-end encrypted'.tr,
            ),
            FeatureCard(
              icon: Iconsax.cloud,
              title: 'Cloud Sync'.tr,
              description: 'Access your data from any device'.tr,
            ),
            FeatureCard(
              icon: Iconsax.bucket,
              title: 'Lightning Fast'.tr,
              description: 'Optimized for maximum performance'.tr,
            ),
            FeatureCard(
              icon: Iconsax.shield_tick,
              title: 'Secure Encryption'.tr,
              description: 'All your data is end-to-end encrypted'.tr,
            ),
            FeatureCard(
              icon: Iconsax.cloud,
              title: 'Cloud Sync'.tr,
              description: 'Access your data from any device'.tr,
            ),
            FeatureCard(
              icon: Iconsax.bucket,
              title: 'Lightning Fast'.tr,
              description: 'Optimized for maximum performance'.tr,
            ),
            FeatureCard(
              icon: Iconsax.shield_tick,
              title: 'Secure Encryption'.tr,
              description: 'All your data is end-to-end encrypted'.tr,
            ),
            FeatureCard(
              icon: Iconsax.cloud,
              title: 'Cloud Sync'.tr,
              description: 'Access your data from any device'.tr,
            ),
            FeatureCard(
              icon: Iconsax.bucket,
              title: 'Lightning Fast'.tr,
              description: 'Optimized for maximum performance'.tr,
            ),
          ],
        ),
      ),
                                  const SizedBox(height: 10),

                                  Center(
                                    child: SmoothPageIndicator(
                                      controller: _featureController,
                                      count: 3,
                                      effect: ExpandingDotsEffect(
                                        activeDotColor: theme.colorScheme.primary,
                                        dotColor: theme.colorScheme.onSurface.withOpacity(0.2),
                                        dotHeight: 8,
                                        dotWidth: 8,
                                        spacing: 6,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  Center(
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          "Don't have an account?".tr,
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _navigateToSignUp,
                                          child: Text(
                                            'Sign Up'.tr,
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                      .animate()
                                      .fadeIn(duration: 1800.ms, delay: 700.ms)
                                      .blurXY(begin: 10, end: 0),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 4) 🌐 bouton langue + label — placé APRÈS SafeArea pour être AU-DESSUS
              Positioned(
                right: 16,
                top: MediaQuery.of(context).padding.top + 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _LangBadgeButton(onTap: _goToLanguage),
                    const SizedBox(height: 6),
                    const _LangHintLabel(),
                  ],
                ),
              ),

              // 5) overlay chargement
              if (isLoading) const OtpLoadingIndicator(),
            ],
          ),
        ),
      );
    });
  }
}

/* ==================== Peintures & cartes ==================== */

class EmojiParticle {
  String emoji;
  double x = Random().nextDouble();
  double y = Random().nextDouble();
  double size = Random().nextDouble() * 20 + 15;
  double speed = Random().nextDouble() * 0.5 + 0.1;
  double rotation = Random().nextDouble() * 2 * pi;
  double rotationSpeed = Random().nextDouble() * 0.05 - 0.025;

  EmojiParticle({required this.emoji});
}

class EmojiPainter extends CustomPainter {
  final List<EmojiParticle> emojis;
  final double time;

  EmojiPainter({required this.emojis, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(fontSize: 24, color: Colors.white.withOpacity(0.3));

    for (final emoji in emojis) {
      emoji.x += emoji.speed * 0.01;
      emoji.y += emoji.speed * 0.01 * sin(time * 2 + emoji.x * 10);
      emoji.rotation += emoji.rotationSpeed;

      if (emoji.x > 1) emoji.x = 0;
      if (emoji.y > 1) emoji.y = 0;

      final textSpan = TextSpan(text: emoji.emoji, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

      final offset = Offset(emoji.x * size.width, emoji.y * size.height);

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(emoji.rotation);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WavePainter extends CustomPainter {
  final Color color;
  WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width, size.height * 0.7);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            title.tr,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description.tr,
            style: GoogleFonts.poppins(fontSize: 12, height: 1.25),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            softWrap: true,
          ),
        ],
      ),
    );
  }
}

/* ==================== 🌐 Bouton Langue flottant ==================== */

class _LangBadgeButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LangBadgeButton({required this.onTap});

  @override
  State<_LangBadgeButton> createState() => _LangBadgeButtonState();
}

class _LangBadgeButtonState extends State<_LangBadgeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;
  late final Animation<Offset> _float;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _float = Tween<Offset>(begin: const Offset(0, -0.02), end: const Offset(0, 0.02))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return SlideTransition(
      position: _float,
      child: ScaleTransition(
        scale: _pulse,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, // capte mieux les taps
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withOpacity(0.45), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(_down ? 0.25 : 0.35),
                      blurRadius: _down ? 10 : 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  '🌐', // emoji moderne & coloré
                  style: TextStyle(fontSize: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ==================== ✨ Label animé sous l’icône ==================== */

class _LangHintLabel extends StatefulWidget {
  const _LangHintLabel();

  @override
  State<_LangHintLabel> createState() => _LangHintLabelState();
}

class _LangHintLabelState extends State<_LangHintLabel> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _fade  = Tween<double>(begin: 0.55, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _slide = Tween<Offset>(begin: const Offset(0.0, -0.04), end: const Offset(0.0, 0.02))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              
            ),
          ),
        ),
      ),
    );
  }
}
