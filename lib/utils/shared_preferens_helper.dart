import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferensHelper {
  static Future<void> saveHasRequestedCameraPermission(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasRequestedCameraPermission', value);
  }

  static Future<bool> getHasRequestedCameraPermission() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasRequestedCameraPermission') ?? false;
  }

  static Future<void> saveHasRequestedStoragePermission(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasRequestedStoragePermission', value);
  }

  /// 📌 Lire la permission de stockage
  static Future<bool> readHasRequestedStoragePermission() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasRequestedStoragePermission') ?? false;
  }

  static Future<void> saveHasRequestedMicrophonePermission(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasRequestedMicrophonePermission', value);
  }

  static Future<bool> getHasRequestedMicrophonePermission() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasRequestedMicrophonePermission') ?? false;
  }

  static Future<void> saveLocation(double latitude, double longitude) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latitude', latitude);
    await prefs.setDouble('longitude', longitude);
  }

  static Future<double?> getLatitude() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('latitude');
  }

  static Future<double?> getLongitude() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('longitude');
  }

  static Future<String?> getName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  static Future<String?> getImage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('image');
  }

  static Future<String?> getAbout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('about');
  }

  static Future<void> saveFcmToken(String fcmToken) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcmToken', fcmToken);
  }

  static Future<String?> getFcmToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcmToken');
  }
}
