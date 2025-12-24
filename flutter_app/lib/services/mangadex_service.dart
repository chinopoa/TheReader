import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/manga.dart';
import '../models/chapter.dart';

/// Service for interacting with the MangaDex API
class MangaDexService {
  static const String _baseUrl = 'https://api.mangadex.org';

  /// Search for manga by query
  static Future<List<Manga>> search(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/manga').replace(queryParameters: {
        'title': query,
        'limit': limit.toString(),
        'includes[]': 'cover_art',
        'order[relevance]': 'desc',
        'contentRating[]': 'safe',
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to search manga: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<dynamic> results = data['data'] ?? [];

      return results.map((item) => _parseManga(item)).toList();
    } catch (e) {
      print('MangaDex search error: $e');
      return [];
    }
  }

  /// Get popular manga (ordered by followers)
  static Future<List<Manga>> getPopular({int page = 1, int limit = 20}) async {
    try {
      final offset = (page - 1) * limit;
      final uri = Uri.parse('$_baseUrl/manga').replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'includes[]': 'cover_art',
        'order[followedCount]': 'desc',
        'contentRating[]': 'safe',
        'hasAvailableChapters': 'true',
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to get popular manga: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<dynamic> results = data['data'] ?? [];

      return results.map((item) => _parseManga(item)).toList();
    } catch (e) {
      print('MangaDex getPopular error: $e');
      return [];
    }
  }

  /// Get latest updated manga
  static Future<List<Manga>> getLatest({int page = 1, int limit = 20}) async {
    try {
      final offset = (page - 1) * limit;
      final uri = Uri.parse('$_baseUrl/manga').replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'includes[]': 'cover_art',
        'order[latestUploadedChapter]': 'desc',
        'contentRating[]': 'safe',
        'hasAvailableChapters': 'true',
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to get latest manga: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<dynamic> results = data['data'] ?? [];

      return results.map((item) => _parseManga(item)).toList();
    } catch (e) {
      print('MangaDex getLatest error: $e');
      return [];
    }
  }

  /// Get manga details by ID
  static Future<Manga?> getMangaDetails(String mangaId) async {
    try {
      final uri = Uri.parse('$_baseUrl/manga/$mangaId').replace(queryParameters: {
        'includes[]': 'cover_art',
      });

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      return _parseManga(data['data']);
    } catch (e) {
      print('MangaDex getMangaDetails error: $e');
      return null;
    }
  }

  /// Get chapters for a manga (fetches all chapters with pagination)
  static Future<List<Chapter>> getChapters(String mangaId, {int limit = 500}) async {
    try {
      List<Chapter> allChapters = [];
      int offset = 0;
      final batchSize = 100; // MangaDex max per request
      
      while (true) {
        final uri = Uri.parse('$_baseUrl/manga/$mangaId/feed').replace(queryParameters: {
          'limit': batchSize.toString(),
          'offset': offset.toString(),
          'translatedLanguage[]': 'en',
          'order[chapter]': 'desc',
          'includes[]': 'scanlation_group',
        });

        final response = await http.get(uri, headers: {
          'Accept': 'application/json',
        });

        if (response.statusCode != 200) {
          print('MangaDex getChapters status: ${response.statusCode}');
          break;
        }

        final data = json.decode(response.body);
        final List<dynamic> results = data['data'] ?? [];
        
        if (results.isEmpty) break;
        
        allChapters.addAll(results.map((item) => _parseChapter(item, mangaId)));
        
        // Check if we got all chapters or hit the limit
        final total = data['total'] ?? 0;
        offset += batchSize;
        
        if (offset >= total || allChapters.length >= limit) break;
      }
      
      // Sort by chapter number descending
      allChapters.sort((a, b) => b.number.compareTo(a.number));
      
      // Filter out chapters with external URLs (can't be read through MangaDex)
      allChapters = allChapters.where((c) => c.externalUrl == null).toList();
      
      return allChapters;
    } catch (e) {
      print('MangaDex getChapters error: $e');
      return [];
    }
  }

  /// Get page URLs for a chapter
  static Future<List<String>> getChapterPages(String chapterId) async {
    try {
      final uri = Uri.parse('$_baseUrl/at-home/server/$chapterId');

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to get chapter pages: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final String baseUrl = data['baseUrl'];
      final String hash = data['chapter']['hash'];
      final List<dynamic> pageFilenames = data['chapter']['data'] ?? [];

      // Build full URLs for each page
      return pageFilenames
          .map((filename) => '$baseUrl/data/$hash/$filename')
          .toList()
          .cast<String>();
    } catch (e) {
      print('MangaDex getChapterPages error: $e');
      return [];
    }
  }

  /// Get data-saver (lower quality) page URLs for a chapter
  static Future<List<String>> getChapterPagesDataSaver(String chapterId) async {
    try {
      final uri = Uri.parse('$_baseUrl/at-home/server/$chapterId');

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to get chapter pages: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final String baseUrl = data['baseUrl'];
      final String hash = data['chapter']['hash'];
      final List<dynamic> pageFilenames = data['chapter']['dataSaver'] ?? [];

      return pageFilenames
          .map((filename) => '$baseUrl/data-saver/$hash/$filename')
          .toList()
          .cast<String>();
    } catch (e) {
      print('MangaDex getChapterPagesDataSaver error: $e');
      return [];
    }
  }

  /// Parse manga from API response
  static Manga _parseManga(Map<String, dynamic> item) {
    final attributes = item['attributes'] ?? {};
    final relationships = item['relationships'] as List<dynamic>? ?? [];

    // Get cover art
    String? coverUrl;
    for (final rel in relationships) {
      if (rel['type'] == 'cover_art') {
        final coverFilename = rel['attributes']?['fileName'];
        if (coverFilename != null) {
          coverUrl = 'https://uploads.mangadex.org/covers/${item['id']}/$coverFilename';
        }
        break;
      }
    }

    // Get title (prefer English)
    final titles = attributes['title'] ?? {};
    final altTitles = attributes['altTitles'] as List<dynamic>? ?? [];
    String title = titles['en'] ?? 
                   titles['ja-ro'] ?? 
                   titles['ja'] ?? 
                   titles.values.first ?? 
                   'Unknown Title';
    
    // Check altTitles for English
    if (title == 'Unknown Title' || !titles.containsKey('en')) {
      for (final alt in altTitles) {
        if (alt is Map && alt.containsKey('en')) {
          title = alt['en'];
          break;
        }
      }
    }

    // Get description (prefer English)
    final descriptions = attributes['description'] ?? {};
    String synopsis = descriptions['en'] ?? 
                      (descriptions.values.isNotEmpty ? descriptions.values.first : null) ?? 
                      'No description available.';

    // Parse status
    MangaStatus status;
    switch (attributes['status']) {
      case 'completed':
        status = MangaStatus.completed;
        break;
      case 'ongoing':
        status = MangaStatus.ongoing;
        break;
      case 'hiatus':
        status = MangaStatus.hiatus;
        break;
      case 'cancelled':
        status = MangaStatus.cancelled;
        break;
      default:
        status = MangaStatus.ongoing;
    }

    // Get tags/genres
    final tags = attributes['tags'] as List<dynamic>? ?? [];
    final genres = tags
        .where((tag) => tag['attributes']?['group'] == 'genre')
        .map((tag) => tag['attributes']?['name']?['en'] as String?)
        .whereType<String>()
        .toList();

    return Manga(
      id: item['id'],
      title: title,
      author: _getCreator(relationships, 'author'),
      artist: _getCreator(relationships, 'artist'),
      status: status,
      synopsis: synopsis,
      coverUrl: coverUrl,
      source: MangaSource.mangadex,
      genres: genres,
      rating: 0.0, // MangaDex doesn't provide rating in search
    );
  }

  /// Get author/artist name from relationships
  static String _getCreator(List<dynamic> relationships, String type) {
    for (final rel in relationships) {
      if (rel['type'] == type) {
        return rel['attributes']?['name'] ?? 'Unknown';
      }
    }
    return 'Unknown';
  }

  /// Parse chapter from API response
  static Chapter _parseChapter(Map<String, dynamic> item, String mangaId) {
    final attributes = item['attributes'] ?? {};
    final relationships = item['relationships'] as List<dynamic>? ?? [];

    // Get scanlation group
    String? scanlator;
    for (final rel in relationships) {
      if (rel['type'] == 'scanlation_group') {
        scanlator = rel['attributes']?['name'];
        break;
      }
    }

    // Parse chapter number
    final chapterNum = attributes['chapter'];
    double number = 0.0;
    if (chapterNum != null) {
      number = double.tryParse(chapterNum.toString()) ?? 0.0;
    }

    // Parse volume
    final volumeVal = attributes['volume'];
    int? volume;
    if (volumeVal != null) {
      volume = int.tryParse(volumeVal.toString());
    }

    // Parse release date
    DateTime releaseDate = DateTime.now();
    if (attributes['publishAt'] != null) {
      releaseDate = DateTime.tryParse(attributes['publishAt']) ?? DateTime.now();
    }

    return Chapter(
      id: item['id'],
      mangaId: mangaId,
      title: attributes['title'] ?? '',
      number: number,
      volume: volume,
      releaseDate: releaseDate,
      pageCount: attributes['pages'] ?? 0,
      scanlator: scanlator,
      externalUrl: attributes['externalUrl'],
    );
  }
}
