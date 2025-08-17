import 'dart:io';
import 'dart:typed_data';
import 'package:bcalio/controllers/filter_controller.dart';
import 'package:bcalio/models/filter_option.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';

class FilterScreen extends StatelessWidget {
  final FilterController controller = Get.put(FilterController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Image Filters'),
        actions: [
          Obx(() => controller.imageFile.value != null
              ? IconButton(
                  icon: const Icon(Icons.save_alt),
                  onPressed: _saveFilteredImage,
                  tooltip: 'Save filtered image',
                )
              : const SizedBox()),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.filteredImage.value != null) {
                return PhotoView(
                  imageProvider: MemoryImage(controller.filteredImage.value!),
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.transparent),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2.0,
                );
              }
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No image selected',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }),
          ),
          Obx(() {
            if (controller.imageFile.value == null) return const SizedBox();
            return _buildFilterThumbnails();
          }),
          _buildImageSourceButtons(),
        ],
      ),
    );
  }

  Widget _buildFilterThumbnails() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.filters.length,
        itemBuilder: (context, index) {
          final filter = controller.filters[index];
          return Obx(() => _buildFilterThumbnail(filter));
        },
      ),
    );
  }

  Widget _buildFilterThumbnail(FilterOption filter) {
    final isSelected = controller.selectedFilter.value == filter;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          InkWell(
            onTap: () => controller.applyFilter(filter),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FutureBuilder<Uint8List?>(
                  future:
                      _getFilterPreview(controller.imageFile.value!, filter),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            filter.name,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSourceButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
            onPressed: () => controller.pickImage(ImageSource.gallery),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
            onPressed: () => controller.pickImage(ImageSource.camera),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _getFilterPreview(File file, FilterOption filter) async {
    try {
      final bytes = await file.readAsBytes();
      if (filter.filter == null) return bytes;

      final image = img.decodeImage(bytes)!;
      final filtered = filter.filter!(image);
      return img.encodePng(filtered);
    } catch (e) {
      debugPrint('Error generating filter preview: $e');
      return null;
    }
  }

  Future<void> _saveFilteredImage() async {
    if (controller.filteredImage.value == null) return;

    // Create temporary file
    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/filtered_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(controller.filteredImage.value!);
    await GallerySaver.saveImage(file.path);
    debugPrint('Filtered image saved to: ${file.path}');
    Get.snackbar(
      'Success',
      'Image saved to gallery',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }
}
