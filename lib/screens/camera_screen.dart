// import 'dart:developer';

// import 'package:deepar_flutter_plus/deepar_flutter_plus.dart';
// import 'package:flutter/material.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'DeepAR Plus Example',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const ARView(),
//     );
//   }
// }

// class ARView extends StatefulWidget {
//   const ARView({
//     super.key,
//   });

//   @override
//   State<ARView> createState() => _ARViewState();
// }

// class _ARViewState extends State<ARView> {
//   final DeepArControllerPlus _controller = DeepArControllerPlus();
//   bool isInitialized = false;
//   final String effectURL = '';

//   @override
//   void initState() {
//     _initializeAR();
//     super.initState();
//   }

//   Future<void> _initializeAR() async {
//     try {
//       // Initialize DeepAR
//       await _controller.initialize(
//         androidLicenseKey:
//             "7d61e98129951b5f6fa155c55b4ac7c32113dbf711e2a4877f3857cd4fc95c8d5119c052dc065848",
//         iosLicenseKey: "<YOUR-IOS-LICENSE-KEY>",
//         resolution: Resolution.medium,
//       );

//       _controller.switchEffect(effectURL);
//       Future.delayed(
//         const Duration(seconds: 2),
//         () {
//           setState(() {
//             isInitialized = true;
//           });
//         },
//       );
//     } catch (e, s) {
//       log('Error initializing AR: $e', stackTrace: s);
//     }
//   }

//   @override
//   void dispose() {
//     _controller.destroy();

//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return isInitialized
//         ? Transform.scale(
//             scale: _controller.aspectRatio * 1.3, //change value as needed
//             child: DeepArPreviewPlus(_controller),
//           )
//         : const Center(
//             child: CircularProgressIndicator(),
//           );
//   }
// }
