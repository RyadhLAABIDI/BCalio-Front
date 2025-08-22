import 'dart:async';
import 'dart:io';            // pour HttpClient (avatar)
import 'dart:typed_data';    // pour Uint8List

import 'package:bcalio/models/conversation_model.dart';
import 'package:bcalio/test_app.dart';
import 'package:bcalio/widgets/notifications/notification_card_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

/* MethodChannel */
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

/* ============================ NOTIFS MESSAGES (Flutter) ============================
   Ces helpers restent présents mais NE SONT PLUS UTILISÉS pour Android.
   Android natif (MyFirebaseMessagingService) gère 100% des notifs "chat".
=================================================================================== */
const String _msgChannelId   = 'msg_channel';
const String _msgChannelName = 'Messages';
const String _msgChannelDesc = 'Notifications de nouveaux messages';

Future<void> _ensureMsgChannel() async {
  final android = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(
    const AndroidNotificationChannel(
      _msgChannelId,
      _msgChannelName,
      description: _msgChannelDesc,
      importance: Importance.high,
    ),
  );
}

Future<Uint8List?> _downloadBytes(String? url, {int timeoutMs = 3500}) async {
  if (url == null || url.trim().isEmpty || !url.startsWith('http')) return null;
  try {
    final client = HttpClient()..connectionTimeout = Duration(milliseconds: timeoutMs);
    final req = await client.getUrl(Uri.parse(url));
    final resp = await req.close();
    if (resp.statusCode != 200) return null;
    final bytes = await consolidateHttpClientResponseBytes(resp);
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<void> _showMessageNotification({
  required String conversationId,
  required String senderName,
  required String bodyOrFallback,
  String? avatarUrl,
}) async {
  await _ensureMsgChannel();

  AndroidBitmap<Object>? largeIcon;
  final bytes = await _downloadBytes(avatarUrl);
  if (bytes != null) {
    largeIcon = ByteArrayAndroidBitmap(bytes);
  }

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _msgChannelId,
      _msgChannelName,
      channelDescription: _msgChannelDesc,
      priority: Priority.high,
      importance: Importance.high,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(bodyOrFallback),
      largeIcon: largeIcon,
      subText: 'Nouveau message',
      ticker: 'Nouveau message',
    ),
  );

  final notifId = conversationId.hashCode;

  await flutterLocalNotificationsPlugin.show(
    notifId,
    senderName,
    bodyOrFallback,
    details,
    payload: conversationId,
  );
}

/* ---------------- FCM background handler (Flutter) ----------------
   ❌ NE PLUS ENREGISTRER CE HANDLER SUR ANDROID.
------------------------------------------------------------------- */
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

/* ---------- canaux natifs ---------- */
const MethodChannel _incomingCallChannel = MethodChannel('incoming_calls');
const MethodChannel _chatPushChannel = MethodChannel('chat_notifications');

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

/* 👇 ouvre la conversation quand MainActivity envoie "open_chat_from_push" */
void _setupChatPushChannel() {
  _chatPushChannel.setMethodCallHandler((call) async {
    if (call.method == 'open_chat_from_push') {
      final Map<String, dynamic> a = Map<String, dynamic>.from(call.arguments as Map);
      final roomId = (a['roomId'] ?? '').toString();
      if (roomId.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openConversationFromPayload(roomId);
      });
    }
    return;
  });
}

/* ====== Handshake "chat_ready" (anti-course au démarrage) ====== */
Future<void> _announceChatReady() async {
  try {
    await _chatPushChannel.invokeMethod('chat_ready');
  } catch (_) {
    // si le canal Android n'est pas encore là, on retentera via _signalChatReadyResilient
  }
}

/// On ping plusieurs fois pour ne rater aucun timing (cold start, etc.)
void _signalChatReadyResilient() {
  void ping() => _announceChatReady();
  ping(); // tout de suite
  Future.delayed(const Duration(milliseconds: 300), ping);
  WidgetsBinding.instance.addPostFrameCallback((_) => ping()); // après 1er frame
}

/* ===========================================================
   ==  🔧 HELPERS POUR CORRIGER L’AVATAR & LE RECIPIENT ID  ==
   =========================================================== */

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

void _setVisibility(bool visible) {
  try {
    if (!Get.isRegistered<UserController>()) return;
    final sock = Get.find<UserController>().socketService;

    sock.setVisibility(visible);

    if (!visible) {
      Future.delayed(const Duration(seconds: 2), () {
        try {
          if (!Get.isRegistered<UserController>()) return;
          final s = Get.find<UserController>().socketService;
          if (!_AppLifecycleSpy.isForeground && s.isConnected) s.dispose();
        } catch (_) {}
      });
    } else {
      if (!sock.isConnected) {
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

/* Notifie nativement si l’app n’est pas au 1er plan */
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
      'callerPhone': _findPhoneFor(callerId) ?? '',
      'isGroup': isGroup,
      'members': memberIds.join(','),
      'recipientID': _myUserIdOrFallback(),
    });
  } catch (_) {}
}

/* ---------- BIND GLOBAL : appels entrants via Socket ---------- */
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
    debugPrint('[Socket][GLOBAL] incoming-GROUP $callerId ($callType) id=$callId');

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

/* tient compte de sock.isConnected et résout le userId au flush */
void _queueOrRunCallAction(String kind, String callId, String myId) {
  try {
    final sock = Get.find<UserController>().socketService;

    String resolvedMyId =
        (myId.trim().isNotEmpty) ? myId.trim() : sock.userId.trim();

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

    _pendingCallActions.add(_PendingCallAction(kind, callId, resolvedMyId));

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

/* ===================== Navigation vers écran d'appel ===================== */
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

    if (autoReject) {
      if (callId.isNotEmpty && myId.isNotEmpty) {
        _queueOrRunCallAction('reject', callId, myId);
      }
      return;
    }

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

  WidgetsBinding.instance.addObserver(_AppLifecycleSpy.I);

  _setupIncomingCallChannel();
  _setupChatPushChannel();
  _signalChatReadyResilient(); // 👈 NEW: annonce "prêt" (plusieurs pings)

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
    ..put(CallLogController(), permanent: true);

  /* ---------- BIND GLOBAL AVANT CONNEXION SOCKET ---------- */
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

  // cas “l’app a été lancée via une notif locale (payload)”
  final launchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if ((launchDetails?.didNotificationLaunchApp ?? false) &&
      launchDetails?.notificationResponse?.payload != null) {
    final payload = launchDetails!.notificationResponse!.payload!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openConversationFromPayload(payload);
    });
  }

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
    sock.connectAndRegister(uid, name);
  }

  // ❌ NE PLUS ENREGISTRER le handler background Flutter pour Android
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  WidgetsBinding.instance.addPostFrameCallback((_) => _drainPendingIncoming());
  Future.delayed(const Duration(milliseconds: 200), _drainPendingIncoming);

  runApp(MyApp(
    rememberMe: rememberMe,
    isFirstTime: isFirstTime,
  ));
}

/* -------------------- OUVERTURE CONVERSATION -------------------- */

// remplace seulement cette fonction dans ton main.dart

Future<void> _openConversationFromPayload(String conversationId, {int attempt = 0}) async {
  // anti-boucle
  if (attempt > 6) return;

  try {
    final convCtrl = Get.find<ConversationController>();
    final usrCtrl = Get.find<UserController>();

    // token pas encore prêt ? réessaie un peu plus tard
    final token = await usrCtrl.getToken();
    if (token == null || token.isEmpty) {
      Future.delayed(const Duration(milliseconds: 400),
          () => _openConversationFromPayload(conversationId, attempt: attempt + 1));
      return;
    }

    // recharge (peut prendre un peu de temps)
    await convCtrl.refreshConversations(token);

    // trouve la conv
    final conv = convCtrl.conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => Conversation(
        id: '',
        createdAt: DateTime.now(),
        messagesIds: [],
        userIds: [],
        users: [],
        messages: [],
      ),
    );

    // pas encore en mémoire ? réessaie
    if (conv.id.isEmpty) {
      Future.delayed(const Duration(milliseconds: 400),
          () => _openConversationFromPayload(conversationId, attempt: attempt + 1));
      return;
    }

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
  } catch (e) {
    // sécurité: petit retry si quelque chose n’est pas prêt
    Future.delayed(const Duration(milliseconds: 400),
        () => _openConversationFromPayload(conversationId, attempt: attempt + 1));
  }
}

Future<void> _onNotifTap(NotificationResponse resp) async {
  final payload = resp.payload;
  if (payload == null) return;
  await _openConversationFromPayload(payload);
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
    // 👇 Extra-sécurité : on re-ping dès que le 1er frame est prêt
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceChatReady());

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
