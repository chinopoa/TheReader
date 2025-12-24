import 'package:hive/hive.dart';

part 'history_item.g.dart';

@HiveType(typeId: 4)
class HistoryItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String mangaId;

  @HiveField(2)
  final String mangaTitle;

  @HiveField(3)
  final String? mangaCoverUrl;

  @HiveField(4)
  final String chapterId;

  @HiveField(5)
  final double chapterNumber;

  @HiveField(6)
  final String chapterTitle;

  @HiveField(7)
  int lastReadPage;

  @HiveField(8)
  int totalPages;

  @HiveField(9)
  DateTime lastReadDate;

  HistoryItem({
    required this.id,
    required this.mangaId,
    required this.mangaTitle,
    this.mangaCoverUrl,
    required this.chapterId,
    required this.chapterNumber,
    this.chapterTitle = '',
    this.lastReadPage = 1,
    this.totalPages = 1,
    DateTime? lastReadDate,
  }) : lastReadDate = lastReadDate ?? DateTime.now();

  double get progress {
    if (totalPages == 0) return 0;
    return lastReadPage / totalPages;
  }

  int get progressPercentage => (progress * 100).toInt();

  String get formattedChapter {
    if (chapterNumber == chapterNumber.truncateToDouble()) {
      return 'Chapter ${chapterNumber.toInt()}';
    }
    return 'Chapter ${chapterNumber.toStringAsFixed(1)}';
  }

  String get relativeDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final readDate = DateTime(lastReadDate.year, lastReadDate.month, lastReadDate.day);

    if (readDate == today) {
      return 'Today';
    } else if (readDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${lastReadDate.month}/${lastReadDate.day}';
    }
  }

  HistoryItem copyWith({
    String? id,
    String? mangaId,
    String? mangaTitle,
    String? mangaCoverUrl,
    String? chapterId,
    double? chapterNumber,
    String? chapterTitle,
    int? lastReadPage,
    int? totalPages,
    DateTime? lastReadDate,
  }) {
    return HistoryItem(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      mangaCoverUrl: mangaCoverUrl ?? this.mangaCoverUrl,
      chapterId: chapterId ?? this.chapterId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      totalPages: totalPages ?? this.totalPages,
      lastReadDate: lastReadDate ?? this.lastReadDate,
    );
  }
}
