import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subtitle.dart';

/// Service to fetch subtitle data from the GitHub-hosted JSON files.
class ApiService {
  // TODO: Replace with your actual GitHub raw content URL after pushing to repo
  // Format: https://raw.githubusercontent.com/{username}/{repo}/main/data/
  static const String _baseUrl =
      'https://raw.githubusercontent.com/user/malayalam-subs/main/data';

  // For local testing, use:
  // static const String _baseUrl = 'http://10.0.2.2:8000/data';

  static String _dataUrl = _baseUrl;

  static String get baseUrl => _dataUrl;

  static void setBaseUrl(String url) {
    _dataUrl = url;
  }

  /// Fetch all subtitles
  static Future<List<Subtitle>> fetchSubtitles() async {
    try {
      final response = await http
          .get(Uri.parse('$_dataUrl/subtitles.json'))
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
      final response = await http
          .get(Uri.parse('$_dataUrl/stats.json'))
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
