import 'package:hive/hive.dart';

part 'manga.g.dart';

@HiveType(typeId: 0)
enum MangaStatus {
  @HiveField(0)
  ongoing('Ongoing'),
  @HiveField(1)
  completed('Completed'),
  @HiveField(2)
  hiatus('Hiatus'),
  @HiveField(3)
  cancelled('Cancelled');

  final String label;
  const MangaStatus(this.label);
}

@HiveType(typeId: 1)
enum MangaSource {
  @HiveField(0)
  mangadex('MangaDex', 'book'),
  @HiveField(1)
  mangakakalot('Mangakakalot', 'menu_book'),
  @HiveField(2)
  webtoons('Webtoons', 'auto_stories'),
  @HiveField(3)
  asurascans('Asura Scans', 'local_fire_department'),
  @HiveField(4)
  custom('Custom Source', 'extension');

  final String label;
  final String iconName;
  const MangaSource(this.label, this.iconName);
}

@HiveType(typeId: 2)
class Manga extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String author;

  @HiveField(3)
  String artist;

  @HiveField(4)
  MangaStatus status;

  @HiveField(5)
  String synopsis;

  @HiveField(6)
  String? coverUrl;

  @HiveField(7)
  MangaSource source;

  @HiveField(8)
  List<String> genres;

  @HiveField(9)
  DateTime lastUpdated;

  @HiveField(10)
  bool isFollowed;

  @HiveField(11)
  double? rating;

  @HiveField(12)
  List<String> chapterIds;

  @HiveField(13)
  String? customSourceId;

  Manga({
    required this.id,
    required this.title,
    this.author = 'Unknown',
    this.artist = 'Unknown',
    this.status = MangaStatus.ongoing,
    this.synopsis = '',
    this.coverUrl,
    this.source = MangaSource.mangadex,
    this.genres = const [],
    DateTime? lastUpdated,
    this.isFollowed = false,
    this.rating,
    this.chapterIds = const [],
    this.customSourceId,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Manga copyWith({
    String? id,
    String? title,
    String? author,
    String? artist,
    MangaStatus? status,
    String? synopsis,
    String? coverUrl,
    MangaSource? source,
    List<String>? genres,
    DateTime? lastUpdated,
    bool? isFollowed,
    double? rating,
    List<String>? chapterIds,
    String? customSourceId,
  }) {
    return Manga(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      artist: artist ?? this.artist,
      status: status ?? this.status,
      synopsis: synopsis ?? this.synopsis,
      coverUrl: coverUrl ?? this.coverUrl,
      source: source ?? this.source,
      genres: genres ?? this.genres,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isFollowed: isFollowed ?? this.isFollowed,
      rating: rating ?? this.rating,
      chapterIds: chapterIds ?? this.chapterIds,
      customSourceId: customSourceId ?? this.customSourceId,
    );
  }
}
