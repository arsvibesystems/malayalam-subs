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

      // Extract IMDb Rating
      // Format usually like: <span class="imdb-rating">8.5</span>
      final ratingElements = document.querySelectorAll('span, div, p');
      for (final el in ratingElements) {
        final text = el.text.trim();
        if (text.contains('IMDB:') || text.contains('IMDb:')) {
          final RegExp ratingRegex = RegExp(r'(\d+\.\d+)');
          final match = ratingRegex.firstMatch(text);
          if (match != null) {
            result['imdb_rating'] = double.tryParse(match.group(1)!);
            break;
          }
        }
      }

      // Extract description
      // usually in <div class="entry-content"> or similar
      final contentDiv = document.querySelector('.entry-content');
      if (contentDiv != null) {
        final paragraphs = contentDiv.querySelectorAll('p');
        String fullDescription = '';
        for (final p in paragraphs) {
          final text = p.text.trim();
          if (text.isNotEmpty && !text.contains('The post')) {
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
