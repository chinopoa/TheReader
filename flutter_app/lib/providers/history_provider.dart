import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/history_item.dart';

final historyBoxProvider = Provider<Box<HistoryItem>>((ref) {
  return Hive.box<HistoryItem>('history');
});

final historyProvider = Provider<List<HistoryItem>>((ref) {
  final box = ref.watch(historyBoxProvider);
  final items = box.values.toList();
  items.sort((a, b) => b.lastReadDate.compareTo(a.lastReadDate));
  return items;
});

final groupedHistoryProvider = Provider<Map<String, List<HistoryItem>>>((ref) {
  final items = ref.watch(historyProvider);
  final grouped = <String, List<HistoryItem>>{};

  for (final item in items) {
    final key = item.relativeDate;
    grouped.putIfAbsent(key, () => []).add(item);
  }

  return grouped;
});

class HistoryNotifier extends StateNotifier<void> {
  final Box<HistoryItem> _box;
  final _uuid = const Uuid();

  HistoryNotifier(this._box) : super(null);

  void addOrUpdate({
    required String mangaId,
    required String mangaTitle,
    String? mangaCoverUrl,
    required String chapterId,
    required double chapterNumber,
    String chapterTitle = '',
    required int lastReadPage,
    required int totalPages,
  }) {
    // Check if entry exists for this manga/chapter combo
    final existing = _box.values.cast<HistoryItem?>().firstWhere(
      (item) => item?.mangaId == mangaId && item?.chapterId == chapterId,
      orElse: () => null,
    );

    if (existing != null) {
      existing.lastReadPage = lastReadPage;
      existing.totalPages = totalPages;
      existing.lastReadDate = DateTime.now();
      existing.save();
    } else {
      final item = HistoryItem(
        id: _uuid.v4(),
        mangaId: mangaId,
        mangaTitle: mangaTitle,
        mangaCoverUrl: mangaCoverUrl,
        chapterId: chapterId,
        chapterNumber: chapterNumber,
        chapterTitle: chapterTitle,
        lastReadPage: lastReadPage,
        totalPages: totalPages,
      );
      _box.put(item.id, item);
    }
  }

  void clearAll() {
    _box.clear();
  }

  void delete(HistoryItem item) {
    item.delete();
  }
}

final historyNotifierProvider = StateNotifierProvider<HistoryNotifier, void>((ref) {
  return HistoryNotifier(ref.watch(historyBoxProvider));
});
