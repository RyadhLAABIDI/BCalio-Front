import 'dart:async'; // 👈 Timer
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:get/get.dart';
import '../controllers/user_controller.dart';

import 'package:bcalio/models/call_log_model.dart';
import 'package:bcalio/controllers/call_log_controller.dart';
import 'package:bcalio/controllers/unread_badges_controller.dart';

import 'package:flutter/widgets.dart' show WidgetsBinding;

class SocketService {
  static SocketService? _instance;

  factory SocketService({String baseUrl = 'http://192.168.1.20:1906'}) {
    return _instance ??= SocketService._internal(baseUrl);
  }
  SocketService._internal(this.baseUrl);

  final String baseUrl;
  io.Socket? _socket;

  String _userId   = '';
  String _socketId = '';
  bool   _inCall   = false;
  String? _activeCallId;

  bool _isConnecting = false;
  String? _registeredUserId;

  String get userId   => _userId;
  String get socketId => _socketId;

  bool get isConnected => _socket?.connected ?? false;

  // ========= File d’actions à rejouer une fois enregistré =========
  final List<VoidCallback> _pendingActions = <VoidCallback>[];
  void _queue(VoidCallback action) => _pendingActions.add(action);
  void _flushPendingActions() {
    if (_pendingActions.isEmpty) return;
    final copy = List<VoidCallback>.from(_pendingActions);
    _pendingActions.clear();
    for (final a in copy) {
      try { a(); } catch (e) { debugPrint('[Socket] pending action error: $e'); }
    }
  }

  /* -------------------------- CALLBACKS -------------------------- */
  void Function()? onRegistered;

  void Function(String callId, String callerId,
                String callerName, String callType)? onIncomingCall;

  void Function(String callId, String callerId, String callerName,
                String callType, List<Map<String, String>> members)? onIncomingGroupCall;

  void Function(String callId)? onCallAccepted;
  void Function()? onCallRejected;
  void Function()? onCallEnded;
  void Function()? onCallCancelled;
  void Function()? onCallTimeout;
  void Function(String error)? onCallError;

  void Function(String from, Map sdp)?  onOffer;
  void Function(String from, Map sdp)?  onAnswer;
  void Function(String from, Map ice)?  onIce;

  void Function(String callId, List<Map<String, String>> participants)? onParticipants;
  void Function(String callId, String userId, String name)? onParticipantJoined;
  void Function(String callId, String userId)? onParticipantLeft;
  void Function(String callId, String userId)? onParticipantRejected;
  void Function(String callId, String userId)? onParticipantTimeout;

  void Function(String callId)? onCallInitiated;

  void Function(String userId, bool online, DateTime? lastSeen)? onPresenceUpdate;
  void Function(List<Map<String, dynamic>> list)? onPresenceState;

  void Function(String conversationId, String fromUserId)? onTyping;
  void Function(String conversationId, String fromUserId)? onStopTyping;

  void disconnect() {
    _socket?.disconnect();
  }

  final Map<String, String> _nameById = {};
  final Map<String, String> _avatarById = {};

  // suivi des appels entrants en attente (pour détecter “manqué”)
  final Set<String> _pendingIncoming = <String>{};
  final Map<String, DateTime> _incomingStart = {};
  final Map<String, Map<String, String>> _incomingMeta = {}; // callId -> {peerId,peerName,peerAvatar,type}

  // ⏱ timers locaux pour fallback timeout (serveur n’émet pas au destinataire hors room)
  final Map<String, Timer> _incomingTimers = {};

  String _normId(dynamic id) => (id?.toString() ?? '').trim();

  List<Map<String, String>> _normalizeMembers(dynamic raw) {
    final List<Map<String, String>> out = [];
    if (raw == null) return out;

    if (raw is Map) {
      raw.forEach((key, value) {
        out.add({'userId': key?.toString() ?? '', 'name': value?.toString() ?? ''});
      });
      return out.where((m) => (m['userId'] ?? '').isNotEmpty).toList();
    }

    if (raw is List) {
      for (final e in raw) {
        if (e is String) out.add({'userId': e, 'name': ''});
        else if (e is Map) {
          final id = e['userId'] ?? e['id'] ?? e['uid'] ?? e['user_id'];
          final nm = e['name'] ?? e['displayName'] ?? e['username'] ?? '';
          out.add({'userId': id?.toString() ?? '', 'name': nm?.toString() ?? ''});
        } else out.add({'userId': e.toString(), 'name': ''});
      }
      return out.where((m) => (m['userId'] ?? '').isNotEmpty).toList();
    }

    out.add({'userId': raw.toString(), 'name': ''});
    return out;
  }
  List<Map<String, String>> _normalizeParticipants(dynamic raw) => _normalizeMembers(raw);

  String _resolveName(String userId, [String? fallback]) {
    if (fallback != null && fallback.isNotEmpty) {
      _nameById[userId] = fallback;
      return fallback;
    }
    return _nameById[userId] ?? userId;
  }

  /* ------------------------ CONNECTION -------------------------- */
  void connectAndRegister(String userId, String name) {
    _userId = userId;

    if ((_socket?.connected ?? false) && _registeredUserId == userId) {
      debugPrint('[Socket] already registered for $_registeredUserId — skip');
      _flushPendingActions();
      return;
    }

    if ((_socket?.connected ?? false) && _registeredUserId != userId) {
      debugPrint('[Socket] connected, re-register for user=$userId');
      _socket!.emit('register', {'userId': userId, 'name': name});
      return;
    }

    if (_isConnecting) {
      debugPrint('[Socket] connect requested while connecting — will register on onConnect');
      return;
    }

    _isConnecting = true;

    final url = baseUrl.trim();

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .disableAutoConnect()
          .setReconnectionAttempts(1 << 30)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        debugPrint('[Socket] connected → register $userId ($name)');
        _socket!.emit('register', {'userId': userId, 'name': name});
      })
      ..on('registered', (d) {
        _isConnecting = false;
        _socketId = d['socketId'];
        _registeredUserId = d['userId']?.toString() ?? userId;
        debugPrint('[Socket] registered OK   socketId=$_socketId  user=$_registeredUserId');
        _nameById[userId] = name;
        _flushPendingActions();
        onRegistered?.call();
      })
      ..on('incoming-call', (d) {
        if (_inCall) return;
        _activeCallId = _normId(d['callId']);

        final isGroup  = d['isGroup'] == true;
        final callId   = _normId(d['callId']);
        final callerId = _normId(d['callerId']);
        final cname    = (d['callerName']?.toString() ?? '');
        final type     = (d['callType']?.toString() ?? 'audio');
        final avatar   = (d['avatarUrl']?.toString() ?? '');

        if (cname.isNotEmpty) _nameById[callerId] = cname;
        if (avatar.isNotEmpty) _avatarById[callerId] = avatar;

        // mémorise pour “missed”/“timeout”
        _pendingIncoming.add(callId);
        _incomingStart[callId] = DateTime.now();
        _incomingMeta[callId] = {
          'peerId': callerId,
          'peerName': cname,
          'peerAvatar': avatar,
          'type': type,
        };

        // ⏱ Fallback local: si le serveur n’envoie pas d’event direct (room-only), on loggue manqué.
        _armLocalTimeout(callId);

        if (isGroup && onIncomingGroupCall != null) {
          final members = _normalizeMembers(d['members']);
          for (final m in members) {
            final uid = m['userId'] ?? '';
            final nm  = m['name'] ?? '';
            if (uid.isNotEmpty && nm.isNotEmpty) _nameById[uid] = nm;
          }
          onIncomingGroupCall!.call(callId, callerId, cname, type, members);
        } else {
          onIncomingCall?.call(callId, callerId, cname, type);
        }
      })
      ..on('call-initiated', (d) {
        _activeCallId = _normId(d['callId']);
        onCallInitiated?.call(_activeCallId!);
      })
      ..on('call-accepted', (d) {
        _inCall       = true;
        final cid = _normId(d['callId']);
        _activeCallId = cid;

        _disarmLocalTimeout(cid); // 👈 stop fallback
        _pendingIncoming.remove(cid);
        _incomingStart.remove(cid);
        _incomingMeta.remove(cid);

        onCallAccepted?.call(cid);
      })
      ..on('call-rejected', (d) {
        final cid = d is Map ? _normId(d['callId']) : (_activeCallId ?? '');
        _disarmLocalTimeout(cid); // 👈 stop fallback
        if (cid.isNotEmpty) {
          _pendingIncoming.remove(cid);
          _incomingStart.remove(cid);
          _incomingMeta.remove(cid);
        }
        _resetFlags();
        onCallRejected?.call();
      })
      ..on('call-ended', (d) {
        // fallback backend: parfois seul 'call-ended' arrive
        final cid = d is Map ? _normId(d['callId']) : (_activeCallId ?? '');
        _disarmLocalTimeout(cid); // 👈 stop fallback
        if (cid.isNotEmpty && _pendingIncoming.contains(cid) && !_inCall) {
          _handlePotentialMissed(cid, status: CallStatus.missed);
        } else {
          if (cid.isNotEmpty) {
            _pendingIncoming.remove(cid);
            _incomingStart.remove(cid);
            _incomingMeta.remove(cid);
          }
        }
        _resetFlags();
        onCallEnded?.call();
      })
      ..on('call-cancelled', (d) {
        final cid = d is Map ? _normId(d['callId']) : (_activeCallId ?? '');
        _disarmLocalTimeout(cid); // 👈 stop fallback
        _handlePotentialMissed(cid, status: CallStatus.missed);
        _resetFlags();
        onCallCancelled?.call();
      })
      ..on('call-timeout', (d) {
        final cid = d is Map ? _normId(d['callId']) : (_activeCallId ?? '');
        _disarmLocalTimeout(cid); // 👈 stop fallback (on va traiter quand même)
        _handlePotentialMissed(cid, status: CallStatus.timeout);
        _resetFlags();
        onCallTimeout?.call();
      })
      ..on('call-error', (d) {
        _resetFlags();
        onCallError?.call(d['error']);
      })
      ..on('participants', (d) {
        final callId = _normId(d['callId']);
        final list = _normalizeParticipants(d['participants']);
        for (final m in list) {
          final uid = m['userId'] ?? '';
          final nm  = m['name'] ?? '';
          if (uid.isNotEmpty && nm.isNotEmpty) _nameById[uid] = nm;
        }
        onParticipants?.call(callId, list);
      })
      ..on('participant-joined', (d) {
        final callId = _normId(d['callId']);
        final uid = _normId(d['user']?['userId']);
        final nm  = d['user']?['name']?.toString() ?? '';
        if (uid.isNotEmpty && nm.isNotEmpty) _nameById[uid] = nm;
        onParticipantJoined?.call(callId, uid, nm);
      })
      ..on('participant-left', (d) {
        final callId = _normId(d['callId']);
        final uid = _normId(d['user']?['userId'] ?? d['userId']);
        final nm  = d['user']?['name']?.toString();
        if (uid.isNotEmpty) {
          _resolveName(uid, nm);
          onParticipantLeft?.call(callId, uid);
        }
      })
      ..on('participant-rejected', (d) {
        final callId = _normId(d['callId']);
        final uid = _normId(d['user']?['userId'] ?? d['userId']);
        final nm  = d['user']?['name']?.toString();
        if (uid.isNotEmpty) {
          _resolveName(uid, nm);
          onParticipantRejected?.call(callId, uid);
        }
      })
      ..on('participant-timeout', (d) {
        final callId = _normId(d['callId']);
        final uid = _normId(d['user']?['userId'] ?? d['userId']);
        final nm  = d['user']?['name']?.toString();
        if (uid.isNotEmpty) {
          _resolveName(uid, nm);
          onParticipantTimeout?.call(callId, uid);
        }
      })
      ..on('presence-update', (d) {
        final uid = _normId(d['userId']);
        final online = d['online'] == true;
        final ls = d['lastSeen'] != null ? DateTime.fromMillisecondsSinceEpoch(d['lastSeen']) : null;
        if (uid.isNotEmpty) onPresenceUpdate?.call(uid, online, ls);
      })
      ..on('presence-state', (d) {
        final raw = (d['list'] as List?) ?? const [];
        final list = raw.map((e) => {
          'userId': e['userId']?.toString() ?? '',
          'online': e['online'] == true,
          'lastSeen': e['lastSeen'] != null
              ? DateTime.fromMillisecondsSinceEpoch(e['lastSeen'])
              : null,
        }).toList();
        onPresenceState?.call(list);
      })
      ..on('typing', (d) {
        final convId = _normId(d['conversationId']);
        final from   = _normId(d['fromUserId']);
        if (convId.isEmpty || from.isEmpty) return;
        onTyping?.call(convId, from);
      })
      ..on('stop-typing', (d) {
        final convId = _normId(d['conversationId']);
        final from   = _normId(d['fromUserId']);
        if (convId.isEmpty || from.isEmpty) return;
        onStopTyping?.call(convId, from);
      })
      ..on('offer',  (d) => onOffer ?.call(d['from'],  Map<String, dynamic>.from(d['sdp'])))
      ..on('answer', (d) => onAnswer?.call(d['from'],  Map<String, dynamic>.from(d['sdp'])))
      ..on('ice',    (d) => onIce   ?.call(d['from'],  Map<String, dynamic>.from(d['ice'])))
      ..on('connect_error', (e) => debugPrint('[Socket] connect_error: $e'))
      ..on('reconnect', (_)     => debugPrint('[Socket] reconnected'))
      ..onDisconnect((_)  {
        debugPrint('[Socket] disconnected');
        _isConnecting = false;
        _registeredUserId = null;
        _resetFlags();
        _socket = null;
      })
      ..connect();
  }

  /* ---------------------------- API APPELS ---------------------------- */

  void initiateCall(String callerId, String recipientId,
      String callerName, String callType) {
    if (!isConnected) {
      _queue(() => initiateCall(callerId, recipientId, callerName, callType));
      return;
    }

    String callerPhone = '';
    String avatarUrl   = '';
    try {
      final u = Get.find<UserController>().currentUser.value;
      callerPhone = (u?.phoneNumber ?? '').trim();
      avatarUrl   = (u?.image ?? '').trim();
    } catch (_) {}

    debugPrint('[Socket] initiate-call → $recipientId  type=$callType');
    _socket!.emit('initiate-call', {
      'callerId'   : callerId,
      'recipientId': recipientId,
      'name'       : callerName,
      'callType'   : callType,
      'callerPhone': callerPhone,
      'avatarUrl'  : avatarUrl,
    });
  }

  void initiateGroupCall(String callerId, List<String> memberIds,
      String callerName, String callType) {
    if (!isConnected) {
      _queue(() => initiateGroupCall(callerId, memberIds, callerName, callType));
      return;
    }

    String callerPhone = '';
    String avatarUrl   = '';
    try {
      final u = Get.find<UserController>().currentUser.value;
      callerPhone = (u?.phoneNumber ?? '').trim();
      avatarUrl   = (u?.image ?? '').trim();
    } catch (_) {}

    debugPrint('[Socket] initiate-group-call → ${memberIds.join(',')} type=$callType');
    _socket!.emit('initiate-group-call', {
      'callerId'  : callerId,
      'memberIds' : memberIds,
      'name'      : callerName,
      'callType'  : callType,
      'callerPhone': callerPhone,
      'avatarUrl'  : avatarUrl,
    });
  }

  void _emitAcceptCall(String callId, String userId) {
    debugPrint('[Socket] accept-call $callId');
    _inCall = true;
    _socket!.emit('accept-call', {'callId': callId, 'userId': userId});
  }

  void acceptCall(String callId, String userId) {
    if (!isConnected) {
      _queue(() => _emitAcceptCall(callId, userId));
      return;
    }
    _emitAcceptCall(callId, userId);
  }

  void _emitRejectCall(String callId, String userId) {
    debugPrint('[Socket] reject-call $callId');
    _socket!.emit('reject-call', {'callId': callId, 'userId': userId});
    _resetFlags();
  }

  void rejectCall(String callId, String userId) {
    if (!isConnected) {
      _queue(() => _emitRejectCall(callId, userId));
      return;
    }
    _emitRejectCall(callId, userId);
  }

  void _emitLeaveCall(String callId, String userId) {
    debugPrint('[Socket] leave-call $callId');
    _socket!.emit('leave-call', {'callId': callId, 'userId': userId});
    _resetFlags();
  }

  void leaveCall(String callId, String userId) {
    if (!isConnected) {
      _queue(() => _emitLeaveCall(callId, userId));
      return;
    }
    _emitLeaveCall(callId, userId);
  }

  void _emitEndCall(String callId) {
    debugPrint('[Socket] end-call $callId');
    _socket!.emit('end-call', {'callId': callId});
    _resetFlags();
  }

  void endCall(String callId) {
    if (!isConnected) {
      _queue(() => _emitEndCall(callId));
      return;
    }
    _emitEndCall(callId);
  }

  void _emitCancelCall(String callId, String userId) {
    debugPrint('[Socket] cancel-call $callId');
    _socket!.emit('cancel-call', {'callId': callId, 'userId': userId});
    _socket!.emit('end-call',    {'callId': callId}); // fallback
    _resetFlags();
  }

  void cancelCall(String callId, String userId) {
    if (!isConnected) {
      _queue(() => _emitCancelCall(callId, userId));
      return;
    }
    _emitCancelCall(callId, userId);
  }

  void requestPresence(List<String> userIds) {
    if (!isConnected) return;
    _socket!.emit('presence-request', {'userIds': userIds});
  }

  void emitTyping(String toUserId, String conversationId) {
    if (!isConnected) return;
    _socket!.emit('typing', {
      'to': toUserId,
      'conversationId': conversationId,
    });
  }

  void emitStopTyping(String toUserId, String conversationId) {
    if (!isConnected) return;
    _socket!.emit('stop-typing', {
      'to': toUserId,
      'conversationId': conversationId,
    });
  }

  void setVisibility(bool visible) {
    if (!isConnected) {
      _queue(() => setVisibility(visible));
      return;
    }
    _socket!.emit('set-visibility', {'visible': visible});
  }

  void emitOffer (String toUserId, Map sdp) =>
      _socket?.emit('offer',  {'to': toUserId, 'sdp': sdp});
  void emitAnswer(String toUserId, Map sdp) =>
      _socket?.emit('answer', {'to': toUserId, 'sdp': sdp});
  void emitIce   (String toUserId, Map ice) =>
      _socket?.emit('ice',    {'to': toUserId, 'ice': ice});

  void _resetFlags() {
    _inCall       = false;
    _activeCallId = null;
  }

  /* ------------------------ Fallback timer helpers ------------------------ */
  void _armLocalTimeout(String callId) {
    _incomingTimers[callId]?.cancel();
    _incomingTimers[callId] = Timer(const Duration(seconds: 32), () {
      // si toujours "pending", on marque manqué/time-out
      if (_pendingIncoming.contains(callId)) {
        _handlePotentialMissed(callId, status: CallStatus.timeout);
      }
      _incomingTimers.remove(callId);
    });
  }

  void _disarmLocalTimeout(String? callId) {
    final id = (callId ?? '').trim();
    if (id.isEmpty) return;
    _incomingTimers.remove(id)?.cancel();
  }

  // si un appel entrant pendait et se termine par cancel/timeout/ended → log + badge (post-frame)
  void _handlePotentialMissed(String? callId, {required CallStatus status}) {
    final cid = _normId(callId);
    if (cid.isEmpty) return;
    if (!_pendingIncoming.remove(cid)) return;

    _disarmLocalTimeout(cid);

    final started = _incomingStart.remove(cid) ?? DateTime.now();
    final meta = _incomingMeta.remove(cid);

    final peerId = meta?['peerId'] ?? '';
    final peerName = meta?['peerName'] ?? (peerId.isNotEmpty ? (_nameById[peerId] ?? peerId) : 'Unknown');
    final peerAvatar = meta?['peerAvatar'] ?? (peerId.isNotEmpty ? _avatarById[peerId] : null);
    final typeStr = (meta?['type'] ?? 'audio').toLowerCase();
    final callType = typeStr == 'video' ? CallType.video : CallType.audio;

    final ended = DateTime.now();
    final duration = ended.difference(started).inSeconds;

    final log = CallLog(
      callId: cid,
      peerId: peerId,
      peerName: peerName,
      peerAvatar: peerAvatar,
      direction: CallDirection.incoming,
      type: callType,
      status: status,
      startedAt: started,
      endedAt: ended,
      durationSeconds: duration < 0 ? 0 : duration,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final callLogCtrl = Get.isRegistered<CallLogController>()
            ? Get.find<CallLogController>()
            : Get.put(CallLogController(), permanent: true);
        callLogCtrl.upsert(log);
      } catch (e) {
        debugPrint('[Socket] upsert CallLog error: $e');
      }

      try {
        final badges = Get.isRegistered<UnreadBadgesController>()
            ? Get.find<UnreadBadgesController>()
            : Get.put(UnreadBadgesController(), permanent: true);
        badges.incCalls();
      } catch (e) {
        debugPrint('[Socket] badge inc error: $e');
      }
    });
  }

  void dispose() {
    debugPrint('[Socket] dispose()');
    for (final t in _incomingTimers.values) {
      try { t.cancel(); } catch (_) {}
    }
    _incomingTimers.clear();

    _socket?.disconnect();
    try { _socket?.dispose(); } catch (_) {}
    _socket   = null;
    _socketId = '';
    _registeredUserId = null;
    _isConnecting = false;
    _pendingActions.clear();
    _resetFlags();
  }
}
