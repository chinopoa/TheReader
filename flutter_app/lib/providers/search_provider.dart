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

/// Live search input - updates as user types (for suggestions)
final liveSearchInputProvider = StateProvider<String>((ref) => '');

final isSearchingProvider = StateProvider<bool>((ref) => false);

/// Quick search suggestions (max 15 results for speed)
/// Uses already-cached indexes so it's instant
final searchSuggestionsProvider = FutureProvider<List<Manga>>((ref) async {
  final query = ref.watch(liveSearchInputProvider);
  final sourceIds = ref.watch(selectedSourceIdsProvider);

  // Only search if query is at least 2 characters
  if (query.length < 2 || sourceIds.isEmpty) return [];

  // Search first 2 sources for quick suggestions (prioritize speed)
  final prioritySources = sourceIds.take(2).toList();
  final futures = prioritySources.map((id) => 
    ref.read(mangaServiceProvider).searchSource(query, id)
  );
  
  final resultsList = await Future.wait(futures);
  
  // Flatten and limit to 15 for quick display
  return resultsList.expand((x) => x).take(15).toList();
});

/// Full search results (all sources)
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

/// Normalize a title for comparison (lowercase, remove special characters)
String _normalizeTitle(String title) {
  return title
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special chars
      .replaceAll(RegExp(r'\s+'), ' ')    // Normalize whitespace
      .trim();
}

/// Check if two normalized titles are similar enough to be grouped
bool _areTitlesSimilar(String title1, String title2) {
  // Exact match after normalization
  if (title1 == title2) return true;
  
  // One title contains the other (handles variations like "One Piece" vs "One Piece: Red")
  if (title1.contains(title2) || title2.contains(title1)) {
    // Only match if the shorter one is substantial (at least 5 chars)
    final shorter = title1.length < title2.length ? title1 : title2;
    if (shorter.length >= 5) return true;
  }
  
  return false;
}

/// Represents a group of manga with similar titles from different sources
class GroupedManga {
  final String displayTitle;
  final String? coverUrl;
  final List<Manga> sources;
  
  GroupedManga({
    required this.displayTitle,
    required this.coverUrl,
    required this.sources,
  });
  
  /// Get the best cover URL from available sources
  static String? _getBestCover(List<Manga> sources) {
    for (final manga in sources) {
      if (manga.coverUrl != null && manga.coverUrl!.isNotEmpty) {
        return manga.coverUrl;
      }
    }
    return null;
  }
}

/// Groups search results by similar titles
final groupedSearchResultsProvider = FutureProvider<List<GroupedManga>>((ref) async {
  final results = await ref.watch(searchResultsProvider.future);
  
  if (results.isEmpty) return [];
  
  // Group by normalized title
  final grouped = <String, List<Manga>>{};
  final titleDisplayMap = <String, String>{}; // normalized -> original display title
  
  for (final manga in results) {
    final normalizedTitle = _normalizeTitle(manga.title);
    
    // Find existing group with similar title
    String? matchingKey;
    for (final key in grouped.keys) {
      if (_areTitlesSimilar(key, normalizedTitle)) {
        matchingKey = key;
        break;
      }
    }
    
    if (matchingKey != null) {
      grouped[matchingKey]!.add(manga);
    } else {
      grouped[normalizedTitle] = [manga];
      titleDisplayMap[normalizedTitle] = manga.title; // Store first seen title as display
    }
  }
  
  // Convert to list of GroupedManga
  return grouped.entries.map((entry) {
    return GroupedManga(
      displayTitle: titleDisplayMap[entry.key] ?? entry.value.first.title,
      coverUrl: GroupedManga._getBestCover(entry.value),
      sources: entry.value,
    );
  }).toList();
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
