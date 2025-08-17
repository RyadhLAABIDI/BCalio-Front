import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushRegistrar {
  PushRegistrar._();

  static Future<String?> _getLocalToken() async {
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) return t;
    } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString('fcmToken');
    } catch (_) {}
    return null;
  }

  static Future<void> registerTokenOnBackend({
    required String baseUrl,
    required String userId,
  }) async {
    try {
      final token = await _getLocalToken();
      if (token == null || userId.isEmpty) return;

      final dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 5)));
      await dio.post('/push/register', data: {
        'userId': userId,
        'token' : token,
      });

      // persist par sécurité
      final p = await SharedPreferences.getInstance();
      await p.setString('fcmToken', token);

      if (kDebugMode) {
        debugPrint('[PushRegistrar] token enregistré pour $userId');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PushRegistrar] register error: $e');
    }
  }

  static StreamSubscription<String>? _refSub;

  static void listenTokenRefresh({
    required String baseUrl,
    required String Function() userIdProvider,
  }) {
    _refSub?.cancel();
    _refSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        final uid = userIdProvider();
        if (uid.isEmpty) return;

        final dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 5)));
        await dio.post('/push/register', data: {
          'userId': uid,
          'token' : newToken,
        });

        final p = await SharedPreferences.getInstance();
        await p.setString('fcmToken', newToken);

        if (kDebugMode) {
          debugPrint('[PushRegistrar] token refresh enregistré pour $uid');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[PushRegistrar] refresh error: $e');
      }
    });
  }
}
