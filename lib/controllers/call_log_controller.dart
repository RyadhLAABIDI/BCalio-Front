import 'package:get/get.dart';
import '../models/call_log_model.dart';
import '../services/call_log_db.dart';

enum CallFilter { all, missed, incoming, outgoing }

class CallLogController extends GetxController {
  final RxList<CallLog> logs = <CallLog>[].obs;
  final Rx<CallFilter> filter = CallFilter.all.obs;

  @override
  void onInit() {
    super.onInit();
    refreshLogs();
  }

  Future<void> refreshLogs() async {
    final all = await CallLogDB().fetchAll();
    logs.assignAll(all);
  }

  List<CallLog> get filtered {
    switch (filter.value) {
      case CallFilter.missed:
        return logs.where((l) => l.isMissed).toList();
      case CallFilter.incoming:
        return logs.where((l) => l.direction == CallDirection.incoming).toList();
      case CallFilter.outgoing:
        return logs.where((l) => l.direction == CallDirection.outgoing).toList();
      case CallFilter.all:
      default:
        return logs;
    }
  }

  /// upsert par callId
  Future<void> upsert(CallLog log) async {
    await CallLogDB().upsertByCallId(log);
    await refreshLogs();
  }

  Future<void> delete(int id) async {
    await CallLogDB().delete(id);
    await refreshLogs();
  }

  Future<void> clearAll() async {
    await CallLogDB().clear();
    await refreshLogs();
  }
}
