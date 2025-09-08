// lib/modules/roomkit/socket_service.dart
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;
import 'dart:convert';

typedef UsersCB   = void Function(List users);
typedef PendingCB = void Function(String id, String name);

// Base serveur (sans namespace)
const String kRoomServerBase = 'http://192.168.1.22:1906';

String _ts() => DateTime.now().toIso8601String().substring(11, 23);
String _short(Object? v, [int max = 120]) {
  final s = v?.toString() ?? '';
  return s.length <= max ? s : s.substring(0, max) + '…';
}

class SocketService {
  final String baseUrl;
  io.Socket? _socket;

  String currentRoomId      = '';
  String currentDisplayName = '';

  bool approved = false;
  bool entered  = false;

  String get id => _socket?.id ?? '';
  String get apiBase => '$baseUrl/api';

  SocketService({this.baseUrl = kRoomServerBase});

  void Function()?               onApproved;
  UsersCB?                       onExistingUsers;
  void Function(String,String)?  onUserConnected;
  void Function(String)?         onUserDisconnected;
  void Function(List)?           onChatHistory;
  void Function(Map)?            onChat;
  PendingCB?                     onPendingRequest;

  // 🔒 Handlers RTC privés (jamais écrasés par accident)
  void Function(String, Map)? _onOffer;
  void Function(String, Map)? _onAnswer;
  void Function(String, Map)? _onIce;

  /// Binder explicite et idempotent des handlers RTC
  void setRtcHandlers({
    required void Function(String, Map) onOffer,
    required void Function(String, Map) onAnswer,
    required void Function(String, Map) onIce,
  }) {
    _onOffer  = onOffer;
    _onAnswer = onAnswer;
    _onIce    = onIce;
    print('[${_ts()}][SOCK] RTC handlers bound (offer/answer/ice)');
  }

  void connectAndJoin(
    String roomId,
    String name, {
    void Function()?               onApproved,
    UsersCB?                       onExistingUsers,
    void Function(String,String)?  onUserConnected,
    void Function(String)?         onUserDisconnected,
    void Function(List)?           onChatHistory,
    void Function(Map)?            onChat,
    // ❌ plus de onOffer/onAnswer/onIce ici → obligatoirement via setRtcHandlers()
    PendingCB?                     onPendingRequest,
  }) {
    currentRoomId      = roomId;
    currentDisplayName = name;

    // On ne touche JAMAIS aux handlers RTC ici.
    this.onApproved         = onApproved         ?? this.onApproved;
    this.onExistingUsers    = onExistingUsers    ?? this.onExistingUsers;
    this.onUserConnected    = onUserConnected    ?? this.onUserConnected;
    this.onUserDisconnected = onUserDisconnected ?? this.onUserDisconnected;
    this.onChatHistory      = onChatHistory      ?? this.onChatHistory;
    this.onChat             = onChat             ?? this.onChat;
    this.onPendingRequest   = onPendingRequest   ?? this.onPendingRequest;

    // 🔑 Namespace /room
    final roomNsUrl = '$baseUrl/room';
    print('[${_ts()}][SOCK] init → io("$roomNsUrl")');
    _socket = io.io(
      roomNsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      print('[${_ts()}][SOCK] ✔ connected id=${_socket!.id}');
      emitJoinRoom(roomId, name);
    });

    _socket!
      ..onConnectError((e) => print('[${_ts()}][SOCK][ERR] onConnectError: ${_short(e)}'))
      ..onError((e)        => print('[${_ts()}][SOCK][ERR] onError: ${_short(e)}'))
      ..onDisconnect((_)   => print('[${_ts()}][SOCK] ✖ disconnected'))
      ..onReconnectAttempt((att) => print('[${_ts()}][SOCK] reconnect attempt #$att'))
      ..onReconnect((_)    => print('[${_ts()}][SOCK] reconnected id=${_socket!.id}'))
      ..onReconnectError((e)=> print('[${_ts()}][SOCK][ERR] onReconnectError: ${_short(e)}'))
      ..onReconnectFailed((_)=> print('[${_ts()}][SOCK][ERR] onReconnectFailed'));

    // Events
    _socket!
      ..on('approved', (_) {
        print('[${_ts()}][SOCK] ← approved');
        if (!entered) {
          print('[${_ts()}][SOCK] approved → enter-room (guest)');
          enterRoom(currentRoomId, currentDisplayName);
        }
        approved = true;
        onApproved?.call();
      })
      ..on('existing-users', (u) {
        final list = List<Map>.from(u);
        print('[${_ts()}][SOCK] ← existing-users count=${list.length}');
        if (!entered && list.isEmpty) {
          print('[${_ts()}][SOCK] I am the first user → enter-room (owner)');
          enterRoom(currentRoomId, currentDisplayName);
        }
        onExistingUsers?.call(list);
      })
      ..on('pending-request', (d) {
        print('[${_ts()}][SOCK] ← pending-request id=${d['id']} name=${d['name']}');
        onPendingRequest?.call(d['id'], d['name']);
      })
      ..on('user-connected', (d) {
        print('[${_ts()}][SOCK] ← user-connected id=${d['id']} name=${d['name']}');
        onUserConnected?.call(d['id'], d['name']);
      })
      ..on('user-disconnected', (id) {
        print('[${_ts()}][SOCK] ← user-disconnected id=$id');
        onUserDisconnected?.call(id);
      })
      ..on('chat-history', (h) {
        print('[${_ts()}][SOCK] ← chat-history items=${(h is List) ? h.length : 'n/a'}');
        onChatHistory?.call(List<Map>.from(h));
      })
      ..on('chat', (p) {
        print('[${_ts()}][SOCK] ← chat from=${p['name']} len=${(p['msg']?.toString().length ?? 0)}');
        onChat?.call(Map<String, dynamic>.from(p));
      })
      ..on('offer', (d) {
        final sdp = Map<String, dynamic>.from(d['sdp']);
        print('[${_ts()}][SOCK] ← offer from=${d['from']} type=${sdp['type']} sdpLen=${(sdp['sdp']?.toString().length ?? 0)}');
        final cb = _onOffer;
        if (cb == null) {
          print('[${_ts()}][SOCK][WARN] onOffer is NULL (bind via setRtcHandlers)');
        } else {
          cb(d['from'], sdp);
        }
      })
      ..on('answer', (d) {
        final sdp = Map<String, dynamic>.from(d['sdp']);
        print('[${_ts()}][SOCK] ← answer from=${d['from']} type=${sdp['type']} sdpLen=${(sdp['sdp']?.toString().length ?? 0)}');
        final cb = _onAnswer;
        if (cb == null) {
          print('[${_ts()}][SOCK][WARN] onAnswer is NULL (bind via setRtcHandlers)');
        } else {
          cb(d['from'], sdp);
        }
      })
      ..on('ice', (d) {
        final ice = Map<String, dynamic>.from(d['ice']);
        print('[${_ts()}][SOCK] ← ice from=${d['from']} mid=${ice['sdpMid']} index=${ice['sdpMLineIndex']} candLen=${(ice['candidate']?.toString().length ?? 0)}');
        final cb = _onIce;
        if (cb == null) {
          print('[${_ts()}][SOCK][WARN] onIce is NULL (bind via setRtcHandlers)');
        } else {
          cb(d['from'], ice);
        }
      });

    _socket!.connect();
    print('[${_ts()}][SOCK] connect() called');
  }

  void emitJoinRoom(String roomId, String name) {
    print('[${_ts()}][SOCK] → join-room roomId=$roomId name="$name"');
    _socket?.emit('join-room', {'roomId': roomId, 'name': name});
  }

  void enterRoom(String roomId, String name) {
    if (entered) return; // idempotent
    print('[${_ts()}][SOCK] → enter-room roomId=$roomId name="$name"');
    _socket?.emit('enter-room', {'roomId': roomId, 'name': name});
    entered = true;
  }

  void approveUser(String roomId, String id, bool allow) {
    print('[${_ts()}][SOCK] → approve-user roomId=$roomId id=$id allow=$allow');
    _socket?.emit('approve-user', {'roomId': roomId, 'id': id, 'allow': allow});
  }

  void emitOffer (String to, Map sdp) {
    print('[${_ts()}][SOCK] → offer to=$to type=${sdp['type']} sdpLen=${(sdp['sdp']?.toString().length ?? 0)}');
    _socket?.emit('offer',  {'to': to, 'sdp': sdp});
  }

  void emitAnswer(String to, Map sdp) {
    print('[${_ts()}][SOCK] → answer to=$to type=${sdp['type']} sdpLen=${(sdp['sdp']?.toString().length ?? 0)}');
    _socket?.emit('answer', {'to': to, 'sdp': sdp});
  }

  void emitIce   (String to, Map ice) {
    print('[${_ts()}][SOCK] → ice to=$to mid=${ice['sdpMid']} index=${ice['sdpMLineIndex']} candLen=${(ice['candidate']?.toString().length ?? 0)}');
    _socket?.emit('ice',    {'to': to, 'ice': ice});
  }

  void sendMessage(String roomId, String name, String msg) {
    // ⬇️ Fallback HTTP uniquement si pas encore "entered"
    if (!entered) {
      print('[${_ts()}][SOCK][WARN] sendMessage → not entered → fallback HTTP');
      sendMessageHttp(roomId, name, msg);
      return;
    }
    print('[${_ts()}][SOCK] → chat roomId=$roomId len=${msg.length}');
    _socket?.emit('chat', {'roomId': roomId, 'msg': msg});
  }

  Future<void> sendMessageHttp(String roomId, String name, String msg) async {
    if (msg.trim().isEmpty) return;
    try {
      final url = '$apiBase/rooms/$roomId/chat';
      print('[${_ts()}][HTTP] POST $url len=${msg.trim().length}');
      final r = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'msg': msg.trim()}),
      );
      print('[${_ts()}][HTTP] status=${r.statusCode} body=${_short(r.body)}');
      if (r.statusCode != 200) {
        debugPrint('[SocketService] HTTP chat fail: ${r.statusCode} ${r.body}');
      }
    } catch (e) {
      print('[${_ts()}][HTTP][ERR] $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchUsers(String roomId) async {
    final url = '$apiBase/rooms/$roomId/users';
    print('[${_ts()}][HTTP] GET $url');
    final r = await http.get(Uri.parse(url));
    print('[${_ts()}][HTTP] status=${r.statusCode} bodyLen=${r.body.length}');
    if (r.statusCode == 200) {
      final j = json.decode(r.body);
      return (j['users'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  void dispose() {
    print('[${_ts()}][SOCK] dispose()');
    _socket?.dispose();
  }
}
