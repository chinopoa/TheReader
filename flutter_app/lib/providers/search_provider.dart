import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/manga.dart';
import '../models/recent_search.dart';
import '../services/manga_service.dart';

final recentSearchBoxProvider = Provider<Box<RecentSearch>>((ref) {
  return Hive.box<RecentSearch>('recent_searches');
});

final recentSearchesProvider = Provider<List<RecentSearch>>((ref) {
  final box = ref.watch(recentSearchBoxProvider);
  final items = box.values.toList();
  items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return items.take(10).toList();
});

// Default to all available IManga sources for global search
final selectedSourceIdsProvider = StateProvider<Set<String>>(
  (ref) => {
    'mangakakalot',
    'mangapark', 
    'batoto',
    'mangabuddy',
    'mangadex-en',
    'mangahere',
  },
);

final searchQueryProvider = StateProvider<String>((ref) => '');

final isSearchingProvider = StateProvider<bool>((ref) => false);

final searchResultsProvider = FutureProvider<List<Manga>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final sourceIds = ref.watch(selectedSourceIdsProvider);

  if (query.isEmpty || sourceIds.isEmpty) return [];

  // Search all selected sources in parallel
  final futures = sourceIds.map((id) => 
    ref.read(mangaServiceProvider).searchSource(query, id)
  );
  
  final resultsList = await Future.wait(futures);
  
  // Flatten results
  return resultsList.expand((x) => x).toList();
});

class SearchNotifier extends StateNotifier<void> {
  final Box<RecentSearch> _box;
  final _uuid = const Uuid();

  SearchNotifier(this._box) : super(null);

  void addSearch(String query, MangaSource source) {
    if (query.trim().isEmpty) return;

    // Remove existing if present
    final existing = _box.values.cast<RecentSearch?>().firstWhere(
      (s) => s?.query.toLowerCase() == query.toLowerCase() && s?.source == source,
      orElse: () => null,
    );

    if (existing != null) {
      existing.timestamp = DateTime.now();
      existing.save();
    } else {
      final search = RecentSearch(
        id: _uuid.v4(),
        query: query.trim(),
        source: source,
      );
      _box.put(search.id, search);
    }
  }

  void deleteSearch(RecentSearch search) {
    search.delete();
  }

  void clearAll() {
    _box.clear();
  }
}

final searchNotifierProvider = StateNotifierProvider<SearchNotifier, void>((ref) {
  return SearchNotifier(ref.watch(recentSearchBoxProvider));
});
