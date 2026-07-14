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
    return WillPopScope(
      onWillPop: () async {
        context.read<SubtitleProvider>().clearFilters();
        return true;
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
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

                // Active filters and clear all
                _buildActiveFilters(provider),

                // Results count
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
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: (MediaQuery.of(context).size.width / 160).floor().clamp(2, 6),
                              childAspectRatio: 0.66,
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
    ),
    ),
    );
  }

  Widget _buildActiveFilters(SubtitleProvider provider) {
    if (!provider.hasActiveFilters) return const SizedBox.shrink();

    final List<Widget> chips = [];
    
    void addChips(List<String> items, Function(String) onRemove) {
      for (final item in items) {
        chips.add(
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              label: Text(item, style: const TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: AppTheme.bgCard,
              deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
              onDeleted: () => onRemove(item),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: AppTheme.dividerColor),
            ),
          ),
        );
      }
    }

    addChips(provider.selectedLanguages, provider.toggleLanguageFilter);
    addChips(provider.selectedGenres, provider.toggleGenreFilter);
    addChips(provider.selectedSources, provider.toggleSourceFilter);
    addChips(provider.selectedTranslators, provider.toggleTranslatorFilter);
    addChips(provider.selectedReleaseTypes, provider.toggleReleaseTypeFilter);

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ACTIVE FILTERS',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                onTap: () {
                  provider.clearFilters();
                  _searchController.clear();
                },
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        ],
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
          _buildMultiSelectField(
            'Movie Language',
            Icons.language_rounded,
            provider.selectedLanguages,
            provider.stats.filters.languages,
            (val) => provider.toggleLanguageFilter(val),
          ),
          const SizedBox(height: 10),

          // Genre filter
          _buildMultiSelectField(
            'Genre',
            Icons.theater_comedy_rounded,
            provider.selectedGenres,
            provider.stats.filters.genres,
            (val) => provider.toggleGenreFilter(val),
          ),
          const SizedBox(height: 10),

          // Source filter
          _buildMultiSelectField(
            'Source Site',
            Icons.public_rounded,
            provider.selectedSources,
            provider.stats.filters.sources,
            (val) => provider.toggleSourceFilter(val),
          ),
          const SizedBox(height: 10),

          // Translator filter
          _buildMultiSelectField(
            'Translator',
            Icons.person_rounded,
            provider.selectedTranslators,
            provider.stats.filters.translators,
            (val) => provider.toggleTranslatorFilter(val),
          ),
          const SizedBox(height: 10),

          // Release type filter
          _buildMultiSelectField(
            'Type',
            Icons.movie_rounded,
            provider.selectedReleaseTypes,
            provider.stats.filters.releaseTypes,
            (val) => provider.toggleReleaseTypeFilter(val),
          ),
          const SizedBox(height: 14),

          // Sort By Section
          const Text(
            'SORT BY',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSortChip('Latest', 'latest', provider),
              _buildSortChip('Oldest', 'oldest', provider),
              _buildSortChip('Rating ↓', 'rating', provider),
              _buildSortChip('A-Z', 'title', provider),
              _buildSortChip('Release No. ↑', 'release_asc', provider),
              _buildSortChip('Release No. ↓', 'release_desc', provider),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => _showFilters = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Show Results',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectField(
    String label,
    IconData icon,
    List<String> selectedValues,
    List<String> options,
    ValueChanged<String> onToggle,
  ) {
    return GestureDetector(
      onTap: () {
        _showMultiSelectSheet(label, options, selectedValues, onToggle);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.textMuted, size: 18),
                const SizedBox(width: 10),
                Text(
                  selectedValues.isEmpty
                      ? 'All $label'
                      : '$label (${selectedValues.length})',
                  style: TextStyle(
                    color: selectedValues.isEmpty ? AppTheme.textMuted : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: selectedValues.isEmpty ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Icon(Icons.expand_more_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  void _showMultiSelectSheet(
    String title,
    List<String> options,
    List<String> selectedValues,
    ValueChanged<String> onToggle,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  Text('Select $title', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.dividerColor, height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = selectedValues.contains(option);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(option, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textSecondary)),
                          activeColor: AppTheme.accent,
                          checkColor: Colors.white,
                          side: const BorderSide(color: AppTheme.textMuted),
                          onChanged: (val) {
                            onToggle(option);
                            setSheetState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortChip(String label, String value, SubtitleProvider provider) {
    final isSelected = provider.sortBy == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.accent,
      backgroundColor: AppTheme.bgDark,
      side: BorderSide(
        color: isSelected ? AppTheme.accent : AppTheme.dividerColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      onSelected: (selected) {
        if (selected) provider.setSortBy(value);
      },
    );
  }
}
