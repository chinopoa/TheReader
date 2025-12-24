import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/manga.dart';
import '../models/chapter.dart';
import 'source_service.dart';

final mangaServiceProvider = Provider<MangaService>((ref) {
  final sourceService = ref.watch(sourceServiceProvider);
  return MangaService(sourceService);
});

/// Unified service for manga operations that delegates to source-specific services
class MangaService {
  final SourceService _sourceService;

  MangaService(this._sourceService);

  /// Search for manga using the appropriate source
  /// Legacy method - use searchSource with source ID instead
  Future<List<Manga>> search(String query, MangaSource source) async {
    // For legacy enum-based calls, search the first available source
    final sources = _sourceService.getSources();
    if (sources.isEmpty) return [];
    return sources.first.search(query);
  }
  
  /// Search using a specific source ID (for extensions)
  Future<List<Manga>> searchSource(String query, String sourceId) async {
    final source = _sourceService.getSource(sourceId);
    if (source != null) {
      return source.search(query);
    }
    return [];
  }

  /// Get manga details
  Future<Manga?> getMangaDetails(Manga manga) async {
    final source = _sourceService.getSourceForManga(manga);
    if (source != null) {
      try {
        final details = await source.getMangaDetails(manga.id);
        // Merge details with existing manga object or return new one?
        // Usually return simple object.
        return details;
      } catch (e) {
        print('Error getting manga details: $e');
        return null; // Or rethrow?
      }
    }
    // Fallback to MangaDex if source not found but enum says mangadex?
    // Should be handled by getSourceForManga returning MangaDexSource.
    return null;
  }

  /// Get chapters for a manga
  Future<List<Chapter>> getChapters(Manga manga) async {
    final source = _sourceService.getSourceForManga(manga);
    if (source != null) {
      return source.getChapters(manga.id);
    }
    return [];
  }

  /// Get page URLs for a chapter
  /// Uses externalUrl for IManga sources (contains cJLink), otherwise uses chapter ID
  Future<List<String>> getChapterPages(Chapter chapter, Manga manga) async {
    final source = _sourceService.getSourceForManga(manga);
    if (source != null) {
      // For IManga sources, use externalUrl which contains the cJLink URL
      // For other sources, use the chapter ID
      final pageUrl = (chapter.externalUrl?.isNotEmpty ?? false) 
          ? chapter.externalUrl! 
          : chapter.id;
      return source.getChapterPages(pageUrl);
    }
    return [];
  }
}
