import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../controllers/language_controller.dart';

class LanguageSection extends StatefulWidget {
  const LanguageSection({super.key});

  @override
  State<LanguageSection> createState() => _LanguageSectionState();
}

class _LanguageSectionState extends State<LanguageSection> {
  // Définir les langues comme des constantes
  static const String english = "anglais";
  static const String french = "français";
  static const String arabic = "arabic";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final LanguageController languageController =
        Get.find<LanguageController>();

    // Liste des langues disponibles
    final List<String> languages = [english, french, arabic];

    return Obx(() {
      // Déterminer la langue sélectionnée
      final selectedLanguage =
          languageController.selectedLocale.value.languageCode == 'fr'
              ? french
              : languageController.selectedLocale.value.languageCode == 'ar'
                  ? arabic
                  : english;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre de la section avec icône
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/3d_icons/translation_icon.png', // Chemin de l'image
                    width: 24, // Ajuster la taille
                    height: 24, // Ajuster la taille
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "language".tr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dropdown pour la sélection de la langue
            DropdownButtonFormField<String>(
              value: selectedLanguage,
              items: languages
                  .map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(
                          lang.tr, // Traduire le texte affiché
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value == french) {
                  languageController.changeLanguage(const Locale('fr', 'FR'));
                } else if (value == arabic) {
                  languageController.changeLanguage(const Locale('ar', 'SA'));
                } else {
                  languageController.changeLanguage(const Locale('en', 'US'));
                }
              },
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: theme.colorScheme.surfaceVariant,
              icon: Icon(
                Iconsax.arrow_down_1,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    });
  }
}
