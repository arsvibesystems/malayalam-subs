import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../providers/subtitle_provider.dart';
import '../models/subtitle.dart';
import '../theme/app_theme.dart';
import '../widgets/subtitle_card.dart';
import 'detail_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        // App title
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [AppTheme.accent, AppTheme.accentGold],
                                ).createShader(bounds),
                                child: const Text(
                                  'മലയാളം Subs',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
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
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SearchScreen()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Settings button
                        _buildIconButton(
                          icon: Icons.settings_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Stats bar
                if (!provider.isLoading && provider.allSubtitles.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildStatsBar(provider),
                  ),

                // Content
                if (provider.isLoading)
                  SliverToBoxAdapter(child: _buildLoadingState())
                else if (provider.error != null && provider.allSubtitles.isEmpty)
                  SliverToBoxAdapter(child: _buildErrorState(provider))
                else if (provider.allSubtitles.isEmpty)
                  SliverToBoxAdapter(child: _buildEmptyState())
                else
                  ..._buildNetflixLayout(context, provider),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
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

  Widget _buildStatsBar(SubtitleProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.15),
            AppTheme.accentGold.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            '${provider.allSubtitles.length}',
            'Total',
            Icons.subtitles_rounded,
          ),
          _buildStatDivider(),
          _buildStatItem(
            '${provider.allSubtitles.where((s) => s.releaseType == "movie").length}',
            'Movies',
            Icons.movie_rounded,
          ),
          _buildStatDivider(),
          _buildStatItem(
            '${provider.allSubtitles.where((s) => s.releaseType == "series").length}',
            'Series',
            Icons.tv_rounded,
          ),
          _buildStatDivider(),
          _buildStatItem(
            '${provider.stats.perSource.length}',
            'Sources',
            Icons.language_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accentGold, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: AppTheme.dividerColor,
    );
  }

  List<Widget> _buildNetflixLayout(BuildContext context, SubtitleProvider provider) {
    // Top 15 Latest
    final latest = provider.allSubtitles.take(15).toList();
    // Top 15 Movies
    final movies = provider.allSubtitles.where((s) => s.releaseType != 'series').take(15).toList();
    // Top 15 Series
    final series = provider.allSubtitles.where((s) => s.releaseType == 'series').take(15).toList();

    return [
      _buildCategoriesRow(context, provider),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
      _buildHorizontalList(context, 'Latest Releases', latest),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      _buildHorizontalList(context, 'Movies', movies),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (series.isNotEmpty) _buildHorizontalList(context, 'Series', series),
    ];
  }

  Widget _buildCategoriesRow(BuildContext context, SubtitleProvider provider) {
    final categories = ['Thriller', 'Horror', 'Action', 'Romance', 'Comedy', 'Drama', 'Sci-Fi'];
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
                  provider.setGenreFilter(cat);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
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

  Widget _buildHorizontalList(BuildContext context, String title, List<Subtitle> items) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            height: 260, // Fixed height for standard thumbnail size
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
                      onTap: () => Navigator.push(
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
            itemBuilder: (_, __) => Padding(
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
