import 'package:flutter/material.dart';
import '../models/subtitle.dart';
import '../services/api_service.dart';

class SubtitleProvider extends ChangeNotifier {
  List<Subtitle> _allSubtitles = [];
  List<Subtitle> _filteredSubtitles = [];
  SubtitleStats _stats = SubtitleStats.empty();
  bool _isLoading = false;
  String? _error;

  // Filter state
  String _searchQuery = '';
  String? _selectedLanguage;
  String? _selectedGenre;
  String? _selectedSource;
  String? _selectedTranslator;
  String? _selectedReleaseType;
  double _minRating = 0;
  double _maxRating = 10;
  String _sortBy = 'latest';

  // Getters
  List<Subtitle> get subtitles => _filteredSubtitles;
  List<Subtitle> get allSubtitles => _allSubtitles;
  SubtitleStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedLanguage => _selectedLanguage;
  String? get selectedGenre => _selectedGenre;
  String? get selectedSource => _selectedSource;
  String? get selectedTranslator => _selectedTranslator;
  String? get selectedReleaseType => _selectedReleaseType;
  double get minRating => _minRating;
  double get maxRating => _maxRating;
  String get sortBy => _sortBy;

  /// Load all subtitles and stats from the API
  Future<void> loadSubtitles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiService.fetchSubtitles(),
        ApiService.fetchStats(),
      ]);

      _allSubtitles = results[0] as List<Subtitle>;
      _stats = results[1] as SubtitleStats;
      _applyFilters();
    } catch (e) {
      _error = e.toString();
      // For demo/offline: load sample data
      _loadSampleData();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Search by title
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Set language filter
  void setLanguageFilter(String? language) {
    _selectedLanguage = language;
    _applyFilters();
    notifyListeners();
  }

  /// Set genre filter
  void setGenreFilter(String? genre) {
    _selectedGenre = genre;
    _applyFilters();
    notifyListeners();
  }

  /// Set source site filter
  void setSourceFilter(String? source) {
    _selectedSource = source;
    _applyFilters();
    notifyListeners();
  }

  /// Set translator filter
  void setTranslatorFilter(String? translator) {
    _selectedTranslator = translator;
    _applyFilters();
    notifyListeners();
  }

  /// Set release type filter
  void setReleaseTypeFilter(String? type) {
    _selectedReleaseType = type;
    _applyFilters();
    notifyListeners();
  }

  /// Set rating range
  void setRatingRange(double min, double max) {
    _minRating = min;
    _maxRating = max;
    _applyFilters();
    notifyListeners();
  }

  /// Set sort order
  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    _applyFilters();
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _selectedLanguage = null;
    _selectedGenre = null;
    _selectedSource = null;
    _selectedTranslator = null;
    _selectedReleaseType = null;
    _minRating = 0;
    _maxRating = 10;
    _sortBy = 'latest';
    _applyFilters();
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedLanguage != null ||
      _selectedGenre != null ||
      _selectedSource != null ||
      _selectedTranslator != null ||
      _selectedReleaseType != null ||
      _minRating > 0 ||
      _maxRating < 10;

  /// Apply all active filters and sorting
  void _applyFilters() {
    var results = List<Subtitle>.from(_allSubtitles);

    // Search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      results = results.where((s) {
        return s.title.toLowerCase().contains(query) ||
            s.translator.toLowerCase().contains(query) ||
            s.movieLanguage.toLowerCase().contains(query) ||
            s.genres.toLowerCase().contains(query);
      }).toList();
    }

    // Language filter
    if (_selectedLanguage != null) {
      results = results.where((s) =>
          s.movieLanguage.toLowerCase().contains(_selectedLanguage!.toLowerCase())
      ).toList();
    }

    // Genre filter
    if (_selectedGenre != null) {
      results = results.where((s) =>
          s.genres.toLowerCase().contains(_selectedGenre!.toLowerCase())
      ).toList();
    }

    // Source filter
    if (_selectedSource != null) {
      results = results.where((s) => s.sourceSite == _selectedSource).toList();
    }

    // Translator filter
    if (_selectedTranslator != null) {
      results = results.where((s) =>
          s.translator.toLowerCase().contains(_selectedTranslator!.toLowerCase())
      ).toList();
    }

    // Release type filter
    if (_selectedReleaseType != null) {
      results = results.where((s) => s.releaseType == _selectedReleaseType).toList();
    }

    // Rating filter
    if (_minRating > 0 || _maxRating < 10) {
      results = results.where((s) {
        if (s.imdbRating == null) return _minRating == 0;
        return s.imdbRating! >= _minRating && s.imdbRating! <= _maxRating;
      }).toList();
    }

    // Sorting
    switch (_sortBy) {
      case 'rating':
        results.sort((a, b) => (b.imdbRating ?? 0).compareTo(a.imdbRating ?? 0));
        break;
      case 'title':
        results.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'year':
        results.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
        break;
      case 'latest':
      default:
        results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }

    _filteredSubtitles = results;
  }

  /// Load sample data for offline/demo mode
  void _loadSampleData() {
    _allSubtitles = [
      Subtitle(
        title: 'The Furious / ദ ഫ്യൂരിയസ് (2025)',
        slug: 'msone_the-furious-2025',
        thumbnailUrl: 'https://malayalamsubtitles.org/wp-content/uploads/2026/07/The-Furious.jpg',
        movieLanguage: 'English, Thai',
        genres: 'Action, Crime, Thriller',
        imdbRating: 7.7,
        imdbUrl: 'https://www.imdb.com/title/tt33311069/',
        translator: 'വിഷ് ആസാദ്',
        sourceSite: 'msone',
        sourceUrl: 'https://malayalamsubtitles.org/languages/english/the-furious-2025/',
        downloadUrl: 'https://malayalamsubtitles.org/languages/english/the-furious-2025/',
        releaseType: 'movie',
        year: 2025,
        certificate: 'R',
        description: 'A Hong Kong action film directed by Kenji Tanigaki.',
        createdAt: '2026-07-13T08:00:00Z',
        updatedAt: '2026-07-13T08:00:00Z',
      ),
      Subtitle(
        title: 'House of the Dragon Season 3 / ഹൗസ് ഓഫ് ദ ഡ്രാഗൺ സീസൺ 3 (2026)',
        slug: 'msone_house-of-the-dragon-s3',
        thumbnailUrl: 'https://malayalamsubtitles.org/wp-content/uploads/2026/06/House-of-the-dragon-S03-E3.jpg',
        movieLanguage: 'English',
        genres: 'Action, Drama',
        imdbRating: 8.3,
        imdbUrl: 'https://www.imdb.com/title/tt11198330/',
        translator: 'വിഷ്‌ണു പ്രസാദ്',
        sourceSite: 'msone',
        sourceUrl: 'https://malayalamsubtitles.org/languages/english/house-of-the-dragon-season-3-2026/',
        downloadUrl: 'https://malayalamsubtitles.org/languages/english/house-of-the-dragon-season-3-2026/',
        releaseType: 'series',
        year: 2026,
        certificate: '',
        description: 'House of the Dragon Season 3',
        createdAt: '2026-07-13T07:00:00Z',
        updatedAt: '2026-07-13T07:00:00Z',
      ),
      Subtitle(
        title: 'Agent Kim Reactivated / ഏജന്റ് കിം റീ ആക്ടിവേറ്റഡ് (2026)',
        slug: 'msone_agent-kim-reactivated-2026',
        thumbnailUrl: 'https://malayalamsubtitles.org/wp-content/uploads/2026/07/Agent-Kim-Reactivated-3-4.Bw_.jpg',
        movieLanguage: 'Korean',
        genres: 'Action, Crime, Thriller',
        imdbRating: 8.1,
        imdbUrl: 'https://www.imdb.com/title/tt42127457/',
        translator: 'അരവിന്ദ് കുമാർ',
        sourceSite: 'msone',
        sourceUrl: 'https://malayalamsubtitles.org/languages/korean/agent-kim-reactivated-2026/',
        downloadUrl: 'https://malayalamsubtitles.org/languages/korean/agent-kim-reactivated-2026/',
        releaseType: 'series',
        year: 2026,
        certificate: '',
        description: 'Agent Kim Reactivated',
        createdAt: '2026-07-13T06:00:00Z',
        updatedAt: '2026-07-13T06:00:00Z',
      ),
    ];
    _applyFilters();
  }
}
