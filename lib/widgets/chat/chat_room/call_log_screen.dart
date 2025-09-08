import 'dart:ui';
import 'package:bcalio/controllers/call_log_controller.dart';
import 'package:bcalio/services/call_launcher.dart';
import 'package:bcalio/themes/theme.dart';
import 'package:bcalio/widgets/chat/chat_room/call_action_sheet.dart';
import 'package:bcalio/widgets/chat/chat_room/call_log_list_item.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

// ❗️IMPORTANT : on NE nettoie plus le badge ici. Le clear se fait seulement
// quand l’onglet Calls est sélectionné (NavigationScreen).

class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});

  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  late CallLogController ctrl;

  final _filters = const [
    (CallFilter.all, 'Tous'),
    (CallFilter.missed, 'Manqués'),
    (CallFilter.incoming, 'Entrants'),
    (CallFilter.outgoing, 'Sortants'),
  ];

  @override
  void initState() {
    super.initState();

    if (Get.isRegistered<CallLogController>()) {
      ctrl = Get.find<CallLogController>();
    } else {
      ctrl = Get.put(CallLogController(), permanent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final topInset = MediaQuery.of(context).padding.top;
    const filterBarHeight = 64.0;
    const extra = 12.0;
    final listTopPadding = topInset + kToolbarHeight + filterBarHeight + extra;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleSpacing: 16,
        title: Text('Journal d’appel'.tr),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.trash, color: Color.fromARGB(255, 213, 36, 23)),
            tooltip: 'Effacer l’historique'.tr,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Effacer l’historique ?'.tr),
                  content: Text('Cette action est irréversible.'.tr),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Effacer'.tr, style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (ok == true) await ctrl.clearAll();
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(filterBarHeight),
          child: _FiltersBar(),
        ),
      ),
      body: Container(
        // ✅ Fond UNI en dark, gradient en light
        decoration: BoxDecoration(
          color: isDark ? kDarkBgColor : null,
          gradient: isDark
              ? null
              : LinearGradient(
                  colors: [kLightBgColor, const Color(0xFFFFFFFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          top: false,
          child: Obx(() {
            final items = ctrl.filtered;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: items.isEmpty
                  ? _EmptyState(topPadding: listTopPadding + 12)
                  : ListView.separated(
                      key: ValueKey('list_${ctrl.filter.value}'),
                      padding: EdgeInsets.fromLTRB(12, listTopPadding, 12, 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final log = items[i];

                        final rowWithTrash = Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 48),
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
                                onDelete: () {
                                  if (log.id != null) ctrl.delete(log.id!);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _InlineTrashButton(
                                onPressed: (log.id == null)
                                    ? null
                                    : () => ctrl.delete(log.id!),
                              ),
                            ),
                          ],
                        );

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
                          child: rowWithTrash,
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

/* ---------- petite poubelle intégrée ---------- */

class _InlineTrashButton extends StatelessWidget {
  const _InlineTrashButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 36,
        height: 36,
        decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color: enabled ? Colors.red.withOpacity(.10) : Colors.transparent,
        ),
        child: IconButton(
          tooltip: 'Supprimer'.tr,
          onPressed: onPressed,
          iconSize: 18,
          splashRadius: 20,
          icon: Icon(
            Iconsax.trash,
            color: enabled ? Colors.red : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );
  }
}

/* ---------------- widgets privés ---------------- */

class _FiltersBar extends StatelessWidget {
  const _FiltersBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ctrl = Get.find<CallLogController>();

    return Padding(
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
              final filters = [
                (CallFilter.all, 'Tous'.tr),
                (CallFilter.missed, 'Manqués'.tr),
                (CallFilter.incoming, 'Entrants'.tr),
                (CallFilter.outgoing, 'Sortants'.tr),
              ];
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: filters.map((f) {
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
    );
  }
}

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
  const _EmptyState({this.topPadding = 120});
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 🎯 Couleurs demandées :
    // - Light mode : kAccentColor
    // - Dark mode  : kDarkPrimaryColor
    final Color base = isDark ? kDarkPrimaryColor : kLightPrimaryColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.call_slash, size: 56, color: base),
            const SizedBox(height: 16),
            Text(
              'Aucun appel pour le moment.'.tr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: base,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Les appels récents apparaîtront ici.'.tr,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: base,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
