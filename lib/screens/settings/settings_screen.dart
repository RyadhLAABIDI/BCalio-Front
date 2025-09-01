import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../themes/theme.dart';
import '../../widgets/settings/contacts_section.dart';
import '../../widgets/settings/notifications_section.dart';
import '../../widgets/settings/profile_section.dart';
import '../../widgets/settings/theme_section.dart';
import '../../widgets/settings/language_section.dart';
import '../../widgets/settings/logout_button.dart';
import '../../controllers/user_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final userCtrl = Get.find<UserController>();

    // Espace de fin pour que le bouton Logout ne soit pas masqué par le bottom nav
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomSpacer = safeBottom + kBottomNavigationBarHeight + 24;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSection(),
          const SizedBox(height: 16),

          // ---- Online Status (glassmorphism) ----
          Obx(() {
            final visible = userCtrl.isOnlineVisible.value;
            return _StatusCard(
              isDark: isDarkMode,
              title: visible ? 'Statut: En ligne'.tr : 'Statut: Hors ligne'.tr,
              subtitle: visible
                  ? 'Vos contacts vous voient “en ligne”.'.tr
                  : 'Vous apparaissez hors ligne (mode invisible).'.tr,
              icon: visible ? Iconsax.record_circle : Iconsax.eye_slash,
              chipText: visible ? 'Visible'.tr : 'Invisible'.tr,
              chipIcon: visible ? Iconsax.flash_1 : Iconsax.shield_cross,
              value: visible,
              onChanged: (v) => userCtrl.setOnlineVisible(v),
            );
          }),

          const SizedBox(height: 16),

          // ---- QR Section : Mon QR (glassmorphism) ----
          _QrCard(isDark: isDarkMode),

          const SizedBox(height: 12),

          // ---- QR Section : Connexion Web (glassmorphism) ----
          _QrPairCard(isDark: isDarkMode),

          const SizedBox(height: 20),
          const NotificationSection(),
          const SizedBox(height: 20),
          const ContactsSectionSection(),
          const SizedBox(height: 20),
          const ThemeSection(),
          const SizedBox(height: 20),
          const LanguageSection(),
          const LogoutButton(),

          // Espace supplémentaire pour assurer la visibilité au scroll
          SizedBox(height: bottomSpacer),
        ],
      ),
    );
  }
}

/// --------- Helpers visuels (glass) ----------
BoxDecoration _glassDecoration({required bool isDark}) {
  return BoxDecoration(
    // ⬇️ applique les couleurs de thème demandées
    color: isDark
        ? kDarkPrimaryColor.withOpacity(0.70)  // dark mode
        : kLightPrimaryColor, // light mode
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
      width: 1,
    ),
    boxShadow: [
      if (!isDark)
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        )
      else
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
    ],
  );
}

Color _tileBg(bool isDark) =>
    isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

Color _titleColor(bool isDark) => isDark ? Colors.white : Colors.black87;
Color _subColor(bool isDark) => isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.75);

/// -------------------------------------------
/// Carte statut (glassmorphism)
class _StatusCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final IconData icon;
  final String chipText;
  final IconData chipIcon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _StatusCard({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.chipText,
    required this.chipIcon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = _titleColor(isDark);
    final subTxt = _subColor(isDark);
    final chipBg = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06);
    final chipTxtCol = titleColor;
    final chipIcoCol = titleColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: _glassDecoration(isDark: isDark),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _tileBg(isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: titleColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Column(
                    key: ValueKey(title + subtitle),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: titleColor, // noir en light, blanc en dark
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: chipBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(chipIcon, size: 14, color: chipIcoCol),
                                const SizedBox(width: 6),
                                Text(
                                  chipText, // ← dynamique
                                  style: TextStyle(
                                    color: chipTxtCol,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: subTxt,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Switch coloré selon le mode
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                // pouce (identique, bien lisible)
                activeColor: Colors.white,
                inactiveThumbColor: Colors.white,
                // piste (différenciée selon mode)
                activeTrackColor: isDark
                    ? Colors.white.withOpacity(0.35)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.55),
                inactiveTrackColor: isDark
                    ? Colors.white24
                    : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------
/// Carte QR “Mon QR” (glassmorphism)
class _QrCard extends StatelessWidget {
  final bool isDark;
  const _QrCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final titleColor = _titleColor(isDark);
    final subTxt = _subColor(isDark);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: _glassDecoration(isDark: isDark),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _tileBg(isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.qr_code_2, color: titleColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mon QR'.tr,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      'Affiche ton code QR (valide ~30 jours) pour être ajouté rapidement.'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subTxt,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => Get.toNamed('/qr/my'),
                icon: Icon(Iconsax.export_1, size: 18, color: isDark ? Colors.black : Colors.black),
                label: Text('Ouvrir'.tr),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------
/// Carte QR “Connexion Web” (glassmorphism)
class _QrPairCard extends StatelessWidget {
  final bool isDark;
  const _QrPairCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final titleColor = _titleColor(isDark);
    final subTxt = _subColor(isDark);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: _glassDecoration(isDark: isDark),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _tileBg(isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.qr_code_scanner, color: titleColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connexion Web'.tr,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      'Scanner le QR affiché sur le site pour ouvrir ta session.'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: subTxt,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => Get.toNamed('/qr/web-scan'),
                icon: Icon(Iconsax.scan_barcode, size: 18, color: isDark ? Colors.black : Colors.black),
                label: Text('Scanner'.tr),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
