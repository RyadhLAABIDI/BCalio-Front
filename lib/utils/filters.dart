// import 'package:image/image.dart' as img;
// import 'package:google_ml_kit/google_ml_kit.dart';

// extension FaceFilter on img.Image {
//   static img.Image applyDogNose(
//     img.Image image,
//     Face face,
//     img.Image noseAsset,
//   ) {
//     final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
//     if (nose != null) {
//       final noseWidth = (face.boundingBox.width * 0.3).toInt();
//       final resizedNose = img.copyResize(noseAsset, width: noseWidth);

//       return img.compositeImage(
//         image,
//         resizedNose,
//         dstX: nose.x.toInt() - noseWidth ~/ 2,
//         dstY: nose.y.toInt(),
//         blend: img.BlendMode.overlay,
//       );
//     }
//     return image;
//   }

//   static img.Image applyGlasses(
//     img.Image image,
//     Face face,
//     img.Image glassesAsset,
//   ) {
//     final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
//     final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

//     if (leftEye != null && rightEye != null) {
//       final glassesWidth = (face.boundingBox.width * 0.8).toInt();
//       final resizedGlasses = img.copyResize(glassesAsset, width: glassesWidth);

//       return img.compositeImage(
//         image,
//         resizedGlasses,
//         dstX: leftEye.x.toInt() - glassesWidth ~/ 4,
//         dstY: leftEye.y.toInt() - glassesWidth ~/ 6,
//         blend: img.BlendMode.overlay,
//       );
//     }
//     return image;
//   }
// }
