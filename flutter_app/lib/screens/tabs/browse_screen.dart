import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/manga.dart';
import '../../providers/search_provider.dart';
import '../../providers/manga_provider.dart';
import '../../services/source_service.dart';
import '../../services/sources/base_source.dart';
import '../../theme/app_theme.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSearchFocused = false;
  bool _isSearchMode = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isSearchFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final sourceIds = ref.read(selectedSourceIdsProvider);

    MangaSource sourceEnum = MangaSource.custom;
    if (sourceIds.contains('mangadex')) sourceEnum = MangaSource.mangadex;

    ref.read(searchNotifierProvider.notifier).addSearch(query, sourceEnum);
    ref.read(searchQueryProvider.notifier).state = query;
    _focusNode.unfocus();
    setState(() => _isSearchMode = true);
  }

  void _exitSearchMode() {
    setState(() {
      _isSearchMode = false;
      _searchController.clear();
    });
    ref.read(searchQueryProvider.notifier).state = '';
  }

  void _showSourcePicker() {
    showDialog(
      context: context,
      builder: (context) => _SourcePickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourceServiceProvider).getSources();
    final recentSearches = ref.watch(recentSearchesProvider);
    final searchResults = ref.watch(searchResultsProvider);
    final selectedSourceIds = ref.watch(selectedSourceIdsProvider);

    String searchHint = 'Search all sources...';
    if (selectedSourceIds.length == 1) {
      final source = sources.firstWhere(
        (s) => s.id == selectedSourceIds.first,
        orElse: () => sources.first,
      );
      searchHint = 'Search ${source.name}...';
    } else if (selectedSourceIds.length > 1 && selectedSourceIds.length < sources.length) {
      searchHint = 'Search ${selectedSourceIds.length} sources...';
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Browse'),
            actions: [
              IconButton(
                icon: const Icon(Icons.extension),
                tooltip: 'Extensions',
                onPressed: () => context.push('/extensions'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty || _isSearchMode)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            if (_isSearchMode) _exitSearchMode();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: 'Select Sources',
                        onPressed: _showSourcePicker,
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: context.glassColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _performSearch(),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Content based on state
          if (_isSearchFocused && _searchController.text.isEmpty)
            _buildRecentSearches(recentSearches)
          else if (_isSearchMode)
            searchResults.when(
              data: (results) => results.isEmpty
                  ? _buildEmptySearchResults()
                  : _buildSearchResultsBySource(results, sources),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, stack) => _buildSearchError(e, sources),
            )
          else
            ..._buildBrowseSections(sources),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  List<Widget> _buildBrowseSections(List<BaseSource> sources) {
    return [
      // Sources Section Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Icon(Icons.public, size: 20, color: context.secondaryTextColor),
              const SizedBox(width: 8),
              Text(
                'SOURCES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.secondaryTextColor,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${sources.length} installed',
                style: TextStyle(
                  fontSize: 12,
                  color: context.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
      // Sources List
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final source = sources[index];
            return _SourceListTile(
              source: source,
              onTap: () => context.push('/browse/source/${source.id}'),
            );
          },
          childCount: sources.length,
        ),
      ),
      // Empty state if no sources
      if (sources.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.extension_off,
                  size: 64,
                  color: context.secondaryTextColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Sources Installed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.glassTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add extensions to browse manga from different sources.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.secondaryTextColor),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.extension),
                  label: const Text('Browse Extensions'),
                  onPressed: () => context.push('/extensions'),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _buildRecentSearches(List recentSearches) {
    if (recentSearches.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, size: 48, color: context.secondaryTextColor),
              const SizedBox(height: 12),
              Text(
                'No Recent Searches',
                style: TextStyle(color: context.secondaryTextColor),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    'RECENT SEARCHES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.secondaryTextColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ref.read(searchNotifierProvider.notifier).clearAll();
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            );
          }

          final search = recentSearches[index - 1];
          return ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(search.query),
            subtitle: Text(search.source.label),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                ref.read(searchNotifierProvider.notifier).deleteSearch(search);
              },
            ),
            onTap: () {
              _searchController.text = search.query;
              _performSearch();
            },
          );
        },
        childCount: recentSearches.length + 1,
      ),
    );
  }

  Widget _buildSearchResultsBySource(List<Manga> results, List<BaseSource> sources) {
    final groupedResults = <String, List<Manga>>{};

    for (final manga in results) {
      String sourceId = 'mangadex';
      if (manga.source == MangaSource.custom) {
        sourceId = manga.customSourceId ?? 'unknown';
      } else if (manga.source == MangaSource.mangadex) {
        sourceId = 'mangadex';
      }

      groupedResults.putIfAbsent(sourceId, () => []).add(manga);
    }

    final sourceIds = groupedResults.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final sourceId = sourceIds[index];
          final mangaList = groupedResults[sourceId]!;

          final sourceName = sources.firstWhere(
            (s) => s.id == sourceId,
            orElse: () => sources.first
          ).name;

          return _SourceSection(
            sourceName: sourceName,
            mangaList: mangaList,
            onMangaTap: (manga) {
              final mangaBox = ref.read(mangaBoxProvider);
              mangaBox.put(manga.id, manga);

              final encodedId = Uri.encodeComponent(manga.id);
              context.push('/library/manga/$encodedId');
            },
          );
        },
        childCount: groupedResults.length,
      ),
    );
  }

  Widget _buildEmptySearchResults() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: context.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              'No Results Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.glassTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(color: context.secondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchError(Object error, List<BaseSource> sources) {
    if (error.toString().contains('CloudflareException') ||
        error.toString().contains('Cloudflare protection detected')) {
      final selectedIds = ref.read(selectedSourceIdsProvider);
      final source = sources.firstWhere(
        (s) => selectedIds.contains(s.id),
        orElse: () => sources.first,
      );

      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Cloudflare Protection Detected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please solve the CAPTCHA for ${source.name} in WebView.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Solve Cloudflare'),
                onPressed: () async {
                  final result = await context.push<Map<String, dynamic>>(
                    '/webview',
                    extra: {
                      'url': source.baseUrl,
                      'title': 'Solve Cloudflare: ${source.name}',
                    },
                  );

                  if (result != null) {
                    final cookies = result['cookies'] as Map<String, String>?;
                    final userAgent = result['userAgent'] as String?;

                    if (cookies != null && cookies.isNotEmpty) {
                      source.setCookies(cookies);
                      if (userAgent != null) {
                        source.setUserAgent(userAgent);
                      }
                      _performSearch();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return SliverFillRemaining(
      child: Center(child: Text('Error: $error')),
    );
  }
}

/// Source list tile for the browse screen
class _SourceListTile extends StatelessWidget {
  final BaseSource source;
  final VoidCallback onTap;

  const _SourceListTile({
    required this.source,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.public,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        source.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: context.glassTextColor,
        ),
      ),
      subtitle: Text(
        source.baseUrl,
        style: TextStyle(
          fontSize: 12,
          color: context.secondaryTextColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: context.secondaryTextColor,
      ),
      onTap: onTap,
    );
  }
}

class _SourcePickerDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SourcePickerDialog> createState() => _SourcePickerDialogState();
}

class _SourcePickerDialogState extends ConsumerState<_SourcePickerDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(ref.read(selectedSourceIdsProvider));
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        if (_selectedIds.length > 1) _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    final sources = ref.read(sourceServiceProvider).getSources();
    setState(() {
      _selectedIds = sources.map((s) => s.id).toSet();
    });
  }

  void _selectNone() {
     setState(() {
       _selectedIds = {'mangadex'};
     });
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.read(sourceServiceProvider).getSources();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.public, size: 24),
          SizedBox(width: 12),
          Text('Select Sources'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 TextButton(onPressed: _selectAll, child: const Text("Select All")),
                 TextButton(onPressed: _selectNone, child: const Text("Reset")),
               ],
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sources.length,
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final isSelected = _selectedIds.contains(source.id);
                  return CheckboxListTile(
                    secondary: Icon(
                      Icons.book,
                      color: isSelected ? Colors.blue : null,
                    ),
                    title: Text(source.name),
                    subtitle: Text(source.baseUrl),
                    value: isSelected,
                    onChanged: (bool? value) {
                       _toggle(source.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(selectedSourceIdsProvider.notifier).state = _selectedIds;
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// Section showing source name with horizontal manga list
class _SourceSection extends StatelessWidget {
  final String sourceName;
  final List<Manga> mangaList;
  final void Function(Manga) onMangaTap;

  const _SourceSection({
    required this.sourceName,
    required this.mangaList,
    required this.onMangaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Icon(Icons.public, size: 20, color: context.secondaryTextColor),
              const SizedBox(width: 8),
              Text(
                sourceName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.glassTextColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${mangaList.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: mangaList.length,
            itemBuilder: (context, index) {
              final manga = mangaList[index];
              return _HorizontalMangaCard(
                manga: manga,
                onTap: () => onMangaTap(manga),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _HorizontalMangaCard extends StatelessWidget {
  final Manga manga;
  final VoidCallback onTap;

  const _HorizontalMangaCard({
    required this.manga,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: manga.coverUrl != null
                    ? Image.network(
                        manga.coverUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: context.glassColor,
                          child: const Icon(Icons.book, size: 40),
                        ),
                      )
                    : Container(
                        color: context.glassColor,
                        child: const Icon(Icons.book, size: 40),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.glassTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
