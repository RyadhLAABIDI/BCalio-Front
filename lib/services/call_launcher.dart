import 'package:bcalio/models/call_log_model.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/controllers/conversation_controller.dart';
import 'package:bcalio/controllers/contact_controller.dart';
import 'package:bcalio/widgets/chat/chat_room/audio_call_screen.dart';
import 'package:bcalio/widgets/chat/chat_room/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Point central pour démarrer un appel depuis l’UI (journal, profil, etc.)
class CallLauncher {
  CallLauncher._();

  /// Depuis un CallLog (choix audio/vidéo via [video]).
  /// ⚠️ Résout toujours "l’autre" partie pour éviter de s’appeler soi-même.
  static Future<void> fromLog(CallLog log, {required bool video}) async {
    final userCtrl = Get.find<UserController>();
    final myId = (userCtrl.userId).trim();

    if (myId.isEmpty) {
      Get.snackbar('Erreur', 'Utilisateur non connecté');
      return;
    }

    // Valeurs de base du modèle (si bien renseignées = "autre partie")
    String otherId    = (log.peerId     ?? '').trim();
    String otherName  = (log.peerName   ?? '').trim();
    String? otherAva  =  log.peerAvatar;

    // --- Groupe ? (souple: lit isGroup/members si dispo) ---
    final bool isGroup = _pickBool(log, ['isGroup']) ?? false;
    final List<String> members = _pickStringList(log, ['members']) ?? const [];

    if (isGroup) {
      final memberIds = members
          .map((e) => (e).trim())
          .where((e) => e.isNotEmpty && e != myId)
          .toList();

      final display = otherName.isNotEmpty ? otherName : 'Appel de groupe';
      await _openScreen(
        video: video,
        isGroup: true,
        name: display,
        avatarUrl: otherAva,
        recipientId: '', // inutilisé en groupe
        myUserId: myId,
        memberIds: memberIds,
      );
      return;
    }

    // --- 1–1 : si peerId pointe sur moi => déduire l’autre depuis caller/callee ---
    if (otherId.isEmpty || otherId == myId) {
      final callerId = _pickString(log, ['callerId', 'fromId', 'sourceId']).trim();
      final calleeId = _pickString(log, ['recipientId', 'calleeId', 'toId', 'targetId']).trim();

      if (callerId.isNotEmpty && callerId != myId) {
        otherId = callerId;
        if (otherName.isEmpty) {
          otherName = _pickString(log, ['callerName', 'fromName']);
        }
      } else if (calleeId.isNotEmpty && calleeId != myId) {
        otherId = calleeId;
        if (otherName.isEmpty) {
          otherName = _pickString(log, ['recipientName', 'calleeName', 'toName']);
        }
      }
    }

    // Encore invalide ? on s’arrête proprement.
    if (otherId.isEmpty || otherId == myId) {
      Get.snackbar('Erreur', "Impossible d'identifier le correspondant.");
      return;
    }

    // Compléter nom/avatar via caches si manquants
    if (otherName.isEmpty || (otherAva == null || otherAva.trim().isEmpty)) {
      final resolved = _resolveDisplayFor(otherId, fallbackName: otherName);
      otherName = resolved.$1;
      otherAva  = resolved.$2 ?? otherAva;
    }

    await _openScreen(
      video: video,
      isGroup: false,
      name: otherName.isNotEmpty ? otherName : otherId,
      avatarUrl: otherAva,
      recipientId: otherId,
      myUserId: myId,
      memberIds: const [],
    );
  }

  /// Démarrage générique
  static Future<void> startCall({
    required String peerId,
    required String peerName,
    String? avatarUrl,
    required bool video,
  }) async {
    final me = Get.find<UserController>();
    final selfId = (me.userId).trim();

    if (selfId.isEmpty) {
      Get.snackbar('Erreur', 'Utilisateur non connecté');
      return;
    }
    if (peerId.trim().isEmpty || peerId.trim() == selfId) {
      Get.snackbar('Erreur', 'Destinataire invalide');
      return;
    }

    await _openScreen(
      video: video,
      isGroup: false,
      name: peerName,
      avatarUrl: avatarUrl,
      recipientId: peerId,
      myUserId: selfId,
      memberIds: const [],
    );
  }

  /// Ouvre l’écran d’appel
  static Future<void> _openScreen({
    required bool video,
    required bool isGroup,
    required String name,
    String? avatarUrl,
    required String recipientId,
    required String myUserId,
    required List<String> memberIds,
  }) async {
    final page = video
        ? VideoCallScreen(
            name: name,
            avatarUrl: avatarUrl,
            phoneNumber: '',
            recipientID: isGroup ? '' : recipientId,
            userId: myUserId,
            isCaller: true,
            existingCallId: null,
            isGroup: isGroup,
            memberIds: memberIds,
          )
        : AudioCallScreen(
            name: name,
            avatarUrl: avatarUrl,
            phoneNumber: '',
            recipientID: isGroup ? '' : recipientId,
            userId: myUserId,
            isCaller: true,
            existingCallId: null,
            isGroup: isGroup,
            memberIds: memberIds,
          );

    await Get.to(() => page,
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 180));
  }

  /// Cherche nom/avatar pour `otherId` dans les caches
  static (String, String?) _resolveDisplayFor(String otherId,
      {String fallbackName = ''}) {
    String name = fallbackName;
    String? avatar;

    try {
      if (Get.isRegistered<ConversationController>()) {
        final convCtrl = Get.find<ConversationController>();
        for (final conv in convCtrl.conversations) {
          for (final u in conv.users) {
            if (u.id == otherId) {
              if ((u.name ?? '').trim().isNotEmpty) name = u.name!;
              if ((u.image ?? '').trim().isNotEmpty) avatar = u.image!;
              return (name, avatar);
            }
          }
        }
      }
    } catch (_) {}

    try {
      if (Get.isRegistered<ContactController>()) {
        final c = Get.find<ContactController>();
        final pools = [c.allContacts, c.contacts, c.originalApiContacts];
        for (final list in pools) {
          for (final u in list) {
            if (u.id == otherId) {
              if ((u.name ?? '').trim().isNotEmpty) name = u.name!;
              if ((u.image ?? '').trim().isNotEmpty) avatar = u.image!;
              return (name, avatar);
            }
          }
        }
      }
    } catch (_) {}

    return (name, avatar);
  }

  // ---------------- helpers "souples" pour lire des champs optionnels ----------------

  static String _pickString(dynamic log, List<String> keys) {
    try {
      for (final k in keys) {
        final v = log.toJson != null
            ? log.toJson()[k]
            : (log is Map ? log[k] : (log as dynamic)?.$k);
        final s = (v?.toString() ?? '').trim();
        if (s.isNotEmpty) return s;
      }
    } catch (_) {}
    return '';
  }

  static bool? _pickBool(dynamic log, List<String> keys) {
    try {
      for (final k in keys) {
        final v = log.toJson != null
            ? log.toJson()[k]
            : (log is Map ? log[k] : (log as dynamic)?.$k);
        if (v is bool) return v;
        if (v is String) {
          final t = v.toLowerCase().trim();
          if (t == '1' || t == 'true') return true;
          if (t == '0' || t == 'false') return false;
        }
      }
    } catch (_) {}
    return null;
  }

  static List<String>? _pickStringList(dynamic log, List<String> keys) {
    try {
      for (final k in keys) {
        final v = log.toJson != null
            ? log.toJson()[k]
            : (log is Map ? log[k] : (log as dynamic)?.$k);
        if (v is List) {
          return v
              .map((e) => (e?.toString() ?? '').trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
        if (v is String && v.contains(',')) {
          return v
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return null;
  }
}
