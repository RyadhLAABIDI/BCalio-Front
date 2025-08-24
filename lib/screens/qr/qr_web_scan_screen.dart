import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/user_controller.dart';
import '../../services/pair_api_service.dart';

class QrWebScanScreen extends StatefulWidget {
  const QrWebScanScreen({super.key});

  @override
  State<QrWebScanScreen> createState() => _QrWebScanScreenState();
}

class _QrWebScanScreenState extends State<QrWebScanScreen> {
  final _svc = PairApiService();
  bool _busy = false;
  bool _done = false;
  final Set<String> _seen = {};

  // accepte "bcalio:pair:<ID>" (et tolère "bcakio" si jamais)
  String? _extractPairId(String raw) {
    final s = raw.trim();
    final prefixes = ['bcalio:pair:', 'bcakio:pair:'];
    for (final p in prefixes) {
      if (s.startsWith(p)) {
        final id = s.substring(p.length).trim();
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  Future<void> _handleScan(String raw) async {
    if (_busy || _done) return;
    final pairId = _extractPairId(raw);
    if (pairId == null) return;
    if (_seen.contains(pairId)) return;
    _seen.add(pairId);

    setState(() => _busy = true);
    try {
      final userCtrl = Get.find<UserController>();
      final token = await userCtrl.getToken();
      if (token == null || token.isEmpty) {
        Get.snackbar('Erreur', 'Vous devez être connecté dans l’app.',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }

      final u = userCtrl.user;
      final preview = {
        'userId': u?.id,
        'name': u?.name,
        'avatar': u?.image,
      };

      // 1) Attacher le token mobile au pairId (Option B)
      await _svc.attach(pairId: pairId, bearerToken: token, preview: preview);

      // 2) Auto-synchroniser les contacts du téléphone vers le serveur
      //    (afin que le web voie immédiatement "Dans B-Callio" / "Téléphone uniquement")
      try {
        await userCtrl.syncPhoneContactsNow();
      } catch (_) {
        // on ignore l'erreur ici, un snackbar est déjà géré dans le controller
      }

      setState(() => _done = true);
      Get.snackbar('Connecté', 'Retourne sur le Web — tu es connecté 👍',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Échec', '$e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner — Connexion Web')),
      body: Stack(
        children: [
          if (!_done)
            MobileScanner(
              onDetect: (capture) {
                final codes = capture.barcodes;
                if (codes.isEmpty) return;
                final raw = codes.first.rawValue;
                if (raw != null) _handleScan(raw);
              },
            ),
          if (_done)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle, size: 88, color: Colors.green),
                  SizedBox(height: 12),
                  Text(
                    'QR scanné.\nVérifie le navigateur Web.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          if (_busy && !_done)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.check),
            label: Text(_done ? 'Terminer' : 'Annuler'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _done ? Colors.green : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }
}
