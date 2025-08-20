import 'dart:async';

import 'package:bcalio/models/conversation_model.dart';
import 'package:bcalio/test_app.dart';
import 'package:bcalio/widgets/notifications/notification_card_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/* controllers & services */
import 'controllers/contact_controller.dart';
import 'controllers/conversation_controller.dart';
import 'controllers/language_controller.dart';
import 'controllers/notification_controller.dart';
import 'controllers/theme_controller.dart';
import 'controllers/user_controller.dart';
import 'i18n/app_translation.dart';
import 'routes.dart';
import 'screens/chat/ChatRoom/chat_room_screen.dart';
import 'services/contact_api_service.dart';
import 'services/conversation_api_service.dart';
import 'services/local_storage_service.dart';
import 'services/message_api_service.dart';
import 'services/user_api_service.dart';

/* thèmes / UI */
import 'themes/theme.dart';

/* notifs locales */
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/* permissions Cam / Mic */
import 'package:permission_handler/permission_handler.dart';

/* MethodChannel pour incoming_call (depuis Android) */
import 'package:flutter/services.dart';
import 'widgets/chat/chat_room/incoming_call_screen.dart';

/* ➕ nécessaires pour autoAccept */
import 'widgets/chat/chat_room/audio_call_screen.dart';
import 'widgets/chat/chat_room/video_call_screen.dart';

/* ---- Journal d’appel ---- */
import 'controllers/call_log_controller.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/* ---------------- FCM background handler ---------------- */
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔕 Background Message: ${message.messageId}');
}

/* token FCM */
Future<void> _getFCMToken() async {
  final fcm = FirebaseMessaging.instance;
  final token = await fcm.getToken();
  if (token != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcmToken', token);
  }
}

/* Demande Caméra + Micro AU DÉMARRAGE */
Future<void> _requestAVPermissions() async {
  final statuses = await [
    Permission.camera,
    Permission.microphone,
  ].request();

  debugPrint('[PERM] camera=${statuses[Permission.camera]} '
      'micro=${statuses[Permission.microphone]}');
}

/* ---------- canal natif "incoming_calls" ---------- */
const MethodChannel _incomingCallChannel = MethodChannel('incoming_calls');

/// File d’attente si l’événement arrive avant que le Navigator soit prêt.
final List<Map<String, dynamic>> _pendingIncoming = [];
bool get _navReady => navigatorKey.currentState != null;
void _drainPendingIncoming() {
  if (!_navReady) return;
  final copy = List<Map<String, dynamic>>.from(_pendingIncoming);
  _pendingIncoming.clear();
  for (final a in copy) {
    _doNavigateToIncoming(a);
  }
}

void _setupIncomingCallChannel() {
  _incomingCallChannel.setMethodCallHandler((call) async {
    if (call.method == 'incoming_call') {
      final Map<String, dynamic> args =
          Map<String, dynamic>.from(call.arguments as Map);
      _navigateToIncoming(args);
    }
  });
}

/* ===========================================================
   ==  🔧 HELPERS POUR CORRIGER L’AVATAR & LE RECIPIENT ID  ==
   =========================================================== */

/* Récupère l’avatar du caller depuis les caches (conversations / contacts) */
String? _findAvatarFor(String userId) {
  try {
    if (Get.isRegistered<ConversationController>()) {
      final convCtrl = Get.find<ConversationController>();
      for (final conv in convCtrl.conversations) {
        for (final u in conv.users) {
          if (u.id == userId) {
            final img = (u.image ?? '').trim();
            if (img.isNotEmpty) return img;
          }
        }
      }
    }

    if (Get.isRegistered<ContactController>()) {
      final cCtrl = Get.find<ContactController>();
      for (final c in cCtrl.allContacts) {
        if (c.id == userId) {
          final img = (c.image ?? '').trim();
          if (img.isNotEmpty) return img;
        }
      }
      for (final c in cCtrl.contacts) {
        if (c.id == userId) {
          final img = (c.image ?? '').trim();
          if (img.isNotEmpty) return img;
        }
      }
      for (final c in cCtrl.originalApiContacts) {
        if (c.id == userId) {
          final img = (c.image ?? '').trim();
          if (img.isNotEmpty) return img;
        }
      }
    }
  } catch (_) {}
  return null;
}

/* ✅ NEW: Récupère le numéro du caller depuis les caches (conversations / contacts) */
String? _findPhoneFor(String userId) {
  try {
    if (Get.isRegistered<ConversationController>()) {
      final convCtrl = Get.find<ConversationController>();
      for (final conv in convCtrl.conversations) {
        for (final u in conv.users) {
          if (u.id == userId) {
            final ph = (u.phoneNumber ?? '').trim();
            if (ph.isNotEmpty) return ph;
          }
        }
      }
    }
    if (Get.isRegistered<ContactController>()) {
      final cCtrl = Get.find<ContactController>();
      for (final c in cCtrl.allContacts) {
        if (c.id == userId) {
          final ph = (c.phoneNumber ?? '').trim();
          if (ph.isNotEmpty) return ph;
        }
      }
      for (final c in cCtrl.contacts) {
        if (c.id == userId) {
          final ph = (c.phoneNumber ?? '').trim();
          if (ph.isNotEmpty) return ph;
        }
      }
      for (final c in cCtrl.originalApiContacts) {
        if (c.id == userId) {
          final ph = (c.phoneNumber ?? '').trim();
          if (ph.isNotEmpty) return ph;
        }
      }
    }
  } catch (_) {}
  return null;
}

/* Retourne mon userId (destinataire de l’appel), avec fallback sur le socket */
String _myUserIdOrFallback() {
  try {
    if (Get.isRegistered<UserController>()) {
      final userCtrl = Get.find<UserController>();
      final me = userCtrl.currentUser.value;
      final meId = (me?.id ?? '').trim();
      if (meId.isNotEmpty) return meId;

      final sockId = (userCtrl.socketService.userId).trim();
      if (sockId.isNotEmpty) return sockId;
    }
  } catch (_) {}
  return '';
}

/* =========================
   ==  👀 LIFECYCLE SPY  ==
   ========================= */
class _AppLifecycleSpy with WidgetsBindingObserver {
  static final _AppLifecycleSpy I = _AppLifecycleSpy();
  static AppLifecycleState state = AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    state = s;
    // Pilotage de la visibilité (serveur FCM fallback quand hidden)
    if (s == AppLifecycleState.resumed) {
      _setVisibility(true);
    } else if (s == AppLifecycleState.paused ||
        s == AppLifecycleState.inactive ||
        s == AppLifecycleState.detached) {
      _setVisibility(false);
    }
  }

  static bool get isForeground => state == AppLifecycleState.resumed;
}

/* Envoie visible/hidden au backend + (dé)connexion socket en conséquence */
void _setVisibility(bool visible) {
  try {
    if (!Get.isRegistered<UserController>()) return;
    final sock = Get.find<UserController>().socketService;

    // notifier le backend
    sock.setVisibility(visible);

    // Optionnel : couper/recréer le socket suivant l'état
    if (!visible) {
      // on coupe 2s après (laisse le temps à un éventuel resume rapide)
      Future.delayed(const Duration(seconds: 2), () {
        try {
          if (!Get.isRegistered<UserController>()) return;
          final s = Get.find<UserController>().socketService;
          // 🔧 SocketService n'a pas disconnect(): on utilise dispose()
          if (!_AppLifecycleSpy.isForeground && s.isConnected) s.dispose();
        } catch (_) {}
      });
    } else {
      if (!sock.isConnected) {
        // Reconnexion: on lit userId / name depuis SharedPreferences
        SharedPreferences.getInstance().then((sp) {
          final uid = sp.getString('userId') ?? '';
          final name = sp.getString('name') ?? '';
          if (uid.isNotEmpty && name.isNotEmpty) {
            sock.connectAndRegister(uid, name);
          }
        });
      }
    }
  } catch (_) {}
}

/* Notifie nativement (fullScreenIntent + sonnerie TEL) si l’app n’est pas au 1er plan */
Future<void> _maybeNotifyIfBackground({
  required String callId,
  required String callerId,
  required String callerName,
  required String callType,
  bool isGroup = false,
  List<String> memberIds = const [],
}) async {
  if (_AppLifecycleSpy.isForeground) return;

  try {
    await _incomingCallChannel.invokeMethod('show_call_notification', {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callType': callType,
      'avatarUrl': _findAvatarFor(callerId) ?? '',
      'callerPhone': _findPhoneFor(callerId) ?? '', // 👈 NEW
      'isGroup': isGroup,
      'members': memberIds.join(','), // string
      'recipientID': _myUserIdOrFallback(),
    });
  } catch (_) {}
}

/* ---------- 💡 BIND GLOBAL : appels entrants via Socket ---------- */
void _bindSocketIncomingHandlers() {
  final userCtrl = Get.find<UserController>();
  final sock = userCtrl.socketService;

  bool _incomingScreenOpen = false;

  void _openIncoming({
    required String callId,
    required String callerId,
    required String callerName,
    required String callType,
    bool isGroup = false,
    List<String> memberIds = const [],
  }) {
    if (_incomingScreenOpen) return;
    _incomingScreenOpen = true;

    final myId = _myUserIdOrFallback();
    final avatar = _findAvatarFor(callerId);

    navigatorKey.currentState
        ?.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: callerName.isNotEmpty ? callerName : callerId,
          callerId: callerId,
          callId: callId,
          callType: callType,
          avatarUrl: avatar,
          recipientID: myId,
          isGroup: isGroup,
          members: memberIds,
        ),
        fullscreenDialog: true,
      ),
    )
        .whenComplete(() {
      _incomingScreenOpen = false;
    });
  }

  // 1–1
  sock.onIncomingCall = (callId, callerId, callerName, callType) {
    debugPrint('[Socket][GLOBAL] incoming-call $callerId ($callType) id=$callId');

    if (!_AppLifecycleSpy.isForeground) {
      _maybeNotifyIfBackground(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callType: callType,
      );
      return;
    }

    _openIncoming(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callType: callType,
    );
  };

  // Groupe
  sock.onIncomingGroupCall =
      (callId, callerId, callerName, callType, members) {
    debugPrint(
        '[Socket][GLOBAL] incoming-GROUP $callerId ($callType) id=$callId');

    final myId = _myUserIdOrFallback();
    final ids = <String>[];
    try {
      for (final m in members) {
        final id = (m['userId'] ?? '').toString();
        if (id.isNotEmpty && id != myId) ids.add(id);
      }
    } catch (_) {}

    if (!_AppLifecycleSpy.isForeground) {
      _maybeNotifyIfBackground(
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callType: callType,
        isGroup: true,
        memberIds: ids,
      );
      return;
    }

    _openIncoming(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callType: callType,
      isGroup: true,
      memberIds: ids,
    );
  };
}

/* Navigue depuis le canal natif — queue si navigator pas prêt */
void _navigateToIncoming(Map<String, dynamic> a) {
  if (!_navReady) {
    _pendingIncoming.add(a);
    return;
  }
  _doNavigateToIncoming(a);
}

/* ===================== File d’actions (accept/reject) ===================== */
class _PendingCallAction {
  final String kind; // 'accept' | 'reject'
  final String callId;
  final String userId;
  _PendingCallAction(this.kind, this.callId, this.userId);
}

final List<_PendingCallAction> _pendingCallActions = [];

/* ✅ VERSION FINALE : tient compte de sock.isConnected et résout le userId au flush */
void _queueOrRunCallAction(String kind, String callId, String myId) {
  try {
    final sock = Get.find<UserController>().socketService;

    // Résoudre mon userId maintenant si vide
    String resolvedMyId =
        (myId.trim().isNotEmpty) ? myId.trim() : sock.userId.trim();

    // Si déjà connecté → on envoie tout de suite
    if (sock.isConnected) {
      if (resolvedMyId.isEmpty) resolvedMyId = sock.userId.trim();
      if (resolvedMyId.isEmpty) {
        _pendingCallActions.add(_PendingCallAction(kind, callId, ''));
      } else {
        if (kind == 'accept') {
          sock.acceptCall(callId, resolvedMyId);
        } else {
          sock.rejectCall(callId, resolvedMyId);
        }
      }
      return;
    }

    // Pas connecté → on file l’action (même si userId est vide, on le résoudra au flush)
    _pendingCallActions.add(_PendingCallAction(kind, callId, resolvedMyId));

    // Au prochain "registered", on flush proprement la file
    final prev = sock.onRegistered;
    sock.onRegistered = () {
      try {
        prev?.call();
      } catch (_) {}
      final copy = List<_PendingCallAction>.from(_pendingCallActions);
      _pendingCallActions.clear();
      for (final a in copy) {
        try {
          final uid =
              a.userId.trim().isNotEmpty ? a.userId.trim() : sock.userId.trim();
          if (uid.isEmpty) continue;
          if (a.kind == 'accept') {
            sock.acceptCall(a.callId, uid);
          } else {
            sock.rejectCall(a.callId, uid);
          }
        } catch (_) {}
      }
    };
  } catch (_) {
    _pendingCallActions.add(_PendingCallAction(kind, callId, myId));
  }
}

/* ===================== NOUVELLE VERSION ===================== */
void _doNavigateToIncoming(Map<String, dynamic> a) {
  try {
    final callerId = (a['callerId'] ?? '').toString();
    final callerName = (a['callerName'] ?? 'Unknown').toString();
    final callId = (a['callId'] ?? '').toString();
    final callType = (a['callType'] ?? 'audio').toString();

    final providedAvatar = a['avatarUrl'];
    final resolvedAvatar =
        (providedAvatar is String && providedAvatar.trim().isNotEmpty)
            ? providedAvatar
            : _findAvatarFor(callerId);

    final providedRecipient = (a['recipientID'] ?? '').toString();
    final myId = providedRecipient.isNotEmpty
        ? providedRecipient
        : _myUserIdOrFallback();

    final bool isGroup = a['isGroup'] == true || a['isGroup'] == '1';
    final List<String> members = (() {
      final raw = (a['members'] ?? '').toString().trim();
      if (raw.isEmpty) return <String>[];
      if (raw.contains(',')) {
        return raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return <String>[];
    })();

    final bool autoAccept = a['autoAccept'] == true;
    final bool autoReject = a['autoReject'] == true;

    // ---- auto-reject depuis la notif ----
    if (autoReject) {
      if (callId.isNotEmpty && myId.isNotEmpty) {
        _queueOrRunCallAction('reject', callId, myId);
      }
      return;
    }

    // ---- auto-accept depuis la notif ----
    if (autoAccept) {
      if (callId.isNotEmpty && myId.isNotEmpty) {
        _queueOrRunCallAction('accept', callId, myId);
      }
      final isVideo = callType == 'video';
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => isVideo
              ? VideoCallScreen(
                  name: callerName,
                  avatarUrl: resolvedAvatar,
                  phoneNumber: '',
                  recipientID: isGroup ? '' : callerId,
                  userId: myId,
                  isCaller: false,
                  existingCallId: callId,
                  isGroup: isGroup,
                  memberIds: members,
                )
              : AudioCallScreen(
                  name: callerName,
                  avatarUrl: resolvedAvatar,
                  phoneNumber: '',
                  recipientID: isGroup ? '' : callerId,
                  userId: myId,
                  isCaller: false,
                  existingCallId: callId,
                  isGroup: isGroup,
                  memberIds: members,
                ),
          fullscreenDialog: true,
        ),
      );
      return;
    }

    // ---- chemin normal (écran slide To Accept/Reject) ----
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerName: callerName,
          callerId: callerId,
          callId: callId,
          callType: callType,
          avatarUrl: resolvedAvatar,
          recipientID: myId,
          isGroup: isGroup,
          members: members,
        ),
        fullscreenDialog: true,
      ),
    );
  } catch (e) {
    debugPrint('[incoming_call] navigate error: $e');
  }
}

/* ------------------------------------------------------------------ */
/*                               MAIN                                 */
/* ------------------------------------------------------------------ */
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 observe le lifecycle pour savoir si l’app est au 1er plan ou non
  WidgetsBinding.instance.addObserver(_AppLifecycleSpy.I);

  _setupIncomingCallChannel(); // ← écoute "incoming_call" (peut arriver très tôt)

  await Firebase.initializeApp();
  await _getFCMToken();

  /* ---------- singletons & services ---------- */
  final localStorageService = LocalStorageService();
  await localStorageService.init();
  Get.put(localStorageService);

  Get
    ..put(UserController(userApiService: UserApiService()))
    ..put(ContactController(contactApiService: ContactApiService()))
    ..put(ThemeController())
    ..put(LanguageController())
    ..put(ConversationApiService())
    ..put(MessageApiService())
    ..put(NotificationController())
    // ❌ pas de SocketService ici (il est fourni par UserController et c'est un singleton)
    ..put(CallLogController(), permanent: true);

  /* ---------- 🔗 BIND GLOBAL AVANT CONNEXION SOCKET ---------- */
  _bindSocketIncomingHandlers();

  /* ---------- thème / langue ---------- */
  await Get.find<ThemeController>().initializeTheme();
  await Get.find<LanguageController>().initializeLanguage();

  /* ---------- notifications locales ---------- */
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const init = InitializationSettings(android: android);
  await flutterLocalNotificationsPlugin.initialize(
    init,
    onDidReceiveNotificationResponse: _onNotifTap,
  );

  /* ---------- permissions ---------- */
  await Get.find<NotificationController>().requestNotificationPermission();
  await Get.find<ContactController>().requestContactsPermission();
  await _requestAVPermissions();

  /* ---------- prefs ---------- */
  final prefs = await SharedPreferences.getInstance();
  final userToken = prefs.getString('token') ?? '';
  final rememberMe =
      userToken.isNotEmpty ? (prefs.getBool('rememberMe') ?? false) : false;
  final isFirstTime = prefs.getBool('isFirstTime') ?? true;

  /* ---------- auto-connexion socket si déjà loggé ---------- */
  final uid = prefs.getString('userId') ?? '';
  final name = prefs.getString('name') ?? '';
  if (uid.isNotEmpty && name.isNotEmpty) {
    final sock = Get.find<UserController>().socketService;
    // (pas de _wirePendingToSocket ici — la file se branche elle-même via onRegistered)
    sock.connectAndRegister(uid, name);
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔔 IMPORTANT : vider la file d’appels entrants dès que le 1er frame est rendu
  WidgetsBinding.instance.addPostFrameCallback((_) => _drainPendingIncoming());
  // petit filet de sécurité
  Future.delayed(const Duration(milliseconds: 200), _drainPendingIncoming);

  runApp(MyApp(
    rememberMe: rememberMe,
    isFirstTime: isFirstTime,
  ));
}

/* tap sur notification locale (payload = id conv) */
Future<void> _onNotifTap(NotificationResponse resp) async {
  final payload = resp.payload;
  if (payload == null) return;

  final convCtrl = Get.find<ConversationController>();
  final usrCtrl = Get.find<UserController>();
  final token = await usrCtrl.getToken();
  if (token == null || token.isEmpty) return;

  await convCtrl.refreshConversations(token);

  final conv = convCtrl.conversations.firstWhere(
    (c) => c.id == payload,
    orElse: () => Conversation(
        id: '',
        createdAt: DateTime.now(),
        messagesIds: [],
        userIds: [],
        users: [],
        messages: []),
  );
  if (conv.id.isEmpty) return;

  final selfId = usrCtrl.currentUser.value?.id;
  final other = conv.users.firstWhere((u) => u.id != selfId,
      orElse: () => throw Exception('user not found'));

  Get.to(() => ChatRoomPage(
        conversationId: conv.id,
        name: other.name,
        phoneNumber: other.phoneNumber ?? '',
        avatarUrl: other.image,
        createdAt: other.createdAt,
      ));
}

/* ------------------------------------------------------------------ */
/*                              APP                                   */
/* ------------------------------------------------------------------ */
class MyApp extends StatelessWidget {
  final bool rememberMe;
  final bool isFirstTime;
  MyApp({super.key, required this.rememberMe, required this.isFirstTime});

  final ThemeController themeCtrl = Get.find<ThemeController>();
  final LanguageController langCtrl = Get.find<LanguageController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() => GetMaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          translations: AppTranslation(),
          locale: langCtrl.selectedLocale.value,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeCtrl.themeMode.value,
          getPages: Routes.routes,
          initialRoute: isFirstTime
              ? Routes.start
              : (rememberMe ? Routes.navigationScreen : Routes.login),
          builder: (_, child) => child ?? const SizedBox.shrink(),
        ));
  }
}
