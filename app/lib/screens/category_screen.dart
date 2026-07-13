import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../models/subtitle.dart';
import '../providers/subtitle_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/subtitle_card.dart';
import 'detail_screen.dart';

class CategoryScreen extends StatefulWidget {
  final String title;
  final String? releaseTypeFilter;

  const CategoryScreen({
    super.key,
    required this.title,
    this.releaseTypeFilter,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 400 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 400 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Consumer<SubtitleProvider>(
                builder: (context, provider, _) {
                  // Filter the subtitles
                  List<Subtitle> items = List.from(provider.allSubtitles);
                  if (widget.releaseTypeFilter != null) {
                    items = items.where((s) => s.releaseType == widget.releaseTypeFilter).toList();
                  }

                  // Explicitly sort by latest releases
                  items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No subtitles found',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                      ),
                    );
                  }

                  // Determine cross axis count based on screen width
                  final screenWidth = MediaQuery.of(context).size.width;
                  final crossAxisCount = screenWidth > 600 ? 5 : 3;

                  return AnimationLimiter(
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.66,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return AnimationConfiguration.staggeredGrid(
                          position: index,
                          duration: const Duration(milliseconds: 400),
                          columnCount: crossAxisCount,
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: SubtitleCard(
                                subtitle: items[index],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(subtitle: items[index]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _showBackToTop ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          ignoring: !_showBackToTop,
          child: FloatingActionButton(
            onPressed: _scrollToTop,
            backgroundColor: AppTheme.accent,
            elevation: 4,
            child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
