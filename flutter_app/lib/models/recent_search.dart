import 'package:hive/hive.dart';
import 'manga.dart';

part 'recent_search.g.dart';

@HiveType(typeId: 5)
class RecentSearch extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String query;

  @HiveField(2)
  final MangaSource source;

  @HiveField(3)
  DateTime timestamp;

  RecentSearch({
    required this.id,
    required this.query,
    this.source = MangaSource.mangadex,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
