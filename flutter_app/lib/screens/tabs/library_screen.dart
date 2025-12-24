import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manga_provider.dart';
import '../../widgets/manga_cover.dart';
import '../../theme/app_theme.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manga = ref.watch(sortedLibraryProvider);
    final sortOption = ref.watch(librarySortProvider);
    final chapterBox = ref.watch(chapterBoxProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Library'),
            actions: [
              PopupMenuButton<LibrarySortOption>(
                icon: const Icon(Icons.sort_rounded),
                onSelected: (option) {
                  ref.read(librarySortProvider.notifier).state = option;
                },
                itemBuilder: (context) => [
                  _buildSortItem(context, 'Title', LibrarySortOption.title, sortOption),
                  _buildSortItem(context, 'Last Updated', LibrarySortOption.lastUpdated, sortOption),
                  _buildSortItem(context, 'Unread Count', LibrarySortOption.unreadCount, sortOption),
                ],
              ),
            ],
          ),
          if (manga.isEmpty)
            SliverFillRemaining(
              child: _EmptyLibrary(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.55,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final m = manga[index];
                    final unreadCount = chapterBox.values
                        .where((c) => c.mangaId == m.id && !c.isRead)
                        .length;

                    return MangaCover(
                      manga: m,
                      unreadCount: unreadCount,
                      onTap: () => context.go('/library/manga/${m.id}'),
                    );
                  },
                  childCount: manga.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  PopupMenuItem<LibrarySortOption> _buildSortItem(
    BuildContext context,
    String label,
    LibrarySortOption option,
    LibrarySortOption current,
  ) {
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          if (option == current)
            const Icon(Icons.check, size: 18, color: Colors.blue),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: context.secondaryTextColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Your Library is Empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.glassTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by browsing for manga\nand adding them to your library.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
