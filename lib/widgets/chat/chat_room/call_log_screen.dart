import 'package:bcalio/controllers/call_log_controller.dart';
import 'package:bcalio/widgets/chat/chat_room/call_action_sheet.dart';
import 'package:bcalio/widgets/chat/chat_room/call_log_list_item.dart';
import 'package:bcalio/services/call_launcher.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

class CallLogScreen extends StatelessWidget {
  const CallLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(CallLogController(), permanent: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal d’appel'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.trash),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Obx(() {
            final f = ctrl.filter.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _chip('Tous',        f == CallFilter.all,      () => ctrl.filter.value = CallFilter.all),
                _chip('Manqués',     f == CallFilter.missed,   () => ctrl.filter.value = CallFilter.missed),
                _chip('Entrants',    f == CallFilter.incoming, () => ctrl.filter.value = CallFilter.incoming),
                _chip('Sortants',    f == CallFilter.outgoing, () => ctrl.filter.value = CallFilter.outgoing),
              ],
            );
          }),
        ),
      ),
      body: Obx(() {
        final items = ctrl.filtered;
        if (items.isEmpty) {
          return const Center(child: Text('Aucun appel pour le moment.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (_, i) {
            final log = items[i];
            return CallLogListItem(
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
            );
          },
        );
      }),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
