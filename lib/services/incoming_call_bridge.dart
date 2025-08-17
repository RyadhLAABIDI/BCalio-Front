import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'; // 👈 pour addPostFrameCallback
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../widgets/chat/chat_room/incoming_call_screen.dart';
import '../widgets/chat/chat_room/audio_call_screen.dart';
import '../widgets/chat/chat_room/video_call_screen.dart';

/// Bridge Android -> Flutter (MethodChannel "incoming_calls").
/// - Met en file les événements si l'UI n'est pas prête.
/// - Met en file accept/reject si le socket n'est pas encore connecté.
class IncomingCallBridge {
  IncomingCallBridge._();
  static final IncomingCallBridge instance = IncomingCallBridge._();

  static const _channel = MethodChannel('incoming_calls');

  bool _initialized = false;
  bool _uiReady = false;

  /// file des "incoming_call" reçus avant que l'UI soit prête
  final List<Map<String, dynamic>> _pendingPayloads = [];

  /// file d'actions accept/reject si socket pas connecté
  final List<_PendingCallAction> _pendingActions = [];
  bool _flushHookInstalled = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_onMethodCall);

    // Marque l'UI prête après le 1er frame, puis flush des events reçus trop tôt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _uiReady = true;
      _flushPendingPayloads();
    });
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != 'incoming_call') return null;

    final Map<dynamic, dynamic> raw = (call.arguments as Map?) ?? const {};
    final payload = <String, dynamic>{
      'callId'     : (raw['callId'] ?? '').toString(),
      'callerId'   : (raw['callerId'] ?? '').toString(),
      'callerName' : (raw['callerName'] ?? 'Unknown').toString(),
      'callType'   : (raw['callType'] ?? 'audio').toString(), // 'audio'|'video'
      'avatarUrl'  : (raw['avatarUrl'] ?? '').toString(),
      'isGroup'    : (raw['isGroup'] == true || raw['isGroup'] == '1'),
      'members'    : (raw['members'] ?? '[]').toString(),
      'autoAccept' : (raw['autoAccept'] == true || raw['autoAccept'] == 'true'),
      'autoReject' : (raw['autoReject'] == true || raw['autoReject'] == 'true'),
    };

    if (!_uiReady) {
      _pendingPayloads.add(payload);
      return null;
    }

    _handleIncomingPayload(payload);
    return null;
  }

  void _flushPendingPayloads() {
    if (_pendingPayloads.isEmpty) return;
    final copy = List<Map<String, dynamic>>.from(_pendingPayloads);
    _pendingPayloads.clear();
    for (final p in copy) {
      _handleIncomingPayload(p);
    }
  }

  void _handleIncomingPayload(Map<String, dynamic> p) {
    final callId     = p['callId'] as String;
    final callerId   = p['callerId'] as String;
    final callerName = p['callerName'] as String;
    final callType   = p['callType'] as String;
    final avatarUrl  = p['avatarUrl'] as String;
    final isGroup    = p['isGroup'] as bool;
    final membersJson= p['members'] as String;
    final autoAccept = p['autoAccept'] as bool;
    final autoReject = p['autoReject'] as bool;

    final List<String> memberIds = _parseMemberIds(membersJson);

    final userCtrl = Get.find<UserController>();
    final meId     = userCtrl.userId;
    final sock     = userCtrl.socketService;

    // Si pas d'identité encore connue côté app, au moins afficher l'écran entrant
    if (callId.isEmpty || meId.isEmpty) {
      _openIncomingScreen(
        callerName: callerName,
        callerId: callerId,
        callId: callId.isEmpty ? '${meId}_${isGroup ? 'group' : callerId}' : callId,
        callType: callType,
        avatarUrl: avatarUrl,
        meId: meId,
        isGroup: isGroup,
        memberIds: memberIds,
      );
      return;
    }

    if (autoReject) {
      _queueOrRunCallAction('reject', callId, meId);
      // Rien à afficher (Android montre "Appel refusé")
      return;
    }

    if (autoAccept) {
      _queueOrRunCallAction('accept', callId, meId);
      final isVideo = (callType == 'video');
      if (isVideo) {
        Get.off(() => VideoCallScreen(
              name:           callerName,
              avatarUrl:      avatarUrl,
              phoneNumber:    '',
              recipientID:    isGroup ? '' : callerId,
              userId:         meId,
              isCaller:       false,
              existingCallId: callId,
              isGroup:        isGroup,
              memberIds:      memberIds,
            ));
      } else {
        Get.off(() => AudioCallScreen(
              name:           callerName,
              avatarUrl:      avatarUrl,
              phoneNumber:    '',
              recipientID:    isGroup ? '' : callerId,
              userId:         meId,
              isCaller:       false,
              existingCallId: callId,
              isGroup:        isGroup,
              memberIds:      memberIds,
            ));
      }
      return;
    }

    // Tap simple sur la notif => on montre l’écran "Incoming"
    _openIncomingScreen(
      callerName: callerName,
      callerId: callerId,
      callId: callId,
      callType: callType,
      avatarUrl: avatarUrl,
      meId: meId,
      isGroup: isGroup,
      memberIds: memberIds,
    );
  }

  void _openIncomingScreen({
    required String callerName,
    required String callerId,
    required String callId,
    required String callType,
    required String avatarUrl,
    required String meId,
    required bool   isGroup,
    required List<String> memberIds,
  }) {
    Get.to(() => IncomingCallScreen(
          callerName:  callerName,
          callerId:    callerId,
          callId:      callId,
          callType:    callType,
          avatarUrl:   avatarUrl.isEmpty ? null : avatarUrl,
          recipientID: meId,       // utilisé pour accept()
          isGroup:     isGroup,
          members:     memberIds,
        ));
  }

  void _queueOrRunCallAction(String kind, String callId, String meId) {
    final sock = Get.find<UserController>().socketService;

    // si déjà connecté → on envoie tout de suite
    if (sock.isConnected && meId.isNotEmpty) {
      if (kind == 'accept') {
        sock.acceptCall(callId, meId);
      } else {
        sock.rejectCall(callId, meId);
      }
      return;
    }

    // sinon, file + hook de flush sur onRegistered
    _pendingActions.add(_PendingCallAction(kind, callId));
    if (_flushHookInstalled) return;
    _flushHookInstalled = true;

    final prev = sock.onRegistered;
    sock.onRegistered = () {
      try { prev?.call(); } catch (_) {}
      _flushPendingActions();
    };
  }

  void _flushPendingActions() {
    final sock = Get.find<UserController>().socketService;
    final meId = Get.find<UserController>().userId;
    if (!sock.isConnected || meId.isEmpty || _pendingActions.isEmpty) return;

    final copy = List<_PendingCallAction>.from(_pendingActions);
    _pendingActions.clear();
    for (final a in copy) {
      try {
        if (a.kind == 'accept') {
          sock.acceptCall(a.callId, meId);
        } else {
          sock.rejectCall(a.callId, meId);
        }
      } catch (_) {}
    }
  }

  List<String> _parseMemberIds(String membersJson) {
    try {
      final decoded = jsonDecode(membersJson);
      if (decoded is List) {
        return decoded.map<String>((e) {
          if (e is String) return e;
          if (e is Map) {
            final v = e['userId'] ?? e['id'] ?? e['uid'] ?? e['user_id'];
            return (v ?? '').toString();
          }
          return e.toString();
        }).where((s) => s.isNotEmpty).toList();
      }
      if (decoded is Map) {
        // map userId->name
        return decoded.keys.map((k) => k.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }
}

class _PendingCallAction {
  final String kind; // 'accept' | 'reject'
  final String callId;
  _PendingCallAction(this.kind, this.callId);
}
