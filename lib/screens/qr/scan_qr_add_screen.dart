import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/contact_controller.dart';
import '../../controllers/user_controller.dart';
import '../../services/qr_api_service.dart';
import '../../services/contact_api_service.dart';

class ScanQrAddScreen extends StatefulWidget {
  const ScanQrAddScreen({super.key});
  @override
  State<ScanQrAddScreen> createState() => _ScanQrAddScreenState();
}

class _ScanQrAddScreenState extends State<ScanQrAddScreen> {
  // Anti-doublons + QR only
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
  );

  final api = QrApiService();
  final contactApi = ContactApiService();

  bool _busy = false;
  String? _msg;
  Timer? _timer;

  final userCtrl = Get.find<UserController>();
  final contactCtrl = Get.find<ContactController>();

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _flash(String text) {
    setState(() => _msg = text);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _msg = null);
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final codes = capture.barcodes;
    if (codes.isEmpty) return;

    final raw = codes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _busy = true);
    try {
      // 1) Résoudre le QR via Node → { ok, contactId, profile? }
      final qrRes = await api.addByQrText(raw);
      if (qrRes['ok'] != true) {
        _flash('${'Échec QR'.tr}: ${qrRes['error'] ?? 'inconnu'.tr}');
        setState(() => _busy = false);
        return;
      }

      final contactId = (qrRes['contactId'] ?? '').toString();
      if (contactId.isEmpty) {
        _flash('${'QR invalide'.tr}: ${'contactId manquant'.tr}');
        setState(() => _busy = false);
        return;
      }

      // 2) On ESSAIE de récupérer les infos utilisateur (lecture seule)
      String name = (qrRes['profile']?['name'] as String?)?.trim() ?? '';
      String email = '';
      String phone = '';

      final token = await userCtrl.getToken();
      if (token != null && token.isNotEmpty) {
        final details = await contactApi.getUserById(token, contactId);
        if (details != null) {
          name  = (details.name.isNotEmpty ? details.name : name);
          email = (details.email.isNotEmpty ? details.email : email);
          phone = (details.phoneNumber ?? '').trim();
        }
      }

      // 3) Exiger un numéro pour pouvoir écrire dans le carnet
      if (phone.isEmpty) {
        _flash(
          'Utilisateur trouvé, mais son numéro n\'a pas été récupéré.\nAjoute-le manuellement ou complète le numéro.'.tr,
        );
        setState(() => _busy = false);
        return;
      }

      // 4) Ajout style “manuel”
      await contactCtrl.addPhoneContactFromQr(
        name: (name.isNotEmpty ? name : contactId),
        phone: phone,
        email: email,
      );

      _flash('${'Contact ajouté'.tr}${name.isNotEmpty ? " : $name" : ""}');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _flash('${'Erreur'.tr}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajouter via QR'.tr)),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_msg != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_msg!, style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
