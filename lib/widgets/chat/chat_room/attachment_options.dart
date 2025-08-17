import 'dart:io';
import 'package:bcalio/filter_data.dart';
import 'package:bcalio/screens/camera_preview_screen.dart';
import 'package:bcalio/services/permission_service.dart';
import 'package:bcalio/utils/constants.dart';
import 'package:deepar_flutter_plus/deepar_flutter_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AttachmentOptions extends StatefulWidget {
  final void Function(File) onAttachImage;
  final void Function(File) onAttachVideo;
  // final void Function(File) onAttachFile;
  final void Function() onStartRecording;

  AttachmentOptions({
    super.key,
    required this.onAttachImage,
    required this.onAttachVideo,
    // required this.onAttachFile,
    required this.onStartRecording,
  });

  @override
  State<AttachmentOptions> createState() => _AttachmentOptionsState();
}

class _AttachmentOptionsState extends State<AttachmentOptions> {
  final DeepArControllerPlus _controller = DeepArControllerPlus();

  bool isCameraInitialized = false;

  final List<String> effects = [
    "assets/filters/burning_effect.deepar",
    "assets/filters/Fire_Effect.deepar",
    "assets/filters/Stallone.deepar",
  ];

  // void _pickImage(BuildContext context) async {
  final picker = ImagePicker();

  File pictureClient = File("");

  final PermissionService permissionService = PermissionService();

  Future<void> getImageFromGallery(BuildContext context) async {
    final permissionStatus = await permissionService.requestStoragePermission();
    debugPrint('permissionStatus---------------: $permissionStatus');
    if (permissionStatus == true) {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        pictureClient = File(pickedFile.path);
        widget.onAttachImage(pictureClient);
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } else if (permissionStatus == false) {
      debugPrint('Permission denied-----------------------------------');
      showDialog(
        context: context,
        builder: (conte) => AlertDialog(
          title: Text("permission_requise".tr),
          content: Text(
              "Vous devez autoriser l'accès à la galerie dans les paramètres."
                  .tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings(); // Ouvre les paramètres de l'application
              },
              child: Text("Ouvrir les paramètres".tr),
            ),
          ],
        ),
      );
    }
  }

  int currentEffectIndex = 0;

  // Future<void> getImageFromCamera(BuildContext context) async {
  //   final permissionStatus = await permissionService.requestCameraPermission();
  //   debugPrint('getImageFromCamera---------------: $permissionStatus');
  //   if (permissionStatus == true) {
  //     final pickedFile = await picker.pickImage(source: ImageSource.camera);
  //     if (pickedFile != null) {
  //       pictureClient = File(pickedFile.path);
  //       widget.onAttachImage(pictureClient);
  //       await _controller.initialize(
  //         androidLicenseKey: androidLicenseKey,
  //         iosLicenseKey: 'YOUR_IOS_LICENSE_KEY',
  //       );

  //       await _controller.switchEffect(effects[currentEffectIndex]);

  //       setState(() {
  //         isCameraInitialized = true;
  //       });

  //       Navigator.pop(context);
  //       Navigator.pop(context);
  //       showDialog(
  //         context: context,
  //         builder: (context) {
  //           return Dialog(
  //             backgroundColor: Colors.black,
  //             child: Stack(
  //               alignment: Alignment.bottomCenter,
  //               children: [
  //                 DeepArPreviewPlus(_controller),
  //                 buildFilters(),
  //                 Positioned(
  //                   bottom: 20,
  //                   child: ElevatedButton.icon(
  //                     onPressed: () async {
  //                       final file = await _controller.takeScreenshot();
  //                       if (file != null) {
  //                         widget.onAttachImage(file);
  //                         Navigator.pop(context); // Ferme la Dialog
  //                         Navigator.pop(context); // Ferme le modal principal
  //                       }
  //                     },
  //                     icon: Icon(Icons.camera),
  //                     label: Text("Prendre Photo"),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //     }
  //   } else {
  //     showDialog(
  //       context: context,
  //       builder: (context) => AlertDialog(
  //         title: Text("permission_requise".tr),
  //         content: Text(
  //             "Vous devez autoriser l'accès à la caméra dans les paramètres."
  //                 .tr),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: Text("cancel".tr),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               Navigator.pop(context);
  //               await openAppSettings(); // Ouvre les paramètres de l'application
  //             },
  //             child: Text("Ouvrir les paramètres".tr),
  //           ),
  //         ],
  //       ),
  //     );
  //   }
  // }

  Future<void> getImageFromCamera(BuildContext context) async {
    final permissionStatus = await permissionService.requestCameraPermission();
    if (permissionStatus == true) {
      Navigator.pop(context);
      Navigator.of(context).pop(); // Ferme le modal
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraPreviewScreen(
            onImageCaptured: (File file) {
              widget.onAttachImage(file);
            },
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("permission_requise".tr),
          content: Text(
              "Vous devez autoriser l'accès à la caméra dans les paramètres."
                  .tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: Text("Ouvrir les paramètres".tr),
            ),
          ],
        ),
      );
    }
  }

  getImage(
    BuildContext context,
  ) {
    return showModalBottomSheet(
      context: context,
      builder: (c) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text(
              "gallery".tr,
              // style: TextStyles.font14BlackRegular
            ),
            onPressed: () {
              getImageFromGallery(context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              "camera".tr,
              // style: TextStyles.font14BlackRegular
            ),
            onPressed: () {
              getImageFromCamera(context);
            },
          ),
        ],
      ),
    );
  }

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

  void _pickVideo(BuildContext context) async {
    final permissionStatus = await permissionService.requestStoragePermission();
    debugPrint('permissionStatus------_pickVideo---------: $permissionStatus');
    if (permissionStatus == true) {
      Navigator.pop(context);
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

      if (pickedFile != null) {
        debugPrint(
            "Video path:============================== ${pickedFile.path}");
        widget.onAttachVideo(File(pickedFile.path));
        Navigator.pop(context);
      }
    } else {
      debugPrint('Permission denied-----------------------------------');
      showDialog(
        context: context,
        builder: (conte) => AlertDialog(
          title: Text("permission_requise".tr),
          content: Text(
              "Vous devez autoriser l'accès à la galerie dans les paramètres."
                  .tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings(); // Ouvre les paramètres de l'application
              },
              child: Text("Ouvrir les paramètres".tr),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Option pour attacher une image
          ListTile(
            leading: Icon(
              Icons.image_outlined,
              color: theme.colorScheme.primary,
              size: 30,
            ),
            title: Text("attach_image".tr, style: theme.textTheme.bodyLarge),
            onTap: () => getImage(context),
          ),
          // isCameraInitialized
          //     ? Stack(
          //         children: [
          //           DeepArPreviewPlus(_controller),
          //           Positioned(
          //             bottom: 40,
          //             left: 20,
          //             right: 20,
          //             child: buildFilters(),
          //           ),
          //         ],
          //       )
          //     : const SizedBox.shrink(),

          Divider(),

          // Option pour attacher une vidéo
          ListTile(
            leading: Icon(
              Icons.video_library_outlined,
              color: theme.colorScheme.primary,
              size: 30,
            ),
            title: Text("attach_video".tr, style: theme.textTheme.bodyLarge),
            onTap: () => _pickVideo(context),
          ),
          const Divider(),

          // Option pour attacher un fichier
          // ListTile(
          //   leading: Icon(
          //     Icons.attach_file_outlined,
          //     color: theme.colorScheme.primary,
          //     size: 30,
          //   ),
          //   title: Text("attach_file".tr, style: theme.textTheme.bodyLarge),
          //   onTap: () => _pickFile(context),
          // ),
          // const Divider(),

          // Option pour enregistrer un message vocal
          ListTile(
            leading: Icon(
              Icons.mic,
              color: theme.colorScheme.primary,
              size: 30,
            ),
            title: Text("record_voice_message".tr,
                style: theme.textTheme.bodyLarge),
            onTap: () async {
              final permissionStatus =
                  await permissionService.requestMicrophonePermission();
              debugPrint('permissionStatus---------------: $permissionStatus');
              if (permissionStatus == true) {
                widget.onStartRecording(); // Delegate to controller
                Navigator.pop(context); // Close the modal
              } else {
                debugPrint(
                    'Permission denied-----------------------------------');
                showDialog(
                  context: context,
                  builder: (conte) => AlertDialog(
                    title: Text("permission_requise".tr),
                    content: Text(
                        "Vous devez autoriser l'accès au microphone dans les paramètres."
                            .tr),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("cancel".tr),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await openAppSettings(); // Ouvre les paramètres de l'application
                        },
                        child: Text("Ouvrir les paramètres".tr),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
