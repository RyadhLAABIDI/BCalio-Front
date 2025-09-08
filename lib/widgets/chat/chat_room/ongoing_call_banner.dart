import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/ongoing_call_controller.dart';

/// Bandeau vert “Appel en cours” affiché au-dessus de toute l’app
/// - Apparaît seulement si une session existe ET qu’elle est minimisée
/// - Un tap restaure l’UI d’appel
class OngoingCallBannerOverlay extends StatelessWidget {
  const OngoingCallBannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = OngoingCallController.I;
    return Obx(() {
      final show = ctrl.inCall.value && ctrl.minimized.value;
      if (!show) return const SizedBox.shrink();

      final name  = ctrl.peerName.value ?? '';
      final timer = ctrl.elapsedText.value;

      return Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          bottom: false,
          child: GestureDetector(
            onTap: () => ctrl.restoreUI(),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              color: const Color(0xFF1AAE5B), // vert style WhatsApp
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone_in_talk, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Appel en cours • $timer ${name.isNotEmpty ? "— $name" : ""}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
