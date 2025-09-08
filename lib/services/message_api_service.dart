import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bcalio/routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cloudinary/cloudinary.dart';
import 'package:pdfx/pdfx.dart';

import '../models/true_message_model.dart';
import '../utils/misc.dart';
import 'http_errors.dart';

class MessageApiService {
  final cloudinary = Cloudinary.unsignedConfig(
    cloudName: cloudName, // défini dans utils/misc.dart
  );

  Future<List<Message>> getMessages(String token, String conversationId) async {
    if (token.isEmpty || conversationId.isEmpty) {
      Get.toNamed(Routes.login);
      throw ArgumentError('Token and conversation ID cannot be empty');
    }

    final url = Uri.parse('$baseUrl/mobile/conversations/$conversationId/messages');
    try {
      final response = await http
          .get(url, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> messagesJson = json.decode(response.body);
        return messagesJson.map((json) => Message.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw UnauthorizedException(response.body);
      } else {
        debugPrint('Error: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to fetch messages: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      rethrow;
    }
  }

  /// Envoi message (texte / image / audio / vidéo)
  Future<Message> sendMessage({
    required String token,
    required String conversationId,
    String? body,
    String? image,
    String? audio,
    String? video,
  }) async {
    if (token.isEmpty || conversationId.isEmpty) {
      Get.toNamed(Routes.login);
      throw ArgumentError('Token and conversation ID cannot be empty');
    }

    final url = Uri.parse('$baseUrl/mobile/messages');
    final Map<String, dynamic> payload = {'conversationId': conversationId};

    if (body != null && body.isNotEmpty) payload['message'] = body; // backend attend "message"
    if (image != null && image.isNotEmpty) payload['image'] = image;
    if (audio != null && audio.isNotEmpty) payload['audio'] = audio;
    if (video != null && video.isNotEmpty) payload['video'] = video;

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Message.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw UnauthorizedException(response.body);
      } else {
        debugPrint('Error: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Upload (images / audio / vidéo / PDF→images)
  /// Retourne des URLs séparées par un espace si plusieurs images (PDF->pages).
  Future<String> uploadFileToCloudinary(File file, bool isAudio) async {
    try {
      final String extension = file.path.split('.').last.toLowerCase();
      final List<String> urls = [];

      if (extension == 'pdf') {
        final pdf = await PdfDocument.openFile(file.path);
        for (int i = 1; i <= pdf.pagesCount; i++) {
          final page = await pdf.getPage(i);
          final rendered = await page.render(
            width: page.width,
            height: page.height,
            format: PdfPageImageFormat.png,
          );
          if (rendered == null) throw Exception('Failed to render PDF page');

          final tmp = File('${Directory.systemTemp.path}/temp_page_$i.png');
          await tmp.writeAsBytes(Uint8List.fromList(rendered.bytes));

          final response = await cloudinary.unsignedUpload(
            file: tmp.path,
            uploadPreset: uploadPreset,
            resourceType: CloudinaryResourceType.image,
            progressCallback: (s, t) => debugPrint('Uploading image: $s/$t'),
          );
          if (!response.isSuccessful) throw Exception('Failed to upload image: ${response.error}');
          urls.add(response.secureUrl!);
          await page.close();
        }
        await pdf.close();
      } else if (['m4a', 'mp3', 'mp4'].contains(extension) && isAudio) {
        final response = await cloudinary.unsignedUpload(
          file: file.path,
          uploadPreset: uploadPreset,
          resourceType: CloudinaryResourceType.raw,
          folder: 'audio',
          progressCallback: (s, t) => debugPrint('Uploading audio: $s/$t'),
        );
        if (!response.isSuccessful) throw Exception('Audio upload failed: ${response.error}');
        urls.add(response.secureUrl!);
      } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension) && !isAudio) {
        final response = await cloudinary.unsignedUpload(
          file: file.path,
          uploadPreset: uploadPreset,
          resourceType: CloudinaryResourceType.video,
          progressCallback: (s, t) => debugPrint('Uploading video: $s/$t'),
        );
        if (!response.isSuccessful) throw Exception('Video upload failed: ${response.error}');
        urls.add(response.secureUrl!);
      } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
        final response = await cloudinary.unsignedUpload(
          file: file.path,
          uploadPreset: uploadPreset,
          resourceType: CloudinaryResourceType.image,
          progressCallback: (s, t) => debugPrint('Uploading image: $s/$t'),
        );
        if (!response.isSuccessful) throw Exception('Image upload failed: ${response.error}');
        urls.add(response.secureUrl!);
      }

      return urls.join(' ');
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      throw Exception('Cloudinary upload error: $e');
    }
  }

  /// Upload document (PDF/DOCX/...) en RAW → secure_url
  Future<String> uploadDocumentToCloudinary(File file) async {
    try {
      final resp = await cloudinary.unsignedUpload(
        file: file.path,
        uploadPreset: uploadPreset,
        resourceType: CloudinaryResourceType.raw,
        folder: 'docs',
        progressCallback: (s, t) => debugPrint('Uploading RAW: $s/$t'),
      );
      if (resp.isSuccessful) {
        return resp.secureUrl ?? '';
      }
      debugPrint('Cloudinary RAW upload error: ${resp.error}');
      return '';
    } catch (e) {
      debugPrint('Cloudinary RAW upload exception: $e');
      return '';
    }
  }

  Future<bool> deleteMessage(String conversationId, String messageId, String token) async {
    final url = Uri.parse('$baseUrl/mobile/messages');
    try {
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode({'conversationId': conversationId, 'messageId': messageId}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else if (response.statusCode == 401) {
        throw UnauthorizedException(response.body);
      } else {
        debugPrint('Error: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to delete message: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }
}
