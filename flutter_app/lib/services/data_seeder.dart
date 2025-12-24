import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/manga.dart';
import '../models/chapter.dart';

class DataSeeder {
  static const _uuid = Uuid();

  static Future<void> seedIfNeeded() async {
    final mangaBox = Hive.box<Manga>('manga');
    final chapterBox = Hive.box<Chapter>('chapters');

    if (mangaBox.isNotEmpty) return;

    // Seed sample manga
    final sampleManga = _createSampleManga();

    for (final manga in sampleManga) {
      await mangaBox.put(manga.id, manga);

      // Generate chapters for each manga
      final chapters = _generateChapters(manga.id, manga.title);
      for (final chapter in chapters) {
        await chapterBox.put(chapter.id, chapter);
      }
    }
  }

  static List<Manga> _createSampleManga() {
    return [
      Manga(
        id: _uuid.v4(),
        title: 'Solo Leveling',
        author: 'Chugong',
        artist: 'DUBU',
        status: MangaStatus.completed,
        synopsis: 'In a world where hunters — humans who possess magical abilities — must battle deadly monsters to protect the human race from certain annihilation, a notoriously weak hunter named Sung Jinwoo finds himself in a seemingly endless struggle for survival. One day, after a brutal encounter in an overpowered dungeon wipes out his party and leaves him critically wounded, a mysterious program called the System chooses him as its sole player.',
        coverUrl: 'https://uploads.mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/e90bdc47-c8b9-4df7-b2c0-17641b645ee1.jpg',
        source: MangaSource.mangadex,
        genres: ['Action', 'Adventure', 'Fantasy', 'Supernatural'],
        isFollowed: true,
        rating: 9.2,
      ),
      Manga(
        id: _uuid.v4(),
        title: 'Tower of God',
        author: 'SIU',
        status: MangaStatus.ongoing,
        synopsis: 'What do you desire? Money and wealth? Honor and pride? Authority and power? Revenge? Or something that transcends them all? Whatever you desire—it\'s here. Tower of God follows the story of Twenty-Fifth Bam, a young boy who spent most of his life trapped beneath a mysterious tower.',
        coverUrl: 'https://uploads.mangadex.org/covers/7fbe06c6-7f90-4c38-a3c4-1e2a6e9f7e50/ce61b11d-c6d6-4a23-b9e6-36b7e3d3f3c9.jpg',
        source: MangaSource.webtoons,
        genres: ['Action', 'Adventure', 'Fantasy', 'Drama'],
        isFollowed: true,
        rating: 8.9,
      ),
      Manga(
        id: _uuid.v4(),
        title: 'Omniscient Reader\'s Viewpoint',
        author: 'Sing Shong',
        status: MangaStatus.ongoing,
        synopsis: 'Dokja was an average office worker whose sole hobby was reading his favorite web novel "Three Ways to Survive the Apocalypse." But when the novel suddenly becomes reality, he is the only person who knows the ending.',
        coverUrl: 'https://uploads.mangadex.org/covers/af3f9e1f-6f89-44a3-9f1e-7a9a2e8f4d5c/cb72c8e4-d5d4-4a12-b8e5-24a6e7d2f4b8.jpg',
        source: MangaSource.asurascans,
        genres: ['Action', 'Adventure', 'Fantasy', 'Drama'],
        isFollowed: true,
        rating: 9.1,
      ),
    ];
  }

  static List<Chapter> _generateChapters(String mangaId, String mangaTitle) {
    int chapterCount;
    switch (mangaTitle) {
      case 'Solo Leveling':
        chapterCount = 179;
        break;
      case 'Tower of God':
        chapterCount = 550;
        break;
      default:
        chapterCount = 180;
    }

    return List.generate(chapterCount, (i) {
      final num = i + 1;
      final isRead = num <= (chapterCount * 0.3).toInt();

      return Chapter(
        id: _uuid.v4(),
        mangaId: mangaId,
        title: num == 1 ? 'Prologue' : '',
        number: num.toDouble(),
        releaseDate: DateTime.now().subtract(Duration(days: (chapterCount - num) * 3)),
        isRead: isRead,
        pageCount: 20 + (num % 15),
        scanlator: 'Official',
      );
    });
  }
}
