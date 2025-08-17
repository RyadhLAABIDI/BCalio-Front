import 'package:bcalio/controllers/chatbot_controller.dart';
import 'package:bcalio/controllers/contact_controller.dart';
import 'package:bcalio/routes.dart';
import 'package:bcalio/services/contact_api_service.dart';
import 'package:bcalio/widgets/chat_bot/chat_bot_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/conversation_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/user_controller.dart';
import '../../themes/theme.dart';
import '../../widgets/base_widget/custom_search_bar.dart';
import '../../widgets/home/more_button.dart';
import '../chat/chat_list_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ThemeController themeController = Get.find<ThemeController>();
  final ConversationController conversationController =
      Get.put(ConversationController(conversationApiService: Get.find()));
  final UserController userController = Get.find<UserController>();
  final ChatbotController chatbotController = Get.put(ChatbotController());
  final RxBool isSearching = false.obs;
  final ContactController contactController = Get.put(
    ContactController(contactApiService: ContactApiService()),
  );
  Future<void> _checkFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

    if (isFirstLaunch) {
      // Exécuter la fonction une seule fois
      chatbotController.initializeChat();

      // Mettre à jour l'indicateur dans SharedPreferences
      await prefs.setBool('isFirstLaunch', false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchConversations();

    userController.getToken().then((token) {
      if (token != null) {
        conversationController.startPolling(token);
      }
    });
    _checkFirstLaunch();
  }
final FocusNode focusNode = FocusNode();
 @override
  void dispose() {
    chatbotController.initializeChat();
    super.dispose();
  }

  final textController = TextEditingController();
   void fetchConversations() async {
    final token = await userController.getToken();
    if (token != null) {
      await conversationController.fetchConversations(token);
    } else {
      Get.toNamed(Routes.login);
      debugPrint('Error: Token is null. Unable to fetch conversations.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return 
    ChatList();
     
  }
}
