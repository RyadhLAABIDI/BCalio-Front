import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:bcalio/models/filter_option.dart';
import 'package:bcalio/utils/color_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

typedef ImageFilter = img.Image Function(img.Image);
// Filter implementations
img.Image applySepia(img.Image image) {
  return img.sepia(image);
}

img.Image applyGrayscale(img.Image image) {
  return img.grayscale(image);
}

img.Image applyInvert(img.Image image) {
  return img.invert(image);
}

img.Image applyCool(img.Image image) {
  return img.colorOffset(image, blue: 50, green: 20);
}

img.Image applyWarm(img.Image image) {
  return img.colorOffset(image, red: 50, green: 20);
}

// img.Image applyVintage(img.Image image) {
//   return img.sepia(image)
//     ..colorOffset(red: 10, green: -10, blue: -20);
// }

img.Image applyColorOverlay(img.Image image, Color color) {
  final overlay = img.Image.from(image);
  return img.compositeImage(
    image,
    overlay,
    blend: img.BlendMode.overlay,
  );
}

class FilterController extends GetxController {
  // Observables
  Rx<File?> imageFile = Rx<File?>(null);
  Rx<Uint8List?> filteredImage = Rx<Uint8List?>(null);
  Rx<FilterOption?> selectedFilter = Rx<FilterOption?>(null);
  Rx<Color> customColor = Rx<Color>(Colors.blue);

  // Available filters
  final List<FilterOption> filters = [
    FilterOption(name: "Original", filter: null),
    FilterOption(name: "Sepia", filter: applySepia),
    FilterOption(name: "Grayscale", filter: applyGrayscale),
    FilterOption(name: "Invert", filter: applyInvert),
    FilterOption(name: "Cool", filter: applyCool),
    FilterOption(name: "Warm", filter: applyWarm),
    // FilterOption(name: "Vintage", filter: applyVintage),
    FilterOption(name: "Custom", filter: null),
  ];

  // Pick image from gallery/camera
  Future<void> pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      imageFile.value = File(pickedFile.path);
      selectedFilter.value = filters[0]; // Default to original
      applyFilter(filters[0]);
    }
  }

  // Apply selected filter
  void applyFilter(FilterOption filterOption) {
    if (imageFile.value == null) return;

    selectedFilter.value = filterOption;

    if (filterOption.name == "Custom") {
      Get.bottomSheet(
        ColorPickerBottomSheet(),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
      );
      return;
    }

    imageFile.value!.readAsBytes().then((bytes) {
      if (filterOption.filter == null) {
        filteredImage.value = bytes; // Original image
        return;
      }

      final image = img.decodeImage(bytes)!;
      final filtered = filterOption.filter!(image);
      filteredImage.value = img.encodePng(filtered);
    });
  }

  // Apply custom color filter
  void applyCustomFilter(Color color) {
    if (imageFile.value == null) return;

    imageFile.value!.readAsBytes().then((bytes) {
      final image = img.decodeImage(bytes)!;
      final filtered = applyColorOverlay(image, color);
      filteredImage.value = img.encodePng(filtered);
      customColor.value = color;
    });
  }
}
// Filter functions (same as previous examples)
// img.Image applySepia(img.Image image) { /* ... */ }
// img.Image applyGrayscale(img.Image image) { /* ... */ }
// ... other filter functions ...
