import 'dart:convert';
import 'package:http/http.dart' as http;

/// Represents a direct subtitle file option returned by a Stremio addon.
class AddonSubtitleOption {
  final String id;
  final String url;
  final String label;
  final String lang;
  final int? totalEpisodes;

  const AddonSubtitleOption({
    required this.id,
    required this.url,
    required this.label,
    required this.lang,
    this.totalEpisodes,
  });

  factory AddonSubtitleOption.fromJson(Map<String, dynamic> json) {
    final rawUrl = (json['url'] ?? '').toString();
    final rawLabel = (json['label'] ?? '').toString();
    final rawLang = (json['lang'] ?? '').toString();

    int? totalEpisodes;
    final parsedUri = Uri.tryParse(rawUrl);
    final totParam = parsedUri?.queryParameters['tot'];
    if (totParam != null) {
      totalEpisodes = int.tryParse(totParam);
    }

    return AddonSubtitleOption(
      id: (json['id'] ?? '').toString(),
      url: rawUrl,
      label: rawLabel.isNotEmpty ? rawLabel : rawLang,
      lang: rawLang,
      totalEpisodes: totalEpisodes,
    );
  }

  /// Whether this option matches the given sourceSite key.
  bool matchesSource(String sourceSite) {
    final lowerId = id.toLowerCase();
    final lowerLang = lang.toLowerCase();
    if (sourceSite == 'teamgoat') {
      return lowerId.startsWith('goat-') || lowerLang.contains('goat');
    }
    if (sourceSite == 'moviemirror') {
      return lowerId.startsWith('moviemirror-') || lowerLang.contains('mirror');
    }
    return true;
  }
}

/// Fetches fresh on-demand direct .srt links from the MSone and GOAT/MovieMirror Stremio addons.
class AddonService {
  static const String msoneBaseUrl = 'https://addon.malayalamsubtitles.org';
  static const String goatMmBaseUrl = 'https://malayalam-subs.onrender.com';

  static String? baseUrlForSource(String sourceSite) {
    switch (sourceSite) {
      case 'msone':
        return msoneBaseUrl;
      case 'teamgoat':
      case 'moviemirror':
        return goatMmBaseUrl;
      default:
        return null;
    }
  }

  /// Fetch direct .srt subtitle options for a movie or series episode.
  static Future<List<AddonSubtitleOption>> fetchSubtitles({
    required String sourceSite,
    required String imdbId,
    required String releaseType,
    int season = 1,
    int episode = 1,
  }) async {
    final baseUrl = baseUrlForSource(sourceSite);
    if (baseUrl == null || imdbId.isEmpty) return [];

    final mediaType = releaseType == 'series' ? 'series' : 'movie';
    final mediaId =
        mediaType == 'series' ? '$imdbId:$season:$episode' : imdbId;
    final url = '$baseUrl/subtitles/$mediaType/$mediaId.json';

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: const {'User-Agent': 'MalayalamSubs/1.0'},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rawList = decoded['subtitles'] as List<dynamic>? ?? [];

      final options = rawList
          .whereType<Map<String, dynamic>>()
          .map(AddonSubtitleOption.fromJson)
          .where((o) => o.url.isNotEmpty)
          .toList();

      // Sort options from the item's own source site first
      options.sort((a, b) {
        final aMatch = a.matchesSource(sourceSite) ? 0 : 1;
        final bMatch = b.matchesSource(sourceSite) ? 0 : 1;
        return aMatch.compareTo(bMatch);
      });

      return options;
    } catch (_) {
      return [];
    }
  }
}

