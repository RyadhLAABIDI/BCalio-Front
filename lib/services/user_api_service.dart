import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloudinary/cloudinary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/AuthResponse_model.dart';
import '../models/true_user_model.dart';
import '../utils/misc.dart';

class UserApiService {
  final cloudinary = Cloudinary.unsignedConfig(
    cloudName: cloudName,
  );

  /// Upload Image to Cloudinary
  Future<String?> uploadImageToCloudinary(File image) async {
    try {
      final response = await cloudinary.unsignedUpload(
        file: image.path,
        uploadPreset: uploadPreset,
        resourceType: CloudinaryResourceType.image,
        progressCallback: (count, total) {
          print('Uploading image: $count/$total');
        },
      );

      if (response.isSuccessful) {
        return response.secureUrl;
      } else {
        throw Exception(
            'Failed to upload image: ${response.error?.toString()}');
      }
    } catch (e) {
      throw Exception('Cloudinary upload error: $e');
    }
  }

  /// Register User
  Future<User> register({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    final url = Uri.parse('$baseUrl/register');

    final payload = {
      'email': email,
      'password': password,
      'name': name,
      'phoneNumber': phoneNumber,
    };

    debugPrint('Register payload: $payload'); // Debug payload

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    debugPrint(
        'Register response status: ${response.statusCode}'); // Debug response status
    debugPrint(
        'Register response body: ${response.body}'); // Debug response body

    if (response.statusCode == 200) {
      final user = User.fromJson(json.decode(response.body));
      debugPrint('Parsed User: $user'); // Debug parsed user
      return user;
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  /// Login User
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  /// Update Profile
  Future<User> updateProfile({
    required String name,
    required String image,
    required String about,
    required String geolocalisation,
    required String screenshotToken,
    required String rfcToken,
  }) async {
    final url = Uri.parse('$baseUrl/user/update');

    // Retrieve token from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('Authorization token is missing');
    }

    final payload = {
      'name': name,
      'image': image,
      'about': about,
      "geolocalisation": geolocalisation,
      "screenshotToken": screenshotToken,
      "rfcToken": rfcToken
    };

    debugPrint('Update payload: $payload'); // Debug payload

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    );

    debugPrint('Update response status: ${response.statusCode}');
    debugPrint('Update response body: ${response.body}');

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update profile: ${response.body}');
    }
  }

  /// Fetch Users
  Future<List<User>> fetchUsers(String token) async {
    final url = Uri.parse('$baseUrl/mobile/users');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    debugPrint('Fetch Users Response Status: ${response.statusCode}');
    debugPrint('Fetch Users Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> usersJson = json.decode(response.body);
      return usersJson.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch users: ${response.body}');
    }
  }

  Future<User?> getUser(String id) async {
    try {
      final url = Uri.parse('$baseUrl/getuserbyid?id=$id');
      final response = await http.get(url);

      debugPrint('Fetch Users Response Status: ${response.statusCode}');
      debugPrint('Fetch Users Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final userJson = json.decode(response.body);
        debugPrint('User JSON: $userJson');

        final user = User.fromJson(userJson); // ✅ التعديل هنا
        debugPrint('Parsed User: $user');
        return user;
      } else {
        throw Exception('Failed to fetch users: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
      return null;
    }
  }
}
