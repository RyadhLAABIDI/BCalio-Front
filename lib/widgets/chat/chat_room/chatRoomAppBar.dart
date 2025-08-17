import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../controllers/user_controller.dart';
import '../../../controllers/conversation_controller.dart';
import '../../../models/conversation_model.dart';

import '../../../screens/chat/ChatRoom/remote_profile_screen.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';
import 'incoming_call_screen.dart';

class ChatRoomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String name;
  final String phoneNumber;
  final String conversationId;
  final String? avatarUrl;
  final DateTime? createdAt;
  final String recipientID;  // 1:1
  final String userId;       // local user
  final Color backgroundColor;

  const ChatRoomAppBar({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.conversationId,
    this.avatarUrl,
    this.createdAt,
    required this.recipientID,
    required this.userId,
    required this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  State<ChatRoomAppBar> createState() => _ChatRoomAppBarState();
}

class _ChatRoomAppBarState extends State<ChatRoomAppBar>
    with TickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;

  Conversation? _conv;
  List<String> _memberIds = const [];

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vu à l’instant';
    if (diff.inMinutes < 60) return 'Vu il y a ${diff.inMinutes} min';
    if (diff.inHours   < 24) return 'Vu il y a ${diff.inHours} h';
    return 'Vu le ${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
  }

  @override
  void initState() {
    super.initState();

    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);

    // Conversation -> savoir si groupe
    try {
      final convCtrl = Get.find<ConversationController>();
      _conv = convCtrl.conversations.firstWhereOrNull((c) => c.id == widget.conversationId);
      if (_conv != null && (_conv!.isGroup ?? false)) {
        _memberIds = _conv!.userIds.where((id) => id != widget.userId).toList();
      }
    } catch (_) {
      _conv = null;
      _memberIds = const [];
    }

    // Écoute des appels entrants (inchangé)
    final sock = Get.find<UserController>().socketService;
    sock.onIncomingCall = (callId, callerId, callerName, callType) => Get.to(
          () => IncomingCallScreen(
            callerName : callerName,
            callerId   : callerId,
            callId     : callId,
            callType   : callType,
            avatarUrl  : widget.avatarUrl,
            recipientID: widget.userId,
            isGroup    : false,
            members    : const [],
          ),
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 200),
        );

    sock.onIncomingGroupCall = (callId, callerId, callerName, callType, members) {
      final memberIds = members
          .map((m) => (m['userId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      Get.to(
        () => IncomingCallScreen(
          callerName : callerName,
          callerId   : callerId,
          callId     : callId,
          callType   : callType,
          avatarUrl  : _conv?.logo ?? widget.avatarUrl,
          recipientID: widget.userId,
          isGroup    : true,
          members    : memberIds,
        ),
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 200),
      );
    };

    sock.onCallError = (e) => Get.snackbar('Call error', e,
        backgroundColor: Colors.red, colorText: Colors.white);

    // 🔔 demander la présence initiale des membres de cette conversation
    final uc = Get.find<UserController>();
    if ((_conv?.isGroup ?? false) && _memberIds.isNotEmpty) {
      uc.requestPresenceFor(_memberIds);
    } else if (widget.recipientID.isNotEmpty) {
      uc.requestPresenceFor([widget.recipientID]);
    }
  }

  void _startCall({required bool video}) {
    final isGroup = (_conv?.isGroup ?? false) && _memberIds.isNotEmpty;

    Get.to(
      () => video
          ? VideoCallScreen(
              name:        _conv?.name ?? widget.name,
              avatarUrl:   _conv?.logo ?? widget.avatarUrl,
              phoneNumber: widget.phoneNumber,
              recipientID: isGroup ? '' : widget.recipientID,
              userId:      widget.userId,
              isCaller:    true,
              existingCallId: null,
              isGroup:     isGroup,
              memberIds:   isGroup ? _memberIds : null,
            )
          : AudioCallScreen(
              name:        _conv?.name ?? widget.name,
              avatarUrl:   _conv?.logo ?? widget.avatarUrl,
              phoneNumber: widget.phoneNumber,
              recipientID: isGroup ? '' : widget.recipientID,
              userId:      widget.userId,
              isCaller:    true,
              existingCallId: null,
              isGroup:     isGroup,
              memberIds:   isGroup ? _memberIds : null,
            ),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleName = _conv?.name ?? widget.name;
    final uc = Get.find<UserController>();

    Widget _statusLine() {
      return Obx(() {
        // GROUPE
        if ((_conv?.isGroup ?? false) && _memberIds.isNotEmpty) {
          final onlineCount = _memberIds.where((id) => uc.isOnline(id)).length;
          final text = onlineCount > 0
              ? '$onlineCount en ligne'
              : 'Hors ligne';
          return Text(text,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.7)));
        }

        // 1:1
        if (widget.recipientID.isEmpty) {
          return Text('Hors ligne',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.7)));
        }
        if (uc.isOnline(widget.recipientID)) {
          return const Text('En ligne',
              style: TextStyle(fontSize: 12, color: Colors.white));
        }
        final ls = uc.lastSeenOf(widget.recipientID);
        return Text(
          ls != null ? _timeAgo(ls) : 'Hors ligne',
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.7)),
        );
      });
    }

    return AppBar(
      backgroundColor: widget.backgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Iconsax.arrow_left, color: Colors.white, size: 26),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () => Get.to(
          () => RemoteProfileScreen(
            username:        titleName,
            profileImageUrl: ((_conv?.logo ?? widget.avatarUrl) ?? '')
                    .isNotEmpty
                ? (_conv?.logo ?? widget.avatarUrl)!
                : 'https://avatar.iran.liara.run/username?username=$titleName',
            phoneNumber:     widget.phoneNumber,
            email:           'test@gmail.com',
            createdAt:       widget.createdAt,
            status:          '',
            conversationId:  widget.conversationId,
          ),
          transition: Transition.rightToLeft,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withOpacity(.3),
              backgroundImage: ((_conv?.logo ?? widget.avatarUrl) ?? '').isNotEmpty
                  ? NetworkImage((_conv?.logo ?? widget.avatarUrl)!)
                  : null,
              child: ((_conv?.logo ?? widget.avatarUrl) ?? '').isEmpty
                  ? Text(titleName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleName,
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                FadeTransition(opacity: _fade, child: _statusLine()),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FadeTransition(
          opacity: _fade,
          child: IconButton(
            icon: const Icon(Iconsax.call, color: Colors.white),
            onPressed: () => _startCall(video: false),
          ),
        ),
        FadeTransition(
          opacity: _fade,
          child: IconButton(
            icon: const Icon(Iconsax.video, color: Colors.white),
            onPressed: () => _startCall(video: true),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }
}
