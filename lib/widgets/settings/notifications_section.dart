// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:get/get.dart';
// import 'package:iconsax/iconsax.dart';
// import '../../controllers/notification_controller.dart'; // Import NotificationController

// class NotificationSection extends StatefulWidget {
//   const NotificationSection({super.key});

//   @override
//   State<NotificationSection> createState() => _NotificationSectionState();
// }

// class _NotificationSectionState extends State<NotificationSection> {
//   @override
//   Widget build(BuildContext context) {
//     final notificationController =
//         Get.find<NotificationController>(); // Get the controller
//     final theme = Theme.of(context);

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: theme.colorScheme.surface,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 12,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Section Title with Icon
//           Row(
//             children: [
//               Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: theme.colorScheme.primary.withOpacity(0.1),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(Icons.notification_important,
//                       color: theme.colorScheme.primary)
//                   //  Image.asset(
//                   //   'assets/3d_icons/notification_icon.png', // Path to the image asset
//                   //   width: 24, // Adjust the size as needed
//                   //   height: 24, // Adjust the size as needed
//                   // ),
//                   ),
//               const SizedBox(width: 12),
//               Text(
//                 "allow_notifications"
//                     .tr, // Use translation key for notifications
//                 style: theme.textTheme.titleMedium?.copyWith(
//                   fontWeight: FontWeight.bold,
//                   color: theme.colorScheme.onSurface,
//                 ),
//               ),
//               const Spacer(), // Push the button to the right
//               // Show loading indicator until permission is checked
//               Obx(() {
//                 if (notificationController.isLoading.value) {
//                   return CircularProgressIndicator(); // Show loading indicator
//                 }

//                 return ElevatedButton(
//                   onPressed: () async {
//                     await notificationController.disabledNotification();
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor:
//                         notificationController.isPermissionGranted.value
//                             ? theme.iconTheme.color
//                             : theme.colorScheme.error,
//                     shape: CircleBorder(),
//                     padding: const EdgeInsets.all(8),
//                     minimumSize: Size(30, 30),
//                   ),
//                   child: Icon(
//                     notificationController.isPermissionGranted.value
//                         ? Icons.check
//                         : Iconsax.close_circle,
//                     color: theme.colorScheme.onPrimary,
//                     size: 18,
//                   ),
//                 );
//               }),
//             ],
//           ),
//           const SizedBox(height: 12), // Reduce space between title and button
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../controllers/notification_controller.dart'; // Import NotificationController

class NotificationSection extends StatefulWidget {
  const NotificationSection({super.key});

  @override
  State<NotificationSection> createState() => _NotificationSectionState();
}

class _NotificationSectionState extends State<NotificationSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Ajoutez l'observateur
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Supprimez l'observateur
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(Duration(seconds: 1), () {
        // Vérifiez à nouveau les permissions après un délai
        final notificationController = Get.find<NotificationController>();
        notificationController.checkNotificationPermission();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationController =
        Get.find<NotificationController>(); // Get the controller
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title with Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notification_important,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                "allow_notifications"
                    .tr, // Use translation key for notifications
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(), // Push the button to the right
              // Show loading indicator until permission is checked
              Obx(() {
                if (notificationController.isLoading.value) {
                  return CircularProgressIndicator(); // Show loading indicator
                }

                return ElevatedButton(
                  onPressed: () async {
                    await notificationController.disabledNotification();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        notificationController.isPermissionGranted.value
                            ? theme.iconTheme.color
                            : theme.colorScheme.error,
                    shape: CircleBorder(),
                    padding: const EdgeInsets.all(8),
                    minimumSize: Size(30, 30),
                  ),
                  child: Icon(
                    notificationController.isPermissionGranted.value
                        ? Icons.check
                        : Iconsax.close_circle,
                    color: theme.colorScheme.onPrimary,
                    size: 18,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12), // Reduce space between title and button
        ],
      ),
    );
  }
}
