import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';           // ← pour Get.snackbar + Colors
import 'package:flutter/widgets.dart';            // ← pour WidgetsBinding.instance.lifecycleState
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation_model.dart';
import '../models/true_message_model.dart';
import '../services/conversation_api_service.dart';
import '../widgets/base_widget/custom_snack_bar.dart';
import 'user_controller.dart';

// ⚠️ IMPORTANT : on supprime toute notif locale Flutter pour “chat”.

class ConversationController extends GetxController {
  final ConversationApiService conversationApiService;

  ConversationController({required this.conversationApiService});

  RxList<Conversation> conversations = <Conversation>[].obs;
  RxBool isLoading = false.obs;
  Timer? _pollingTimer;
  bool isPollingPaused = false;

  @override
  void onInit() async {
    super.onInit();
    final token = await Get.find<UserController>().getToken();
    if (token != null && token.isNotEmpty) {
      await loadCachedConversations();
      await fetchConversations(token);
      startPolling(token);
    }
  }

  @override
  void onClose() {
    stopPolling();
    super.onClose();
  }

  Future<void> fetchConversations(String token) async {
    isLoading.value = true;
    try {
      final fetchedConversations =
          await conversationApiService.getConversations(token);
      conversations.value = fetchedConversations;
      _saveConversationsToCache(fetchedConversations);
      debugPrint('Conversations récupérées: ${conversations.length}');
    } catch (e) {
      debugPrint('Erreur dans fetchConversations: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _saveConversationsToCache(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList =
        conversations.map((conversation) => conversation.toJson()).toList();
    prefs.setString('cachedConversations', jsonEncode(jsonList));
    debugPrint('Toutes les conversations sauvegardées en cache: ${conversations.length}');
  }

  Future<void> loadCachedConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedConversations = prefs.getString('cachedConversations');
      if (cachedConversations != null) {
        final List<dynamic> jsonList = jsonDecode(cachedConversations);
        final allConversation =
            jsonList.map((json) => Conversation.fromJson(json)).toList();
        conversations.value = allConversation;
        debugPrint('Conversations chargées depuis cache: ${conversations.length}');
      }
    } catch (e) {
      debugPrint('Erreur chargement conversations en cache: $e');
    }
  }

  Future<void> refreshConversations(String token) async {
    try {
      final updatedConversations =
          await conversationApiService.getConversations(token);
      conversations.value = updatedConversations;
    } catch (e) {
      debugPrint('Erreur dans refreshConversations: $e');
    }
  }

  void startPolling(String token) {
    debugPrint('Démarrage polling conversations…');
    if (_pollingTimer != null && _pollingTimer!.isActive) return;

    final currentUserId = Get.find<UserController>().currentUser.value?.id;

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (isPollingPaused) return;

      try {
        final oldConversations = List<Conversation>.from(conversations);
        await refreshConversations(token);

        for (final conversation in conversations) {
          final oldConversation = oldConversations.firstWhere(
            (c) => c.id == conversation.id,
            orElse: () => Conversation(
              id: '',
              createdAt: DateTime.now(),
              messagesIds: [],
              userIds: [],
              users: [],
              messages: [],
            ),
          );

          // Nouveau message ?
          if (conversation.messages.length > oldConversation.messages.length) {
            final newMessage = conversation.messages.last;

            // Pas mes propres messages
            if (newMessage.sender?.id != currentUserId) {
              // ✅ NE PAS créer de notif système ici.
              // Android (service natif) s’occupe des notifs quand l’app n’est pas au 1er plan.

              // Optionnel: petit toast *uniquement* si l’app est AU PREMIER PLAN.
              if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
                final senderName = newMessage.sender?.name ?? "Message";
                final content = _previewFor(newMessage);
                // Un petit banner discret in-app (aucune notification système)
                Get.snackbar(
                  senderName,
                  content,
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.black87,
                  colorText: Colors.white,
                  margin: const EdgeInsets.all(12),
                  duration: const Duration(seconds: 2),
                );
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Erreur polling: $e');
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<Conversation> createConversation({
    required String token,
    required String userId,
  }) async {
    try {
      final newConversation = await conversationApiService.createConversation(
        token: token,
        isGroup: false,
        userId: userId,
      );
      conversations.add(newConversation);
      return newConversation;
    } catch (e) {
      debugPrint('Erreur dans createConversation: $e');
      Get.snackbar('Erreur', 'Échec de la création de la conversation.');
      rethrow;
    }
  }

  /// Création de groupe conforme à l’API:
  /// - filtre IDs invalides (ObjectId 24 hex)
  /// - n’envoie PAS l’ID du créateur (le backend l’ajoute)
  /// - exige au moins 2 autres membres valides
  Future<bool> createGroupConversation({
    required BuildContext context,
    required String token,
    required String name,
    String? logo,
    required List<String> memberIds,
  }) async {
    isLoading.value = true;
    try {
      final meId = Get.find<UserController>().currentUser.value?.id ?? '';
      final objectIdRx = RegExp(r'^[0-9a-fA-F]{24}$');

      // Conserver uniquement des ObjectId valides et exclure l'auteur
      final others = <String>{
        ...memberIds.where(
          (id) => id.isNotEmpty && objectIdRx.hasMatch(id) && id != meId,
        ),
      };

      if (others.length < 2) {
        showErrorSnackbar("Sélectionne au moins 2 contacts ayant un compte B-callio.");
        return false;
      }

      // Appel service : il transforme memberIds -> members: [{value: id}]
      final newGroup = await conversationApiService.createGroupConversation(
        token: token,
        name: name,
        logo: logo,
        memberIds: others.toList(),
      );

      conversations.add(newGroup);
      showSuccessSnackbar("Succès, groupe créé avec succès.");
      return true;
    } catch (e) {
      debugPrint('Erreur dans createGroupConversation: $e');
      showErrorSnackbar(
        "Échec de création du groupe. Vérifie le format des membres et réessaie.",
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsSeen({
    required String token,
    required String conversationId,
  }) async {
    try {
      final updatedConversation =
          await conversationApiService.markConversationAsSeen(
        token: token,
        conversationId: conversationId,
      );

      if (updatedConversation.id.isNotEmpty) {
        final index = conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          conversations[index] = updatedConversation;
        }
      }
    } catch (e) {
      debugPrint('Exception dans markAsSeen: $e');
    }
  }

  Future<void> deleteConversation({
    required String token,
    required String conversationId,
  }) async {
    try {
      await conversationApiService.deleteConversation(
          token: token, conversationId: conversationId);
      conversations.removeWhere((c) => c.id == conversationId);
      showSuccessSnackbar("Succès, conversation supprimée avec succès.");
    } catch (e) {
      debugPrint('Erreur dans deleteConversation: $e');
      showErrorSnackbar('Erreur, échec de la suppression de la conversation.');
    }
  }

  /* ---------- helpers ---------- */
  String _previewFor(Message m) {
    if ((m.image ?? '').isNotEmpty) return '📷 Photo';
    if ((m.audio ?? '').isNotEmpty) return '🎤 Message vocal';
    if ((m.video ?? '').isNotEmpty) return '🎬 Vidéo';
    final b = (m.body).trim();
    return b.isEmpty ? 'Nouveau message' : b;
  }
}
