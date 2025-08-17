// import 'dart:io';

// import 'package:google_ml_kit/google_ml_kit.dart';
// import 'package:image/image.dart' as img;

// Future<void> detectFaceLandmarks() async {
//   final faceDetector = GoogleMlKit.vision.faceDetector(
//     FaceDetectorOptions(
//       enableLandmarks: true,
//       enableClassification: true,
//     ),
//   );

//   // Pour une image venant de la caméra
//   final inputImage = InputImage.fromFilePath('your_image_path.jpg');
//   final List<Face> faces = await faceDetector.processImage(inputImage);

//   if (faces.isNotEmpty) {
//     final Face face = faces.first;

//     // Accéder aux landmarks spécifiques
//     final FaceLandmark? leftEye = face.landmarks[FaceLandmarkType.leftEye];
//     final FaceLandmark? rightEye = face.landmarks[FaceLandmarkType.rightEye];
//     final FaceLandmark? noseBase = face.landmarks[FaceLandmarkType.noseBase];
//     final FaceLandmark? leftCheek = face.landmarks[FaceLandmarkType.leftCheek];
//     final FaceLandmark? rightCheek =
//         face.landmarks[FaceLandmarkType.rightCheek];
//     final FaceLandmark? mouthBottom =
//         face.landmarks[FaceLandmarkType.bottomMouth];

//     if (leftEye != null && rightEye != null) {
//       print('Position oeil gauche: ${leftEye.position}');
//       print('Position oeil droit: ${rightEye.position}');
//     }
//   }

//   await faceDetector.close();
// }

// img.Image applyDogFilter(
//     img.Image background, Face face, img.Image dogNose, img.Image dogEars) {
//   // 1. Vérifier les landmarks
//   final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
//   final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
//   final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

//   if (nose != null && leftEye != null && rightEye != null) {
//     // 2. Redimensionner les éléments si nécessaire
//     final noseWidth = (face.boundingBox.width * 0.3).toInt();
//     dogNose = img.copyResize(dogNose, width: noseWidth);

//     // 3. Positionner et dessiner le nez
//     background = img.compositeImage(
//       background,
//       dogNose,
//       dstX: nose.x.toInt() - dogNose.width ~/ 2,
//       dstY: nose.y.toInt(),
//       blend: img.BlendMode.overlay, // Mode de fusion
//     );

//     // 4. Positionner et dessiner les oreilles
//     final earWidth = (face.boundingBox.width * 0.5).toInt();
//     dogEars = img.copyResize(dogEars, width: earWidth);

//     background = img.compositeImage(
//       background,
//       dogEars,
//       dstX: leftEye.x.toInt() - earWidth ~/ 3,
//       dstY: leftEye.y.toInt() - earWidth ~/ 2,
//       blend: img.BlendMode.overlay,
//     );
//   }

//   return background;
// }
