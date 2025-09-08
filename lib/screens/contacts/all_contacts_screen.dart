import 'package:bcalio/widgets/base_widget/primary_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../controllers/contact_controller.dart';
import '../../controllers/conversation_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/contact_model.dart';
import '../../models/true_user_model.dart';
import '../../services/contact_api_service.dart';
// NEW: service d’invitation SMS (via ton serveur Node + Infobip)
import '../../services/invite_sms_service.dart';

import '../../themes/theme.dart';
import '../../widgets/base_widget/custom_loading_indicator.dart';
import '../../widgets/base_widget/custom_search_bar.dart';
import '../../widgets/base_widget/custom_snack_bar.dart';
import '../../widgets/base_widget/no_search_found.dart';
import '../../widgets/contacts/contact_list_tile.dart';
import '../chat/ChatRoom/chat_room_screen.dart';
import 'modern_loading_indicator.dart';

class AllContactsScreen extends StatefulWidget {
  const AllContactsScreen({super.key});

  @override
  State<AllContactsScreen> createState() => _AllContactsScreenState();
}

class _AllContactsScreenState extends State<AllContactsScreen> {
  final ContactController contactController =
      Get.put(ContactController(contactApiService: ContactApiService()));

  final ConversationController conversationController =
      Get.find<ConversationController>();

  final UserController userController = Get.find<UserController>();
  final ContactApiService contactApiService = ContactApiService();
  final RxBool isLoading = false.obs;

  // NEW: backend invite
  final InviteSmsService inviteSms = InviteSmsService();

  bool isFirst = true;

  @override
  void initState() {
    super.initState();
    debugPrint('isFirst: $isFirst');
    isFirst
        ? contactController.fetchContactsFromApiPhone()
        : contactController.loadCachedContacts();
  }

  @override
  void dispose() {
    super.dispose();
  }

  final TextEditingController searchController = TextEditingController();

  /* ───────────────── helpers ───────────────── */

  String normalizePhoneNumber(String? phoneNumber) {
    final raw = (phoneNumber ?? '').trim();
    return raw.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String _normalizeString(String input) {
    return input
        .toLowerCase()
        .replaceAllMapped(RegExp(r'[àáâãäå]'), (m) => 'a')
        .replaceAllMapped(RegExp(r'[èéêë]'), (m) => 'e')
        .replaceAllMapped(RegExp(r'[ìíîï]'), (m) => 'i')
        .replaceAllMapped(RegExp(r'[òóôõö]'), (m) => 'o')
        .replaceAllMapped(RegExp(r'[ùúûü]'), (m) => 'u')
        .replaceAllMapped(RegExp(r'[ç]'), (m) => 'c')
        .replaceAllMapped(RegExp(r'[ñ]'), (m) => 'n')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll(RegExp(r'[ة]'), 'ه')
        .replaceAll(RegExp(r'[يى]'), 'ي')
        .replaceAll(RegExp(r'[ك]'), 'ك')
        .replaceAll(RegExp(r'[ـ]'), '')
        .replaceAll(RegExp(r'[ًٌٍَُِّْ]'), '');
  }

  /// Déduplique par ID si dispo, sinon par numéro normalisé
  List<Contact> _uniqueByIdOrPhone(List<Contact> list) {
    final seen = <String>{};
    final out = <Contact>[];

    for (final c in list) {
      final key = (c.id.isNotEmpty)
          ? 'id:${c.id}'
          : 'phone:${normalizePhoneNumber(c.phoneNumber)}';
      if (key == 'phone:' || key == 'id:') {
        // rien d’exploitable : on pousse tel quel mais on évite le set vide
        if (seen.add('rand:${out.length}')) out.add(c);
      } else {
        if (seen.add(key)) out.add(c);
      }
    }
    return out;
  }

  Future<void> _dedupeAndPersist() async {
    final unique = _uniqueByIdOrPhone(contactController.contacts);
    contactController.contacts.assignAll(unique);
    await contactController.saveContactsToCache();
  }

  /// Essaie de produire un E.164 : si pas de +, préfixe avec l’indicatif du numéro de l’utilisateur
  String _toE164BestEffort(String phone) {
    String s = normalizePhoneNumber(phone);
    if (s.startsWith('+')) return s;
    final me = normalizePhoneNumber(userController.user?.phoneNumber ?? '');
    final m  = RegExp(r'^\+(\d{1,3})').firstMatch(me);
    final cc = m?.group(1) ?? '';
    return cc.isNotEmpty ? '+$cc$s' : s; // ex: '+216' + '54485678'
  }

  void _navigateWithAnimation(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  /* ───────────────── navigation chat ───────────────── */

  Future<void> navigateToChatRoom(
    String contactId,
    String name,
    String phoneNumber,
    String? avatarUrl,
  ) async {
    debugPrint(
        'Navigating to chat: contactId=$contactId, name=$name, phone=$phoneNumber');

    final token = await userController.getToken();
    if (token == null || token.isEmpty) {
      Get.toNamed('/login');
      return;
    }

    // Si pas un ObjectId valide → INVITER via backend /api/invite-sms
    if (contactId.isEmpty || !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(contactId)) {
      final normalized = _toE164BestEffort(phoneNumber);
      final ok = await inviteSms.sendOne(
        token: token,
        phone: normalized,
        name: name,
      );
      if (ok) {
        showSuccessSnackbar("Invitation envoyée à $name");
      } else {
        showErrorSnackbar("Échec de l'envoi de l'invitation à $name");
      }
      return;
    }

    isLoading.value = true;
    try {
      final existing = conversationController.conversations.firstWhereOrNull(
        (c) => c.isGroup == false && c.userIds.contains(contactId),
      );

      if (existing != null) {
        _navigateWithAnimation(
          context,
          ChatRoomPage(
            name: name,
            phoneNumber: phoneNumber,
            avatarUrl: avatarUrl,
            conversationId: existing.id,
            createdAt: existing.createdAt,
          ),
        );
        return;
      }

      final created = await conversationController.createConversation(
        token: token,
        userId: contactId,
      );
      if (created == null) {
        throw Exception("Échec de la création de la conversation : réponse nulle");
      }

      // Important pour éviter le 404 “Conversation not found”
      await conversationController.refreshConversations(token);

      // S’assure que l’ID existe bien côté store
      String convId = created.id;
      if (convId.isEmpty ||
          !conversationController.conversations.any((c) => c.id == convId)) {
        final byPeer = conversationController.conversations.firstWhereOrNull(
          (c) => c.isGroup == false && c.userIds.contains(contactId),
        );
        convId = byPeer?.id ?? convId;
      }
      if (convId.isEmpty) {
        throw Exception('Conversation introuvable après création');
      }

      _navigateWithAnimation(
        context,
        ChatRoomPage(
          name: name,
          phoneNumber: phoneNumber,
          avatarUrl: avatarUrl,
          conversationId: convId,
          createdAt: created.createdAt,
        ),
      );
    } catch (e) {
      debugPrint('navigateToChatRoom error: $e');
      showErrorSnackbar('Erreur : Impossible de naviguer vers la conversation. Détails : $e');
    } finally {
      isLoading.value = false;
    }
  }

  /* ───────────────── ajout contact (depuis “contacts téléphone”) ───────────────── */

  Future<void> _handleAddContact(Contact contact) async {
    try {
      isLoading.value = true;

      final token = await userController.getToken();
      if (token == null || token.isEmpty) {
        showErrorSnackbar("Échec de la récupération du token. Veuillez vous reconnecter.");
        return;
      }

      // Chercher si ce numéro correspond à un user app
      final users = await userController.fetchUsers(token);
      final normalize = (String? p) =>
          normalizePhoneNumber(p).replaceAll(RegExp(r'^\+216'), ''); // adapte si besoin
      final user = users.firstWhere(
        (u) => normalize(u.phoneNumber) == normalize(contact.phoneNumber),
        orElse: () => User(id: '', email: '', name: '', image: '', phoneNumber: null),
      );

      if (user.id.isNotEmpty) {
        // Ajout via API app (retourne un Contact complet grâce au service corrigé)
        await contactController.addContact(
          token,
          user.id,
          user.name,
          user.phoneNumber ?? '',
          user.email,
        );

        // Rafraîchir la source et dédupliquer pour éviter les doublons visibles
        await contactController.fetchContactsFromApiPhone();
        await _dedupeAndPersist();

        // Ouvrir la conversation
        await navigateToChatRoom(
          user.id,
          user.name,
          user.phoneNumber ?? '',
          user.image,
        );
      } else {
        // Inviter via backend /api/invite-sms si pas d’utilisateur app
        final normalized = _toE164BestEffort(contact.phoneNumber ?? '');
        final success = await inviteSms.sendOne(
          token: token,
          phone: normalized,
          name: contact.name,
        );
        if (success) {
          showSuccessSnackbar("Succès, invitation envoyée à ${contact.name}");
        } else {
          showErrorSnackbar("Erreur, échec de l'envoi de l'invitation à ${contact.name}");
        }
      }
    } catch (e) {
      debugPrint('Erreur ajout contact: $e');
      showErrorSnackbar("Échec de l'ajout du contact: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /* ──────────────── PULL-TO-REFRESH (nouveau) ──────────────── */

  Future<void> _refreshContacts() async {
    try {
      // recharge depuis API (inclut les nouveaux contacts ajoutés/scan)
      await contactController.fetchContactsFromApiPhone();
      await _dedupeAndPersist();
      // (optionnel) haptics léger si tu veux du “tactile”:
      // HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('refresh error: $e');
    }
  }

  /* ───────────────── UI ───────────────── */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    debugPrint("All contacts screen");

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              CustomSearchBar(
                controller: searchController,
                hintText: "Search for a contact or select one from the list below."
                    .tr,
                onChanged: (query) async {
                  if (query.isEmpty || query.trim().isEmpty) {
                    await contactController.loadCachedContacts();
                  } else {
                    await contactController.loadCachedContacts();
                    final trimmed = _normalizeString(query).trim();
                    final filtered = contactController.contacts.where((c) {
                      final nameMatch = _normalizeString(c.name).startsWith(trimmed);
                      final phoneMatch =
                          _normalizeString(c.phoneNumber ?? '').contains(trimmed);
                      return nameMatch || phoneMatch;
                    }).toList();

                    // Dédup avant affichage
                    contactController.contacts.assignAll(_uniqueByIdOrPhone(filtered));
                  }
                },
                onBack: () async => Get.back(),
              ),

              // Boutons QR
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Get.toNamed('/qr/scan'),
                      icon: const Icon(Icons.qr_code_scanner),
                      label:  Text("scan_qr".tr),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Get.toNamed('/qr/my'),
                      icon: const Icon(Icons.qr_code_2),
                      label:  Text("my_qr".tr),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Obx(() {
                  if (contactController.isLoadingContacts.value) {
                    return Center(child: CustomLoadingIndicator());
                  }

                  // Liste unique pour l’affichage (évite les doublons API/téléphone)
                  final uniqueAll = _uniqueByIdOrPhone(contactController.contacts);

                  if (uniqueAll.isEmpty) {
                    // On garde une ScrollView pour permettre le pull même à vide
                    return RefreshIndicator(
                      onRefresh: _refreshContacts,
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      strokeWidth: 2.4,
                      displacement: 24,
                      triggerMode: RefreshIndicatorTriggerMode.onEdge,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.25,
                          ),
                          Center(child: NoSearchFound(message: "Aucun contact trouvé.".tr)),
                        ],
                      ),
                    );
                  }

                  final appContacts =
                      uniqueAll.where((c) => !c.isPhoneContact).toList();
                  final phoneContacts =
                      uniqueAll.where((c) => c.isPhoneContact).toList();

                  // ⬇️ PULL-TO-REFRESH autour de la liste
                  return RefreshIndicator(
                    onRefresh: _refreshContacts,
                    color: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surface,
                    strokeWidth: 2.4,
                    displacement: 24,
                    triggerMode: RefreshIndicatorTriggerMode.onEdge,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (appContacts.isNotEmpty) ...[
                          _buildSectionHeader("Contacts enregistrés".tr),
                          ...appContacts.map(_buildContactTile).toList(),
                        ],
                        if (appContacts.isNotEmpty && phoneContacts.isNotEmpty)
                          _buildSectionDivider("Contacts non enregistrés".tr),
                        if (phoneContacts.isNotEmpty) ...[
                          ...phoneContacts.map(_buildContactTile).toList(),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSectionDivider(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              thickness: 1,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(Contact contact) {
    final theme = Theme.of(context);
    final contactName = contact.name.isNotEmpty ? contact.name : "No Name Available".tr;
    final contactPhoneNumber = (contact.phoneNumber?.isNotEmpty == true)
        ? contact.phoneNumber!
        : "No Phone Number".tr;

    final isPhoneContact = contact.isPhoneContact;
    final RxBool isContactLoading = false.obs;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Obx(
        () => ContactListTile(
          name: contactName,
          phoneNumber: contactPhoneNumber,
          avatarUrl: contact.image,
          onTap: () async {
            isContactLoading.value = true;
            await navigateToChatRoom(
              contact.id,
              contact.name,
              (contact.phoneNumber ?? ''),
              contact.image,
            );
            isContactLoading.value = false;
          },
          trailing: isPhoneContact
              ? GestureDetector(
                  onTap: () async {
                    isContactLoading.value = true;
                    await _handleAddContact(contact);
                    isContactLoading.value = false;
                  },
                  child: isContactLoading.value
                      ? ModernLoadingIndicator(
                          size: 24,
                          color: theme.colorScheme.primary,
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/3d_icons/user_icon.png',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'add'.tr,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                )
              : isContactLoading.value
                  ? ModernLoadingIndicator(
                      size: 24,
                      color: theme.colorScheme.primary,
                    )
                  : null,
        ),
      ),
    );
  }
}
