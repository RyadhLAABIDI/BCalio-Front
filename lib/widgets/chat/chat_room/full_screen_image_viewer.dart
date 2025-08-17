import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
// import 'package:gallery_saver/gallery_saver.dart';
import 'package:iconsax/iconsax.dart';
import '../../base_widget/custom_snack_bar.dart';

class FullScreenImageViewer extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;

  const FullScreenImageViewer({
    super.key,
    this.imageFile,
    this.imageUrl,
  });

  void _downloadImage(BuildContext context) async {
    try {
      if (imageFile != null) {
        // Save image file
        await GallerySaver.saveImage(imageFile!.path);
      } else if (imageUrl != null) {
        // Save image from URL
        await GallerySaver.saveImage(imageUrl!);
      } else {
        throw Exception("No image available to download.");
      }
      showSuccessSnackbar("Image saved to gallery");
    } catch (e) {
      showErrorSnackbar("Failed to save image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.document_download, color: Colors.white),
            onPressed: () => _downloadImage(context),
          ),
        ],
      ),
      body: Center(
        child: imageFile != null
            ? Image.file(
                imageFile!,
                fit: BoxFit.contain,
              )
            : imageUrl != null
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.contain,
                  )
                : const Text(
                    "No image available",
                    style: TextStyle(color: Colors.white),
                  ),
      ),
    );
  }
}