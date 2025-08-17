import 'dart:ui';
import 'package:bcalio/models/call_log_model.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class CallActionSheet extends StatelessWidget {
  final CallLog log;
  final VoidCallback onAudio;
  final VoidCallback onVideo;

  const CallActionSheet({
    super.key,
    required this.log,
    required this.onAudio,
    required this.onVideo,
  });

  static Future<void> show(
    BuildContext context, {
    required CallLog log,
    required VoidCallback onAudio,
    required VoidCallback onVideo,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) => CallActionSheet(log: log, onAudio: onAudio, onVideo: onVideo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // blur du fond
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: const SizedBox.expand(),
        ),
        // contenu
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 14, offset: const Offset(0, -4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: (log.peerAvatar ?? '').isNotEmpty
                      ? NetworkImage(log.peerAvatar!)
                      : null,
                  child: (log.peerAvatar ?? '').isEmpty
                      ? const Icon(Iconsax.user, color: Colors.white)
                      : null,
                ),
                title: Text(log.peerName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Choisir le type d’appel'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _BigButton(
                      icon: Iconsax.call,
                      label: 'Appel audio',
                      onTap: () {
                        Navigator.pop(context);
                        onAudio();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigButton(
                      icon: Iconsax.video,
                      label: 'Appel vidéo',
                      onTap: () {
                        Navigator.pop(context);
                        onVideo();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BigButton({required this.icon, required this.label, required this.onTap});

  @override
  State<_BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<_BigButton> with SingleTickerProviderStateMixin {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = .97),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(.12),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(widget.label, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
