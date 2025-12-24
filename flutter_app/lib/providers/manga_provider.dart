import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/manga.dart';
import '../models/chapter.dart';

final mangaBoxProvider = Provider<Box<Manga>>((ref) {
  return Hive.box<Manga>('manga');
});

final chapterBoxProvider = Provider<Box<Chapter>>((ref) {
  return Hive.box<Chapter>('chapters');
});

final followedMangaProvider = Provider<List<Manga>>((ref) {
  final box = ref.watch(mangaBoxProvider);
  return box.values.where((m) => m.isFollowed).toList();
});

final mangaChaptersProvider = Provider.family<List<Chapter>, String>((ref, mangaId) {
  final box = ref.watch(chapterBoxProvider);
  return box.values.where((c) => c.mangaId == mangaId).toList()
    ..sort((a, b) => b.number.compareTo(a.number));
});

final recentUpdatesProvider = Provider<List<MapEntry<Manga, Chapter>>>((ref) {
  final mangaBox = ref.watch(mangaBoxProvider);
  final chapterBox = ref.watch(chapterBoxProvider);

  final followedManga = mangaBox.values.where((m) => m.isFollowed).toList();
  final updates = <MapEntry<Manga, Chapter>>[];

  for (final manga in followedManga) {
    final chapters = chapterBox.values.where((c) => c.mangaId == manga.id).toList();
    for (final chapter in chapters) {
      updates.add(MapEntry(manga, chapter));
    }
  }

  updates.sort((a, b) => b.value.releaseDate.compareTo(a.value.releaseDate));
  return updates.take(50).toList();
});

enum LibrarySortOption { title, lastUpdated, unreadCount }

final librarySortProvider = StateProvider<LibrarySortOption>(
  (ref) => LibrarySortOption.lastUpdated,
);

final sortedLibraryProvider = Provider<List<Manga>>((ref) {
  final manga = ref.watch(followedMangaProvider);
  final sortOption = ref.watch(librarySortProvider);
  final chapterBox = ref.watch(chapterBoxProvider);

  final sorted = List<Manga>.from(manga);

  switch (sortOption) {
    case LibrarySortOption.title:
      sorted.sort((a, b) => a.title.compareTo(b.title));
      break;
    case LibrarySortOption.lastUpdated:
      sorted.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
      break;
    case LibrarySortOption.unreadCount:
      sorted.sort((a, b) {
        final aUnread = chapterBox.values
            .where((c) => c.mangaId == a.id && !c.isRead).length;
        final bUnread = chapterBox.values
            .where((c) => c.mangaId == b.id && !c.isRead).length;
        return bUnread.compareTo(aUnread);
      });
      break;
  }

  return sorted;
});

class MangaNotifier extends StateNotifier<void> {
  final Box<Manga> _mangaBox;
  final Box<Chapter> _chapterBox;

  MangaNotifier(this._mangaBox, this._chapterBox) : super(null);

  void toggleFollow(Manga manga) {
    manga.isFollowed = !manga.isFollowed;
    manga.save();
  }

  void markChapterRead(Chapter chapter) {
    chapter.isRead = true;
    chapter.save();
  }

  void markAllRead(Manga manga) {
    final chapters = _chapterBox.values.where((c) => c.mangaId == manga.id);
    for (final chapter in chapters) {
      chapter.isRead = true;
      chapter.save();
    }
  }

  int getUnreadCount(String mangaId) {
    return _chapterBox.values
        .where((c) => c.mangaId == mangaId && !c.isRead)
        .length;
  }
}

final mangaNotifierProvider = StateNotifierProvider<MangaNotifier, void>((ref) {
  return MangaNotifier(
    ref.watch(mangaBoxProvider),
    ref.watch(chapterBoxProvider),
  );
});
