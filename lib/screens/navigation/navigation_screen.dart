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

import '../../routes.dart';

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

  // index visuel du bouton "Room" dans la NavBar (action, pas d’onglet)
  static const int _roomsNavIndex = 2;

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

  // map index NavBar → index PageView
  int _mapNavToPageIndex(int navIndex) {
    if (navIndex == _roomsNavIndex) return _selectedIndex; // Room = action
    if (navIndex >= _roomsNavIndex) {
      return navIndex - 1; // décalage après Room
    }
    return navIndex;
  }

  Future<void> onNavTap(int navIndex) async {
    if (navIndex == _roomsNavIndex) {
      _openRoomSheet(); // action : Join/Create room
      return;
    }

    final nextPage = _mapNavToPageIndex(navIndex);
    if (nextPage == _selectedIndex) return;

    setState(() => _selectedIndex = nextPage);
    _animationControllers[_selectedIndex].reset();
    _animationControllers[_selectedIndex].forward();

    await _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    if (nextPage == 3 && Get.isRegistered<UnreadBadgesController>()) {
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
    AppBar(),           // 3
    AppBar(),           // 4
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
        onNavTap: onNavTap,
        isDark: isDark,
        roomsNavIndex: _roomsNavIndex,
        openRoomSheet: _openRoomSheet,
      ),
    );
  }

  // ---------- Bottom sheet Room (Join / Create) ----------
  void _openRoomSheet() {
    final nameCtrl = TextEditingController(text: userController.userName);
    final roomCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final neon = themeController.isDarkMode ? kDarkPrimaryColor : kLightPrimaryColor;
        final glass = (themeController.isDarkMode ? const Color(0xFF101014) : Colors.white).withOpacity(0.65);
        return _RoomSheet(
          neon: neon,
          glass: glass,
          nameCtrl: nameCtrl,
          roomCtrl: roomCtrl,
        );
      },
    );
  }
}

/// ------------------------ SHEET CONTENU AVANCÉ ------------------------
class _RoomSheet extends StatefulWidget {
  final Color neon;
  final Color glass;
  final TextEditingController nameCtrl;
  final TextEditingController roomCtrl;

  const _RoomSheet({
    required this.neon,
    required this.glass,
    required this.nameCtrl,
    required this.roomCtrl,
  });

  @override
  State<_RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends State<_RoomSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _arrowCtrl;
  late final Animation<Offset> _float;
  late final Animation<double> _pulse;
  double _extent = 0.48; // taille courante du Draggable sheet

  bool get _showGuide => _extent > 0.62; // seuil pour révéler la “surprise”

  @override
  void initState() {
    super.initState();
    _arrowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _float = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut),
    );
    _pulse = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.46,
      minChildSize: 0.38,
      maxChildSize: 0.92,
      builder: (_, scroll) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) {
            setState(() => _extent = n.extent);
            return false;
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.glass,
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          // 🎥 emoji titre
                          Text('🎥', style: TextStyle(fontSize: 22, color: widget.neon)),
                          const SizedBox(width: 8),
                          Text('rooms'.tr,
                              style: TextStyle(color: widget.neon, fontWeight: FontWeight.w800, fontSize: 18)),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: widget.nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'your_name'.tr,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: widget.roomCtrl,
                        decoration: InputDecoration(
                          labelText: 'room_id_optional'.tr,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          final name = widget.nameCtrl.text.trim();
                          final room = widget.roomCtrl.text.trim().isEmpty
                              ? DateTime.now().millisecondsSinceEpoch.toRadixString(36)
                              : widget.roomCtrl.text.trim();
                          if (name.isEmpty) return;
                          Navigator.pop(context);
                          Get.toNamed(
                            Routes.room,
                            arguments: {'room': room, 'name': name},
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('join_create'.tr),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),

                      // ---------- HINT collé au bouton (zéro grand espace) ----------
                      const SizedBox(height: 10),
                      if (!_showGuide) _InstructionHint(float: _float, pulse: _pulse),

                      // ---------- SURPRISE: GUIDE (apparait quand on étire) ----------
                      AnimatedCrossFade(
                        crossFadeState: _showGuide ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        duration: const Duration(milliseconds: 300),
                        firstCurve: Curves.easeOut,
                        secondCurve: Curves.easeOut,
                        firstChild: _GuideCard(neon: widget.neon),
                        secondChild: const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bandeau “Instructions / Balayez vers le haut” AVEC EMOJIS (collé au bouton)
class _InstructionHint extends StatelessWidget {
  final Animation<Offset> float;
  final Animation<double> pulse;
  const _InstructionHint({required this.float, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 📖 Instructions — flèche supprimée
        ScaleTransition(
          scale: pulse,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📖 ${'instructions'.tr}',
                    style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        SlideTransition(
          position: float,
          child: Opacity(
            opacity: 0.9,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⬆️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text('swipe_up'.tr, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Carte “Guide” stylée (glass + emojis + bullets wrap-safe)
class _GuideCard extends StatelessWidget {
  final Color neon;
  const _GuideCard({required this.neon});

  @override
  Widget build(BuildContext context) {
    final onBg = Theme.of(context).colorScheme.onSurface.withOpacity(0.88);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.55),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: neon.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header fun avec emoji ✨
          Row(
            children: [
              Text('✨', style: TextStyle(fontSize: 20, color: neon)),
              const SizedBox(width: 8),
              Text('quick_guide'.tr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: neon)),
            ],
          ),
          const SizedBox(height: 10),

          // puces en emojis (pas d’icônes)
          _EmojiBullet(emoji: '👤', text: 'bullet_name'.tr, onBg: onBg),
          _EmojiBullet(emoji: '🚪', text: 'bullet_join'.tr, onBg: onBg),
          _EmojiBullet(emoji: '➕', text: 'bullet_create'.tr, onBg: onBg),
          _EmojiBullet(emoji: '🔗', text: 'bullet_share'.tr, onBg: onBg),

          const SizedBox(height: 6),
          // Astuce WRAP-SAFE (plus d’overflow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎉', style: TextStyle(fontSize: 18, color: neon)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'tip_more'.tr,
                  softWrap: true,
                  style: TextStyle(fontSize: 12.5, height: 1.25, color: onBg),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmojiBullet extends StatelessWidget {
  final String emoji;
  final String text;
  final Color onBg;
  const _EmojiBullet({required this.emoji, required this.text, required this.onBg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 20, child: Text(emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              softWrap: true,
              style: TextStyle(fontSize: 13.5, height: 1.25, color: onBg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre de nav
class _FrostedModernNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final bool isDark;
  final int roomsNavIndex;
  final VoidCallback openRoomSheet;

  const _FrostedModernNavBar({
    required this.selectedIndex,
    required this.onNavTap,
    required this.isDark,
    required this.roomsNavIndex,
    required this.openRoomSheet,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navMedia = mq.copyWith(textScaler: const TextScaler.linear(1.0));

    final bg = (isDark ? const Color(0xFF101014) : Colors.white).withOpacity(0.55);
    final border = (isDark ? const Color.fromARGB(255, 133, 129, 129) : const Color.fromARGB(255, 133, 129, 129));
    final Color brand = isDark ? kDarkPrimaryColor : kLightPrimaryColor;

    // 👉 Montre le label uniquement pour l’onglet sélectionné (gain d’espace)
    const labelBehavior = NavigationDestinationLabelBehavior.onlyShowSelected;

    int uiSelectedIndex() {
      if (selectedIndex <= 1) return selectedIndex; // 0,1 -> 0,1
      return selectedIndex + 1;                      // 2->3  3->4  4->5
    }

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
                    // Icônes : taille de base (on met le zoom dans selectedIcon via AnimatedScale)
                    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
                      (states) => IconThemeData(
                        size: states.contains(WidgetState.selected) ? 22 : 22,
                        color: brand,
                      ),
                    ),
                    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
                      (states) => TextStyle(
                        fontSize: 12,
                        fontWeight: states.contains(WidgetState.selected)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: brand,
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    selectedIndex: uiSelectedIndex(),
                    onDestinationSelected: onNavTap,
                    labelBehavior: labelBehavior,
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.location_on_outlined),
                        selectedIcon: AnimatedScale(
                          scale: 1.18,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: const Icon(Icons.location_on),
                        ),
                        label: 'Location'.tr,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.chat_outlined),
                        selectedIcon: AnimatedScale(
                          scale: 1.18,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: const Icon(Icons.chat),
                        ),
                        label: 'Chat'.tr,
                      ),
                      // Bouton "Room" AU CENTRE — action : bottom sheet (pas de page)
                      NavigationDestination(
                        icon: const Icon(Icons.videocam_outlined),
                        selectedIcon: AnimatedScale(
                          scale: 1.18,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: const Icon(Icons.videocam),
                        ),
                        label: 'Room'.tr,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.person_add_outlined),
                        selectedIcon: AnimatedScale(
                          scale: 1.18,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: const Icon(Icons.person_add),
                        ),
                        label: 'Contact'.tr,
                      ),
                      NavigationDestination(
                        icon: const _CallsIcon(selected: false),
                        selectedIcon: AnimatedScale(
                          scale: 1.18,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: const _CallsIcon(selected: true),
                        ),
                        label: 'Calls'.tr,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: AnimatedScale(
                          scale: 1.18,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: const Icon(Icons.settings),
                        ),
                        label: 'Settings'.tr,
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
