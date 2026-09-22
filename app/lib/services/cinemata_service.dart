import 'dart:convert';
import 'package:http/http.dart' as http;

class CinemataService {
  static const String _baseUrl = 'https://v3-cinemeta.strem.io';

  /// Search for IMDB ID by movie/series title
  static Future<String?> searchImdbId(String title, {String type = 'movie'}) async {
    try {
      final encoded = Uri.encodeComponent(title);
      final url = '$_baseUrl/catalog/$type/top/search=$encoded.json';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'MalayalamSubs/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final metas = json['metas'] as List<dynamic>?;
        if (metas != null && metas.isNotEmpty) {
          return metas[0]['imdb_id'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }
}
