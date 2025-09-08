import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/call_session_controller.dart';

class InCallBanner extends StatelessWidget implements PreferredSizeWidget {
  final double _height = 32;

  const InCallBanner({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(32);

  @override
  Widget build(BuildContext context) {
    final call = Get.find<CallSessionController>();
    final theme = Theme.of(context);

    return Obx(() {
      final active = call.isOngoing.value;
      if (!active) {
        return const SizedBox.shrink(); // Rien si pas d’appel
      }

      return Material(
        color: theme.colorScheme.primaryContainer.withOpacity(0.85),
        elevation: 0,
        child: InkWell(
          onTap: () => call.restoreUI(),
          child: SizedBox(
            height: _height,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  call.isVideo.value ? Icons.videocam : Icons.phone_in_talk,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Appel en cours · ${call.elapsedText}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Reprendre',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      );
    });
  }
}
