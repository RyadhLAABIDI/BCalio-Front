// lib/services/socket_service.dart
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

// 👇 NEW: pour récupérer phone/avatar depuis le profil local
import 'package:get/get.dart';
import '../controllers/user_controller.dart';

class SocketService {
  static SocketService? _instance;

  /// ⚠️ Corrigé : pas d'espace dans l'URL par défaut
  factory SocketService({String baseUrl = 'http://192.168.1.26:1906'}) {
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

  // dans SocketService
  void disconnect() {
    _socket?.disconnect();
  }

  final Map<String, String> _nameById = {};

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
      _flushPendingActions(); // ✅ rejouer ce qui attendait
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

    // ⚠️ Sûreté : trim() (évite les "%20" en tête)
    final url = baseUrl.trim();

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .disableAutoConnect()
          .setReconnectionAttempts(1 << 30) // grand nombre
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
        _flushPendingActions(); // ✅ IMPORTANT
        onRegistered?.call();
      })
      ..on('incoming-call', (d) {
        if (_inCall) return;
        _activeCallId = d['callId'];

        final isGroup  = d['isGroup'] == true;
        final callId   = d['callId']?.toString() ?? '';
        final callerId = d['callerId']?.toString() ?? '';
        final cname    = d['callerName']?.toString() ?? '';
        final type     = d['callType']?.toString() ?? 'audio';

        if (cname.isNotEmpty) _nameById[callerId] = cname;

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
        _activeCallId = d['callId'];
        onCallInitiated?.call(d['callId']);
      })
      ..on('call-accepted', (d) {
        _inCall       = true;
        _activeCallId = d['callId'];
        onCallAccepted?.call(d['callId']);
      })
      ..on('call-rejected', (_) {
        _resetFlags();
        onCallRejected?.call();
      })
      ..on('call-ended', (_) {
        _resetFlags();
        onCallEnded?.call();
      })
      ..on('call-cancelled', (_) {
        _resetFlags();
        onCallCancelled?.call();
      })
      ..on('call-timeout', (_) {
        _resetFlags();
        onCallTimeout?.call();
      })
      ..on('call-error', (d) {
        _resetFlags();
        onCallError?.call(d['error']);
      })
      ..on('participants', (d) {
        final callId = d['callId']?.toString() ?? '';
        final list = _normalizeParticipants(d['participants']);
        for (final m in list) {
          final uid = m['userId'] ?? '';
          final nm  = m['name'] ?? '';
          if (uid.isNotEmpty && nm.isNotEmpty) _nameById[uid] = nm;
        }
        onParticipants?.call(callId, list);
      })
      ..on('participant-joined', (d) {
        final callId = d['callId']?.toString() ?? '';
        final uid = d['user']?['userId']?.toString() ?? '';
        final nm  = d['user']?['name']?.toString() ?? '';
        if (uid.isNotEmpty && nm.isNotEmpty) _nameById[uid] = nm;
        onParticipantJoined?.call(callId, uid, nm);
      })
      ..on('participant-left', (d) {
        final callId = d['callId']?.toString() ?? '';
        final uid = d['user']?['userId']?.toString() ?? d['userId']?.toString() ?? '';
        final nm  = d['user']?['name']?.toString();
        if (uid.isNotEmpty) {
          _resolveName(uid, nm);
          onParticipantLeft?.call(callId, uid);
        }
      })
      ..on('participant-rejected', (d) {
        final callId = d['callId']?.toString() ?? '';
        final uid = d['user']?['userId']?.toString() ?? d['userId']?.toString() ?? '';
        final nm  = d['user']?['name']?.toString();
        if (uid.isNotEmpty) {
          _resolveName(uid, nm);
          onParticipantRejected?.call(callId, uid);
        }
      })
      ..on('participant-timeout', (d) {
        final callId = d['callId']?.toString() ?? '';
        final uid = d['user']?['userId']?.toString() ?? d['userId']?.toString() ?? '';
        final nm  = d['user']?['name']?.toString();
        if (uid.isNotEmpty) {
          _resolveName(uid, nm);
          onParticipantTimeout?.call(callId, uid);
        }
      })
      ..on('presence-update', (d) {
        final uid = d['userId']?.toString() ?? '';
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
        final convId = d['conversationId']?.toString() ?? '';
        final from   = d['fromUserId']?.toString() ?? '';
        if (convId.isEmpty || from.isEmpty) return;
        onTyping?.call(convId, from);
      })
      ..on('stop-typing', (d) {
        final convId = d['conversationId']?.toString() ?? '';
        final from   = d['fromUserId']?.toString() ?? '';
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

    // 👇 NEW: enrichir avec phone & avatar locaux (si dispos)
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
      'callerPhone': callerPhone, // 👈 NEW
      'avatarUrl'  : avatarUrl,   // 👈 NEW
    });
  }

  void initiateGroupCall(String callerId, List<String> memberIds,
      String callerName, String callType) {
    if (!isConnected) {
      _queue(() => initiateGroupCall(callerId, memberIds, callerName, callType));
      return;
    }

    // 👇 NEW: enrichir avec phone & avatar locaux (si dispos)
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
      'callerPhone': callerPhone, // 👈 NEW
      'avatarUrl'  : avatarUrl,   // 👈 NEW
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

  void dispose() {
    debugPrint('[Socket] dispose()');
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
