import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/contact_controller.dart';
import '../../controllers/user_controller.dart';
import '../../services/qr_api_service.dart';

class ScanQrAddScreen extends StatefulWidget {
  const ScanQrAddScreen({super.key});
  @override
  State<ScanQrAddScreen> createState() => _ScanQrAddScreenState();
}

class _ScanQrAddScreenState extends State<ScanQrAddScreen> {
  // ✅ v3+: config anti-doublons via le controller
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, // évite les callbacks multiples
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],       // scanne uniquement les QR
  );

  final api = QrApiService();
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
    if (_busy) return; // double sécurité côté UI
    final codes = capture.barcodes;
    if (codes.isEmpty) return;

    final raw = codes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    setState(() => _busy = true);
    try {
      // 1) Résoudre le QR via Node (retourne contactId)
      final qrRes = await api.addByQrText(raw);
      if (qrRes['ok'] != true) {
        _flash('Échec: ${qrRes['error'] ?? 'inconnu'}');
        setState(() => _busy = false);
        return;
      }
      final contactId = (qrRes['contactId'] ?? '').toString();
      if (contactId.isEmpty) {
        _flash('QR invalide: contactId manquant');
        setState(() => _busy = false);
        return;
      }

      // 2) Appeler TON API existante pour ajouter le contact (pour mise à jour correcte)
      final token = await userCtrl.getToken();
      if (token == null || token.isEmpty) {
        _flash('Session expirée, reconnecte-toi');
        setState(() => _busy = false);
        return;
      }

      // Récupérer les infos du user pour nom/tel (pour l’ajout au carnet local)
      final user = await userCtrl.getUser(contactId);
      final name = user?.name ?? contactId;
      final phone = user?.phoneNumber ?? '';

      await contactCtrl.addContact(token, contactId, name, phone, user?.email);

      _flash('Contact ajouté: $name');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _flash('Erreur: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter via QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            // ❌ allowDuplicates: false,  // supprimé en v3
            onDetect: _onDetect,
          ),
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
