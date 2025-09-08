import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ← TON API BASE DIRECTEMENT ICI
const String kServerBase = 'http://192.168.1.64:1906/api';

class PdfDownloader {
  static Future<String?> downloadPdf(String url, {String? fileName}) async {
    try {
      if (url.isEmpty) return null;

      final uriIn = Uri.parse(url);

      // 1) Cloudinary RAW ? (on garde au cas où, mais tu n'en utilises pas)
      if (_isCloudinaryRaw(uriIn)) {
        final inferredName = fileName?.trim().isNotEmpty == true
            ? fileName!.trim()
            : _inferNameFromUrl(uriIn) ?? 'document.pdf';

        final proxy = Uri.parse(
          '${_serverOriginFromBase(kServerBase)}/api/files/proxy'
          '?url=${Uri.encodeQueryComponent(uriIn.toString())}'
          '&filename=${Uri.encodeQueryComponent(inferredName)}',
        );

        debugPrint('[PdfDownloader] via proxy: $proxy');
        return _downloadToAppDir(proxy, inferredName);
      }

      // 2) /docs/... → forcer vers ton serveur local
      final localDocs = _rewriteDocsToLocal(uriIn, _serverOriginFromBase(kServerBase));

      // 3) Sinon: téléchargement direct
      final chosen = localDocs ?? uriIn;
      final inferredName = (fileName?.trim().isNotEmpty == true)
          ? fileName!.trim()
          : _inferNameFromUrl(chosen) ?? 'file_${DateTime.now().millisecondsSinceEpoch}.pdf';

      debugPrint('[PdfDownloader] GET $chosen');
      return _downloadToAppDir(chosen, inferredName);
    } catch (e) {
      debugPrint('[PdfDownloader] error: $e');
      return null;
    }
  }

  // ----------------- Helpers -----------------

  static bool _isCloudinaryRaw(Uri uri) {
    final h = uri.host.toLowerCase();
    return h.contains('res.cloudinary.com') && uri.path.contains('/raw/upload/');
  }

  static bool _isDocsPath(Uri uri) {
    return uri.path.startsWith('/docs/');
  }

  static Uri? _rewriteDocsToLocal(Uri input, String serverOrigin) {
    if (_isDocsPath(input)) {
      final local = Uri.parse('$serverOrigin${input.path}');
      if (input.host != local.host || input.port != local.port || input.scheme != local.scheme) {
        debugPrint('[PdfDownloader] rewrite /docs → $local');
        return local;
      }
    }
    return null;
  }

  static String? _inferNameFromUrl(Uri uri) {
    if (uri.pathSegments.isEmpty) return null;
    final last = uri.pathSegments.last;
    if (last.isEmpty) return null;
    return last.contains('.') ? last : '$last.pdf';
  }

  static String _serverOriginFromBase(String base) {
    // ex: "http://192.168.1.64:1906/api" → "http://192.168.1.64:1906"
    final u = Uri.parse(base);
    return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
  }

  static Future<String?> _downloadToAppDir(Uri uri, String fileName) async {
    try {
      final resp = await http.get(uri);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint('[PdfDownloader] GET $uri → ${resp.statusCode}');
        return null;
      }

      Directory dir;
      if (Platform.isAndroid) {
        dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(resp.bodyBytes);
      return file.path;
    } catch (e) {
      debugPrint('[PdfDownloader] save error: $e');
      return null;
    }
  }
}
