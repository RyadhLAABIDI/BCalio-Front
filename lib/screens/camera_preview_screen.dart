import 'dart:io';
import 'package:bcalio/filter_data.dart';
import 'package:bcalio/utils/constants.dart';
import 'package:deepar_flutter_plus/deepar_flutter_plus.dart';
import 'package:flutter/material.dart';

class CameraPreviewScreen extends StatefulWidget {
  final void Function(File) onImageCaptured;

  const CameraPreviewScreen({super.key, required this.onImageCaptured});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  final DeepArControllerPlus _controller = DeepArControllerPlus();

  final List<String> effects = [
    "assets/filters/burning_effect.deepar",
    "assets/filters/Fire_Effect.deepar",
    "assets/filters/Stallone.deepar",
  ];

  int currentEffectIndex = 0;
  bool isInitialized = false;
  bool isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    await _controller.initialize(
      androidLicenseKey: androidLicenseKey,
      iosLicenseKey: 'YOUR_IOS_LICENSE_KEY',
    );
    await _controller.switchEffect(effects[currentEffectIndex]);
    setState(() {
      isInitialized = true;
    });
  }

  Widget buildButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: _controller.flipCamera,
            icon: const Icon(
              Icons.flip_camera_ios_outlined,
              size: 34,
              color: Colors.white,
            ),
          ),
          FilledButton(
            onPressed: () async {
              widget.onImageCaptured(await _controller.takeScreenshot());
              Future.delayed(const Duration(milliseconds: 500), () {
                Navigator.pop(context);
              });
            },
            child: const Icon(Icons.camera),
          ),
          IconButton(
            onPressed: _controller.toggleFlash,
            icon: const Icon(Icons.flash_on, size: 34, color: Colors.white),
          ),
        ],
      );

  Widget buildCameraPreview() => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Transform.scale(
          scale: 1.5,
          child: DeepArPreviewPlus(_controller),
        ),
      );

  Widget buildFilters() => SizedBox(
        height: MediaQuery.of(context).size.height * 0.1,
        child: ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          itemBuilder: (context, index) {
            final filter = filters[index];
            final effectFile = File('assets/filters/${filter.filterPath}').path;
            return InkWell(
              onTap: () => _controller.switchEffect(effectFile),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    image: DecorationImage(
                      image: AssetImage('assets/previews/${filter.imagePath}'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

  void nextEffect() {
    setState(() {
      currentEffectIndex = (currentEffectIndex + 1) % effects.length;
    });
    _controller.switchEffect(effects[currentEffectIndex]);
  }

  Future<void> flipCamera() async {
    await _controller.flipCamera();
    setState(() {
      isFrontCamera = !isFrontCamera;
    });
  }

  @override
  void dispose() {
    _controller.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: FutureBuilder(
        future: initializeCamera(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [buildCameraPreview(), buildButtons(), buildFilters()],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
