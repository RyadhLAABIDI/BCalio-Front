// lib/controllers/location_controller.dart
import 'package:bcalio/controllers/contact_controller.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/services/location_service.dart';
import 'package:bcalio/utils/shared_preferens_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';

class LocationController extends GetxController {
  final LocationService _locationService = LocationService();
  var isPermissionGranted = false.obs;
  var currentPosition = Rxn<Position>();

  String _normEmail(String? e) => (e ?? '').trim().toLowerCase();

  /// fallback “8 derniers chiffres” si la normalisation E.164/nationale échoue
  String _last8(String? p) {
    if (p == null) return '';
    final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 8) return digits;
    return digits.substring(digits.length - 8);
  }

  Future<List<Map<String, dynamic>>> getContactsLocations() async {
    debugPrint('MAP2: show ONLY users who are in my PHONE CONTACTS + registered');

    final List<Map<String, dynamic>> out = [];
    try {
      final userController = Get.find<UserController>();
      final myUid = userController.userId;
      final token = await userController.getToken() ?? '';
      if (token.isEmpty) {
        debugPrint('MAP2: ❌ token vide → impossible de lister les users');
        return out;
      }

      // 1) Récupérer/mettre à jour la liste fusionnée des contacts (API + Phone)
      if (!Get.isRegistered<ContactController>()) {
        debugPrint('MAP2: ❌ ContactController non enregistré');
        return out;
      }
      final cc = Get.find<ContactController>();

      // Assure la fusion (API + phone) avant d’utiliser cc.contacts
      // (idempotent, et gère les permissions contacts)
      await cc.fetchContactsFromApiPhone();

      // 2) Construire les ensembles autorisés à partir de TES contacts (fusionnés)
      final allowEmails = <String>{};
      final allowPhoneKeys = <String>{}; // nationalNumber OU 8 derniers chiffres

      for (final c in cc.contacts) {
        final em = _normEmail(c.email);
        if (em.isNotEmpty) allowEmails.add(em);

        // essaye d’extraire le nationalNumber avec la même fonction que le controller
        String? national;
        try {
          national = await cc.extractPhoneDetails(c.phoneNumber);
        } catch (_) {}
        if (national != null && national.isNotEmpty) {
          allowPhoneKeys.add(national);
        } else {
          final k = _last8(c.phoneNumber);
          if (k.isNotEmpty) allowPhoneKeys.add(k);
        }
      }

      debugPrint('MAP2: allowEmails=${allowEmails.length} allowPhones=${allowPhoneKeys.length} '
          '(contacts fusionnés = ${cc.contacts.length})');

      if (allowEmails.isEmpty && allowPhoneKeys.isEmpty) {
        debugPrint('MAP2: ❌ aucun email/phone exploitable depuis le carnet');
        return out;
      }

      // 3) Récupérer TOUS les users et filtrer par (email || phone)
      final users = await userController.fetchUsers(token);
      debugPrint('MAP2: users in DB = ${users.length}');

      final matchedUserIds = <String>[];
      for (final u in users) {
        final uid = (u.id ?? '').toString();
        if (uid == myUid) continue;

        final uMail = _normEmail(u.email);

        // normalise le téléphone user de la même manière
        String? uNational;
        try {
          uNational = await cc.extractPhoneDetails(u.phoneNumber);
        } catch (_) {}
        final uKey = (uNational != null && uNational.isNotEmpty)
            ? uNational
            : _last8(u.phoneNumber);

        final emailMatch = uMail.isNotEmpty && allowEmails.contains(uMail);
        final phoneMatch = uKey.isNotEmpty && allowPhoneKeys.contains(uKey);

        if (emailMatch || phoneMatch) {
          matchedUserIds.add(uid);
        }
      }

      debugPrint('MAP2: matchedUserIds=${matchedUserIds.length} → $matchedUserIds');

      if (matchedUserIds.isEmpty) {
        debugPrint('MAP2: ℹ️ personne de la DB ne matche ton carnet');
        return out;
      }

      // 4) Charger leurs fiches pour récupérer les coordonnées
      int noCoords = 0;
      await Future.wait(matchedUserIds.map((uid) async {
        try {
          final full = await userController.getUser(uid);
          if (full == null) return;

          final latStr = (full.geolocalisation ?? '').toString();
          final lngStr = (full.screenshotToken ?? '').toString();
          if (latStr.isEmpty || lngStr.isEmpty) {
            noCoords++;
            debugPrint('MAP2: ⛔ ${full.name} ($uid) sans coords');
            return;
          }

          out.add({
            'id': full.id,
            'name': full.name,
            'latitude': latStr,
            'longitude': lngStr,
            'phone': full.phoneNumber,
            'email': full.email,
            'image': full.image,
          });
          debugPrint('MAP2: ✔ ${full.name} ($uid) lat=$latStr lng=$lngStr');
        } catch (e) {
          debugPrint('MAP2: getUser($uid) error: $e');
        }
      }));

      if (out.isEmpty && noCoords > 0) {
        debugPrint('MAP2: ⚠️ matches trouvés mais sans coordonnées (ils doivent ouvrir l’app pour pousser leur position).');
      }

      return out;
    } catch (e) {
      debugPrint('MAP2: error: $e');
      return out;
    }
  }

  Future<bool> checkAndRequestPermission() async {
    isPermissionGranted.value =
        await _locationService.requestLocationPermission();
    if (isPermissionGranted.value) {
      try {
        currentPosition.value = await _locationService.getCurrentLocation();
        if (currentPosition.value != null) {
          await SharedPreferensHelper.saveLocation(
            currentPosition.value!.latitude,
            currentPosition.value!.longitude,
          );
        }
        return true;
      } catch (e) {
        return false;
      }
    } else {
      return false;
    }
  }
}
