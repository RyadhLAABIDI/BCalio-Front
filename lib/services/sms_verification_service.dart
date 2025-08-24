import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class SmsVerificationService {
  static const String _baseUrl =
      'https://mpr282.api.infobip.com/sms/2/text/advanced';

  static const String _apiKey =
      '7c1f7bb583f9ea17665ce2fe7f65bfbf-09ecbc38-898b-4f05-a358-653c6ce358a2'; 
  // ⚠️ Remplace par ta propre clé API

  static const String _sender = '+44 7491 163443'; 
  // ⚠️ Remplace par ton Sender ID enregistré

  /// ✅ Formatte le numéro de téléphone en ajoutant +216 s’il ne l’a pas déjà.
  String formatPhoneNumber(String phoneNumber) {
    if (!phoneNumber.startsWith('+216')) {
      // Supprimer les zéros initiaux
      phoneNumber = phoneNumber.replaceAll(RegExp(r'^0+'), '');
      // Supprimer tout caractère non numérique
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      // Ajouter le préfixe +216
      return '$phoneNumber';
    }
    return phoneNumber;
  }

  /// ✅ Envoie un message personnalisé à un numéro donné.
  Future<bool> sendMessage(String phoneNumber, String message) async {
    try {
      // Formater le numéro avant l’envoi
      final formattedPhoneNumber = formatPhoneNumber(phoneNumber);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'App $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "messages": [
            {
              "channel": "SMS",
              "sender": _sender,
              "destinations": [
                {"to": formattedPhoneNumber}
              ],
              "content": {
                "body": {
                  "text": message,
                  "type": "TEXT",
                }
              }
            }
          ]
        }),
      );

      print("📩 Response send sms : ${response.body}");

      if (response.statusCode == 200) {
        print('✅ Message envoyé avec succès à $formattedPhoneNumber');
        return true;
      } else {
        print('❌ Échec de l’envoi : ${response.body}');
        return false;
      }
    } catch (e) {
      print('⚠️ Erreur lors de l’envoi : $e');
      return false;
    }
  }

  /// ✅ Envoie un OTP à un numéro donné.
  Future<bool> sendOTP(String phoneNumber, String otp) async {
    final message = "Your OTP is $otp. It is valid for 10 minutes.";
    return sendMessage(phoneNumber, message);
  }

  /// ✅ Génère un OTP aléatoire à 6 chiffres.
  String generateOTP() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString();
  }
}
