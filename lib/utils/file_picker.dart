import 'dart:io';
import 'package:image_picker/image_picker.dart';

enum FilePickerSource {
  camera,
  galleryImage,
  galleryVideo,
}

class FilePicker {
  static Future<File?> pickFile(FilePickerSource src) async {
    try {
      final instance = ImagePicker();
      final crossFile = await switch (src) {
        FilePickerSource.camera =>
          instance.pickImage(source: ImageSource.camera),
        FilePickerSource.galleryImage =>
          instance.pickImage(source: ImageSource.gallery),
        FilePickerSource.galleryVideo =>
          instance.pickVideo(source: ImageSource.gallery),
      };
      return crossFile != null ? File(crossFile.path) : null;
    } catch (e) {
      print("Error picking file: $e"); // Log the error
      return null;
    }
  }
}
