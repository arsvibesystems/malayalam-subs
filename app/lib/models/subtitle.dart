/// Data model for a subtitle entry.
class Subtitle {
  final String title;
  final String slug;
  final String thumbnailUrl;
  final String movieLanguage;
  final String genres;
  final double? imdbRating;
  final String imdbUrl;
  final String translator;
  final String sourceSite;
  final String sourceUrl;
  final String downloadUrl;
  final String releaseType;
  final int? year;
  final String certificate;
  final String description;
  final String createdAt;
  final String updatedAt;
  final int? releaseNumber;

  Subtitle({
    required this.title,
    required this.slug,
    required this.thumbnailUrl,
    required this.movieLanguage,
    required this.genres,
    this.imdbRating,
    required this.imdbUrl,
    required this.translator,
    required this.sourceSite,
    required this.sourceUrl,
    required this.downloadUrl,
    required this.releaseType,
    this.year,
    required this.certificate,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.releaseNumber,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      movieLanguage: json['movie_language'] ?? '',
      genres: json['genres'] ?? '',
      imdbRating: json['imdb_rating'] != null
          ? (json['imdb_rating'] as num).toDouble()
          : null,
      imdbUrl: json['imdb_url'] ?? '',
      translator: json['translator'] ?? '',
      sourceSite: json['source_site'] ?? '',
      sourceUrl: json['source_url'] ?? '',
      downloadUrl: json['download_url'] ?? '',
      releaseType: json['release_type'] ?? 'movie',
      year: json['year'],
      certificate: json['certificate'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      releaseNumber: json['release_number'],
    );
  }

  /// Split genres string into a list
  List<String> get genreList =>
      genres.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList();

  /// Split language string into a list
  List<String> get languageList =>
      movieLanguage.split(',').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  /// Short title (English part only before the slash)
  String get shortTitle {
    if (title.contains('/')) {
      return title.split('/').first.trim();
    }
    // Remove Malayalam part if it exists after a dash/em-dash
    if (title.contains('–')) {
      return title.split('–').first.trim();
    }
    return title;
  }

  /// Malayalam title part (after the slash)
  String get malayalamTitle {
    if (title.contains('/')) {
      return title.split('/').last.trim();
    }
    if (title.contains('–')) {
      return title.split('–').last.trim();
    }
    return '';
  }
}

class SourceStats {
  final int total;
  final int movies;
  final int series;

  SourceStats({
    required this.total,
    required this.movies,
    required this.series,
  });

  factory SourceStats.fromJson(Map<String, dynamic> json) {
    return SourceStats(
      total: json['total'] ?? 0,
      movies: json['movies'] ?? 0,
      series: json['series'] ?? 0,
    );
  }
}

/// Stats/filter metadata from the API
class SubtitleStats {
  final int totalCount;
  final String lastUpdated;
  final Map<String, SourceStats> perSource;
  final SubtitleFilters filters;

  SubtitleStats({
    required this.totalCount,
    required this.lastUpdated,
    required this.perSource,
    required this.filters,
  });

  factory SubtitleStats.fromJson(Map<String, dynamic> json) {
    final perSource = <String, SourceStats>{};
    if (json['per_source'] != null) {
      (json['per_source'] as Map).forEach((k, v) {
        if (v is Map<String, dynamic>) {
          perSource[k.toString()] = SourceStats.fromJson(v);
        } else if (v is int) {
          // Fallback for older stats format
          perSource[k.toString()] = SourceStats(total: v, movies: v, series: 0);
        }
      });
    }
    return SubtitleStats(
      totalCount: json['total_count'] ?? 0,
      lastUpdated: json['last_updated'] ?? '',
      perSource: perSource,
      filters: SubtitleFilters.fromJson(json['filters'] ?? {}),
    );
  }

  factory SubtitleStats.empty() {
    return SubtitleStats(
      totalCount: 0,
      lastUpdated: '',
      perSource: {},
      filters: SubtitleFilters.empty(),
    );
  }
}

class SubtitleFilters {
  final List<String> languages;
  final List<String> genres;
  final List<String> translators;
  final List<String> sources;
  final List<String> releaseTypes;

  SubtitleFilters({
    required this.languages,
    required this.genres,
    required this.translators,
    required this.sources,
    required this.releaseTypes,
  });

  factory SubtitleFilters.fromJson(Map<String, dynamic> json) {
    return SubtitleFilters(
      languages: List<String>.from(json['languages'] ?? []),
      genres: List<String>.from(json['genres'] ?? []),
      translators: List<String>.from(json['translators'] ?? []),
      sources: List<String>.from(json['sources'] ?? []),
      releaseTypes: List<String>.from(json['release_types'] ?? []),
    );
  }

  factory SubtitleFilters.empty() {
    return SubtitleFilters(
      languages: [],
      genres: [],
      translators: [],
      sources: [],
      releaseTypes: [],
    );
  }
}
