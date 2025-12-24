import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/manga_provider.dart';
import '../../models/manga.dart';
import '../../models/chapter.dart';
import '../../theme/app_theme.dart';
import '../../services/manga_service.dart';

/// Provider to fetch chapters from the API for a manga
final mangaChaptersFetchProvider = FutureProvider.family<List<Chapter>, String>((ref, mangaId) async {
  final mangaBox = ref.read(mangaBoxProvider);
  final manga = mangaBox.get(mangaId);
  
  if (manga == null) return [];
  
  // Fetch chapters from API
  final chapters = await ref.read(mangaServiceProvider).getChapters(manga);
  
  // Save to Hive for offline access
  final chapterBox = ref.read(chapterBoxProvider);
  for (final chapter in chapters) {
    chapterBox.put(chapter.id, chapter);
  }
  
  return chapters;
});

class MangaDetailScreen extends ConsumerStatefulWidget {
  final String mangaId;

  const MangaDetailScreen({super.key, required this.mangaId});

  @override
  ConsumerState<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends ConsumerState<MangaDetailScreen> {
  bool _sortAscending = false;
  bool _showFullDescription = false;

  @override
  Widget build(BuildContext context) {
    final mangaBox = ref.watch(mangaBoxProvider);
    final manga = mangaBox.get(widget.mangaId);

    if (manga == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Manga not found')),
      );
    }

    // Fetch chapters from API
    final chaptersAsync = ref.watch(mangaChaptersFetchProvider(widget.mangaId));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, manga),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMetadata(context, manga),
                  const SizedBox(height: 16),
                  _buildActionButtons(context, manga, chaptersAsync),
                  const SizedBox(height: 20),
                  _buildDescription(context, manga),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Chapters section with loading state
          chaptersAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Failed to load chapters: $error'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(mangaChaptersFetchProvider(widget.mangaId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (chapters) {
              final sortedChapters = _sortAscending
                  ? chapters.reversed.toList()
                  : chapters;
              
              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildChapterHeader(context, chapters.length),
                    ),
                  ),
                  _buildChapterList(context, manga, sortedChapters),
                ],
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Manga manga) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: GestureDetector(
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/library');
          }
        },
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (manga.coverUrl != null)
              CachedNetworkImage(
                imageUrl: manga.coverUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: context.glassColor,
                ),
              )
            else
              Container(color: context.glassColor),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, Manga manga) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          manga.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.glassTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.person_outline, size: 16, color: context.secondaryTextColor),
            const SizedBox(width: 4),
            Text(
              manga.author,
              style: TextStyle(fontSize: 14, color: context.secondaryTextColor),
            ),
            const SizedBox(width: 16),
            _StatusBadge(status: manga.status),
            if (manga.rating != null && manga.rating! > 0) ...[
              const SizedBox(width: 12),
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                manga.rating!.toStringAsFixed(1),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        if (manga.genres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: manga.genres.map((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.glassColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  genre,
                  style: TextStyle(fontSize: 12, color: context.secondaryTextColor),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Manga manga, AsyncValue<List<Chapter>> chaptersAsync) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: chaptersAsync.maybeWhen(
              data: (chapters) => chapters.isNotEmpty
                  ? () {
                      // Find first unread chapter
                      // 1. Sort chapters by number ascending
                      final sortedChapters = [...chapters]
                        ..sort((a, b) => a.number.compareTo(b.number));
                      
                      // 2. Find first unread
                      final firstUnread = sortedChapters.firstWhere(
                        (c) => !c.isRead,
                        orElse: () => sortedChapters.last, // If all read, open latest
                      );
                      
                      context.push('/reader/${manga.id}/${firstUnread.id}');
                    }
                  : null,
              orElse: () => null,
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: chaptersAsync.isLoading 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Start Reading'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: context.glassColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              // Save manga to Hive first if not already saved
              final mangaBox = ref.read(mangaBoxProvider);
              if (!mangaBox.containsKey(manga.id)) {
                mangaBox.put(manga.id, manga);
              }
              // Now toggle follow
              ref.read(mangaNotifierProvider.notifier).toggleFollow(manga);
              // Force rebuild to update icon
              setState(() {});
            },
            icon: Icon(
              manga.isFollowed ? Icons.bookmark : Icons.bookmark_border,
              color: manga.isFollowed ? Colors.blue : context.glassTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context, Manga manga) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Synopsis',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.glassTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          manga.synopsis,
          maxLines: _showFullDescription ? null : 4,
          overflow: _showFullDescription ? null : TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: context.secondaryTextColor,
            height: 1.5,
          ),
        ),
        if (manga.synopsis.length > 200)
          TextButton(
            onPressed: () => setState(() => _showFullDescription = !_showFullDescription),
            child: Text(_showFullDescription ? 'Show Less' : 'Show More'),
          ),
      ],
    );
  }

  Widget _buildChapterHeader(BuildContext context, int count) {
    return Row(
      children: [
        Text(
          '$count Chapters',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.glassTextColor,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => _sortAscending = !_sortAscending),
          icon: Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
          ),
          label: Text(_sortAscending ? 'Oldest' : 'Newest'),
        ),
      ],
    );
  }

  Widget _buildChapterList(BuildContext context, Manga manga, List<Chapter> chapters) {
    if (chapters.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No chapters available',
              style: TextStyle(color: context.secondaryTextColor),
            ),
          ),
        ),
      );
    }
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final chapter = chapters[index];
          return _ChapterRow(
            chapter: chapter,
            onTap: () {
               final encodedMangaId = Uri.encodeComponent(manga.id);
               final encodedChapterId = Uri.encodeComponent(chapter.id);
               context.push('/reader/$encodedMangaId/$encodedChapterId');
            },
            onDownload: () async {
              // Show downloading snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloading ${chapter.displayTitle}...'),
                  duration: const Duration(seconds: 2),
                ),
              );
              
              try {
                // Fetch chapter pages
                final pages = await ref.read(mangaServiceProvider).getChapterPages(manga, chapter);
                
                // Pre-cache all images
                for (final pageUrl in pages) {
                  await CachedNetworkImage.evictFromCache(pageUrl); // Clear old cache
                  // Trigger download by getting the image
                  await precacheImage(
                    CachedNetworkImageProvider(pageUrl),
                    context,
                  );
                }
                
                // Mark chapter as downloaded
                chapter.isDownloaded = true;
                chapter.save();
                
                // Refresh UI
                ref.invalidate(mangaChaptersFetchProvider(manga.id));
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Downloaded ${chapter.displayTitle} (${pages.length} pages)'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Download failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          );
        },
        childCount: chapters.length,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MangaStatus status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case MangaStatus.ongoing:
        return Colors.green;
      case MangaStatus.completed:
        return Colors.blue;
      case MangaStatus.hiatus:
        return Colors.orange;
      case MangaStatus.cancelled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _ChapterRow({
    required this.chapter,
    required this.onTap,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        chapter.displayTitle,
        style: TextStyle(
          fontWeight: chapter.isRead ? FontWeight.normal : FontWeight.w600,
          color: chapter.isRead ? context.secondaryTextColor : context.glassTextColor,
        ),
      ),
      subtitle: Text(
        '${chapter.relativeDate}${chapter.scanlator != null ? ' • ${chapter.scanlator}' : ''}',
        style: TextStyle(
          fontSize: 12,
          color: context.secondaryTextColor,
        ),
      ),
      trailing: chapter.isDownloaded
          ? Icon(Icons.check_circle, color: Colors.green, size: 20)
          : IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: onDownload,
            ),
    );
  }
}
