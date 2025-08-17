import 'dart:developer';

import 'package:bcalio/controllers/chatbot_controller.dart';
import 'package:bcalio/controllers/contact_controller.dart';
import 'package:bcalio/controllers/conversation_controller.dart';
import 'package:bcalio/controllers/theme_controller.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/screens/contacts/Add_Contact_screen.dart';
import 'package:bcalio/screens/contacts/all_contacts_screen.dart';
import 'package:bcalio/screens/home/home_screen.dart';
import 'package:bcalio/screens/map/map_screen.dart';
import 'package:bcalio/screens/navigation/widgets/all_contacts_app_bar.dart';
import 'package:bcalio/screens/navigation/widgets/custom_app_bar.dart';
import 'package:bcalio/screens/navigation/widgets/map_app_bar.dart';
import 'package:bcalio/screens/settings/settings_screen.dart';
import 'package:bcalio/services/contact_api_service.dart';
import 'package:bcalio/themes/theme.dart';
import 'package:bcalio/widgets/base_widget/custom_search_bar.dart';
import 'package:bcalio/widgets/chat/chat_room/call_log_screen.dart';
import 'package:bcalio/widgets/chat_bot/chat_bot_modal.dart';
import 'package:bottom_navy_bar/bottom_navy_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:lottie/lottie.dart';

// NEW: écran Journal d’appel

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final ThemeController themeController = Get.find<ThemeController>();
  final ConversationController conversationController =
      Get.put(ConversationController(conversationApiService: Get.find()));
  final UserController userController = Get.find<UserController>();
  final ChatbotController chatbotController = Get.put(ChatbotController());
  final RxBool isSearching = false.obs;
  final ContactController contactController = Get.put(
    ContactController(contactApiService: ContactApiService()),
  );
  final FocusNode focusNode = FocusNode();
  final textController = TextEditingController();

  late PageController _pageController;
  late List<AnimationController> _animationControllers;
  late List<Animation<Offset>> _animations;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // NOTE: on passe à 5 écrans (Map, Home, Contacts, Calls, Settings)
    _animationControllers = List.generate(
      5,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _animations = [
      // 0) MapScreen (slide depuis gauche)
      Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _animationControllers[0],
        curve: Curves.easeOut,
      )),
      // 1) HomePage (slide depuis bas)
      Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _animationControllers[1],
        curve: Curves.easeOut,
      )),
      // 2) AllContacts (slide depuis droite)
      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _animationControllers[2],
        curve: Curves.easeOut,
      )),
      // 3) CallLogScreen (slide doux depuis droite)
      Tween<Offset>(begin: const Offset(0.6, 0), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _animationControllers[3],
        curve: Curves.easeOut,
      )),
      // 4) Settings (slide depuis haut)
      Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _animationControllers[4],
        curve: Curves.easeOut,
      )),
    ];

    // Démarrer l'animation initiale
    _animationControllers[_selectedIndex].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  onItemSelected(index) async {
    if (index == _selectedIndex) return;

    // Animation de transition (on garde ta logique simple)
    setState(() {
      _selectedIndex = index;
    });

    _animationControllers[_selectedIndex].reset();
    _animationControllers[_selectedIndex].forward();

    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  // NOTE: ajout de CallLogScreen à l’index 3
  final List<Widget> _screens = [
    MapScreen(),                                      // 0
    const SafeArea(maintainBottomViewPadding: true, child: HomePage()),       // 1
    const SafeArea(maintainBottomViewPadding: true, child: AllContactsScreen()), // 2
    const CallLogScreen(),                            // 3 (Scaffold interne)
    const SafeArea(maintainBottomViewPadding: true, child: SettingsScreen()), // 4
  ];

  // On garde la structure existante; l’app-bar externe n’est pas utilisée pour 3 & 4
  final List<PreferredSizeWidget?> _appBar = [
    MapAppBar(),         // 0
    CustomAppBar(),      // 1
    AllContactAppBar(),  // 2
    AppBar(),            // 3 (placeholder, sera masqué)
    AppBar(),            // 4 (placeholder, sera masqué)
  ];

  final language = Get.locale?.languageCode ?? 'en';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      // Masquer l’app-bar externe pour Calls(3) et Settings(4) afin d’utiliser leur propre Scaffold/entête
      appBar: (_selectedIndex == 3 || _selectedIndex == 4) ? null : _appBar[_selectedIndex],
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(5, (index) {
          return SlideTransition(
            position: _animations[index],
            child: _screens[index],
          );
        }),
      ),
      extendBody: true,
      extendBodyBehindAppBar: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: BottomNavyBar(
          containerHeight: MediaQuery.sizeOf(context).height * .06,
          borderRadius: BorderRadius.circular(49),
          backgroundColor: isDarkMode ? kDarkPrimaryColor : kLightPrimaryColor,
          iconSize: 14.74,
          shadowColor: Colors.black.withOpacity(0.14),
          blurRadius: 6,
          shadowOffset: const Offset(0, 2),
          selectedIndex: _selectedIndex,
          onItemSelected: onItemSelected,
          showElevation: true,
          items: [
            BottomNavyBarItem(
              icon: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width * .015),
                child: const Icon(Icons.location_on_outlined, size: 20),
              ),
              title: Text("Location".tr),
              activeColor: isDarkMode ? kDarkBgColor : kShadowColor,
              inactiveColor: isDarkMode ? kDarkBgColor : kShadowColor,
            ),
            BottomNavyBarItem(
              icon: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width * .015),
                child: const Icon(Icons.chat, size: 20),
              ),
              title: Text("Chat".tr),
              activeColor: isDarkMode ? kDarkBgColor : kShadowColor,
              inactiveColor: isDarkMode ? kDarkBgColor : kShadowColor,
            ),
            BottomNavyBarItem(
              icon: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width * .015),
                child: const Icon(Icons.person_add, size: 20),
              ),
              title: Text("Contact".tr),
              activeColor: isDarkMode ? kDarkBgColor : kShadowColor,
              inactiveColor: isDarkMode ? kDarkBgColor : kShadowColor,
            ),
            // NEW: onglet Calls (Journal d’appel)
            BottomNavyBarItem(
              icon: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width * .015),
                child: const Icon(Icons.call, size: 20),
              ),
              title: Text("Calls".tr),
              activeColor: isDarkMode ? kDarkBgColor : kShadowColor,
              inactiveColor: isDarkMode ? kDarkBgColor : kShadowColor,
            ),
            BottomNavyBarItem(
              icon: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width * .015),
                child: const Icon(Icons.settings, size: 20),
              ),
              title: Text("Settings".tr),
              activeColor: isDarkMode ? kDarkBgColor : kShadowColor,
              inactiveColor: isDarkMode ? kDarkBgColor : kShadowColor,
            ),
          ],
        ),
      ),
    );
  }
}
