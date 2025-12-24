import '../../models/manga.dart';
import '../../models/chapter.dart';

/// Sort type for browsing manga
enum BrowseSortType {
  popular,
  latest,
}

/// Abstract base class for all manga sources
abstract class BaseSource {
  /// Unique identifier for the source
  String get id;

  /// Display name of the source
  String get name;

  /// Base URL of the source
  String get baseUrl;

  /// Search for manga
  Future<List<Manga>> search(String query);

  /// Get popular manga from the source (paginated)
  Future<List<Manga>> getPopular({int page = 1});

  /// Get latest updated manga from the source (paginated)
  Future<List<Manga>> getLatest({int page = 1});

  /// Get manga details
  Future<Manga> getMangaDetails(String mangaId);

  /// Get chapters for a manga
  Future<List<Chapter>> getChapters(String mangaId);

  /// Get page URLs for a chapter
  Future<List<String>> getChapterPages(String chapterId);

  /// Update cookies (for Cloudflare bypass)
  void setCookies(Map<String, String> cookies) {}

  /// Update User-Agent (for Cloudflare bypass)
  void setUserAgent(String userAgent) {}
}

class CloudflareException implements Exception {
  final String message;
  final String url;
  
  CloudflareException(this.message, this.url);
  
  @override
  String toString() => 'CloudflareException: $message ($url)';
}
