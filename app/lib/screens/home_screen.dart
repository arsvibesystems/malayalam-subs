import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/subtitle_provider.dart';
import '../models/subtitle.dart';
import '../theme/app_theme.dart';
import '../widgets/subtitle_card.dart';
import 'detail_screen.dart';
import 'search_screen.dart';
import 'category_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Consumer<SubtitleProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: () => provider.loadSubtitles(),
              color: AppTheme.accent,
              backgroundColor: AppTheme.bgCard,
              child: CustomScrollView(
                slivers: [
                  // Custom App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          // Drawer Menu Button
                          Builder(
                            builder:
                                (context) => _buildIconButton(
                                  icon: Icons.menu_rounded,
                                  onTap:
                                      () => Scaffold.of(context).openDrawer(),
                                ),
                          ),
                          const SizedBox(width: 12),
                          // App title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Malayalam Subs',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  provider.isLoading
                                      ? 'Loading subtitles...'
                                      : '${provider.allSubtitles.length} subtitles available',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Search button
                          _buildIconButton(
                            icon: Icons.search_rounded,
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SearchScreen(),
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Content
                  if (provider.isLoading)
                    SliverToBoxAdapter(child: _buildLoadingState())
                  else if (provider.error != null &&
                      provider.allSubtitles.isEmpty)
                    SliverToBoxAdapter(child: _buildErrorState(provider))
                  else if (provider.allSubtitles.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else
                    ..._buildNetflixLayout(context, provider),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColor, width: 1),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 22),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final provider = Provider.of<SubtitleProvider>(context);
    return Drawer(
      backgroundColor: AppTheme.bgDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: const Border(
                  bottom: BorderSide(color: AppTheme.dividerColor),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.query_stats_rounded,
                    color: AppTheme.accent,
                    size: 40,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Stats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (!provider.isLoading && provider.allSubtitles.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildDrawerStatRow(
                          '${provider.allSubtitles.length}',
                          'Total Subtitles',
                          Icons.subtitles_rounded,
                        ),
                        const SizedBox(height: 24),
                        _buildDrawerStatRow(
                          '${provider.allSubtitles.where((s) => s.releaseType == "movie").length}',
                          'Movies',
                          Icons.movie_rounded,
                        ),
                        const SizedBox(height: 24),
                        _buildDrawerStatRow(
                          '${provider.allSubtitles.where((s) => s.releaseType == "series").length}',
                          'Series',
                          Icons.tv_rounded,
                        ),
                        const SizedBox(height: 24),
                        _buildDrawerStatRow(
                          '${provider.stats.perSource.length}',
                          'Sources',
                          Icons.language_rounded,
                        ),
                        const SizedBox(height: 16),
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            collapsedIconColor: AppTheme.textMuted,
                            iconColor: AppTheme.accentGold,
                            title: const Text(
                              'Sources Breakdown',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            children: provider.stats.perSource.entries.map((entry) {
                              final site = entry.key;
                              final siteStats = entry.value;
                              String displayName = site;
                              if (site == 'teamgoat') displayName = 'Team GOAT';
                              if (site == 'msone') displayName = 'MSone';
                              if (site == 'moviemirror') displayName = 'Movie Mirror';
    
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgCardLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: AppTheme.accentGold,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildMiniStat('Total', siteStats.total),
                                          _buildMiniStat('Movies', siteStats.movies),
                                          _buildMiniStat('Series', siteStats.series),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerStatRow(String value, String label, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgCardLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.accentGold, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildNetflixLayout(
    BuildContext context,
    SubtitleProvider provider,
  ) {
    // Top 15 Latest
    final latest = provider.allSubtitles.take(15).toList();
    // Top 15 Movies
    final movies =
        provider.allSubtitles
            .where((s) => s.releaseType != 'series')
            .take(15)
            .toList();
    // Top 15 Series
    final series =
        provider.allSubtitles
            .where((s) => s.releaseType == 'series')
            .take(15)
            .toList();

    return [
      _buildCategoriesRow(context, provider),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
      _buildHorizontalList(
        context,
        'Latest Releases',
        latest,
        onSeeMore: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CategoryScreen(title: 'Latest Releases'),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      _buildHorizontalList(
        context,
        'Movies',
        movies,
        onSeeMore: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CategoryScreen(
              title: 'All Movies',
              releaseTypeFilter: 'movie',
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (series.isNotEmpty)
        _buildHorizontalList(
          context,
          'Series',
          series,
          onSeeMore: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CategoryScreen(
                title: 'All Series',
                releaseTypeFilter: 'series',
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildCategoriesRow(BuildContext context, SubtitleProvider provider) {
    final categories = [
      'Thriller',
      'Horror',
      'Action',
      'Romance',
      'Comedy',
      'Drama',
      'Sci-Fi',
    ];
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  provider.clearFilters();
                  provider.toggleGenreFilter(cat);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 0,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Text(
                    cat,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalList(
    BuildContext context,
    String title,
    List<Subtitle> items, {
    VoidCallback? onSeeMore,
  }) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onSeeMore != null)
                  TextButton(
                    onPressed: onSeeMore,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'See More >',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 210, // Fixed height for 2:3 poster aspect ratio
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final subtitle = items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 140, // Standard poster width
                    child: SubtitleCard(
                      subtitle: subtitle,
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailScreen(subtitle: subtitle),
                            ),
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerRow(),
          const SizedBox(height: 24),
          _buildShimmerRow(),
        ],
      ),
    );
  }

  Widget _buildShimmerRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shimmer.fromColors(
          baseColor: AppTheme.bgCard,
          highlightColor: AppTheme.bgCardLight,
          child: Container(
            width: 150,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder:
                (_, __) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Shimmer.fromColors(
                    baseColor: AppTheme.bgCard,
                    highlightColor: AppTheme.bgCardLight,
                    child: Container(
                      width: 140,
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(SubtitleProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(Icons.cloud_off_rounded, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Unable to load subtitles',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection or update the data URL in settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.loadSubtitles(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(Icons.search_off_rounded, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No subtitles found',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
