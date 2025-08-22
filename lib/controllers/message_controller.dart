import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/true_message_model.dart';
import '../services/ai_chabot_service.dart';
import '../services/message_api_service.dart';

// 👇 imports ajoutés
import '../services/push_api_service.dart';
import 'conversation_controller.dart';
import 'user_controller.dart';

class MessageController extends GetxController {
  final MessageApiService messageApiService;
  final AIChatbotService aiChatbotService = AIChatbotService();
  MessageController({required this.messageApiService});

  final PushApiService _pushApi = PushApiService(); // 👈 NEW

  RxList<Message> messages = <Message>[].obs;
  RxList<Message> aiMessages = <Message>[].obs;
  RxBool isLoading = false.obs;

  /// Fetch Messages
  Future<void> fetchMessages(String token, String conversationId) async {
    if (token.isEmpty || conversationId.isEmpty) {
      Get.snackbar('Error'.tr, 'Token and conversation ID cannot be empty.');
      return;
    }

    isLoading.value = true;
    try {
      final fetchedMessages =
          await messageApiService.getMessages(token, conversationId);
      messages.value = fetchedMessages;
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      Get.snackbar(
          'Error'.tr, "Failed to fetch messages. Please try again.".tr);
    } finally {
      isLoading.value = false;
    }
  }

  /// Send Message + 🔔 déclenche la push "chat_message"
  Future<void> sendMessage({
    required String token,
    required String conversationId,
    required String body,
    String? image,
    String? audio,
    String? video,
  }) async {
    try {
      // 1) Envoi serveur principal (création du message)
      final newMessage = await messageApiService.sendMessage(
        token: token,
        conversationId: conversationId,
        body: body,
        image: image,
        audio: audio,
        video: video,
      );
      messages.add(newMessage);

      // 2) Détermination du type + contenu à afficher dans la notif
      String contentType = 'text';
      String textForPush = body;
      if (image != null && image.isNotEmpty) {
        contentType = 'image';
        textForPush = image; // l’URL de l’image (BigPicture dans Android natif)
      } else if (audio != null && audio.isNotEmpty) {
        contentType = 'audio';
        textForPush = audio; // URL / hint
      } else if (video != null && video.isNotEmpty) {
        contentType = 'video';
        textForPush = video; // URL / hint
      }

      // 3) Qui notifier ? (autres membres de la conversation)
      final convCtrl = Get.find<ConversationController>();
      final userCtrl = Get.find<UserController>();

      // trouve la conv en mémoire
      final conv = convCtrl.conversations.firstWhereOrNull((c) => c.id == conversationId);
      if (conv == null) {
        // pas en cache ? on ne fait pas échouer l’envoi : on skip la notif proprement
        debugPrint('[push] conversation not in cache, skip notify');
        return;
      }

      final myId = userCtrl.userId;
      final toUserIds = <String>{
        // d’abord via users (objets)
        ...conv.users.map((u) => u.id),
        // fallback via userIds (strings)
        ...conv.userIds,
      }.where((id) => id.isNotEmpty && id != myId).toList();

      if (toUserIds.isEmpty) {
        debugPrint('[push] no recipients to notify');
        return;
      }

      // 4) Métadonnées expéditeur (nom + avatar)
      final fromName = userCtrl.userName;
      final avatarUrl = userCtrl.user?.image ?? '';

      // 5) Envoi de la commande de push au call-server
      await _pushApi.notifyNewMessage(
        toUserIds: toUserIds,
        roomId: conversationId,
        messageId: newMessage.id, // si ton modèle le contient
        fromId: myId,
        fromName: fromName,
        avatarUrl: avatarUrl,
        text: textForPush,
        contentType: contentType,
        isGroup: toUserIds.length > 1,
        sentAtIso: (newMessage.createdAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
      );
    } catch (e) {
      // On ne bloque pas l’UI si la push échoue, l’envoi du message est prioritaire
      debugPrint('Error sending message / notify: $e');
      // Get.snackbar('Error', e.toString());
    }
  }

  /// Send AI Chatbot Message (inchangé)
  Future<void> sendAIChatbotMessage({
    required String token,
    required String conversationId,
    required String userMessage,
  }) async {
    try {
      isLoading.value = true;

      final aiResponse = await aiChatbotService.sendMessageToAI(userMessage);
      final aiMessage = Message(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        senderId: 'ai',
        body: aiResponse,
        createdAt: DateTime.now(),
        isFromAI: true,
      );
      aiMessages.add(aiMessage);
    } catch (e) {
      Get.snackbar('Error'.tr, "Failed to get AI response".tr);
    } finally {
      isLoading.value = false;
    }
  }

  void clearAIMessages() => aiMessages.clear();
}
