import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/qr_api_service.dart';

class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  final api = QrApiService();
  String? _qrText;
  int? _ttl;
  DateTime? _expiresAt;
  bool _loading = true;
  String? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.getMyQr();
      setState(() {
        _qrText = (data['text'] as String?) ?? data['token'] as String?;
        _ttl = data['expSeconds'] as int?;
        _expiresAt =
            (_ttl != null) ? DateTime.now().add(Duration(seconds: _ttl!)) : null;
      });
      _startTicker();
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _startTicker() {
    _tick?.cancel();
    if (_expiresAt == null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String _remaining() {
    if (_expiresAt == null) return 'Sans expiration';
    final now = DateTime.now();
    if (_expiresAt!.isBefore(now)) return 'Expiré • Régénérer';
    final d = _expiresAt!.difference(now);
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    return 'Expire dans ${days}j ${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon QR')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : (_error != null)
                ? Text(_error!)
                : (_qrText == null)
                    ? const Text('Aucun QR')
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Carte avec fond blanc pour contraste en dark mode
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white, // ✅ fond clair garanti
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                if (isDark)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  )
                                else
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                              ],
                            ),
                            child: QrImageView(
                              data: _qrText!,
                              version: QrVersions.auto,
                              size: 260,
                              gapless: true,
                              // ✅ couleurs forcées (noir sur blanc) pour lisibilité
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _remaining(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Régénérer'),
                          ),
                        ],
                      ),
      ),
    );
  }
}
