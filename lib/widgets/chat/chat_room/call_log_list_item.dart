import 'package:bcalio/models/call_log_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class CallLogListItem extends StatelessWidget {
  final CallLog log;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// actions rapides existantes (icônes à droite)
  final VoidCallback? onCallAudio;
  final VoidCallback? onCallVideo;

  const CallLogListItem({
    super.key,
    required this.log,
    this.onTap,
    this.onDelete,
    this.onCallAudio,
    this.onCallVideo,
  });

  IconData get _arrow {
    if (log.direction == CallDirection.outgoing) return Icons.call_made_rounded;
    return Icons.call_received_rounded;
  }

  Color _arrowColor(BuildContext ctx) {
    if (log.isMissed) return Colors.redAccent;
    return Theme.of(ctx).colorScheme.primary;
  }

  String get _subtitle {
    final df = DateFormat('EEE d MMM, HH:mm');
    final when = df.format(log.startedAt);
    final dur = log.durationSeconds;
    final durTxt = dur > 0 ? ' • ${_fmtDuration(dur)}' : '';
    final kind = log.type == CallType.video ? 'vidéo' : 'audio';

    switch (log.status) {
      case CallStatus.rejected: return 'Refusé • $kind • $when';
      case CallStatus.cancelled:return 'Annulé • $kind • $when';
      case CallStatus.missed:  return 'Manqué • $kind • $when';
      case CallStatus.timeout: return 'Ne répond pas • $kind • $when';
      case CallStatus.ended:
      case CallStatus.accepted:
        return 'Reçu • $kind • $when$durTxt';
      case CallStatus.ringing:
      default:
        return 'Appel en cours • $kind • $when';
    }
  }

  String _fmtDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    // ⬅️ suppression = swipe left (endToStart) — inchangé
    final dismissible = Dismissible(
      key: ValueKey('log_${log.id ?? log.callId}'),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: onDelete != null
          ? (_) async {
              onDelete!();
              return false;
            }
          : null,
      // 👉 swipe-to-call est géré à l’intérieur via _SwipeToCall
      child: _SwipeToCall(
        enabled: onCallAudio != null,
        onTriggered: onCallAudio,
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: (log.peerAvatar ?? '').isNotEmpty
                ? NetworkImage(log.peerAvatar!)
                : null,
            child: (log.peerAvatar ?? '').isEmpty
                ? const Icon(Iconsax.user, color: Colors.white)
                : null,
          ),
          title:
              Text(log.peerName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(_subtitle, maxLines: 2),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onCallAudio != null)
                _ActionIcon(
                  icon: Iconsax.call,
                  tooltip: 'Appel audio',
                  onTap: onCallAudio!,
                ),
              if (onCallVideo != null)
                _ActionIcon(
                  icon: Iconsax.video,
                  tooltip: 'Appel vidéo',
                  onTap: onCallVideo!,
                ),
              const SizedBox(width: 6),
              Icon(_arrow, color: _arrowColor(context)),
            ],
          ),
        ),
      ),
    );

    return dismissible;
  }
}

/// Petit bouton animé (scale) pour les actions rapides
class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _press(bool down) {
    setState(() => _scale = down ? .9 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _press(true),
        onTapCancel: () => _press(false),
        onTapUp: (_) => _press(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon,
                size: 18, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

/// Swipe-to-call à droite, style WhatsApp, sans package externe.
/// - drag à droite fait glisser le tile et révèle un bouton vert animé
/// - au-delà d’un seuil (~84px) → haptique + déclenche onTriggered à la relâche
class _SwipeToCall extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback? onTriggered;

  const _SwipeToCall({
    required this.child,
    required this.enabled,
    required this.onTriggered,
  });

  @override
  State<_SwipeToCall> createState() => _SwipeToCallState();
}

class _SwipeToCallState extends State<_SwipeToCall>
    with SingleTickerProviderStateMixin {
  static const double _maxDrag = 120; // translation max
  static const double _trigger = 84;  // seuil de déclenchement
  double _dx = 0;
  bool _vibrated = false;

  void _reset() {
    setState(() {
      _dx = 0;
      _vibrated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final theme = Theme.of(context);
    final progress = (_dx / _trigger).clamp(0.0, 1.0);
    final scale = 0.72 + 0.38 * progress; // 0.72 → 1.10

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        // limit to right-swipe only
        final next = (_dx + d.delta.dx).clamp(0.0, _maxDrag);
        setState(() => _dx = next);

        // haptique quand on franchit le seuil
        if (!_vibrated && _dx >= _trigger) {
          _vibrated = true;
          HapticFeedback.mediumImpact();
        } else if (_vibrated && _dx < _trigger) {
          _vibrated = false;
        }
      },
      onHorizontalDragEnd: (_) {
        final shouldTrigger = _dx >= _trigger;
        if (shouldTrigger && widget.onTriggered != null) {
          // petit snap visuel
          setState(() => _dx = _maxDrag);
          Future.delayed(const Duration(milliseconds: 80), () {
            widget.onTriggered!.call();
            _reset();
          });
        } else {
          // retour à zéro
          _reset();
        }
      },
      onHorizontalDragCancel: _reset,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // fond + bouton vert derrière
          Positioned.fill(
            child: Container(
              color: theme.colorScheme.primary.withOpacity(.06),
            ),
          ),
          // bouton circulaire qui “grossit” avec le drag
          Positioned(
            left: 16,
            child: AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 60),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade500,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Icon(Iconsax.call, color: Colors.white, size: 20),
              ),
            ),
          ),
          // le tile qui glisse
          Transform.translate(
            offset: Offset(_dx, 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: theme.cardColor,
              ),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
