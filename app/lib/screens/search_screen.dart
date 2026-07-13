import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/subtitle_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/subtitle_card.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubtitleProvider>();
    _searchController.text = provider.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<SubtitleProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                // Search bar + back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          provider.clearFilters();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Search movies, series, translators...',
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.setSearchQuery('');
                                    },
                                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            provider.setSearchQuery(value);
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter toggle
                      GestureDetector(
                        onTap: () => setState(() => _showFilters = !_showFilters),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _showFilters || provider.hasActiveFilters
                                ? AppTheme.accent.withValues(alpha: 0.2)
                                : AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: provider.hasActiveFilters
                                  ? AppTheme.accent
                                  : AppTheme.dividerColor,
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: provider.hasActiveFilters
                                      ? AppTheme.accent
                                      : AppTheme.textPrimary,
                                  size: 22,
                                ),
                              ),
                              if (provider.hasActiveFilters)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter panel (collapsible)
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _buildFilterPanel(provider),
                  crossFadeState: _showFilters
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),

                // Results count + sort
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        '${provider.subtitles.length} results',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (provider.hasActiveFilters)
                        GestureDetector(
                          onTap: () {
                            provider.clearFilters();
                            _searchController.clear();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.clear_all_rounded, color: AppTheme.accent, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Clear all',
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      _buildSortDropdown(provider),
                    ],
                  ),
                ),

                // Results grid
                Expanded(
                  child: provider.subtitles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 56, color: AppTheme.textMuted),
                              const SizedBox(height: 12),
                              const Text(
                                'No matches found',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : AnimationLimiter(
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: (MediaQuery.of(context).size.width / 160).floor().clamp(2, 6),
                              childAspectRatio: 0.58,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: provider.subtitles.length,
                            itemBuilder: (context, index) {
                              final subtitle = provider.subtitles[index];
                              return AnimationConfiguration.staggeredGrid(
                                position: index,
                                columnCount: 2,
                                duration: const Duration(milliseconds: 375),
                                child: ScaleAnimation(
                                  child: FadeInAnimation(
                                    child: SubtitleCard(
                                      subtitle: subtitle,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DetailScreen(subtitle: subtitle),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterPanel(SubtitleProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADVANCED FILTERS',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // Language filter
          _buildFilterDropdown(
            'Movie Language',
            Icons.language_rounded,
            provider.selectedLanguage,
            provider.stats.filters.languages,
            (val) => provider.setLanguageFilter(val),
          ),
          const SizedBox(height: 10),

          // Genre filter
          _buildFilterDropdown(
            'Genre',
            Icons.theater_comedy_rounded,
            provider.selectedGenre,
            provider.stats.filters.genres,
            (val) => provider.setGenreFilter(val),
          ),
          const SizedBox(height: 10),

          // Source filter
          _buildFilterDropdown(
            'Source Site',
            Icons.public_rounded,
            provider.selectedSource,
            provider.stats.filters.sources,
            (val) => provider.setSourceFilter(val),
          ),
          const SizedBox(height: 10),

          // Translator filter
          _buildFilterDropdown(
            'Translator',
            Icons.person_rounded,
            provider.selectedTranslator,
            provider.stats.filters.translators,
            (val) => provider.setTranslatorFilter(val),
          ),
          const SizedBox(height: 10),

          // Release type filter
          _buildFilterDropdown(
            'Type',
            Icons.movie_rounded,
            provider.selectedReleaseType,
            provider.stats.filters.releaseTypes,
            (val) => provider.setReleaseTypeFilter(val),
          ),
          const SizedBox(height: 14),

          // IMDB Rating slider
          const Text(
            'IMDb Rating',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          RangeSlider(
            values: RangeValues(provider.minRating, provider.maxRating),
            min: 0,
            max: 10,
            divisions: 20,
            activeColor: AppTheme.accentGold,
            inactiveColor: AppTheme.bgCardLight,
            labels: RangeLabels(
              provider.minRating.toStringAsFixed(1),
              provider.maxRating.toStringAsFixed(1),
            ),
            onChanged: (values) {
              provider.setRatingRange(values.start, values.end);
            },
          ),
          Center(
            child: Text(
              '${provider.minRating.toStringAsFixed(1)} — ${provider.maxRating.toStringAsFixed(1)}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    IconData icon,
    String? selectedValue,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedValue,
          isExpanded: true,
          dropdownColor: AppTheme.bgCard,
          icon: const Icon(Icons.expand_more_rounded, color: AppTheme.textMuted),
          hint: Row(
            children: [
              Icon(icon, color: AppTheme.textMuted, size: 18),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
            ],
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All $label', style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ...options.map((opt) => DropdownMenuItem(
              value: opt,
              child: Text(
                opt,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSortDropdown(SubtitleProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.sortBy,
          dropdownColor: AppTheme.bgCard,
          icon: const Icon(Icons.sort_rounded, color: AppTheme.textMuted, size: 18),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'latest', child: Text('Latest')),
            DropdownMenuItem(value: 'rating', child: Text('Rating ↓')),
            DropdownMenuItem(value: 'title', child: Text('A-Z')),
            DropdownMenuItem(value: 'year', child: Text('Year ↓')),
          ],
          onChanged: (val) {
            if (val != null) provider.setSortBy(val);
          },
        ),
      ),
    );
  }
}
