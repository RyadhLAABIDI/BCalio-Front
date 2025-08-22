import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bcalio/routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cloudinary/cloudinary.dart';
import 'package:image/image.dart';
import 'package:pdfx/pdfx.dart';

import '../models/true_message_model.dart';
import '../utils/misc.dart';

class MessageApiService {
  final cloudinary = Cloudinary.unsignedConfig(
    cloudName: cloudName,
  );

  /// Fetch Messages by Conversation
  Future<List<Message>> getMessages(String token, String conversationId) async {
    if (token.isEmpty || conversationId.isEmpty) {
      Get.toNamed(Routes.login);
      throw ArgumentError('Token and conversation ID cannot be empty');
    }

    final url =
        Uri.parse('$baseUrl/mobile/conversations/$conversationId/messages');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> messagesJson = json.decode(response.body);
        return messagesJson.map((json) => Message.fromJson(json)).toList();
      } else {
        debugPrint('Error: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to fetch messages: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      rethrow;
    }
  }

  /// Send Message
  Future<Message> sendMessage({
    required String token,
    required String conversationId,
    String? body,
    String? image,
    String? audio,
    String? video,
  }) async {
    debugPrint('sendMsg=============================== $token=====: $video');
    if (token.isEmpty || conversationId.isEmpty) {
      Get.toNamed(Routes.login);
      throw ArgumentError('Token and conversation ID cannot be empty');
    }

    final url = Uri.parse('$baseUrl/mobile/messages');
    final Map<String, dynamic> bodyPayload = {
      'conversationId': conversationId,
    };
    debugPrint('bodyPayload====================================: $bodyPayload');

    if (body != null && body.isNotEmpty) {
      bodyPayload['message'] = body;
    }
    if (image != null && image.isNotEmpty) {
      bodyPayload['image'] = image;
    }
    if (audio != null && audio.isNotEmpty) {
      bodyPayload['audio'] = audio;
    }
    if (video != null && video.isNotEmpty) {
      debugPrint('video send api ============$video');
      // ✅ FIX: envoyer la vidéo dans le champ "video" (et non "audio")
      bodyPayload['video'] = video;
    }

    try {
      debugPrint('json.encode(bodyPayload)========${json.encode(bodyPayload)}');
      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(bodyPayload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Message.fromJson(json.decode(response.body));
      } else {
        debugPrint('Error: ${response.statusCode}, ${response.body}');
        throw Exception('Failed to send message: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Future<String> uploadFileToCloudinary(File file, bool isAudio) async {
    debugPrint('isAudio====================$isAudio');
    try {
      final String extension = file.path.split('.').last.toLowerCase();
      final List<String> imageUrls = []; // On stocke les URLs uploadées

      if (extension == 'pdf') {
        // Ouvrir le document PDF
        final pdf = await PdfDocument.openFile(file.path);

        // Parcourir toutes les pages du PDF
        for (int i = 1; i <= pdf.pagesCount; i++) {
          final page = await pdf.getPage(i);

          // Rendre la page en tant qu'image
          final image = await page.render(
            width: page.width,
            height: page.height,
            format: PdfPageImageFormat.png, // Format de l'image
          );

          if (image != null) {
            // Accéder aux données de l'image
            final Uint8List pngBytes = image.bytes;

            // Sauvegarder l'image dans un fichier temporaire
            final tempFile =
                File('${Directory.systemTemp.path}/temp_page_$i.png');
            await tempFile.writeAsBytes(pngBytes);

            debugPrint('Image saved to: ${tempFile.path}');

            // Uploader l'image vers Cloudinary
            final response = await cloudinary.unsignedUpload(
              file: tempFile.path,
              uploadPreset: uploadPreset,
              resourceType: CloudinaryResourceType.image,
              progressCallback: (count, total) {
                debugPrint('Uploading file: $count/$total bytes');
              },
            );

            if (response.isSuccessful) {
              debugPrint('Upload image successful: ${response.secureUrl}');
              imageUrls.add(response.secureUrl!);
            } else {
              throw Exception(
                'Failed to upload file: ${response.error?.toString()}',
              );
            }
          } else {
            throw Exception('Failed to render PDF page to image');
          }

          // Fermer la page
          await page.close();
        }

        // Fermer le document PDF
        await pdf.close();
      } else if (['m4a', 'mp3', 'mp4'].contains(extension) && isAudio) {
        // Uploader un fichier audio
        debugPrint('Uploading audio file+++++++++++++++++++++++++++++++++++++++++++');
        final response = await cloudinary.unsignedUpload(
          file: file.path,
          uploadPreset: uploadPreset,
          resourceType: CloudinaryResourceType.raw,
          folder: "audio",
          progressCallback: (count, total) {
            debugPrint('Uploading file: $count/$total bytes');
          },
        );

        if (response.isSuccessful) {
          debugPrint('Upload successful: ${response.secureUrl}');
          imageUrls.add(response.secureUrl!);
        } else {
          throw Exception(
            'Failed to upload file: ${response.error?.toString()}',
          );
        }
      } else if (['mp4', 'mov', 'avi', 'mkv'].contains(extension) && !isAudio) {
        // Uploader un fichier vidéo
        final response = await cloudinary.unsignedUpload(
          file: file.path,
          uploadPreset: uploadPreset,
          resourceType: CloudinaryResourceType.video,
          progressCallback: (count, total) {
            debugPrint('Uploading file: $count/$total bytes');
          },
        );

        if (response.isSuccessful) {
          debugPrint('Upload successful: ${response.secureUrl}');
          imageUrls.add(response.secureUrl!);
        } else {
          throw Exception(
            'Failed to upload file: ${response.error?.toString()}',
          );
        }
      } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp']
          .contains(extension)) {
        // Uploader une image
        final response = await cloudinary.unsignedUpload(
          file: file.path,
          uploadPreset: uploadPreset,
          resourceType: CloudinaryResourceType.image,
          progressCallback: (count, total) {
            debugPrint('Uploading file: $count/$total bytes');
          },
        );

        if (response.isSuccessful) {
          debugPrint('Upload successful: ${response.secureUrl}');
          imageUrls.add(response.secureUrl!);
        } else {
          throw Exception(
            'Failed to upload file: ${response.error?.toString()}',
          );
        }
      }

      // Retourner les URLs séparées par un espace
      return imageUrls.join(' ');
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      throw Exception('Cloudinary upload error: $e');
    }
  }

  Future<bool> deleteMessage(
    String conversationId,
    String messageId,
    String token,
  ) async {
    final url = Uri.parse('$baseUrl/mobile/messages');
    try {
      debugPrint('deleteMessage=================mes ===$messageId');
      debugPrint('deleteMessage====================$conversationId');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'conversationId': conversationId,
          'messageId': messageId,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Message deleted successfully');
        return true;
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
