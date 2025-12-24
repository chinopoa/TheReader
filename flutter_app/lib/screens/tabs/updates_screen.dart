import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manga_provider.dart';
import '../../widgets/manga_cover.dart';
import '../../theme/app_theme.dart';

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final updates = ref.watch(recentUpdatesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('Updates'),
              actions: [
                IconButton(
                  icon: AnimatedRotation(
                    turns: _isRefreshing ? 1 : 0,
                    duration: const Duration(seconds: 1),
                    child: const Icon(Icons.refresh_rounded),
                  ),
                  onPressed: _refresh,
                ),
              ],
            ),
            if (updates.isEmpty)
              SliverFillRemaining(child: _EmptyUpdates())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final update = updates[index];
                    return Column(
                      children: [
                        _UpdateRow(
                          manga: update.key,
                          chapter: update.value,
                          onTap: () => context.go(
                            '/reader/${update.key.id}/${update.value.id}',
                          ),
                        ),
                        if (index < updates.length - 1)
                          Divider(
                            height: 1,
                            indent: 92,
                            color: context.glassBorderColor,
                          ),
                      ],
                    );
                  },
                  childCount: updates.length,
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  final dynamic manga;
  final dynamic chapter;
  final VoidCallback onTap;

  const _UpdateRow({
    required this.manga,
    required this.chapter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MangaCoverRow(
      manga: manga,
      subtitle: '${chapter.displayTitle}\n${chapter.relativeDate}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!chapter.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: context.secondaryTextColor,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _EmptyUpdates extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: context.secondaryTextColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No Updates',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.glassTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to check for\nnew chapters from your library.',
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
