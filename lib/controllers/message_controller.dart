import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/true_message_model.dart';
import '../services/ai_chabot_service.dart';
import '../services/message_api_service.dart';

class MessageController extends GetxController {
  final MessageApiService messageApiService;
  final AIChatbotService aiChatbotService = AIChatbotService();
  MessageController({required this.messageApiService});

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

  /// Send Message
  Future<void> sendMessage({
    required String token,
    required String conversationId,
    required String body,
    String? image,
    String? audio,
    String? video,
  }) async {
    try {
      final newMessage = await messageApiService.sendMessage(
        token: token,
        conversationId: conversationId,
        body: body,
        image: image,
        audio: audio,
        video: video,
      );
      messages.add(newMessage);
    } catch (e) {
      // Get.snackbar('Error', e.toString());
    }
  }

  /// Send AI Chatbot Message
  Future<void> sendAIChatbotMessage({
    required String token,
    required String conversationId,
    required String userMessage,
  }) async {
    try {
      isLoading.value = true;

      // Step 1: Get AI response
      final aiResponse = await aiChatbotService.sendMessageToAI(userMessage);

      // Step 2: Add AI response to the temporary list
      final aiMessage = Message(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}', // Unique ID for AI message
        conversationId: conversationId,
        senderId: 'ai', // Use a special sender ID for AI
        body: aiResponse,
        createdAt: DateTime.now(),
        isFromAI: true, // Mark as AI message
      );

      aiMessages.add(aiMessage); // Add to temporary list
    } catch (e) {
      Get.snackbar('Error'.tr, "Failed to get AI response".tr);
    } finally {
      isLoading.value = false;
    }
  }

  /// Clear AI messages when leaving the conversation
  void clearAIMessages() {
    aiMessages.clear();
  }
}
