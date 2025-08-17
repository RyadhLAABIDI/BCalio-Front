import 'dart:convert';
import 'package:bcalio/controllers/language_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:http/http.dart' as http;

class AIChatbotService {
  final String baseUrl = 'https://sd5.savooria.com/chat';
  static const String translateMessageUrl =
      "https://chat.speedobot.com/translate";

  /// Send a message to the AI chatbot
  Future<String> sendMessageToAI(String userMessage) async {
    debugPrint("sendMessageToAI====================: $userMessage");
    final url = Uri.parse(baseUrl);

    final body = {
      "messages": [
        {"role": "system", "content": "Hi! How can I assist you?"},
        {"role": "user", "content": userMessage},
      ],
      "model": "llama2",
    };
    debugPrint('Body=====================: $body');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));
      debugPrint("Response=====================: ${response.body}");
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        return responseData['message']['content'] as String;
      } else {
        throw Exception('Failed to get AI response: ${response.body}');
      }
    } catch (e) {
      throw Exception('AI Chatbot error: $e');
    }
  }

  final LanguageController languageController = Get.find<LanguageController>();
  Future<String> translateMessage(String message, {String? lang}) async {
    debugPrint("Translating message===================: $message");
    String language =
        lang ?? languageController.selectedLocale.value.languageCode;
    final url = Uri.parse(translateMessageUrl);

    final body = {"text": message, "lang": language};
    debugPrint("Translating message===================: $body");

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint("Response Data: ${responseData['translation']}");
        String jsonString = responseData['translation'] as String;
        debugPrint("Response Data: $jsonString");

        return jsonString;
      } else {
        throw Exception('Failed to get AI response: ${response.body}');
      }
    } catch (e) {
      throw Exception('AI Chatbot error: $e');
    }
  }
}
