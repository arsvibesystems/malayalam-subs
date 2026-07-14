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
  List<String> _selectedLanguages = [];
  List<String> _selectedGenres = [];
  List<String> _selectedSources = [];
  List<String> _selectedTranslators = [];
  List<String> _selectedReleaseTypes = [];
  String _sortBy = 'latest';

  // Getters
  List<Subtitle> get subtitles => _filteredSubtitles;
  List<Subtitle> get allSubtitles => _allSubtitles;
  SubtitleStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  List<String> get selectedLanguages => _selectedLanguages;
  List<String> get selectedGenres => _selectedGenres;
  List<String> get selectedSources => _selectedSources;
  List<String> get selectedTranslators => _selectedTranslators;
  List<String> get selectedReleaseTypes => _selectedReleaseTypes;
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
  void toggleLanguageFilter(String language) {
    if (_selectedLanguages.contains(language)) {
      _selectedLanguages.remove(language);
    } else {
      _selectedLanguages.add(language);
    }
    _applyFilters();
    notifyListeners();
  }

  /// Set genre filter
  void toggleGenreFilter(String genre) {
    if (_selectedGenres.contains(genre)) {
      _selectedGenres.remove(genre);
    } else {
      _selectedGenres.add(genre);
    }
    _applyFilters();
    notifyListeners();
  }

  /// Set source site filter
  void toggleSourceFilter(String source) {
    if (_selectedSources.contains(source)) {
      _selectedSources.remove(source);
    } else {
      _selectedSources.add(source);
    }
    _applyFilters();
    notifyListeners();
  }

  /// Set translator filter
  void toggleTranslatorFilter(String translator) {
    if (_selectedTranslators.contains(translator)) {
      _selectedTranslators.remove(translator);
    } else {
      _selectedTranslators.add(translator);
    }
    _applyFilters();
    notifyListeners();
  }

  /// Set release type filter
  void toggleReleaseTypeFilter(String type) {
    if (_selectedReleaseTypes.contains(type)) {
      _selectedReleaseTypes.remove(type);
    } else {
      _selectedReleaseTypes.add(type);
    }
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
    _selectedLanguages.clear();
    _selectedGenres.clear();
    _selectedSources.clear();
    _selectedTranslators.clear();
    _selectedReleaseTypes.clear();
    _sortBy = 'latest';
    _applyFilters();
    notifyListeners();
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedLanguages.isNotEmpty ||
      _selectedGenres.isNotEmpty ||
      _selectedSources.isNotEmpty ||
      _selectedTranslators.isNotEmpty ||
      _selectedReleaseTypes.isNotEmpty;

  /// Apply all active filters and sorting
  void _applyFilters() {
    var results = List<Subtitle>.from(_allSubtitles);

    // Search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      final cleanQuery = query.replaceAll('#', ''); // Allow searching like "#123"
      
      results = results.where((s) {
        final releaseNumStr = s.releaseNumber?.toString() ?? '';
        
        return s.title.toLowerCase().contains(query) ||
            s.translator.toLowerCase().contains(query) ||
            s.movieLanguage.toLowerCase().contains(query) ||
            s.genres.toLowerCase().contains(query) ||
            s.releaseType.toLowerCase().contains(query) ||
            (cleanQuery.isNotEmpty && releaseNumStr == cleanQuery);
      }).toList();
    }

    // Language filter
    if (_selectedLanguages.isNotEmpty) {
      results = results.where((s) => _selectedLanguages.any((lang) => 
          s.movieLanguage.toLowerCase().contains(lang.toLowerCase()))).toList();
    }

    // Genre filter
    if (_selectedGenres.isNotEmpty) {
      results = results.where((s) => _selectedGenres.any((genre) => 
          s.genres.toLowerCase().contains(genre.toLowerCase()))).toList();
    }

    // Source filter
    if (_selectedSources.isNotEmpty) {
      results = results.where((s) => _selectedSources.contains(s.sourceSite)).toList();
    }

    // Translator filter
    if (_selectedTranslators.isNotEmpty) {
      results = results.where((s) => _selectedTranslators.any((trans) => 
          s.translator.toLowerCase().contains(trans.toLowerCase()))).toList();
    }

    // Release type filter
    if (_selectedReleaseTypes.isNotEmpty) {
      results = results.where((s) => _selectedReleaseTypes.contains(s.releaseType)).toList();
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
      case 'oldest':
        results.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case 'release_desc':
        results.sort((a, b) => (b.releaseNumber ?? 0).compareTo(a.releaseNumber ?? 0));
        break;
      case 'release_asc':
        results.sort((a, b) => (a.releaseNumber ?? 0).compareTo(b.releaseNumber ?? 0));
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
