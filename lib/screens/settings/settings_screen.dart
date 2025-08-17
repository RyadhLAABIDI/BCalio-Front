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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSection(),
          const SizedBox(height: 16),

          // ---- Online Status (moderne) ----
          Obx(() {
            final visible = userCtrl.isOnlineVisible.value;
            return _StatusCard(
              isDark: isDarkMode,
              title: visible ? 'Statut: En ligne' : 'Statut: Hors ligne',
              subtitle: visible
                  ? 'Vos contacts vous voient “en ligne”.'
                  : 'Vous apparaissez hors ligne (mode invisible).',
              icon: visible ? Iconsax.record_circle : Iconsax.eye_slash,
              chipText: visible ? 'Visible' : 'Invisible',
              chipIcon: visible ? Iconsax.flash_1 : Iconsax.shield_cross,
              value: visible,
              onChanged: (v) => userCtrl.setOnlineVisible(v),
            );
          }),

          const SizedBox(height: 16),

          // ---- QR Section (NOUVEAU) ----
          _QrCard(isDark: isDarkMode),

          const SizedBox(height: 20),
          const NotificationSection(),
          const SizedBox(height: 20),
          const ContactsSectionSection(),
          const SizedBox(height: 20),
          const ThemeSection(),
          const SizedBox(height: 20),
          const LanguageSection(),
          const LogoutButton(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

/// Carte statut (existant)
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
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0E1B1B), Color(0xFF0B2B2B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF89C6C9), Color(0xFFB6E2E4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.25) : Colors.teal.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isDark ? 0.08 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(chipIcon, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              chipText,
                              style: const TextStyle(
                                color: Colors.white,
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
                                color: Colors.white.withOpacity(0.9),
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
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.35),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}

/// Carte QR (nouvelle)
class _QrCard extends StatelessWidget {
  final bool isDark;
  const _QrCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final gradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF17151F), Color(0xFF1E2940)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFD8E6FF), Color(0xFFEEF4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.blue.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isDark ? 0.08 : 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.qr_code_2, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mon QR',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 4),
                Text(
                  'Affiche ton code QR (valide ~30 jours) pour être ajouté rapidement.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/qr/my'),
            icon: const Icon(Iconsax.export_1, size: 18),
            label: const Text('Ouvrir'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
