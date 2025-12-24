import '../../models/manga.dart';
import '../../models/chapter.dart';
import '../mangadex_service.dart';
import 'base_source.dart';

class MangaDexSource implements BaseSource {
  @override
  String get id => 'mangadex';

  @override
  String get name => 'MangaDex';

  @override
  String get baseUrl => 'https://mangadex.org';

  @override
  Future<List<Manga>> search(String query) async {
    return MangaDexService.search(query);
  }

  @override
  Future<List<Manga>> getPopular({int page = 1}) async {
    return MangaDexService.getPopular(page: page);
  }

  @override
  Future<List<Manga>> getLatest({int page = 1}) async {
    return MangaDexService.getLatest(page: page);
  }

  @override
  Future<Manga> getMangaDetails(String mangaId) async {
    final manga = await MangaDexService.getMangaDetails(mangaId);
    if (manga == null) throw Exception('Manga not found');
    return manga;
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    return MangaDexService.getChapters(mangaId);
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    return MangaDexService.getChapterPages(chapterId);
  }

  @override
  void setCookies(Map<String, String> cookies) {
    // MangaDex doesn't use Cloudflare cookies currently, but we must implement the interface
  }

  @override
  void setUserAgent(String userAgent) {
    // MangaDex doesn't use Cloudflare UA currently
  }
}
