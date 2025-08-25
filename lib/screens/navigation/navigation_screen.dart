import 'dart:developer';
import 'dart:ui' show BackdropFilter, ImageFilter;

import 'package:bcalio/controllers/chatbot_controller.dart';
import 'package:bcalio/controllers/contact_controller.dart';
import 'package:bcalio/controllers/conversation_controller.dart';
import 'package:bcalio/controllers/theme_controller.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/screens/contacts/all_contacts_screen.dart';
import 'package:bcalio/screens/home/home_screen.dart';
import 'package:bcalio/screens/map/map_screen.dart';
import 'package:bcalio/screens/navigation/widgets/all_contacts_app_bar.dart';
import 'package:bcalio/screens/navigation/widgets/custom_app_bar.dart';
import 'package:bcalio/screens/navigation/widgets/map_app_bar.dart';
import 'package:bcalio/screens/settings/settings_screen.dart';
import 'package:bcalio/services/contact_api_service.dart';
import 'package:bcalio/themes/theme.dart';
import 'package:bcalio/widgets/chat/chat_room/call_log_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:bcalio/controllers/unread_badges_controller.dart';
import 'package:bcalio/controllers/call_log_controller.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;

  final ThemeController themeController = Get.find<ThemeController>();
  final ConversationController conversationController =
      Get.put(ConversationController(conversationApiService: Get.find()));
  final UserController userController = Get.find<UserController>();
  final ChatbotController chatbotController = Get.put(ChatbotController());
  final RxBool isSearching = false.obs;
  final ContactController contactController =
      Get.put(ContactController(contactApiService: ContactApiService()));
  final FocusNode focusNode = FocusNode();
  final textController = TextEditingController();

  late PageController _pageController;
  late List<AnimationController> _animationControllers;
  late List<Animation<Offset>> _animations;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    if (!Get.isRegistered<UnreadBadgesController>()) {
      Get.put(UnreadBadgesController(), permanent: true);
    }
    if (!Get.isRegistered<CallLogController>()) {
      Get.put(CallLogController(), permanent: true);
    }

    _animationControllers = List.generate(
      5,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _animations = [
      Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: _animationControllers[0], curve: Curves.easeOut)),
      Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: _animationControllers[1], curve: Curves.easeOut)),
      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: _animationControllers[2], curve: Curves.easeOut)),
      Tween<Offset>(begin: const Offset(0.6, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: _animationControllers[3], curve: Curves.easeOut)),
      Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
          .animate(CurvedAnimation(parent: _animationControllers[4], curve: Curves.easeOut)),
    ];

    _animationControllers[_selectedIndex].forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var c in _animationControllers) c.dispose();
    super.dispose();
  }

  Future<void> onItemSelected(int index) async {
    if (index == _selectedIndex) return;

    setState(() => _selectedIndex = index);
    _animationControllers[_selectedIndex].reset();
    _animationControllers[_selectedIndex].forward();

    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    // Effacer le badge UNIQUEMENT quand l’onglet Calls (index 3) est ouvert
    if (index == 3 && Get.isRegistered<UnreadBadgesController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<UnreadBadgesController>().clearCalls();
      });
    }
  }

  final List<Widget> _screens = const [
    MapScreen(), // 0
    SafeArea(maintainBottomViewPadding: true, child: HomePage()), // 1
    SafeArea(maintainBottomViewPadding: true, child: AllContactsScreen()), // 2
    CallLogScreen(), // 3
    SafeArea(maintainBottomViewPadding: true, child: SettingsScreen()), // 4
  ];

  final List<PreferredSizeWidget?> _appBar = [
    MapAppBar(),        // 0
    CustomAppBar(),     // 1
    AllContactAppBar(), // 2
    AppBar(),           // 3 (placeholder)
    AppBar(),           // 4 (placeholder)
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: (_selectedIndex == 3 || _selectedIndex == 4) ? null : _appBar[_selectedIndex],
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(5, (i) => SlideTransition(position: _animations[i], child: _screens[i])),
      ),
      extendBody: true,
      bottomNavigationBar: _FrostedModernNavBar(
        selectedIndex: _selectedIndex,
        onSelected: onItemSelected,
        isDark: isDark,
      ),
    );
  }
}

/// Barre de nav
class _FrostedModernNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool isDark;

  const _FrostedModernNavBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navMedia = mq.copyWith(textScaler: const TextScaler.linear(1.0));

    final bg = (isDark ? const Color(0xFF101014) : Colors.white).withOpacity(0.55);
    final border = (isDark ? const Color.fromARGB(255, 133, 129, 129) : const Color.fromARGB(255, 133, 129, 129));
    final Color brand = isDark ? kDarkPrimaryColor : kLightPrimaryColor;

    return MediaQuery(
      data: navMedia,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    height: 72,
                    indicatorColor: brand.withOpacity(0.12),
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                      (states) => TextStyle(
                        fontSize: 12,
                        fontWeight: states.contains(WidgetState.selected)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: brand,
                      ),
                    ),
                    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
                      (states) => IconThemeData(
                        size: 22,
                        color: brand,
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onSelected,
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.location_on_outlined),
                        selectedIcon: Icon(Icons.location_on),
                        label: 'Location',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.chat_outlined),
                        selectedIcon: Icon(Icons.chat),
                        label: 'Chat',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_add_outlined),
                        selectedIcon: Icon(Icons.person_add),
                        label: 'Contact',
                      ),
                      // Calls avec fond rouge + compteur si non lu
                      NavigationDestination(
                        icon: _CallsIcon(selected: false),
                        selectedIcon: _CallsIcon(selected: true),
                        label: 'Calls',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icône “Calls” avec fond rouge complet + badge quand il y a des manqués
class _CallsIcon extends StatelessWidget {
  final bool selected;
  const _CallsIcon({required this.selected});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<UnreadBadgesController>()) {
      return Icon(selected ? Icons.call : Icons.call_outlined);
    }
    final ctrl = Get.find<UnreadBadgesController>();
    return Obx(() {
      final count = ctrl.calls.value;

      if (count <= 0) {
        return Icon(selected ? Icons.call : Icons.call_outlined);
      }

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.call, size: 18, color: Colors.white),
          ),
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent, width: 1),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
