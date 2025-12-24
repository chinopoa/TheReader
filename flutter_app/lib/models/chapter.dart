import 'package:hive/hive.dart';

part 'chapter.g.dart';

@HiveType(typeId: 3)
class Chapter extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String mangaId;

  @HiveField(2)
  String title;

  @HiveField(3)
  double number;

  @HiveField(4)
  int? volume;

  @HiveField(5)
  DateTime releaseDate;

  @HiveField(6)
  bool isRead;

  @HiveField(7)
  bool isDownloaded;

  @HiveField(8)
  int pageCount;

  @HiveField(9)
  String? scanlator;

  @HiveField(10)
  String? externalUrl;

  Chapter({
    required this.id,
    required this.mangaId,
    this.title = '',
    required this.number,
    this.volume,
    DateTime? releaseDate,
    this.isRead = false,
    this.isDownloaded = false,
    this.pageCount = 0,
    this.scanlator,
    this.externalUrl,
  }) : releaseDate = releaseDate ?? DateTime.now();

  String get displayTitle {
    if (title.isEmpty) {
      return 'Chapter ${formattedNumber}';
    }
    return 'Ch. $formattedNumber - $title';
  }

  String get formattedNumber {
    if (number == number.truncateToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(1);
  }

  String get relativeDate {
    final now = DateTime.now();
    final diff = now.difference(releaseDate);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}w ago';
    } else {
      return '${(diff.inDays / 30).floor()}mo ago';
    }
  }

  Chapter copyWith({
    String? id,
    String? mangaId,
    String? title,
    double? number,
    int? volume,
    DateTime? releaseDate,
    bool? isRead,
    bool? isDownloaded,
    int? pageCount,
    String? scanlator,
    String? externalUrl,
  }) {
    return Chapter(
      id: id ?? this.id,
      mangaId: mangaId ?? this.mangaId,
      title: title ?? this.title,
      number: number ?? this.number,
      volume: volume ?? this.volume,
      releaseDate: releaseDate ?? this.releaseDate,
      isRead: isRead ?? this.isRead,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      pageCount: pageCount ?? this.pageCount,
      scanlator: scanlator ?? this.scanlator,
      externalUrl: externalUrl ?? this.externalUrl,
    );
  }
}
