import 'dart:ui';
import 'package:bcalio/controllers/call_log_controller.dart';
import 'package:bcalio/services/call_launcher.dart';
import 'package:bcalio/widgets/chat/chat_room/call_action_sheet.dart';
import 'package:bcalio/widgets/chat/chat_room/call_log_list_item.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  late final CallLogController ctrl;

  // ordre et libellés des filtres (facile à maintenir)
  final _filters = const [
    (CallFilter.all, 'Tous'),
    (CallFilter.missed, 'Manqués'),
    (CallFilter.incoming, 'Entrants'),
    (CallFilter.outgoing, 'Sortants'),
  ];

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(CallLogController(), permanent: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleSpacing: 16,
        title: const Text('Journal d’appel'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.trash),
            tooltip: 'Effacer l’historique',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Effacer l’historique ?'),
                  content: const Text('Cette action est irréversible.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Effacer')),
                  ],
                ),
              );
              if (ok == true) await ctrl.clearAll();
            },
          ),
        ],
        // barre de filtres « verre dépoli » scrollable
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white10 : Colors.white.withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  child: Obx(() {
                    final current = ctrl.filter.value;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: _filters.map((f) {
                          final selected = current == f.$1;
                          return _FilterPill(
                            label: f.$2,
                            selected: selected,
                            onTap: () => ctrl.filter.value = f.$1,
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),

      // fond subtil dégradé pour un look « premium »
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0C0F14), const Color(0xFF11151C)]
                : [const Color(0xFFF7F8FA), const Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Obx(() {
            final items = ctrl.filtered;

            // transition douce entre « vide » et « liste »
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: items.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      key: ValueKey('list_${ctrl.filter.value}'),
                      padding: const EdgeInsets.fromLTRB(12, 90, 12, 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final log = items[i];

                        // entrée item « slide + fade » très légère
                        return TweenAnimationBuilder<double>(
                          key: ValueKey('log_${log.id ?? i}'),
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 180 + (i.clamp(0, 6) * 18)),
                          curve: Curves.easeOut,
                          builder: (context, t, child) {
                            return Transform.translate(
                              offset: Offset(0, (1 - t) * 12),
                              child: Opacity(opacity: t, child: child),
                            );
                          },
                          child: CallLogListItem(
                            log: log,
                            onTap: () => CallActionSheet.show(
                              context,
                              log: log,
                              onAudio: () => CallLauncher.fromLog(log, video: false),
                              onVideo: () => CallLauncher.fromLog(log, video: true),
                            ),
                            onCallAudio: () => CallLauncher.fromLog(log, video: false),
                            onCallVideo: () => CallLauncher.fromLog(log, video: true),
                            onDelete: () => ctrl.delete(log.id!),
                          ),
                        );
                      },
                    ),
            );
          }),
        ),
      ),
    );
  }
}

/* ---------------- widgets privés ---------------- */

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selBg  = theme.colorScheme.primary.withOpacity(.14);
    final selTxt = theme.colorScheme.primary;
    final unBg   = Colors.transparent;
    final unTxt  = theme.textTheme.bodyMedium?.color?.withOpacity(.8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selBg : unBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withOpacity(.35)
                  : theme.dividerColor.withOpacity(.18),
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? selTxt : unTxt,
              letterSpacing: .2,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.call_slash, size: 56, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'Aucun appel pour le moment.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Les appels récents apparaîtront ici.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
