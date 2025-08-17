import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class SmsVerificationService {
  static const String _baseUrl =
      'https://mpr282.api.infobip.com/messages-api/1/messages';
  static const String _apiKey =
      'f1a67b7be0b2703198f2dc63862d9cf6-dd1a7a76-465e-4cdb-8fc2-194eb6162a28'; // Replace with your API key
  static const String _sender =
      '+44 7491 163443'; // Replace with your registered Sender ID

  /// Formats the phone number by adding +216 if it doesn't already have it.
  String formatPhoneNumber(String phoneNumber) {
    if (!phoneNumber.startsWith('+216')) {
      // Remove any leading zeros or other prefixes
      phoneNumber =
          phoneNumber.replaceAll(RegExp(r'^0+'), ''); // Remove leading zeros
      phoneNumber = phoneNumber.replaceAll(
          RegExp(r'[^0-9]'), ''); // Remove non-numeric characters
      return '+216$phoneNumber'; // Add +216 prefix
    }
    return phoneNumber; // Return the number as is if it already has +216
  }

  /// Sends a custom message to the given phone number.
  Future<bool> sendMessage(String phoneNumber, String message) async {
    try {
      // Format the phone number before sending the message
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
                  "text": message, // Use the custom message here
                  "type": "TEXT"
                }
              }
            }
          ]
        }),
      );
      print("Response send sms : ${response.body}");
      if (response.statusCode == 200) {
        print('Message sent successfully to $formattedPhoneNumber');
        return true;
      } else {
        print('Failed to send message: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  /// Sends an OTP to the given phone number.
  Future<bool> sendOTP(String phoneNumber, String otp) async {
    final message = "Your OTP is $otp. It is valid for 10 minutes.";
    return sendMessage(phoneNumber, message);
  }

  /// Generates a random 6-digit OTP.
  String generateOTP() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString(); // Generate 6-digit OTP
  }
}
