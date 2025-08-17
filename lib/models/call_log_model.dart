import 'package:flutter/foundation.dart';

enum CallDirection { incoming, outgoing }
enum CallType { audio, video }
enum CallStatus {
  ringing,     // en sonnerie (temporaire, rarement persisté)
  accepted,    // en appel / terminé normalement
  rejected,    // refusé par le destinataire
  cancelled,   // annulé par l’appelant avant acceptation
  missed,      // manqué (pas répondu)
  timeout,     // ne répond pas (30s)
  ended,       // raccroché normalement
}

class CallLog {
  final int? id;                 // clé locale auto-inc
  final String callId;           // id serveur (caller_recipient_timestamp)
  final String peerId;           // l’autre participant
  final String peerName;
  final String? peerAvatar;
  final CallDirection direction; // incoming / outgoing
  final CallType type;           // audio / video
  final CallStatus status;       // see enum
  final DateTime startedAt;      // début sonnerie / appel
  final DateTime? endedAt;       // fin (si connu)
  final int durationSeconds;     // calculé (si connu)

  CallLog({
    this.id,
    required this.callId,
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
    required this.direction,
    required this.type,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  bool get isMissed =>
      status == CallStatus.missed || status == CallStatus.timeout;

  CallLog copyWith({
    int? id,
    String? callId,
    String? peerId,
    String? peerName,
    String? peerAvatar,
    CallDirection? direction,
    CallType? type,
    CallStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return CallLog(
      id: id ?? this.id,
      callId: callId ?? this.callId,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      direction: direction ?? this.direction,
      type: type ?? this.type,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  /* ----------------- DB mapping ----------------- */
  static CallDirection _dirFromString(String v) =>
      v == 'incoming' ? CallDirection.incoming : CallDirection.outgoing;

  static String _dirToString(CallDirection v) =>
      v == CallDirection.incoming ? 'incoming' : 'outgoing';

  static CallType _typeFromString(String v) =>
      v == 'video' ? CallType.video : CallType.audio;

  static String _typeToString(CallType v) =>
      v == CallType.video ? 'video' : 'audio';

  static CallStatus _statusFromString(String v) {
    switch (v) {
      case 'accepted': return CallStatus.accepted;
      case 'rejected': return CallStatus.rejected;
      case 'cancelled':return CallStatus.cancelled;
      case 'missed':   return CallStatus.missed;
      case 'timeout':  return CallStatus.timeout;
      case 'ended':    return CallStatus.ended;
      case 'ringing':
      default:         return CallStatus.ringing;
    }
  }

  static String _statusToString(CallStatus s) {
    switch (s) {
      case CallStatus.accepted:  return 'accepted';
      case CallStatus.rejected:  return 'rejected';
      case CallStatus.cancelled: return 'cancelled';
      case CallStatus.missed:    return 'missed';
      case CallStatus.timeout:   return 'timeout';
      case CallStatus.ended:     return 'ended';
      case CallStatus.ringing:
      default:                   return 'ringing';
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'callId': callId,
    'peerId': peerId,
    'peerName': peerName,
    'peerAvatar': peerAvatar,
    'direction': _dirToString(direction),
    'type': _typeToString(type),
    'status': _statusToString(status),
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endedAt': endedAt?.millisecondsSinceEpoch,
    'durationSeconds': durationSeconds,
  };

  static CallLog fromMap(Map<String, dynamic> m) => CallLog(
    id: m['id'] as int?,
    callId: m['callId'] as String,
    peerId: m['peerId'] as String,
    peerName: m['peerName'] as String,
    peerAvatar: m['peerAvatar'] as String?,
    direction: _dirFromString(m['direction'] as String),
    type: _typeFromString(m['type'] as String),
    status: _statusFromString(m['status'] as String),
    startedAt: DateTime.fromMillisecondsSinceEpoch(m['startedAt'] as int),
    endedAt: (m['endedAt'] as int?) != null
        ? DateTime.fromMillisecondsSinceEpoch(m['endedAt'] as int)
        : null,
    durationSeconds: (m['durationSeconds'] as int?) ?? 0,
  );
}
