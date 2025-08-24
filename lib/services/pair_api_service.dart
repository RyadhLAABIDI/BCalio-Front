import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/misc.dart'; // on y met pairBaseUrl (voir §4)

class PairApiService {
  /// Le mobile attache son token auth au pairId (scan)
  Future<void> attach({
    required String pairId,
    required String bearerToken,
    Map<String, dynamic>? preview,
  }) async {
    final url = Uri.parse('$pairBaseUrl/api/pair/attach');
    final r = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      },
      body: jsonEncode({
        'pairId': pairId,
        if (preview != null) 'preview': preview,
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('Attach failed: ${r.statusCode} ${r.body}');
    }
  }
}
