import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:language_detector/language_detector.dart';

import '../services/ai_chabot_service.dart'; // Replace with your actual package name

class ChatbotController extends GetxController {
  final AIChatbotService _aiChatbotService = AIChatbotService();
  final RxList<String> messages = <String>[].obs;
  final RxBool isLoading = false.obs;
  final RxString userInput = ''.obs;

  // Add a system message to start the conversation
  void initializeChat() {
    messages.add("hi_how_can_i_assist_you?".tr);
  }

  // Send message to AI and handle response
  Future<void> sendMessage(String message) async {
    debugPrint("User sendMessage=====================: $message");
    if (message.isEmpty) return;

    isLoading.value = true;

    messages.add("You: $message");

    try {
      debugPrint('Detecting Language=====================: $message');
      final language = await LanguageDetector.getLanguageCode(content: message);
      debugPrint('Detected 11111=====================: ${language}');
      final messageTranslatedIA =
          await _aiChatbotService.translateMessage(message, lang: 'en');

      debugPrint(
          'Translated Message=====================: $messageTranslatedIA');
      final aiResponse =
          await _aiChatbotService.sendMessageToAI(messageTranslatedIA);
      final messageTranslated =
          await _aiChatbotService.translateMessage(aiResponse, lang: language);
      messages.add("AI: $messageTranslated");
    } catch (e) {
      debugPrint('Error=====================: $e');
      messages.add("AI: Sorry, there was an error processing your request.");
    } finally {
      isLoading.value = false;
      userInput.value = ''; // Clear the input field after sending
    }
  }

  // Clear the conversation
  void clearConversation() {
    messages.clear();
    initializeChat(); // Reinitialize with the default message
  }
}
