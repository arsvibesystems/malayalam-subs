import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/subtitle.dart';
import '../theme/app_theme.dart';

/// Subtitle card widget used in grid layouts
class SubtitleCard extends StatelessWidget {
  final Subtitle subtitle;
  final VoidCallback onTap;

  const SubtitleCard({
    super.key,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.bgCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster image
            Hero(
              tag: 'poster_${subtitle.slug}',
              child: CachedNetworkImage(
                imageUrl: subtitle.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: AppTheme.bgCardLight,
                  highlightColor: AppTheme.bgCard,
                  child: Container(color: AppTheme.bgCardLight),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppTheme.bgCardLight,
                  child: const Icon(
                    Icons.movie_outlined,
                    color: AppTheme.textMuted,
                    size: 40,
                  ),
                ),
              ),
            ),

            // Source badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.getSourceColor(subtitle.sourceSite).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppTheme.getSourceLabel(subtitle.sourceSite),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Release type badge (series)
            if (subtitle.releaseType == 'series')
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tv, color: Colors.white, size: 10),
                      SizedBox(width: 2),
                      Text(
                        'SERIES',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
