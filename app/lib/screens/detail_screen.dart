import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../models/subtitle.dart';
import '../theme/app_theme.dart';
import '../services/addon_service.dart';
import '../services/cinemata_service.dart';
import '../widgets/poster_image.dart';

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
                    child: PosterImage(
                      imageUrl: subtitle.effectiveBackdropUrl,
                      imdbId: subtitle.imdbId,
                      isBackdrop: true,
                      errorIconSize: 80,
                      showShimmer: false,
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
                      GestureDetector(
                        onTap: () {
                          String botUrl = '';
                          if (subtitle.sourceSite == 'msone') {
                            botUrl = 'https://t.me/msoneccbot';
                          } else if (subtitle.sourceSite == 'moviemirror') {
                            botUrl = 'https://t.me/MMSubtitleBot';
                          } else if (subtitle.sourceSite == 'teamgoat') {
                            botUrl = 'https://t.me/Team_Goat_Bot';
                          } else if (subtitle.sourceSite == 'ddmlsub') {
                            botUrl = 'https://t.me/ddmlsubbot';
                          }

                          if (botUrl.isNotEmpty) {
                            if (subtitle.releaseNumber != null) {
                              final textToCopy = '/${subtitle.releaseNumber}';
                              Clipboard.setData(ClipboardData(text: textToCopy));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied $textToCopy to clipboard!'),
                                  backgroundColor: AppTheme.accentTeal,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                            _launchUrl(botUrl);
                          }
                        },
                        child: Container(
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
                            Clipboard.setData(ClipboardData(text: '/${subtitle.releaseNumber}'));
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
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action buttons
                  _buildWatchMovieButton(context),
                  const SizedBox(height: 12),
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
    final ValueNotifier<bool> isLoading = ValueNotifier(false);
    return ValueListenableBuilder<bool>(
      valueListenable: isLoading,
      builder: (context, loading, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: loading ? null : () => _handleDownload(context, isLoading),
            icon: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 22),
            label: Text(
              loading ? 'Fetching Subtitle...' : 'Download Subtitle',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
      },
    );
  }

  Widget _buildWatchMovieButton(BuildContext context) {
    final ValueNotifier<bool> isLoading = ValueNotifier(false);
    return ValueListenableBuilder<bool>(
      valueListenable: isLoading,
      builder: (context, loading, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: loading ? null : () => _handleWatchMovie(context, isLoading),
            icon: loading 
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.play_circle_fill_rounded, size: 22),
            label: Text(
              loading ? 'Loading...' : 'Watch Movie',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppTheme.accentTeal.withValues(alpha: 0.4),
            ),
          ),
        );
      },
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

  Future<void> _handleDownload(BuildContext context, ValueNotifier<bool> loading) async {
    if (subtitle.hasImdbId &&
        AddonService.baseUrlForSource(subtitle.sourceSite) != null) {
      int season = 1;
      int episode = 1;

      if (subtitle.releaseType == 'series') {
        final selection = await _promptSeasonEpisode(context);
        if (selection == null) return; // Cancelled
        if (selection.$1 == -1) {
          if (context.mounted) await _fallbackWebsiteDownload(context);
          return;
        }
        season = selection.$1;
        episode = selection.$2;
      }

      loading.value = true;
      try {
        final options = await AddonService.fetchSubtitles(
          sourceSite: subtitle.sourceSite,
          imdbId: subtitle.imdbId,
          releaseType: subtitle.releaseType,
          season: season,
          episode: episode,
        );

        if (!context.mounted) return;

        if (options.length == 1) {
          await _launchUrl(options.first.url);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloading ${options.first.label}...'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: AppTheme.bgCard,
              ),
            );
          }
          return;
        }

        if (options.length > 1) {
          await _showSubtitlePickerSheet(context, options);
          return;
        }
      } finally {
        loading.value = false;
      }
    }

    if (context.mounted) {
      await _fallbackWebsiteDownload(context);
    }
  }

  Future<(int, int)?> _promptSeasonEpisode(BuildContext context) {
    int season = 1;
    int episode = 1;
    return showDialog<(int, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Select Episode',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCounterRow('Season', season, (val) {
                setDialogState(() => season = val);
              }),
              const SizedBox(height: 12),
              _buildCounterRow('Episode', episode, (val) {
                setDialogState(() => episode = val);
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, (-1, -1)),
              child: const Text('Website', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, (season, episode)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Get .srt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        Row(
          children: [
            IconButton(
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.accent),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.accent),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showSubtitlePickerSheet(
    BuildContext context,
    List<AddonSubtitleOption> options,
  ) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Subtitle File',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...options.map(
                (opt) => ListTile(
                  leading: const Icon(Icons.subtitles_rounded, color: AppTheme.accent),
                  title: Text(
                    opt.label,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  ),
                  subtitle: opt.lang.isNotEmpty && opt.lang != opt.label
                      ? Text(opt.lang, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))
                      : null,
                  trailing: const Icon(Icons.download_rounded, color: AppTheme.accentTeal),
                  onTap: () {
                    Navigator.pop(ctx);
                    _launchUrl(opt.url);
                  },
                ),
              ),
              const Divider(color: AppTheme.dividerColor),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded, color: AppTheme.textSecondary),
                title: const Text(
                  'Open Website Download Instead',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _fallbackWebsiteDownload(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fallbackWebsiteDownload(BuildContext context) async {
    final url = subtitle.downloadUrl.isNotEmpty ? subtitle.downloadUrl : subtitle.sourceUrl;
    final uri = Uri.parse(url);

    if (subtitle.sourceSite == 'teamgoat' || subtitle.sourceSite == 'moviemirror') {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        // Wait for download to initiate, then close the browser automatically
        Future.delayed(const Duration(seconds: 3), () {
          closeInAppWebView();
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Downloading subtitle...'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppTheme.bgCard,
          ),
        );
      }
    } else {
      // Redirect to the website page for download (e.g., msone)
      await _launchUrl(url);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Opening download page in browser...'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppTheme.bgCard,
          ),
        );
      }
    }
  }

  Future<void> _handleWatchMovie(BuildContext context, ValueNotifier<bool> loading) async {
    loading.value = true;
    try {
      String? imdbId = subtitle.hasImdbId ? subtitle.imdbId : null;
      if (imdbId == null) {
        // Clean up title: remove trailing year like (2023) or [2023] and Malayalam text
        String cleanTitle = subtitle.shortTitle.replaceAll(RegExp(r'\s*[\(\[]\d{4}[\)\]]\s*'), '').trim();
        cleanTitle = cleanTitle.replaceAll(RegExp(r'[\u0D00-\u0D7F]+'), '').trim();
        imdbId = await CinemataService.searchImdbId(cleanTitle, type: subtitle.releaseType);
      }
      
      if (!context.mounted) return;
      
      if (imdbId != null && imdbId.isNotEmpty) {
        final nuvioUrl = 'nuvio:///detail/${subtitle.releaseType}/$imdbId/$imdbId';
        final stremioUrl = 'stremio:///detail/${subtitle.releaseType}/$imdbId/$imdbId';
        
        if (Platform.isAndroid) {
          final nuvioIntent = AndroidIntent(action: 'action_view', data: nuvioUrl);
          bool canLaunchNuvio = await nuvioIntent.canResolveActivity() ?? false;
          if (canLaunchNuvio) {
            await nuvioIntent.launch();
            return;
          }
          
          final stremioIntent = AndroidIntent(action: 'action_view', data: stremioUrl);
          bool canLaunchStremio = await stremioIntent.canResolveActivity() ?? false;
          if (canLaunchStremio) {
            await stremioIntent.launch();
            return;
          }
        } else {
          // iOS fallback
          if (await canLaunchUrl(Uri.parse(nuvioUrl))) {
            await launchUrl(Uri.parse(nuvioUrl), mode: LaunchMode.externalApplication);
            return;
          }
          if (await canLaunchUrl(Uri.parse(stremioUrl))) {
            await launchUrl(Uri.parse(stremioUrl), mode: LaunchMode.externalApplication);
            return;
          }
        }
        
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Nuvio or Stremio is not installed.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppTheme.bgCard,
          ),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not find movie ID on Cinemeta.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppTheme.bgCard,
          ),
        );
      }
    } finally {
      loading.value = false;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
