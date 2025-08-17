import 'dart:async';
/*import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../controllers/conversation_controller.dart';
import '../controllers/user_controller.dart';

void backgroundService() {
  FlutterBackgroundService().onDataReceived.listen((event) {
    // Check for any event or trigger here if needed
  });

  // Initialize services inside the background task
  final ConversationController conversationController = Get.find<ConversationController>();
  final UserController userController = Get.find<UserController>();

  // Perform background tasks
  Timer.periodic(const Duration(seconds: 5), (_) async {
    final token = await userController.getToken();
    if (token != null) {
      // Fetch, refresh, and poll conversations in the background
      await conversationController.fetchConversations(token);
      await conversationController.refreshConversations(token);
      conversationController.startPolling(token);
    }
  });
}
*/
