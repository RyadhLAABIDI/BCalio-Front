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

  Future<List<Map<String, dynamic>>> getContactsLocations() async {
    debugPrint("Fetching contacts locations...");
    try {
      final token = await Get.find<UserController>().getToken();
      final contactController = Get.find<ContactController>();
      final userController = Get.find<UserController>();

      List<Map<String, dynamic>> locations = [];

      if (token != null && token.isNotEmpty) {
        final contacts =
            await contactController.contactApiService.getContacts(token);
        debugPrint("Fetched contacts: $contacts-------------------------");

        for (final contact in contacts) {
          final user = await userController.getUser(contact.id);
          debugPrint("Fetched user: ${contact.id}-------------------------");

          if (user != null &&
              user.geolocalisation != null &&
              user.screenshotToken != null) {
            locations.add({
              'id'       : user.id,                 // ← IMPORTANT pour lancer l’appel
              'name'     : user.name,
              'latitude' : user.geolocalisation,
              'longitude': user.screenshotToken,
              'phone'    : user.phoneNumber,
              'email'    : user.email,
              'image'    : user.image,
            });
            debugPrint(
                "Contact Location - Name: ${user.name}, Lat: ${user.geolocalisation}, Long: ${user.screenshotToken}");
          }
        }
      }
      debugPrint("Fetched contacts locations: $locations");
      return locations;
    } catch (e) {
      debugPrint("Error fetching contacts locations: $e");
      return [];
    }
  }

  Future<bool> checkAndRequestPermission() async {
    isPermissionGranted.value =
        await _locationService.requestLocationPermission();
    if (isPermissionGranted.value) {
      try {
        currentPosition.value = await _locationService.getCurrentLocation();
        if (currentPosition.value != null) {
          // Save the location to shared preferences or any other storage
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
