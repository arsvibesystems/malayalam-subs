import 'package:flutter_test/flutter_test.dart';
import 'package:malayalam_subs_app/models/subtitle.dart';
import 'package:malayalam_subs_app/services/addon_service.dart';
import 'package:malayalam_subs_app/widgets/poster_image.dart';

void main() {
  group('Subtitle model addon fields', () {
    test('extracts imdbId from explicit field or falls back to imdb_url', () {
      final fromField = Subtitle.fromJson({
        'title': 'Sore: A Wife from the Future (2025)',
        'slug': 'msone_sore-2025',
        'thumbnail_url': 'https://example.com/poster.webp',
        'backdrop_url': 'https://example.com/bg.webp',
        'imdb_id': 'tt34548722',
        'imdb_url': '',
        'source_site': 'msone',
      });

      expect(fromField.imdbId, 'tt34548722');
      expect(fromField.hasImdbId, isTrue);
      expect(fromField.imdbUrl, 'https://www.imdb.com/title/tt34548722/');
      expect(fromField.effectiveBackdropUrl, 'https://example.com/bg.webp');

      final fromUrl = Subtitle.fromJson({
        'title': 'Pleasure (2021)',
        'slug': 'moviemirror_pleasure-2021',
        'thumbnail_url': 'https://example.com/poster.jpg',
        'imdb_url': 'https://www.imdb.com/title/tt8550054/?ref_=ext_shr',
        'source_site': 'moviemirror',
      });

      expect(fromUrl.imdbId, 'tt8550054');
      expect(fromUrl.hasImdbId, isTrue);
      expect(fromUrl.effectiveBackdropUrl, 'https://example.com/poster.jpg');
    });
  });

  group('AddonSubtitleOption', () {
    test('parses MSone series tot parameter and matches GOAT/MM source IDs', () {
      final msoneSeries = AddonSubtitleOption.fromJson({
        'id': 'tt19875850-0',
        'url':
            'https://addon.malayalamsubtitles.org/subfiles/tt19875850/s1/ep1.srt?e=1&pid=53678&tot=6&sig=abc',
        'lang': 'mal',
        'label': 'Tekken.Bloodline.S01E01.Msone.srt',
      });

      expect(msoneSeries.totalEpisodes, 6);
      expect(msoneSeries.label, 'Tekken.Bloodline.S01E01.Msone.srt');
      expect(msoneSeries.matchesSource('msone'), isTrue);

      final goatOption = AddonSubtitleOption.fromJson({
        'id': 'goat-tt33764258',
        'url': 'https://malayalam-subs.onrender.com/sub/123.srt',
        'lang': 'Malayalam (Team GOAT)',
      });
      final mmOption = AddonSubtitleOption.fromJson({
        'id': 'moviemirror-tt33764258',
        'url': 'https://malayalam-subs.onrender.com/sub/456.srt',
        'lang': 'Malayalam (Movie Mirror)',
      });

      expect(goatOption.matchesSource('teamgoat'), isTrue);
      expect(goatOption.matchesSource('moviemirror'), isFalse);
      expect(mmOption.matchesSource('moviemirror'), isTrue);
      expect(mmOption.matchesSource('teamgoat'), isFalse);
    });
  });

  group('PosterImage helpers', () {
    test('adds site Referer header and builds Metahub fallback URLs', () {
      final msoneHeaders = PosterImage.headersFor(
        'https://malayalamsubtitles.org/wp-content/uploads/2026/09/test.jpg',
      );
      expect(msoneHeaders['Referer'], 'https://malayalamsubtitles.org/');
      expect(msoneHeaders['User-Agent'], isNotEmpty);

      expect(
        PosterImage.metahubUrl('tt0088847'),
        'https://images.metahub.space/poster/medium/tt0088847/img',
      );
      expect(
        PosterImage.metahubUrl('tt0088847', large: true),
        'https://images.metahub.space/poster/large/tt0088847/img',
      );
    });
  });
}

