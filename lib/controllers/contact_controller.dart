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
  RxBool isPermissionGranted = false.obs;
  RxBool isLoading = false.obs;
  RxBool isLoadingContacts = true.obs;
  RxString selectedCountryCode = ''.obs;
  ContactController({required this.contactApiService});

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
    final token = await userController.getToken();
    if (token != null && token.isNotEmpty) {
      await loadCachedContacts();
      await fetchContacts(token);
    }
  }

  Future<void> fetchContactsFromApiPhone() async {
    debugPrint('Fetching contacts...');

    final token = await userController.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar("Erreur", "Échec de la récupération du token. Veuillez vous reconnecter.");
      return;
    }

    try {
      isLoading.value = true;
      await loadCachedContacts();
      final cachedContacts = List<Contact>.from(contacts);
      debugPrint('Loading cached contacts: ${cachedContacts.length}');

      // Fetch API contacts
      debugPrint('Fetching API contacts...');
      await fetchContacts(token);
      await fetchAllContacts(token);

      // Fetch phone contacts
      debugPrint('Fetching phone contacts...');
      final phoneContacts = await fetchPhoneContacts();
      originalPhoneContacts.assignAll(phoneContacts);

      // Check if contacts have changed
      if (areContactsDifferent(cachedContacts, [
        ...originalApiContacts,
        ...phoneContacts,
        ...originalAllApiContacts,
      ])) {
        // Normalize all API contacts
        final apiContactMap = <String, Contact>{};
        for (final apiContact in originalAllApiContacts) {
          try {
            final normalized = await extractPhoneDetails(apiContact.phoneNumber);
            if (normalized != null) {
              apiContactMap[normalized] = apiContact;
              debugPrint('API contact normalized: $normalized, ID: ${apiContact.id}');
            }
          } catch (e) {
            debugPrint('Erreur normalisation contact API ${apiContact.phoneNumber}: $e');
          }
        }

        // Process phone contacts
        final updatedPhoneContacts = <Contact>[];
        for (final phoneContact in originalPhoneContacts) {
          final phoneNumber = phoneContact.phoneNumber;
          if (phoneNumber == null || phoneNumber.isEmpty) {
            debugPrint('Skipping empty phone number');
            continue;
          }

          debugPrint('Processing phone contact: $phoneNumber');
          final phoneNormalized = await extractPhoneDetails(phoneNumber);
          if (phoneNormalized == null) {
            debugPrint('Format numéro invalide: $phoneNumber');
            updatedPhoneContacts.add(phoneContact.copyWith(isPhoneContact: true));
            continue;
          }

          final matchingApiContact = apiContactMap[phoneNormalized];
          if (matchingApiContact != null) {
            debugPrint('Match trouvé pour $phoneNormalized, utilisation contactId: ${matchingApiContact.id}');
            updatedPhoneContacts.add(matchingApiContact);
          } else {
            updatedPhoneContacts.add(phoneContact.copyWith(
              isPhoneContact: true,
              id: '',
            ));
            debugPrint('Aucun match pour $phoneNormalized, marqué comme contact téléphone');
          }
        }

        // Combine API and phone contacts
        contacts.assignAll([
          ...originalApiContacts,
          ...updatedPhoneContacts.where(
              (c) => !originalApiContacts.contains(c)),
        ]);

        await saveContactsToCache();
        debugPrint('Contacts chargés: ${contacts.length}');
      } else {
        debugPrint('Contacts identiques. Traitement ignoré.');
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Échec du traitement des contacts: ${e.toString()}');
      debugPrint('Erreur traitement contacts: $e');
    } finally {
      isLoading.value = false;
      isLoadingContacts.value = false;
    }
  }

  Future<String?> extractPhoneDetails(String? phone) async {
    if (phone == null || phone.isEmpty) {
      debugPrint("Numéro de téléphone vide ou null");
      return null;
    }
    debugPrint("Phone number extractPhoneDetails: $phone");
    try {
      String cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      
      if (cleanedPhone.startsWith("+")) {
        final parsed = await PhoneNumberUtil().parse(cleanedPhone);
        debugPrint("Numéro normalisé: ${parsed.nationalNumber}");
        return parsed.nationalNumber;
      } else {
        cleanedPhone = '+216$cleanedPhone';
        final parsed = await PhoneNumberUtil().parse(cleanedPhone);
        debugPrint("Numéro normalisé avec +216: ${parsed.nationalNumber}");
        return parsed.nationalNumber;
      }
    } catch (e) {
      debugPrint('Erreur numéro téléphone: $e');
      return null;
    }
  }

  String removeSubstring(String input) {
    int plusIndex = input.indexOf("+");
    if (plusIndex == -1) {
      return input;
    }
    int spaceIndex = input.indexOf(" ", plusIndex);
    if (spaceIndex == -1) {
      return input.substring(0, plusIndex);
    }
    return input.substring(0, plusIndex) + input.substring(spaceIndex);
  }

  final UserController userController = Get.find<UserController>();
  bool areContactsDifferent(
      List<Contact> oldContacts, List<Contact> newContacts) {
    if (oldContacts.length != newContacts.length) {
      return true;
    }
    final oldSet = oldContacts.map((c) => '${c.phoneNumber}-${c.name}').toSet();
    final newSet = newContacts.map((c) => '${c.phoneNumber}-${c.name}').toSet();
    return !oldSet.containsAll(newSet) || !newSet.containsAll(oldSet);
  }

  Future<void> loadCachedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedContacts = prefs.getString('cachedContacts');
      debugPrint('loadCachedContacts Contacts en cache: $cachedContacts');
      if (cachedContacts != null) {
        debugPrint('Chargement contacts depuis cache...');
        final List<dynamic> jsonList = jsonDecode(cachedContacts);
        final allContactsFromCache =
            jsonList.map((json) => Contact.fromJson(json)).toList();
        contacts.assignAll(allContactsFromCache);
      } else {
        debugPrint('Aucun contact en cache trouvé.');
      }
    } catch (e) {
      debugPrint('Erreur chargement contacts en cache: $e');
    }
  }

  Future<void> saveContactsToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final allContact = contacts;
    final jsonList = allContact.map((contact) => contact.toJson()).toList();
    prefs.setString('cachedContacts', jsonEncode(jsonList));
    debugPrint('Tous les contacts sauvegardés en cache: ${allContact.length}');
  }

  Future<void> requestContactsPermission() async {
    isLoading.value = true;
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      isPermissionGranted.value = true;
      await _saveContactPermissionPreference(true);
    } else {
      isPermissionGranted.value = false;
      await _saveContactPermissionPreference(false);
    }
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
    isPermissionGranted.value =
        prefs.getBool('isContactsPermissionGranted') ?? false;
  }

  Future<void> fetchContacts(String token) async {
    isLoading.value = true;
    try {
      if (token.isEmpty) {
        debugPrint('Token vide');
        return;
      }
      final fetchedContacts = await contactApiService.getContacts(token);
      originalApiContacts.assignAll(fetchedContacts);
    } catch (e) {
      Get.snackbar('Erreur', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchAllContacts(String token) async {
    isLoading.value = true;
    try {
      final fetchedContacts = await contactApiService.getAllContacts(token);
      debugPrint('Tous les contacts récupérés: ${fetchedContacts.map((c) => {"id": c.id, "phoneNumber": c.phoneNumber, "name": c.name})}');
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
      final mappedContacts = phoneContacts.map((phoneContact) {
        return Contact(
          id: '',
          name: phoneContact.displayName != null && phoneContact.displayName!.isNotEmpty
              ? phoneContact.displayName!
              : phoneContact.phones.isNotEmpty
                  ? phoneContact.phones.first.number
                  : '',
          email: '',
          image: phoneContact.photo != null && phoneContact.photo!.isNotEmpty
              ? 'data:image/jpeg;base64,${base64Encode(phoneContact.photo!)}'
              : null,
          phoneNumber: phoneContact.phones.isNotEmpty ? phoneContact.phones.first.number : '',
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

  Future<void> addContact(String token, String contactId, String name,
      String phone, String? email) async {
    try {
      final existingContact = contacts.firstWhere(
        (contact) => contact.id == contactId,
        orElse: () => Contact(
          id: '',
          name: '',
          email: '',
          image: null,
          phoneNumber: null,
        ),
      );

      if (existingContact.id.isNotEmpty) {
        showSuccessSnackbar("Contact déjà ajouté");
        return;
      }

      final newContact = await contactApiService.addContact(token, contactId);
      originalApiContacts.add(newContact);
      contacts.add(newContact);
      await saveContactsToCache();
      showSuccessSnackbar("Contact ajouté avec succès !");
      
      // CORRECTION 1: Toujours ajouter au carnet de contacts
      await addContactToPhone(name, phone, email); // <-- Ajout crucial
    } catch (e) {
      debugPrint('Erreur ajout contact: $e');
      if (e.toString().contains('Contact already added')) {
        showSuccessSnackbar("Contact déjà ajouté");
      } else {
        Get.snackbar('Erreur', e.toString());
      }
    }
  }

  Future<void> addContactToPhone(
    String name, String phone, String? email) async {
  try {
    final status = await Permission.contacts.status;
    if (!status.isGranted) {
      final request = await Permission.contacts.request();
      if (!request.isGranted) throw Exception("Permission refusée");
    }

    // CORRECTION: Use correct Name constructor for flutter_contacts
    final contact = phone_contacts.Contact()
      ..name = phone_contacts.Name(first: name) // Use 'first' instead of 'display'
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

    await contact.insert(); // Insertion correcte
    debugPrint('Contact ajouté au téléphone: name=$name, phone=$phone');
  } catch (e) {
    debugPrint('Échec ajout contact au téléphone: $e');
    throw Exception("Échec ajout contact au téléphone: $e");
  }
}}