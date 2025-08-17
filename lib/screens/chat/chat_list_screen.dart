import 'package:bcalio/controllers/chat_room_controller.dart';
import 'package:bcalio/controllers/chatbot_controller.dart';
import 'package:bcalio/models/conversation_model.dart';
import 'package:bcalio/widgets/chat_bot/chat_bot_modal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart'; // haptics
import 'package:shared_preferences/shared_preferences.dart'; // NEW: local lastOpened
import '../../controllers/conversation_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/true_user_model.dart';
import '../../widgets/chat/chat_tile.dart';
import '../../widgets/chat/empty_chat.dart';
import '../../widgets/chat/list_tile_shimmer.dart';
import 'ChatRoom/chat_room_screen.dart';

class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> with TickerProviderStateMixin {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  final Map<String, AnimationController> _animationControllers = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _searchQuery = '';
  late AnimationController _robotAnimationController;
  late Animation<double> _scaleAnimation;
  bool _isModalOpen = false;
  final GlobalKey _robotKey = GlobalKey();

  // ---- NEW: mémorise localement le dernier "ouvert" pour chaque conv
  Map<String, int> _lastOpenedMs = {}; // convId -> epoch ms

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });

    _loadLastOpened(); // NEW

    // Robot animation
    _robotAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _robotAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _robotAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _robotAnimationController.reverse();
      }
    });

    _robotAnimationController.repeat(reverse: true);
  }

  // ---- NEW: charge/écrit le cache local
  Future<void> _loadLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    final map = prefs.getStringList('conv_last_opened') ?? [];
    // format: ["convId|1680000000000", ...]
    _lastOpenedMs = {
      for (final entry in map)
        if (entry.contains('|'))
          entry.split('|')[0]: int.tryParse(entry.split('|')[1]) ?? 0
    };
    setState(() {});
  }

  Future<void> _saveLastOpened() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _lastOpenedMs.entries
        .map((e) => '${e.key}|${e.value}')
        .toList(growable: false);
    await prefs.setStringList('conv_last_opened', list);
  }

  Future<void> _markOpened(String convId) async {
    _lastOpenedMs[convId] = DateTime.now().millisecondsSinceEpoch;
    setState(() {}); // refresh immédiat UI
    await _saveLastOpened();
  }

  int _getLastOpenedMs(String convId) => _lastOpenedMs[convId] ?? 0;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationControllers.forEach((_, controller) => controller.dispose());
    _robotAnimationController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh(ConversationController conversationController,
      UserController userController) async {
    final token = await userController.getToken();
    if (token != null) {
      await conversationController.fetchConversations(token);
      _refreshController.refreshCompleted();
    } else {
      _refreshController.refreshFailed();
      debugPrint('Error: Token is null. Unable to refresh conversations.');
    }
  }

  void _startDeleteAnimation(String conversationId, BuildContext context) {
    if (!_animationControllers.containsKey(conversationId)) {
      _animationControllers[conversationId] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
    }

    final animationController = _animationControllers[conversationId]!;
    animationController.forward().then((_) async {
      final userController = Get.find<UserController>();
      final token = await userController.getToken();
      if (token != null) {
        await Get.find<ConversationController>().deleteConversation(
          token: token,
          conversationId: conversationId,
        );
      }
      animationController.dispose();
      _animationControllers.remove(conversationId);
    });
  }

  // Transition ultra courte
  void _openChatWithAnimation(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.06, 0.0), end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _showChatbotModal(BuildContext context) {
    if (_isModalOpen) return;

    setState(() => _isModalOpen = true);

    final RenderBox? renderBox = _robotKey.currentContext?.findRenderObject() as RenderBox?;
    final position = renderBox != null ? renderBox.localToGlobal(Offset.zero) : Offset.zero;

    Future.delayed(const Duration(milliseconds: 100), () {
      final chatbotController = Get.find<ChatbotController>();
      final textController = TextEditingController();
      final focusNode = FocusNode();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        builder: (context) {
          return ChatbotModal(
            scrollController: ScrollController(),
            chatbotController: chatbotController,
            textController: textController,
            focusNode: focusNode,
            robotPosition: position,
          );
        },
      ).then((_) {
        setState(() => _isModalOpen = false);
      });
    });
  }

  List<Conversation> _filterConversations(
      List<Conversation> conversations, String query) {
    if (query.isEmpty) return conversations;

    final lowerCaseQuery = query.toLowerCase();
    return conversations.where((conversation) {
      if (conversation.isGroup ?? false) {
        if ((conversation.name ?? '').toLowerCase().contains(lowerCaseQuery)) {
          return true;
        }
      }

      for (var user in conversation.users) {
        if ((user.name ?? '').toLowerCase().contains(lowerCaseQuery)) {
          return true;
        }
      }

      return false;
    }).toList();
  }

  // ---- NEW: non-lu local = messages > lastOpened & pas envoyés par moi
  int _computeUnreadCount(Conversation c, String myId) {
    if (c.messages.isEmpty) return 0;
    final openedMs = _getLastOpenedMs(c.id);
    int count = 0;
    for (final m in c.messages) {
      if (m.senderId == myId) continue;
      if (m.createdAt.millisecondsSinceEpoch > openedMs) {
        count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final conversationController = Get.find<ConversationController>();
    final userController = Get.find<UserController>();
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final backgroundColor = isLight ? const Color(0xFFF5F7FA) : const Color.fromARGB(255, 0, 8, 8);
    final tileColor = isLight ? Colors.white : const Color.fromARGB(255, 14, 19, 23);
    final textColor = isLight ? Colors.black : Colors.white;
    final secondaryTextColor = isLight ? const Color(0xFF667781) : const Color(0xFF8696A0);

    final filteredConversations = _filterConversations(
        conversationController.conversations, _searchQuery);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchBar(context),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  color: backgroundColor,
                  child: Obx(
                    () => conversationController.isLoading.value
                        ? ListView.builder(
                            itemCount: 6,
                            itemBuilder: (context, index) => _buildShimmerTile(tileColor),
                          )
                        : conversationController.conversations.isEmpty
                            ? const EmptyChatList()
                            : SmartRefresher(
                                enablePullDown: true,
                                header: WaterDropMaterialHeader(
                                  backgroundColor: isLight
                                      ? theme.colorScheme.primary
                                      : theme.appBarTheme.backgroundColor ?? tileColor,
                                ),
                                controller: _refreshController,
                                onRefresh: () => _onRefresh(conversationController, userController),
                                child: filteredConversations.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Iconsax.search_status,
                                                size: 60, color: secondaryTextColor),
                                            const SizedBox(height: 16),
                                            Text(
                                              'no_results_found'.tr,
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  color: secondaryTextColor),
                                            ),
                                            Text(
                                              'try_different_keywords'.tr,
                                              style: TextStyle(color: secondaryTextColor),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        itemCount: filteredConversations.length,
                                        separatorBuilder: (context, index) => Padding(
                                          padding: const EdgeInsets.only(left: 80.0, top: 8, bottom: 8),
                                          child: Divider(
                                            height: 1,
                                            color: isLight ? Colors.grey[300] : Colors.grey[800],
                                          ),
                                        ),
                                        itemBuilder: (context, index) {
                                          final conversation = filteredConversations[index];
                                          final currentUserId = userController.currentUser.value?.id ?? '';

                                          final isGroup = conversation.isGroup ?? false;

                                          String displayName;
                                          String displayImage;
                                          String displayPhoneNumber = 'N/A';
                                          DateTime? otherUserCreatedAt;

                                          if (isGroup) {
                                            displayName = conversation.name ?? "Group Chat";
                                            displayImage = conversation.logo ?? "";
                                          } else {
                                            final otherUser = conversation.users.firstWhere(
                                              (user) => user.id != currentUserId,
                                              orElse: () => User(
                                                id: '',
                                                name: 'Unknown',
                                                email: '',
                                                image: '',
                                                phoneNumber: 'N/A',
                                              ),
                                            );

                                            displayName = otherUser.name ?? 'Unknown';
                                            displayImage = otherUser.image ?? '';
                                            displayPhoneNumber = otherUser.phoneNumber ?? 'N/A';
                                            otherUserCreatedAt = otherUser.createdAt;
                                          }

                                          final lastMessage = conversation.messages.isNotEmpty
                                              ? conversation.messages.last
                                              : null;

                                          String lastMessageText = "no_messages_yet".tr;
                                          IconData messageIcon = Iconsax.message;
                                          if (lastMessage != null) {
                                            if (lastMessage.image != null &&
                                                lastMessage.image!.isNotEmpty) {
                                              lastMessageText = "image_was_sent".tr;
                                              messageIcon = Iconsax.gallery;
                                            } else if (lastMessage.audio != null &&
                                                lastMessage.audio!.isNotEmpty) {
                                              if (lastMessage.audio!.contains("audio")) {
                                                lastMessageText = "audio_message_was_sent".tr;
                                                messageIcon = Iconsax.microphone;
                                              } else {
                                                lastMessageText = "video_message_was_sent".tr;
                                                messageIcon = Iconsax.video;
                                              }
                                            } else {
                                              String cleanedMessage = lastMessage.body.replaceFirst(
                                                  RegExp(r'^\[?system\]?\s*', caseSensitive: false),
                                                  '');
                                              lastMessageText = cleanedMessage;
                                            }
                                          }

                                          // ---- NEW: baseline cohérent, local
                                          final unreadCount = currentUserId.isEmpty
                                              ? 0
                                              : _computeUnreadCount(conversation, currentUserId);
                                          final isUnread = unreadCount > 0;

                                          return AnimatedBuilder(
                                            animation: _animationControllers[conversation.id] ??
                                                AnimationController(vsync: this),
                                            builder: (context, child) {
                                              final animationController =
                                                  _animationControllers[conversation.id];

                                              if (animationController != null &&
                                                  animationController.isAnimating) {
                                                return SizeTransition(
                                                  sizeFactor: animationController.drive(
                                                    Tween(begin: 1.0, end: 0.0)
                                                        .chain(CurveTween(curve: Curves.easeInOut)),
                                                  ),
                                                  child: SlideTransition(
                                                    position: animationController.drive(
                                                      Tween<Offset>(
                                                        begin: Offset.zero,
                                                        end: const Offset(1.0, 0.0),
                                                      ).chain(CurveTween(curve: Curves.easeInOut)),
                                                    ),
                                                    child: child,
                                                  ),
                                                );
                                              }
                                              return child!;
                                            },
                                            child: Slidable(
                                              key: Key(conversation.id),
                                              endActionPane: ActionPane(
                                                extentRatio: 0.5,
                                                motion: const ScrollMotion(),
                                                children: [
                                                  CustomSlidableAction(
                                                    onPressed: (context) {
                                                      _startDeleteAnimation(conversation.id, context);
                                                    },
                                                    backgroundColor: Colors.red,
                                                    foregroundColor: Colors.white,
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        const Icon(Iconsax.trash, size: 24),
                                                        const SizedBox(height: 4),
                                                        Text('Delete'.tr,
                                                            style: const TextStyle(fontSize: 12)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              child: _ModernChatTile(
                                                avatarImage: displayImage,
                                                title: displayName,
                                                lastMessage: lastMessageText.tr,
                                                time: lastMessage?.createdAt ?? DateTime.now(),
                                                isUnread: isUnread,
                                                unreadCount: unreadCount,
                                                messageIcon: messageIcon,
                                                tileColor: tileColor,
                                                textColor: textColor,
                                                secondaryTextColor: secondaryTextColor,
                                                onTap: () async {
                                                  HapticFeedback.selectionClick();
                                                  // 1) marque localement comme ouvert (UI instantanément à jour)
                                                  await _markOpened(conversation.id);

                                                  // 2) OUVERTURE IMMÉDIATE (sans attente réseau)
                                                  _openChatWithAnimation(
                                                    context,
                                                    ChatRoomPage(
                                                      name: displayName,
                                                      phoneNumber: displayPhoneNumber,
                                                      conversationId: conversation.id,
                                                      avatarUrl: displayImage,
                                                      createdAt: otherUserCreatedAt,
                                                    ),
                                                  );

                                                  // 3) API markAsSeen en arrière-plan
                                                  () async {
                                                    final token = await userController.getToken();
                                                    if (token != null && token.isNotEmpty) {
                                                      try {
                                                        await conversationController.markAsSeen(
                                                          token: token,
                                                          conversationId: conversation.id,
                                                        );
                                                      } catch (_) {/* silencieux */}
                                                    }
                                                  }();
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ),
              ),
                ),),
              
            ],
          ),
          Positioned(
            bottom: 100,
            right: 30,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: GestureDetector(
                onTap: () => _showChatbotModal(context),
                child: Container(
                  key: _robotKey,
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Lottie.asset(
                      'assets/json/robot.json',
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final backgroundColor = isLight ? const Color(0xFFF0F2F5) : const Color.fromARGB(255, 4, 15, 18);
    final tileColor = isLight ? Colors.white : const Color.fromARGB(255, 1, 4, 5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: backgroundColor,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isLight ? Colors.white : tileColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Iconsax.search_normal,
                      color: isLight ? const Color(0xFF667781) : Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'search_chats'.tr,
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                            color: isLight
                                ? const Color(0xFF667781)
                                : Colors.grey[400]),
                      ),
                      style: TextStyle(
                          color: isLight ? Colors.black : Colors.white),
                      onTap: () {
                        setState(() {
                          _isSearching = true;
                        });
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Iconsax.close_circle,
                          color: isLight ? const Color(0xFF667781) : Colors.grey[400]),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
                ],
              ),
            ),
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  });
                },
                child: Text('cancel'.tr,
                    style: TextStyle(
                        color: isLight ? theme.colorScheme.primary : Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerTile(Color tileColor) {
    return Container(
      color: tileColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 18,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==== TILE avec mise en avant claire des non-lus (couleur + ruban) ====
class _ModernChatTile extends StatefulWidget {
  final String avatarImage;
  final String title;
  final String lastMessage;
  final DateTime time;
  final bool isUnread;
  final int unreadCount;
  final IconData messageIcon;
  final Color tileColor;
  final Color textColor;
  final Color secondaryTextColor;
  final VoidCallback onTap;

  const _ModernChatTile({
    required this.avatarImage,
    required this.title,
    required this.lastMessage,
    required this.time,
    required this.isUnread,
    required this.unreadCount,
    required this.messageIcon,
    required this.tileColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.onTap,
  });

  @override
  State<_ModernChatTile> createState() => _ModernChatTileState();
}

class _ModernChatTileState extends State<_ModernChatTile> {
  bool _pressed = false;

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (time.isAfter(today)) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (time.isAfter(yesterday)) {
      return 'Yesterday';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = theme.colorScheme.primary;

    // Fond légèrement teinté si non-lu
    final tinted = widget.isUnread
        ? Color.alphaBlend(badgeColor.withOpacity(0.06), widget.tileColor)
        : widget.tileColor;

    final decoration = BoxDecoration(
      color: tinted,
      borderRadius: BorderRadius.circular(16),
      border: widget.isUnread
          ? Border.all(color: badgeColor.withOpacity(0.25), width: 1.1)
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(widget.isUnread ? 0.12 : 0.05),
          blurRadius: widget.isUnread ? 14 : 8,
          spreadRadius: widget.isUnread ? 2 : 1,
          offset: const Offset(0, 2),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.colorScheme.primary.withOpacity(0.08),
          highlightColor: theme.colorScheme.primary.withOpacity(0.06),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  // Ruban accent si non-lu
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: widget.isUnread ? 4 : 0,
                    height: 56,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  if (widget.isUnread) const SizedBox(width: 12),

                  // Avatar
                  Container(
                    padding: const EdgeInsets.all(2.2),
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.transparent,
                      backgroundImage: widget.avatarImage.isNotEmpty
                          ? NetworkImage(widget.avatarImage) as ImageProvider
                          : const AssetImage('assets/default_avatar.png'),
                      child: widget.avatarImage.isEmpty
                          ? Text(
                              widget.title.isNotEmpty ? widget.title[0] : '',
                              style: const TextStyle(fontSize: 24, color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Textes
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titre + time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      widget.isUnread ? FontWeight.w700 : FontWeight.w600,
                                  color: widget.textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(widget.time),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    widget.isUnread ? FontWeight.w600 : FontWeight.w400,
                                color: widget.isUnread
                                    ? widget.textColor
                                    : widget.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // dernière ligne
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              widget.messageIcon,
                              size: 18,
                              color: widget.isUnread ? badgeColor : widget.secondaryTextColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.lastMessage,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      widget.isUnread ? FontWeight.w600 : FontWeight.w400,
                                  color: widget.isUnread
                                      ? widget.textColor
                                      : widget.secondaryTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),

                            // Badge non-lu (1, 2, ... 9+)
                            AnimatedScale(
                              scale: widget.isUnread ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutBack,
                              child: widget.isUnread
                                  ? Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeColor,
                                        borderRadius: BorderRadius.circular(999),
                                        boxShadow: [
                                          BoxShadow(
                                            color: badgeColor.withOpacity(0.35),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        widget.unreadCount > 9
                                            ? '9+'
                                            : '${widget.unreadCount}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
