import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/manga.dart';
import '../../providers/manga_provider.dart';
import '../../services/manga_service.dart';
import '../../services/source_service.dart';
import '../../services/sources/base_source.dart';
import '../../theme/app_theme.dart';

/// Screen for browsing manga from a specific source
class SourceBrowseScreen extends ConsumerStatefulWidget {
  final String sourceId;

  const SourceBrowseScreen({super.key, required this.sourceId});

  @override
  ConsumerState<SourceBrowseScreen> createState() => _SourceBrowseScreenState();
}

class _SourceBrowseScreenState extends ConsumerState<SourceBrowseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  // State
  BrowseSortType _currentSort = BrowseSortType.popular;
  List<Manga> _mangaList = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;
  
  // Search state
  bool _isSearchMode = false;
  String _searchQuery = '';
  List<Manga> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    final newSort = _tabController.index == 0
        ? BrowseSortType.popular
        : BrowseSortType.latest;

    if (_tabController.index == 2) {
      // Filter tab - show filter dialog
      _showFilterDialog();
      return;
    }

    if (newSort != _currentSort) {
      setState(() {
        _currentSort = newSort;
        _mangaList = [];
        _currentPage = 1;
        _hasMore = true;
        _error = null;
      });
      _loadData();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final source = ref.read(sourceServiceProvider).getSource(widget.sourceId);
      if (source == null) throw Exception('Source not found');

      final results = _currentSort == BrowseSortType.popular
          ? await source.getPopular(page: _currentPage)
          : await source.getLatest(page: _currentPage);

      setState(() {
        _mangaList = results;
        _hasMore = results.length >= 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final source = ref.read(sourceServiceProvider).getSource(widget.sourceId);
      if (source == null) return;

      final nextPage = _currentPage + 1;
      final results = _currentSort == BrowseSortType.popular
          ? await source.getPopular(page: nextPage)
          : await source.getLatest(page: nextPage);

      setState(() {
        _mangaList.addAll(results);
        _currentPage = nextPage;
        _hasMore = results.length >= 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _mangaList = [];
      _currentPage = 1;
      _hasMore = true;
      _error = null;
      _isSearchMode = false;
      _searchQuery = '';
      _searchController.clear();
    });
    await _loadData();
  }

  void _showFilterDialog() {
    // Reset tab to previous selection since Filter is an action, not a tab
    _tabController.animateTo(_currentSort == BrowseSortType.popular ? 0 : 1);

    showModalBottomSheet(
      context: context,
      builder: (context) => _FilterSheet(),
    );
  }
  
  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      _suggestions = [];
      _showSuggestions = false;
      if (!_isSearchMode) {
        // Exiting search mode - reload regular content
        _searchQuery = '';
        _searchController.clear();
        _mangaList = [];
        _currentPage = 1;
        _hasMore = true;
        _loadData();
      }
    });
  }
  
  /// Load search suggestions as user types
  Future<void> _loadSuggestions(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    
    try {
      // Use manga service to search this specific source
      final results = await ref.read(mangaServiceProvider).searchSource(query, widget.sourceId);
      
      if (mounted) {
        setState(() {
          _suggestions = results.take(10).toList(); // Limit to 10 suggestions
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      print('Suggestion error: $e');
    }
  }
  
  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
      _searchQuery = query;
      _mangaList = [];
      _showSuggestions = false; // Hide suggestions when searching
      _suggestions = [];
    });

    try {
      final source = ref.read(sourceServiceProvider).getSource(widget.sourceId);
      if (source == null) throw Exception('Source not found');

      print('SourceBrowse: searching "$query" in source ${widget.sourceId}');
      final results = await source.search(query);
      print('SourceBrowse: got ${results.length} results');

      setState(() {
        _mangaList = results;
        _hasMore = false; // Search doesn't paginate
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onMangaTap(Manga manga) {
    // Save manga to Hive so it can be accessed by ID on the detail screen
    final mangaBox = ref.read(mangaBoxProvider);
    mangaBox.put(manga.id, manga);

    // Navigate to detail screen
    final encodedId = Uri.encodeComponent(manga.id);
    context.push('/library/manga/$encodedId');
  }

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(sourceServiceProvider).getSource(widget.sourceId);
    final followedManga = ref.watch(followedMangaProvider);
    final followedIds = followedManga.map((m) => m.id).toSet();

    if (source == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Source Not Found')),
        body: const Center(child: Text('Source not found')),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: _isSearchMode 
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search in ${source.name}...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: context.secondaryTextColor),
                  ),
                  onChanged: _loadSuggestions,
                  onSubmitted: (query) {
                    _search(query);
                    FocusScope.of(context).unfocus();
                  },
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _searchQuery.isNotEmpty ? 'Search: "$_searchQuery"' : source.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      source.baseUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
            actions: [
              IconButton(
                icon: Icon(_isSearchMode ? Icons.close : Icons.search),
                onPressed: _toggleSearchMode,
              ),
              IconButton(
                icon: const Icon(Icons.open_in_browser),
                onPressed: () async {
                  await context.push<Map<String, dynamic>>(
                    '/webview',
                    extra: {
                      'url': source.baseUrl,
                      'title': source.name,
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            pinned: true,
            floating: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _buildTabs(),
            ),
          ),
        ],
        body: Stack(
          children: [
            _buildBody(followedIds),
            // Suggestions overlay
            if (_showSuggestions && _suggestions.isNotEmpty && _isSearchMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 4,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final manga = _suggestions[index];
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) {
                              // Use the suggestion title as search query
                              final title = manga.title;
                              Future.microtask(() {
                                _searchController.text = title;
                                _search(title);
                                FocusScope.of(context).unfocus();
                              });
                            },
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: manga.coverUrl != null
                                    ? Image.network(
                                        manga.coverUrl!,
                                        width: 40,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 40,
                                          height: 56,
                                          color: context.glassColor,
                                          child: const Icon(Icons.book, size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 56,
                                        color: context.glassColor,
                                        child: const Icon(Icons.book, size: 20),
                                      ),
                              ),
                              title: Text(
                                manga.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                manga.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: context.secondaryTextColor),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _TabChip(
            label: 'Popular',
            icon: Icons.trending_up,
            isSelected: _currentSort == BrowseSortType.popular,
            onTap: () {
              _tabController.animateTo(0);
            },
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Latest',
            icon: Icons.schedule,
            isSelected: _currentSort == BrowseSortType.latest,
            onTap: () {
              _tabController.animateTo(1);
            },
          ),
          const SizedBox(width: 8),
          _TabChip(
            label: 'Filter',
            icon: Icons.filter_list,
            isSelected: false,
            onTap: _showFilterDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Set<String> followedIds) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_mangaList.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mangaList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: context.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              'No manga found',
              style: TextStyle(color: context.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _mangaList.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _mangaList.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final manga = _mangaList[index];
          final isInLibrary = followedIds.contains(manga.id);

          return _MangaGridItem(
            manga: manga,
            isInLibrary: isInLibrary,
            onTap: () => _onMangaTap(manga),
          );
        },
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Material(
      color: isSelected ? primaryColor.withValues(alpha: 0.2) : context.glassColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check, size: 18, color: primaryColor),
                const SizedBox(width: 6),
              ] else ...[
                Icon(icon, size: 18, color: context.secondaryTextColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? primaryColor : context.glassTextColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MangaGridItem extends StatelessWidget {
  final Manga manga;
  final bool isInLibrary;
  final VoidCallback onTap;

  const _MangaGridItem({
    required this.manga,
    required this.isInLibrary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image with badge
          Expanded(
            child: Stack(
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: manga.coverUrl != null
                      ? Image.network(
                          manga.coverUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          headers: const {
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                            'Referer': 'https://mangapark.net/',
                          },
                          errorBuilder: (_, error, ___) {
                            print('Cover error: $error');
                            return _PlaceholderCover();
                          },
                        )
                      : _PlaceholderCover(),
                ),
                // "In library" badge
                if (isInLibrary)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'In library',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Title
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
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: context.glassColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.book, size: 40, color: context.secondaryTextColor),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.glassTextColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Filters coming soon...',
            style: TextStyle(color: context.secondaryTextColor),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
