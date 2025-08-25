import 'package:get/get.dart';

class UnreadBadgesController extends GetxController {
  /// Nombre d’appels manqués non consultés
  final RxInt calls = 0.obs;

  void incCalls([int by = 1]) => calls.value += by;
  void clearCalls() => calls.value = 0;
}
