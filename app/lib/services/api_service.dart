import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subtitle.dart';

/// Service to fetch subtitle data from the GitHub-hosted JSON files.
class ApiService {
  // GitHub raw content URL for the data folder
  static const String _baseUrl =
      'https://raw.githubusercontent.com/arsvibesystems/malayalam-subs/main/data';

  static String get baseUrl => _baseUrl;

  /// Fetch all subtitles
  static Future<List<Subtitle>> fetchSubtitles() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http
          .get(Uri.parse('$_baseUrl/subtitles.json?t=$timestamp'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Subtitle.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load subtitles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Fetch stats/filter metadata
  static Future<SubtitleStats> fetchStats() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http
          .get(Uri.parse('$_baseUrl/stats.json?t=$timestamp'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return SubtitleStats.fromJson(json.decode(response.body));
      } else {
        return SubtitleStats.empty();
      }
    } catch (e) {
      return SubtitleStats.empty();
    }
  }
}
