import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/language_controller.dart';
import '../../routes.dart';

class LanguageOnboardingPage extends StatefulWidget {
  const LanguageOnboardingPage({super.key});

  @override
  State<LanguageOnboardingPage> createState() => _LanguageOnboardingPageState();
}

class _LanguageOnboardingPageState extends State<LanguageOnboardingPage>
    with TickerProviderStateMixin {
  final LanguageController lang = Get.find<LanguageController>();

  // ====== Palette (tes couleurs) ======
  static const Color kTealLight = Color(0xFF89C6C9);
  static const Color kTealMid   = Color(0xFF327E88);
  static const Color kCopper    = Color(0xFFC46535);
  static const Color kCopperD   = Color(0xFF943A1B);
  static const Color kDark      = Color.fromARGB(255, 0, 8, 8);
  static const Color kPaper     = Color(0xFFF5F7FA);

  String _selected = 'en'; // en | fr | ar

  // BG “respire”
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgAnim;

  // Accent animé quand la langue change
  late final AnimationController _accentCtrl;
  late Animation<Color?> _accentAnim;
  Color _accent = kTealMid;

  // Petite anim d’icône dans le header
  late final AnimationController _iconCtrl;

  @override
  void initState() {
    super.initState();

    final code = lang.selectedLocale.value.languageCode;
    _selected = (code == 'fr') ? 'fr' : (code == 'ar') ? 'ar' : 'en';

    _accent = _accentFor(_selected);

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);

    _accentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _accentAnim = ColorTween(begin: _accent, end: _accent).animate(
      CurvedAnimation(parent: _accentCtrl, curve: Curves.easeOutCubic),
    );

    _iconCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _accentCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  Color _accentFor(String code) {
    switch (code) {
      case 'fr':
        return kCopper;     // FR → cuivre
      case 'ar':
        return kTealLight;  // AR → teal clair
      case 'en':
      default:
        return kTealMid;    // EN → teal moyen
    }
  }

  void _retint(String newCode) {
    final newAccent = _accentFor(newCode);
    _accentAnim = ColorTween(begin: _accentAnim.value ?? _accent, end: newAccent).animate(
      CurvedAnimation(parent: _accentCtrl, curve: Curves.easeOutCubic),
    );
    _accentCtrl
      ..reset()
      ..forward();
    _accent = newAccent;
  }

  void _applyAndContinue() async {
    if (_selected == 'fr') {
      lang.changeLanguage(const Locale('fr', 'FR'));
    } else if (_selected == 'ar') {
      lang.changeLanguage(const Locale('ar', 'SA'));
    } else {
      lang.changeLanguage(const Locale('en', 'US'));
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);

    if (!mounted) return;
    Get.offAllNamed(Routes.start);
  }

  Widget _languageCard({
    required String code, // 'en' | 'fr' | 'ar'
    required String labelKey,
    required String emoji,
  }) {
    final bool isSel = _selected == code;

    return AnimatedBuilder(
      animation: Listenable.merge([_accentCtrl, _bgCtrl]),
      builder: (context, _) {
        final accent = _accentAnim.value ?? _accent;
        return AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: isSel ? 1.03 : 1.0,
          child: InkWell(
            onTap: () {
              setState(() => _selected = code);
              if (code == 'fr') {
                lang.changeLanguage(const Locale('fr', 'FR'));
              } else if (code == 'ar') {
                lang.changeLanguage(const Locale('ar', 'SA'));
              } else {
                lang.changeLanguage(const Locale('en', 'US'));
              }
              _retint(code);
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isSel
                    ? LinearGradient(
                        colors: [
                          (accent).withOpacity(0.18),
                          (accent == kCopper ? kCopperD : kDark).withOpacity(0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSel ? null : Colors.white.withOpacity(0.80),
                border: Border.all(
                  color: isSel ? (accent).withOpacity(0.65) : Colors.black.withOpacity(0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  if (isSel)
                    BoxShadow(
                      color: (accent).withOpacity(0.25),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedScale(
                    scale: isSel ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kDark,
                          ),
                      child: Text(labelKey.tr),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutBack,
                    child: isSel
                        ? Icon(Iconsax.tick_circle,
                            key: const ValueKey('sel'),
                            color: accent)
                        : const SizedBox(key: ValueKey('nosel'), width: 24, height: 24),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bgCtrl, _accentCtrl, _iconCtrl]),
      builder: (context, _) {
        final t = _bgAnim.value;
        final accent = _accentAnim.value ?? _accent;

        // Dégradé animé re-teinté par l’accent
        final bg = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.5, 1.0],
          colors: [
            Color.lerp(kTealLight, accent, t)!,
            Color.lerp(accent, kDark, 1 - t)!,
            Color.lerp(kTealMid, kDark, t)!,
          ],
        );

        return Scaffold(
          body: Stack(
            children: [
              // Fond dégradé animé
              Container(decoration: BoxDecoration(gradient: bg)),

              // ====== ✨ logo flottant en haut-droite ======
              Positioned.fill(
                child: IgnorePointer(
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20, top: 8),
                        child: _LogoBadge(
                          accentAnim: _accentAnim,
                          iconCtrl: _iconCtrl,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // ====== fin logo ======

              // Blobs “verre” neutres
              Positioned.fill(
                child: Stack(
                  children: [
                    _blob(
                      alignment: Alignment(-0.88 + 0.22 * t, -0.78),
                      size: 210,
                      color: Colors.white.withOpacity(0.10),
                    ),
                    _blob(
                      alignment: Alignment(0.84 - 0.28 * t, -0.18),
                      size: 270,
                      color: Colors.white.withOpacity(0.09),
                    ),
                    _blob(
                      alignment: Alignment(-0.58, 0.74 - 0.10 * t),
                      size: 230,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ],
                ),
              ),

              // Contenu (centrage/scroll réactif)
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    final isTall = h >= 740; // écran confortable
                    final cardH = (h * 0.46).clamp(320.0, 520.0);

                    final header = Row(
                      children: [
                        ScaleTransition(
                          scale: Tween(begin: 0.96, end: 1.06).animate(
                            CurvedAnimation(parent: _iconCtrl, curve: Curves.easeInOutSine),
                          ),
                          child: RotationTransition(
                            turns: Tween(begin: -0.005, end: 0.005).animate(
                              CurvedAnimation(parent: _iconCtrl, curve: Curves.easeInOut),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Iconsax.translate, color: kPaper, size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: kPaper,
                          ),
                          child: Text('choose_language'.tr),
                        ),
                      ],
                    );

                    final hint = AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      style: const TextStyle(
                        color: kPaper,
                        fontWeight: FontWeight.w500,
                      ),
                      child: Text('change_anytime_hint'.tr),
                    );

                    final card = ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          height: cardH,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                style: const TextStyle(
                                  color: kPaper,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                child: Text('app_language'.tr),
                              ),
                              const SizedBox(height: 12),
                              _languageCard(code: 'en', labelKey: 'lang_english', emoji: '🇺🇸'),
                              const SizedBox(height: 12),
                              _languageCard(code: 'fr', labelKey: 'lang_french', emoji: '🇫🇷'),
                              const SizedBox(height: 12),
                              _languageCard(code: 'ar', labelKey: 'lang_arabic', emoji: '🇸🇦'),
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(Iconsax.setting_2, size: 18, color: kPaper),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeOut,
                                      style: const TextStyle(
                                        color: kPaper,
                                        fontSize: 12.5,
                                      ),
                                      child: Text('tip_change_later'.tr),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    final cta = _AnimatedCTA(
                      label: 'continue_btn'.tr,
                      accentAnim: _accentAnim,
                      onPressed: _applyAndContinue,
                    );

                    final content = Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        mainAxisAlignment:
                            isTall ? MainAxisAlignment.center : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          header,
                          const SizedBox(height: 18),
                          hint,
                          SizedBox(height: isTall ? 26 : 20),
                          card,
                          SizedBox(height: isTall ? 36 : 16),
                          cta,
                        ],
                      ),
                    );

                    if (isTall) {
                      return content;
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: h),
                        child: content,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _blob({required Alignment alignment, required double size, required Color color}) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// ====== ✨ Widget: badge logo flottant (glass + animation) — logo plus grand sans changer le badge ======
class _LogoBadge extends StatelessWidget {
  final Animation<Color?> accentAnim;
  final AnimationController iconCtrl;

  /// Contrôle la taille relative du logo à l’intérieur du badge (0.0 → 1.0).
  /// 0.92 = 92% de la largeur/hauteur du badge (ajuste selon ton goût).
  final double logoFactor;

  const _LogoBadge({
    required this.accentAnim,
    required this.iconCtrl,
    this.logoFactor = 0.999, // ← augmente pour agrandir le logo (ex: 0.96)
  });

  @override
  Widget build(BuildContext context) {
    // Taille du badge (inchangée)
    final screenW = MediaQuery.sizeOf(context).width;
    final double badgeSize = (screenW * 0.16).clamp(56.0, 88.0) as double;
    final double radius    = badgeSize * 0.28;

    return AnimatedBuilder(
      animation: Listenable.merge([accentAnim, iconCtrl]),
      builder: (context, _) {
        final accent = accentAnim.value ?? _LanguageOnboardingPageState.kTealMid;
        return ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.04).animate(
            CurvedAnimation(parent: iconCtrl, curve: Curves.easeInOutSine),
          ),
          child: RotationTransition(
            turns: Tween(begin: -0.01, end: 0.01).animate(
              CurvedAnimation(parent: iconCtrl, curve: Curves.easeInOut),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: badgeSize, // ⟵ taille du badge conservée
                  width:  badgeSize, // ⟵ taille du badge conservée
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: accent.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  // Plus de padding fixe: on laisse le logo prendre une fraction du badge
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor:  logoFactor, // ← ajuste ici (0.90–0.98)
                      heightFactor: logoFactor, // ← ajuste ici
                      child: Image.asset(
                        'assets/img/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


/// Bouton custom animé (gradient teinte → foncé + flèche slide)
class _AnimatedCTA extends StatefulWidget {
  final String label;
  final Animation<Color?> accentAnim;
  final VoidCallback onPressed;

  const _AnimatedCTA({
    required this.label,
    required this.accentAnim,
    required this.onPressed,
  });

  @override
  State<_AnimatedCTA> createState() => _AnimatedCTAState();
}

class _AnimatedCTAState extends State<_AnimatedCTA> with SingleTickerProviderStateMixin {
  late final AnimationController _hoverCtrl; // pour l’anim de flèche
  late final Animation<Offset> _slide;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween(begin: const Offset(0, 0), end: const Offset(0.14, 0))
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_hoverCtrl);
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const height = 54.0;

    return AnimatedBuilder(
      animation: widget.accentAnim,
      builder: (context, _) {
        final accent = widget.accentAnim.value ?? _LanguageOnboardingPageState.kTealMid;
        final endDark = _LanguageOnboardingPageState.kDark;

        return GestureDetector(
          onTapDown: (_) {
            setState(() => _down = true);
            _hoverCtrl.forward();
          },
          onTapCancel: () {
            setState(() => _down = false);
            _hoverCtrl.reverse();
          },
          onTapUp: (_) {
            setState(() => _down = false);
            _hoverCtrl.reverse();
            widget.onPressed();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.35),
                  blurRadius: _down ? 10 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _down
                    ? [accent.withOpacity(0.92), endDark.withOpacity(0.92)]
                    : [accent, Color.lerp(accent, endDark, 0.18)!],
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      const Spacer(),
                      SlideTransition(
                        position: _slide,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Icon(Iconsax.arrow_right_3, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
