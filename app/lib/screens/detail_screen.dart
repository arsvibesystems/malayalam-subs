import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/subtitle.dart';
import '../theme/app_theme.dart';

class DetailScreen extends StatelessWidget {
  final Subtitle subtitle;

  const DetailScreen({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero poster with back button
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.5,
            pinned: true,
            backgroundColor: AppTheme.bgDark,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'poster_${subtitle.slug}',
                    child: CachedNetworkImage(
                      imageUrl: subtitle.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.bgCardLight,
                        child: const Icon(Icons.movie_outlined, size: 80, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          AppTheme.bgDark.withValues(alpha: 0.7),
                          AppTheme.bgDark,
                        ],
                        stops: const [0.0, 0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverSafeArea(
            top: false,
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    subtitle.shortTitle,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle.malayalamTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle.malayalamTitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Metadata chips row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (subtitle.year != null)
                        _buildChip('${subtitle.year}', Icons.calendar_today_rounded),
                      if (subtitle.movieLanguage.isNotEmpty)
                        ...subtitle.languageList.take(2).map(
                          (lang) => _buildChip(lang, Icons.language_rounded),
                        ),
                      if (subtitle.releaseType.isNotEmpty)
                        _buildChip(
                          subtitle.releaseType == 'series' ? 'Series' : 'Movie',
                          subtitle.releaseType == 'series' ? Icons.tv_rounded : Icons.movie_rounded,
                        ),
                      if (subtitle.certificate.isNotEmpty && subtitle.certificate.length < 10)
                        _buildChip(subtitle.certificate, Icons.verified_rounded),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // IMDB Rating & Source
                  Row(
                    children: [
                      // IMDB Rating
                      if (subtitle.imdbRating != null)
                        GestureDetector(
                          onTap: subtitle.imdbUrl.isNotEmpty
                              ? () => _launchUrl(subtitle.imdbUrl)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: AppTheme.accentGold, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${subtitle.imdbRating!.toStringAsFixed(1)}/10 IMDb',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const Spacer(),

                      // Source site badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.getSourceColor(subtitle.sourceSite).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.getSourceColor(subtitle.sourceSite).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.public_rounded,
                              color: AppTheme.getSourceColor(subtitle.sourceSite),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppTheme.getSourceLabel(subtitle.sourceSite),
                              style: TextStyle(
                                color: AppTheme.getSourceColor(subtitle.sourceSite),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Genre chips
                  if (subtitle.genres.isNotEmpty) ...[
                    const Text(
                      'GENRES',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subtitle.genreList.map((genre) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            genre,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Translator
                  if (subtitle.translator.isNotEmpty) ...[
                    _buildInfoRow(
                      Icons.person_rounded,
                      'Translated by',
                      subtitle.translator,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Release Number
                  if (subtitle.releaseNumber != null) ...[
                    Builder(
                      builder: (ctx) => _buildInfoRow(
                        Icons.numbers_rounded,
                        'Release Number',
                        '${subtitle.releaseNumber}',
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppTheme.accentTeal, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: subtitle.releaseNumber.toString()));
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: const Text('Release number copied to clipboard!'),
                                backgroundColor: AppTheme.accentTeal,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  if (subtitle.description.isNotEmpty &&
                      subtitle.description.length > 10) ...[
                    const Text(
                      'ABOUT',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle.description,
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action buttons
                  _buildDownloadButton(context),
                  const SizedBox(height: 12),
                  _buildSecondaryButton(
                    'View on ${AppTheme.getSourceLabel(subtitle.sourceSite)}',
                    Icons.open_in_new_rounded,
                    () => _launchUrl(subtitle.sourceUrl),
                  ),
                  if (subtitle.imdbUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSecondaryButton(
                      'View on IMDb',
                      Icons.movie_rounded,
                      () => _launchUrl(subtitle.imdbUrl),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentTeal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _handleDownload(context),
        icon: const Icon(Icons.download_rounded, size: 22),
        label: const Text(
          'Download Subtitle',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppTheme.accent.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppTheme.dividerColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _handleDownload(BuildContext context) {
    final url = subtitle.downloadUrl.isNotEmpty ? subtitle.downloadUrl : subtitle.sourceUrl;
    // Redirect to the website page for download
    // (respects Cloudflare protection and lets user download from the source)
    _launchUrl(url);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Opening download page in browser...'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppTheme.bgCard,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
