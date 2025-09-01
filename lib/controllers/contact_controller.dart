import 'dart:convert';

import 'package:bcalio/controllers/user_controller.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as phone_contacts;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_number/phone_number.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_model.dart';
import '../services/contact_api_service.dart';
import '../widgets/base_widget/custom_snack_bar.dart';

class ContactController extends GetxController {
  final ContactApiService contactApiService;
  ContactController({required this.contactApiService});

  final UserController userController = Get.find<UserController>();

  RxBool isPermissionGranted = false.obs;
  RxBool isLoading = false.obs;
  RxBool isLoadingContacts = true.obs;
  RxString selectedCountryCode = ''.obs;

  RxList<Contact> contacts = <Contact>[].obs;
  RxList<Contact> allContacts = <Contact>[].obs;
  RxList<Contact> originalAllApiContacts = <Contact>[].obs;
  RxList<Contact> originalApiContacts = <Contact>[].obs;
  RxList<Contact> originalPhoneContacts = <Contact>[].obs;
  bool isFirst = true;

  @override
  void onInit() async {
    super.onInit();
    loadContactPermissionPreference();
    checkContactsPermission();
    // on ne bloque pas si pas de token : withAuthRetry s’en charge
    await loadCachedContacts();
    await fetchContacts('');
  }

  /* ─────────────────────────── utils ─────────────────────────── */

  String _normalizePhone(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  bool _existsByPhone(String phone) {
    final p = _normalizePhone(phone);
    if (p.isEmpty) return false;
    return contacts.any((c) => _normalizePhone(c.phoneNumber) == p);
  }

  Future<String?> extractPhoneDetails(String? phone) async {
    if (phone == null || phone.isEmpty) return null;
    try {
      String cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (cleanedPhone.startsWith("+")) {
        final parsed = await PhoneNumberUtil().parse(cleanedPhone);
        return parsed.nationalNumber;
      } else {
        cleanedPhone = '+216$cleanedPhone';
        final parsed = await PhoneNumberUtil().parse(cleanedPhone);
        return parsed.nationalNumber;
      }
    } catch (_) {
      return null;
    }
  }

  bool areContactsDifferent(List<Contact> oldContacts, List<Contact> newContacts) {
    if (oldContacts.length != newContacts.length) return true;
    final oldSet = oldContacts.map((c) => '${c.phoneNumber}-${c.name}').toSet();
    final newSet = newContacts.map((c) => '${c.phoneNumber}-${c.name}').toSet();
    return !oldSet.containsAll(newSet) || !newSet.containsAll(oldSet);
  }

  /* ───────────────── caching ───────────────── */

  Future<void> loadCachedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedContacts = prefs.getString('cachedContacts');
      if (cachedContacts != null) {
        final List<dynamic> jsonList = jsonDecode(cachedContacts);
        final allContactsFromCache = jsonList.map((json) => Contact.fromJson(json)).toList();
        contacts.assignAll(allContactsFromCache);
      }
    } catch (e) {
      debugPrint('Erreur chargement contacts en cache: $e');
    }
  }

  Future<void> saveContactsToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = contacts.map((contact) => contact.toJson()).toList();
    await prefs.setString('cachedContacts', jsonEncode(jsonList));
  }

  /* ───────────── permissions contacts ───────────── */

  Future<void> requestContactsPermission() async {
    isLoading.value = true;
    final status = await Permission.contacts.request();
    isPermissionGranted.value = status.isGranted;
    await _saveContactPermissionPreference(isPermissionGranted.value);
    isLoading.value = false;
  }

  Future<void> checkContactsPermission() async {
    final status = await Permission.contacts.status;
    isPermissionGranted.value = status.isGranted;
    await _saveContactPermissionPreference(isPermissionGranted.value);
  }

  Future<void> _saveContactPermissionPreference(bool isGranted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isContactsPermissionGranted', isGranted);
  }

  Future<void> loadContactPermissionPreference() async {
    final prefs = await SharedPreferences.getInstance();
    isPermissionGranted.value = prefs.getBool('isContactsPermissionGranted') ?? false;
  }

  /* ───────────── fetch API / téléphone ───────────── */

  Future<void> fetchContacts(String _ignored) async {
    isLoading.value = true;
    try {
      final fetchedContacts = await userController.withAuthRetry<List<Contact>>(
        (t) => contactApiService.getContacts(t),
      );
      originalApiContacts.assignAll(fetchedContacts);
    } catch (e) {
      Get.snackbar('Erreur', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchAllContacts(String _ignored) async {
    isLoading.value = true;
    try {
      final fetchedContacts = await userController.withAuthRetry<List<Contact>>(
        (t) => contactApiService.getAllContacts(t),
      );
      originalAllApiContacts.assignAll(fetchedContacts);
      allContacts.assignAll(fetchedContacts);
    } catch (e) {
      Get.snackbar('Erreur', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<Contact>> fetchPhoneContacts() async {
    if (!isPermissionGranted.value) {
      Get.snackbar('Permission requise', 'Permission contacts non accordée');
      return [];
    }
    try {
      final phoneContacts = await phone_contacts.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      final mappedContacts = phoneContacts.map((pc) {
        return Contact(
          id: '',
          name: (pc.displayName != null && pc.displayName!.isNotEmpty)
              ? pc.displayName!
              : (pc.phones.isNotEmpty ? pc.phones.first.number : ''),
          email: '',
          image: (pc.photo != null && pc.photo!.isNotEmpty)
              ? 'data:image/jpeg;base64,${base64Encode(pc.photo!)}'
              : null,
          phoneNumber: pc.phones.isNotEmpty ? pc.phones.first.number : '',
          isPhoneContact: true,
        );
      }).toList();
      originalPhoneContacts.assignAll(mappedContacts);
      return mappedContacts;
    } catch (e) {
      debugPrint("Erreur récupération contacts téléphone: $e");
      return [];
    }
  }

  Future<void> fetchContactsFromApiPhone() async {
    debugPrint('Fetching contacts...');

    try {
      isLoading.value = true;
      await loadCachedContacts();
      final cachedContacts = List<Contact>.from(contacts);

      await fetchContacts('');
      await fetchAllContacts('');

      final phoneContacts = await fetchPhoneContacts();
      originalPhoneContacts.assignAll(phoneContacts);

      if (areContactsDifferent(cachedContacts, [
        ...originalApiContacts,
        ...phoneContacts,
        ...originalAllApiContacts,
      ])) {
        // Map tel → Contact API
        final apiContactMap = <String, Contact>{};
        for (final apiContact in originalAllApiContacts) {
          try {
            final normalized = await extractPhoneDetails(apiContact.phoneNumber);
            if (normalized != null) apiContactMap[normalized] = apiContact;
          } catch (_) {}
        }

        // Projette les contacts téléphone
        final updatedPhoneContacts = <Contact>[];
        for (final phoneContact in originalPhoneContacts) {
          final phoneNumber = phoneContact.phoneNumber;
          if (phoneNumber == null || phoneNumber.isEmpty) continue;
          final phoneNormalized = await extractPhoneDetails(phoneNumber);
          if (phoneNormalized == null) {
            updatedPhoneContacts.add(phoneContact.copyWith(isPhoneContact: true));
            continue;
          }
          final matchingApiContact = apiContactMap[phoneNormalized];
          if (matchingApiContact != null) {
            updatedPhoneContacts.add(matchingApiContact);
          } else {
            updatedPhoneContacts.add(phoneContact.copyWith(isPhoneContact: true, id: ''));
          }
        }

        contacts.assignAll([
          ...originalApiContacts,
          ...updatedPhoneContacts.where((c) => !originalApiContacts.contains(c)),
        ]);

        await saveContactsToCache();
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Échec du traitement des contacts: ${e.toString()}');
    } finally {
      isLoading.value = false;
      isLoadingContacts.value = false;
    }
  }

  /* ───────────── Ajout carnet téléphone ───────────── */

  Future<void> addContactToPhone(String name, String phone, String? email) async {
    try {
      if (phone.trim().isEmpty) {
        debugPrint('addContactToPhone: phone vide — on ignore.');
        return;
      }

      final status = await Permission.contacts.status;
      if (!status.isGranted) {
        final request = await Permission.contacts.request();
        if (!request.isGranted) throw Exception("Permission refusée");
      }

      final contact = phone_contacts.Contact()
        ..name = phone_contacts.Name(first: name)
        ..phones.add(phone_contacts.Phone(
          phone,
          label: phone_contacts.PhoneLabel.mobile,
        ));

      if (email != null && email.isNotEmpty) {
        contact.emails.add(phone_contacts.Email(
          email,
          label: phone_contacts.EmailLabel.work,
        ));
      }

      await contact.insert();
      debugPrint('Contact ajouté au téléphone: name=$name, phone=$phone');
    } catch (e) {
      debugPrint('Échec ajout contact au téléphone: $e');
      // On ne bloque pas l’app si l’écriture carnet échoue.
    }
  }

  /// ➜ Méthode utilisée par le **scan QR** pour faire "comme le manuel"
  ///    (ajout carnet + liste locale), sans POST /mobile/contacts
  Future<void> addPhoneContactFromQr({
    required String name,
    required String phone,
    String? email,
  }) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) {
      Get.snackbar('Erreur', 'Ce contact ne contient pas de numéro.');
      return;
    }

    if (_existsByPhone(normalized)) {
      showSuccessSnackbar('Contact déjà présent');
      return;
    }

    // 1) carnet téléphone
    await addContactToPhone(name.isNotEmpty ? name : phone, phone, email);

    // 2) liste locale (+ cache)
    final local = Contact(
      id: '', // pas d'ID serveur (carnet seulement)
      name: name.isNotEmpty ? name : phone,
      email: email ?? '',
      image: null,
      phoneNumber: phone,
      isPhoneContact: true,
    );
    contacts.add(local);
    await saveContactsToCache();

    showSuccessSnackbar('Contact ajouté au téléphone');
  }

  /* ───────────── (Optionnel) Ajout via API centrale ─────────────
     — utile pour tes autres écrans, pas utilisé par le flow QR —  */

  Future<void> addContact(
    String _ignoredToken,
    String contactId,
    String name,
    String phone,
    String? email,
  ) async {
    try {
      final existingContact = contacts.firstWhere(
        (c) => c.id == contactId,
        orElse: () => Contact(id: '', name: '', email: '', image: null, phoneNumber: null),
      );
      if (existingContact.id.isNotEmpty) {
        showSuccessSnackbar("Contact déjà ajouté");
        return;
      }

      // Appel API centrale via retry auth
      final added = await userController.withAuthRetry<Contact>(
        (t) => contactApiService.addContact(t, contactId),
      );

      // Enrichir avec user details (pour récupérer numéro)
      final details = await userController.withAuthRetry<Contact?>(
        (t) => contactApiService.getUserById(t, contactId),
      );
      final merged = Contact(
        id: added.id.isNotEmpty ? added.id : (details?.id ?? ''),
        name: added.name.isNotEmpty ? added.name : (details?.name ?? ''),
        email: added.email.isNotEmpty ? added.email : (details?.email ?? ''),
        image: added.image ?? details?.image,
        phoneNumber: added.phoneNumber ?? details?.phoneNumber,
        isPhoneContact: added.isPhoneContact || (details?.isPhoneContact == true),
      );

      originalApiContacts.add(merged);
      contacts.add(merged);
      await saveContactsToCache();

      showSuccessSnackbar("Contact ajouté avec succès !");
      // Ajout dans le carnet seulement si un numéro est disponible :
      final phoneToSave = (merged.phoneNumber ?? '').trim();
      if (phoneToSave.isNotEmpty) {
        await addContactToPhone(
          merged.name.isNotEmpty ? merged.name : (name.isNotEmpty ? name : contactId),
          phoneToSave,
          merged.email.isNotEmpty ? merged.email : (email ?? ''),
        );
      }
    } catch (e) {
      debugPrint('Erreur ajout contact: $e');
      if (e.toString().contains('Contact already added')) {
        showSuccessSnackbar("Contact déjà ajouté");
      } else {
        Get.snackbar('Erreur', e.toString());
      }
    }
  }
}
