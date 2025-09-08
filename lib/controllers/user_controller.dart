// lib/controllers/user_controller.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/true_user_model.dart';
import '../services/socket_service.dart';
import '../services/user_api_service.dart';
import '../utils/misc.dart';
// [SYNC] ajoute
import '../services/contacts_sync_service.dart';
// ⬇️ pour intercepter les 401 venant des services
import '../services/http_errors.dart';

class UserController extends GetxController {
  final UserApiService userApiService;
  late final SocketService socketService;

  static const String pushBaseUrl = 'http://192.168.1.22:1906';

  UserController({required this.userApiService})
      : socketService = SocketService(baseUrl: 'http://192.168.1.22:1906');

  final Rx<User?> _currentUser = Rx<User?>(null);
  Rx<User?> get currentUser => _currentUser;

  final RxBool isLoading = false.obs;

  User?  get user     => _currentUser.value;
  String get userId   => _currentUser.value?.id   ?? '';
  String get userName => _currentUser.value?.name ?? '';

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  final RxMap<String, bool>       online   = <String, bool>{}.obs;
  final RxMap<String, DateTime?>  lastSeen = <String, DateTime?>{}.obs;

  bool      isOnline(String uid)   => online[uid] == true;
  DateTime? lastSeenOf(String uid) => lastSeen[uid];

  void requestPresenceFor(List<String> uids) {
    if (uids.isEmpty) return;
    socketService.requestPresence(uids);
  }

  final RxBool isOnlineVisible = true.obs;

  Future<void> loadVisibilityPref() async {
    final p = await SharedPreferences.getInstance();
    isOnlineVisible.value = p.getBool('isOnlineVisible') ?? true;
  }

  Future<void> setOnlineVisible(bool visible) async {
    isOnlineVisible.value = visible;
    (await SharedPreferences.getInstance()).setBool('isOnlineVisible', visible);
    socketService.setVisibility(visible);
  }

  // [SYNC] ajoute
  final ContactsSyncService _contactsSync = ContactsSyncService();
  final Rx<DateTime?> lastPhoneSync = Rx<DateTime?>(null);

  @override
  void onInit() {
    super.onInit();

    loadVisibilityPref();

    socketService.onRegistered = () {
      debugPrint('[Socket] Registered OK (userId: $userId)');
      socketService.setVisibility(isOnlineVisible.value);
    };
    socketService.onCallEnded = () =>
        debugPrint('[Socket] Call ended (userId: $userId)');
    socketService.onCallError = (err) => Get.snackbar('Error', err,
        backgroundColor: Colors.red, colorText: Colors.white);

    socketService.onPresenceUpdate = (uid, isOn, ls) {
      if (uid.isEmpty) return;
      online[uid]   = isOn;
      lastSeen[uid] = isOn ? null : ls;
    };
    socketService.onPresenceState = (list) {
      for (final e in list) {
        final uid = (e['userId'] ?? '').toString();
        if (uid.isEmpty) continue;
        final isOn = e['online'] == true;
        final ls   = e['lastSeen'] as DateTime?;
        online[uid]   = isOn;
        lastSeen[uid] = isOn ? null : ls;
      }
    };

    ever<User?>(_currentUser, (u) async {
      if (u != null) {
        socketService.connectAndRegister(u.id, u.name);
        await _ensureFcmRegistered();
      }
    });

    _restoreSessionAndRegister();

    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] onTokenRefresh: $newToken');
      final p = await SharedPreferences.getInstance();
      await p.setString('fcmToken', newToken);
      if (userId.isNotEmpty) {
        await _registerFcmToBackend(userId, newToken);
      }
    });
  }

  Future<void> _restoreSessionAndRegister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token')        ?? '';
      final uid   = prefs.getString('userId')       ?? '';
      final name  = prefs.getString('name')         ?? '';
      final image = prefs.getString('image');
      final about = prefs.getString('about');
      final phone = prefs.getString('phoneNumber'); // ⬅️ persisted

      if (token.isEmpty || uid.isEmpty || name.isEmpty) {
        debugPrint('[Session] no persisted session to restore');
        return;
      }

      final email = (await getCredentials())['email'] ?? '';
      final u = User(
        id: uid,
        email: email,
        name: name,
        image: image,
        about: about,
        phoneNumber: phone, // ⬅️ hydrate phone from prefs
      );

      _currentUser.value = u;
      debugPrint('[Session] restored → $uid / $name');

      // 🔄 Hydrate phoneNumber si manquant (appel léger)
      if ((u.phoneNumber ?? '').isEmpty) {
        try {
          final fromApi = await userApiService.getUser(uid);
          final fetchedPhone = fromApi?.phoneNumber ?? '';
          if (fetchedPhone.trim().isNotEmpty) {
            // ✅ Pas de copyWith → on reconstruit l'objet User
            _currentUser.value = User(
              id: u.id,
              email: u.email,
              name: u.name,
              image: u.image,
              about: u.about,
              phoneNumber: fetchedPhone,
            );
            await prefs.setString('phoneNumber', fetchedPhone);
          }
        } catch (_) {
          // on ignore si l'API ne renvoie pas le numéro
        }
      }
    } catch (e) {
      debugPrint('[Session] restore error: $e');
    }
  }

  Future<void> _ensureFcmRegistered() async {
    try {
      await _fcm.requestPermission();

      String? token = await _fcm.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] getToken returned null/empty');
        return;
      }

      final p = await SharedPreferences.getInstance();
      await p.setString('fcmToken', token);

      if (userId.isNotEmpty) {
        await _registerFcmToBackend(userId, token);
      }
    } catch (e) {
      debugPrint('[FCM] ensure register error: $e');
    }
  }

  Uri _buildUri(String base, String path) {
    final b = base.trim();
    final u = Uri.parse(b);
    return u.replace(path: path.startsWith('/') ? path : '/$path');
  }

  Future<void> _registerFcmToBackend(String uid, String token) async {
    try {
      final uri = _buildUri(pushBaseUrl, '/push/register');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': uid, 'fcmToken': token}),
      );
      debugPrint('[FCM] register → ${resp.statusCode} ${resp.body}  @ ${uri.toString()}');
    } catch (e) {
      debugPrint('[FCM] register http error: $e');
    }
  }

  Future<void> _unregisterFcmFromBackend(String uid) async {
    try {
      final p     = await SharedPreferences.getInstance();
      final token = p.getString('fcmToken') ?? '';
      if (token.isEmpty) return;
      final uri = _buildUri(pushBaseUrl, '/push/unregister');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': uid, 'fcmToken': token}),
      );
      debugPrint('[FCM] unregister → ${resp.statusCode} ${resp.body}  @ ${uri.toString()}');
    } catch (e) {
      debugPrint('[FCM] unregister http error: $e');
    }
  }

  Future<void> _saveToken(String token) async =>
      (await SharedPreferences.getInstance()).setString('token', token);

  Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString('token');

  Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
    await prefs.setString('password', password);
  }

  Future<Map<String, String?>> getCredentials() async {
    final p = await SharedPreferences.getInstance();
    return {'email': p.getString('email'), 'password': p.getString('password')};
  }

  /// 🔐 Login "normal" (avec navigation)
  Future<void> login(String email, String password) async {
    isLoading.value = true;
    try {
      final auth = await userApiService.login(email: email, password: password);
      _currentUser.value = auth.user;

      await _saveToken(auth.token);
      await saveCredentials(email, password);

      final prefs = await SharedPreferences.getInstance();
      await prefs
        ..setString('name',        auth.user.name)
        ..setString('image',       auth.user.image ?? '')
        ..setString('about',       auth.user.about ?? '')
        ..setString('userId',      auth.user.id)
        ..setString('phoneNumber', auth.user.phoneNumber ?? '');   // ⬅️ persist phone

      await _ensureFcmRegistered();
      Get.offAllNamed('/navigationScreen');
    } catch (e) {
      showSnackbar('Please check your credentials'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  /// 🔄 Re-login silencieux (aucune navigation)
  Future<void> reLoginSilently() async {
    final creds = await getCredentials();
    final email = creds['email'];
    final pass  = creds['password'];
    if ((email ?? '').isEmpty || (pass ?? '').isEmpty) {
      throw UnauthorizedException('Missing stored credentials');
    }

    final auth = await userApiService.login(email: email!, password: pass!);

    _currentUser.value = auth.user;
    await _saveToken(auth.token);

    final prefs = await SharedPreferences.getInstance();
    await prefs
      ..setString('name',        auth.user.name)
      ..setString('image',       auth.user.image ?? '')
      ..setString('about',       auth.user.about ?? '')
      ..setString('userId',      auth.user.id)
      ..setString('phoneNumber', auth.user.phoneNumber ?? '');

    await _ensureFcmRegistered();
    debugPrint('[Auth] Silent re-login OK');
  }

  /// 🛡️ Enveloppe pour relancer l’appel si 401
  Future<T> withAuthRetry<T>(Future<T> Function(String token) op, {int maxRetries = 1}) async {
    String token = (await getToken()) ?? '';
    if (token.isEmpty) {
      // pas de token → tente direct une reconnexion silencieuse
      await reLoginSilently();
      token = (await getToken()) ?? '';
      if (token.isEmpty) throw UnauthorizedException('No token after re-login');
    }

    try {
      return await op(token);
    } on UnauthorizedException {
      if (maxRetries <= 0) rethrow;
      debugPrint('[Auth] 401 → trying silent re-login…');
      await reLoginSilently();
      final newToken = (await getToken()) ?? '';
      if (newToken.isEmpty) throw UnauthorizedException('No token after re-login');
      return await op(newToken);
    }
  }

  Future<void> logout() async {
    try {
      if (userId.isNotEmpty) {
        await _unregisterFcmFromBackend(userId);
      }
      (await SharedPreferences.getInstance()).clear();
      _currentUser.value = null;
      socketService.dispose();
      online.clear();
      lastSeen.clear();
      isOnlineVisible.value = true;
      Get.offAllNamed('/login');
    } catch (e) {
      Get.snackbar('Error'.tr, 'Failed to log out. Please try again.'.tr,
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> registerWithAvatar({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
    File? avatar,
  }) async {
    isLoading.value = true;
    try {
      if (avatar != null) {
        await userApiService.uploadImageToCloudinary(avatar);
      }
      final user = await userApiService.register(
        email: email,
        password: password,
        name: name,
        phoneNumber: phoneNumber,
      );
      _currentUser.value = user;
      Get.offAllNamed('/login');
    } catch (_) {
      showSnackbar('User already exist'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> autoLogin() async {
    final creds = await getCredentials();
    if (creds['email'] != null && creds['password'] != null) {
      await login(creds['email']!, creds['password']!);
    }
  }

  Future<void> updateProfile({
  required String name,
  required String image,
  required String about,
  required String geolocalisation,
  required String screenshotToken,
  required String rfcToken,
}) async {
  isLoading.value = true;
  try {
    final updated = await userApiService.updateProfile(
      name: name,
      image: image,
      about: about,
      geolocalisation: geolocalisation,
      screenshotToken: screenshotToken,
      rfcToken: rfcToken,
    );

    _currentUser.value = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs
      ..setString('name',        updated.name)
      ..setString('image',       updated.image ?? '')
      ..setString('about',       updated.about ?? '')
      ..setString('phoneNumber', updated.phoneNumber ?? '');
  } catch (_) {
    // plus de snackbar ni de message à l’utilisateur
    debugPrint('[UserController] updateProfile failed (silencieux)');
  } finally {
    isLoading.value = false;
  }
}

  Future<List<User>> fetchUsers(String token) async {
    try {
      return await userApiService.fetchUsers(token);
    } catch (e) {
      debugPrint('Fetch users error: $e');
      return [];
    }
  }

  Future<User?> getUser(String id) async {
    try {
      return await userApiService.getUser(id);
    } catch (e) {
      debugPrint('Get user error: $e');
      return null;
    }
  }

  void debugUserInfo() =>
      debugPrint('UserId: $userId  —  Name: $userName (logged: ${user != null})');

  // [SYNC] expose la synchro pour l’appeler après scan QR
  Future<void> syncPhoneContactsNow() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        showSnackbar('Non connecté');
        return;
      }
      isLoading.value = true;
      final res = await _contactsSync.syncPhoneContacts(token);
      lastPhoneSync.value = res.updatedAt ?? DateTime.now();
      showSnackbar('Contacts synchronisés (${res.saved})');
    } catch (e) {
      showSnackbar('Échec de la synchronisation');
    } finally {
      isLoading.value = false;
    }
  }
}
