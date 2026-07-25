import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class MetadataFetcher {
  /// Fetches the missing metadata for an MSone subtitle URL
  static Future<Map<String, dynamic>?> fetchMissingData(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; SM-S901B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return null;
      }

      final document = parse(response.body);
      final result = <String, dynamic>{};

      // Extract poster (og:image)
      final ogImage = document.querySelector('meta[property="og:image"]');
      if (ogImage != null) {
        result['thumbnail_url'] = ogImage.attributes['content'];
      }

      final bodyText = document.body?.text ?? '';

      // Extract IMDb Rating (matching patterns like 7.7/10 or 8/10 anywhere in page text)
      final RegExp ratingRegex = RegExp(r'(\d+(?:\.\d+)?)\s*/\s*10');
      final ratingMatch = ratingRegex.firstMatch(bodyText);
      if (ratingMatch != null) {
        result['imdb_rating'] = double.tryParse(ratingMatch.group(1)!);
      } else {
        // Fallback: look for IMDb: 8.5 format
        final RegExp altRatingRegex = RegExp(r'IMDB\s*(?:Rating)?\s*[:\-–]\s*(\d+(?:\.\d+)?)', caseSensitive: false);
        final altMatch = altRatingRegex.firstMatch(bodyText);
        if (altMatch != null) {
          result['imdb_rating'] = double.tryParse(altMatch.group(1)!);
        }
      }

      // Extract Release Number (matching patterns like റിലീസ് : 3700 or Release - 3700)
      final RegExp releaseRegex = RegExp(r'(?:റിലീസ്|Release)\s*[:\-–\s]\s*(\d+)', caseSensitive: false);
      final relMatch = releaseRegex.firstMatch(bodyText);
      if (relMatch != null) {
        result['release_number'] = int.tryParse(relMatch.group(1)!);
      }

      // Extract genres
      final genreLinks = document.querySelectorAll('a[href*="/genres/"]');
      if (genreLinks.isNotEmpty) {
        final genresList = genreLinks.map((e) => e.text.trim()).where((g) => g.isNotEmpty).toSet().toList();
        if (genresList.isNotEmpty) {
          result['genres'] = genresList.join(', ');
        }
      }

      // Extract certificate
      final certLinks = document.querySelectorAll('a[href*="/certificates/"]');
      if (certLinks.isNotEmpty) {
        result['certificate'] = certLinks.first.text.trim();
      }

      // Extract description
      final contentDiv = document.querySelector('.entry-content');
      if (contentDiv != null) {
        final paragraphs = contentDiv.querySelectorAll('p');
        String fullDescription = '';
        for (final p in paragraphs) {
          final text = p.text.trim();
          if (text.isNotEmpty && !text.contains('The post') && !text.contains('ഡൗൺലോഡ്')) {
            fullDescription += '$text\n\n';
          }
        }
        if (fullDescription.isNotEmpty) {
          result['description'] = fullDescription.trim();
        }
      }

      return result;
    } catch (e) {
      return null;
    }
  }
}
