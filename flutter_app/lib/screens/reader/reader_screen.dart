import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/manga_provider.dart';
import '../../providers/history_provider.dart';
import '../../services/manga_service.dart';
import '../../theme/app_theme.dart';

enum ReadingMode { webtoon, manga }

/// Provider for fetching chapter pages - uses data-saver for faster loading
/// Provider for fetching chapter pages
final chapterPagesProvider = FutureProvider.family<List<String>, (String, String)>((ref, params) async {
  final (mangaId, chapterId) = params;
  
  final mangaBox = ref.read(mangaBoxProvider);
  final manga = mangaBox.get(mangaId);
  
  final chapterBox = ref.read(chapterBoxProvider);
  final chapter = chapterBox.get(chapterId);
  
  if (manga == null || chapter == null) return [];

  return ref.read(mangaServiceProvider).getChapterPages(chapter, manga);
});

class ReaderScreen extends ConsumerStatefulWidget {
  final String mangaId;
  final String chapterId;

  const ReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  bool _showHUD = true;
  ReadingMode _mode = ReadingMode.webtoon;
  int _currentPage = 1;
  int _totalPages = 0;
  late PageController _pageController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Hide system UI for immersive reading
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onScroll() {
    if (_totalPages == 0) return;
    
    // Calculate current page based on scroll position
    final itemHeight = MediaQuery.of(context).size.width * 1.5;
    final page = (_scrollController.offset / itemHeight).floor() + 1;
    if (page != _currentPage && page >= 1 && page <= _totalPages) {
      setState(() => _currentPage = page);
      // Save progress every 5 pages for updating history
      if (page % 5 == 0) {
        _saveProgress();
      }
    }
  }
  
  @override
  void deactivate() {
    // Save reading progress when leaving the screen
    _saveProgress();
    super.deactivate();
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    // Note: Cannot save progress here as ref is already disposed
    // Progress should be saved before navigation or via deactivate()

    super.dispose();
  }

  void _saveProgress() {
    final mangaBox = ref.read(mangaBoxProvider);
    final manga = mangaBox.get(widget.mangaId);
    final chapterBox = ref.read(chapterBoxProvider);
    final chapter = chapterBox.get(widget.chapterId);

    if (manga != null && chapter != null) {
      ref.read(historyNotifierProvider.notifier).addOrUpdate(
        mangaId: manga.id,
        mangaTitle: manga.title,
        mangaCoverUrl: manga.coverUrl,
        chapterId: chapter.id,
        chapterNumber: chapter.number,
        chapterTitle: chapter.title,
        lastReadPage: _currentPage,
        totalPages: _totalPages,
      );

      if (_currentPage >= _totalPages) {
        chapter.isRead = true;
        chapter.save();
      }
    }
  }

  void _toggleHUD() {
    setState(() => _showHUD = !_showHUD);
  }

  @override
  Widget build(BuildContext context) {
    final mangaBox = ref.watch(mangaBoxProvider);
    final manga = mangaBox.get(widget.mangaId);
    final chapterBox = ref.watch(chapterBoxProvider);
    final chapter = chapterBox.get(widget.chapterId);
    final pagesAsync = ref.watch(chapterPagesProvider((widget.mangaId, widget.chapterId)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: pagesAsync.when(
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(error.toString()),
        data: (pages) {
          if (pages.isEmpty) {
            return _buildErrorState('No pages found for this chapter');
          }
          
          // Update total pages
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_totalPages != pages.length) {
              setState(() => _totalPages = pages.length);
            }
          });

          return Stack(
            children: [
              // Reader content
              GestureDetector(
                onTap: _toggleHUD,
                child: _mode == ReadingMode.webtoon
                    ? _buildWebtoonReader(pages)
                    : _buildMangaReader(pages),
              ),

              // HUD overlay
              if (_showHUD) ...[
                _buildTopBar(context, manga?.title ?? '', chapter?.displayTitle ?? ''),
                _buildBottomBar(context),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading chapter...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load chapter',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/library');
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(chapterPagesProvider((widget.mangaId, widget.chapterId)));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebtoonReader(List<String> pages) {
    final screenWidth = MediaQuery.of(context).size.width;
    final pageHeight = screenWidth * 1.5;
    
    return ListView.builder(
      controller: _scrollController,
      itemCount: pages.length,
      // Fixed height per item - better ListView performance
      itemExtent: pageHeight,
      // Preload 3 pages ahead for smoother scrolling
      cacheExtent: pageHeight * 3,
      itemBuilder: (context, index) {
        return _ChapterPage(
          imageUrl: pages[index],
          pageNumber: index + 1,
          isWebtoon: true,
        );
      },
    );
  }

  Widget _buildMangaReader(List<String> pages) {
    return PageView.builder(
      controller: _pageController,
      reverse: true, // RTL for manga
      itemCount: pages.length,
      onPageChanged: (page) {
        setState(() => _currentPage = page + 1);
      },
      itemBuilder: (context, index) {
        return _ChapterPage(
          imageUrl: pages[index],
          pageNumber: index + 1,
          isWebtoon: false,
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, String mangaTitle, String chapterTitle) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/library');
                    }
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mangaTitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        chapterTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () => _showSettingsSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              top: 12,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                          thumbColor: Colors.white,
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _currentPage.toDouble().clamp(1, _totalPages > 0 ? _totalPages.toDouble() : 1),
                          min: 1,
                          max: _totalPages > 0 ? _totalPages.toDouble() : 1,
                          onChanged: (value) {
                            setState(() => _currentPage = value.toInt());
                            if (_mode == ReadingMode.manga) {
                              _pageController.jumpToPage(value.toInt() - 1);
                            } else {
                              final itemHeight = MediaQuery.of(context).size.width * 1.5;
                              _scrollController.jumpTo((value.toInt() - 1) * itemHeight);
                            }
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _totalPages > 0 ? 'Page $_currentPage of $_totalPages' : 'Loading...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          _mode == ReadingMode.webtoon
                              ? Icons.swap_vert_rounded
                              : Icons.swap_horiz_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _mode == ReadingMode.webtoon ? 'Vertical Scroll' : 'Horizontal (RTL)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reading Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.swap_vert_rounded),
              title: const Text('Webtoon'),
              subtitle: const Text('Vertical Scroll'),
              trailing: _mode == ReadingMode.webtoon
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                setState(() => _mode = ReadingMode.webtoon);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Manga'),
              subtitle: const Text('Horizontal (Right-to-Left)'),
              trailing: _mode == ReadingMode.manga
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                setState(() => _mode = ReadingMode.manga);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to display a single chapter page with loading and error states
class _ChapterPage extends StatelessWidget {
  final String imageUrl;
  final int pageNumber;
  final bool isWebtoon;

  const _ChapterPage({
    required this.imageUrl,
    required this.pageNumber,
    required this.isWebtoon,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Fixed height prevents layout shifts - height is locked BEFORE image loads
    // Manga pages: 1.4x width (typical manga ratio)
    // Webtoon: 1.5x width (taller for vertical scroll comics)
    final fixedHeight = screenWidth * (isWebtoon ? 1.5 : 1.4);
    
    return SizedBox(
      width: screenWidth,
      height: fixedHeight,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain, // Image fits inside fixed container
        alignment: Alignment.center,
        placeholder: (context, url) => Container(
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white38,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Page $pageNumber',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Page $pageNumber failed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
