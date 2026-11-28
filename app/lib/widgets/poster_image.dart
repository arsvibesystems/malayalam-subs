import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Displays a poster/backdrop with browser-like headers and automatic
/// Metahub IMDb CDN fallback when the primary image URL is empty or blocked.
class PosterImage extends StatelessWidget {
  final String imageUrl;
  final String imdbId;
  final bool isBackdrop;
  final double errorIconSize;
  final bool showShimmer;

  const PosterImage({
    super.key,
    required this.imageUrl,
    this.imdbId = '',
    this.isBackdrop = false,
    this.errorIconSize = 40,
    this.showShimmer = true,
  });

  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
  };

  static Map<String, String> headersFor(String url) {
    final headers = Map<String, String>.from(_browserHeaders);
    if (url.contains('malayalamsubtitles.org')) {
      headers['Referer'] = 'https://malayalamsubtitles.org/';
    } else if (url.contains('malayalamsubtitles.in')) {
      headers['Referer'] = 'https://malayalamsubtitles.in/';
    } else if (url.contains('moviemirrorsubtitles.com')) {
      headers['Referer'] = 'https://moviemirrorsubtitles.com/';
    }
    return headers;
  }

  static String metahubUrl(String imdbId, {bool large = false}) {
    final size = large ? 'large' : 'medium';
    return 'https://images.metahub.space/poster/$size/$imdbId/img';
  }

  Widget _buildPlaceholder() {
    if (!showShimmer) {
      return Container(color: AppTheme.bgCardLight);
    }
    return Shimmer.fromColors(
      baseColor: AppTheme.bgCardLight,
      highlightColor: AppTheme.bgCard,
      child: Container(color: AppTheme.bgCardLight),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      color: AppTheme.bgCardLight,
      child: Icon(
        Icons.movie_outlined,
        color: AppTheme.textMuted,
        size: errorIconSize,
      ),
    );
  }

  Widget _buildMetahubFallback() {
    if (imdbId.isEmpty) {
      return _buildErrorBox();
    }
    final fallbackUrl = metahubUrl(imdbId, large: isBackdrop);
    return CachedNetworkImage(
      imageUrl: fallbackUrl,
      fit: BoxFit.cover,
      httpHeaders: _browserHeaders,
      placeholder: (_, __) => _buildPlaceholder(),
      errorWidget: (_, __, ___) => _buildErrorBox(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildMetahubFallback();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      httpHeaders: headersFor(imageUrl),
      placeholder: (_, __) => _buildPlaceholder(),
      errorWidget: (_, __, ___) => _buildMetahubFallback(),
    );
  }
}

