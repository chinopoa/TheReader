import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/manga.dart';
import '../../models/chapter.dart';
import 'base_source.dart';

/// Source implementation that connects to a Suwayomi/Tachidesk server
/// This allows using ALL Tachiyomi extensions through the server
class TachideskSource implements BaseSource {
  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl; // Tachidesk server URL, e.g., http://192.168.1.100:4567

  final String sourceId; // The actual source ID on the Tachidesk server
  final http.Client _client = http.Client();

  TachideskSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.sourceId,
  });

  @override
  void setCookies(Map<String, String> cookies) {
    // Not used - Tachidesk handles cookies
  }

  @override
  void setUserAgent(String userAgent) {
    // Not used - Tachidesk handles user agent
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Execute a GraphQL query
  Future<Map<String, dynamic>> _graphql(String query, [Map<String, dynamic>? variables]) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/graphql'),
      headers: _headers,
      body: json.encode({
        'query': query,
        if (variables != null) 'variables': variables,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('GraphQL request failed: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    if (data['errors'] != null) {
      throw Exception('GraphQL error: ${data['errors']}');
    }

    return data['data'] as Map<String, dynamic>;
  }

  @override
  Future<List<Manga>> getPopular({int page = 1}) async {
    try {
      final query = '''
        query GetMangaList(\$sourceId: LongString!, \$page: Int!) {
          fetchSourceManga(
            sourceId: \$sourceId,
            type: POPULAR,
            page: \$page
          ) {
            hasNextPage
            mangas {
              id
              title
              thumbnailUrl
              author
              artist
              status
              description
              genre
              inLibrary
            }
          }
        }
      ''';

      final data = await _graphql(query, {
        'sourceId': sourceId,
        'page': page,
      });

      final mangaList = data['fetchSourceManga']['mangas'] as List;
      return mangaList.map((m) => _parseManga(m)).toList();
    } catch (e) {
      print('Tachidesk getPopular error: $e');
      // Fallback to REST API
      return _getPopularRest(page);
    }
  }

  Future<List<Manga>> _getPopularRest(int page) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/source/$sourceId/popular/$page'),
        headers: _headers,
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final mangaList = data['mangaList'] as List? ?? [];
      return mangaList.map((m) => _parseMangaRest(m)).toList();
    } catch (e) {
      print('Tachidesk REST getPopular error: $e');
      return [];
    }
  }

  @override
  Future<List<Manga>> getLatest({int page = 1}) async {
    try {
      final query = '''
        query GetMangaList(\$sourceId: LongString!, \$page: Int!) {
          fetchSourceManga(
            sourceId: \$sourceId,
            type: LATEST,
            page: \$page
          ) {
            hasNextPage
            mangas {
              id
              title
              thumbnailUrl
              author
              artist
              status
              description
              genre
              inLibrary
            }
          }
        }
      ''';

      final data = await _graphql(query, {
        'sourceId': sourceId,
        'page': page,
      });

      final mangaList = data['fetchSourceManga']['mangas'] as List;
      return mangaList.map((m) => _parseManga(m)).toList();
    } catch (e) {
      print('Tachidesk getLatest error: $e');
      // Fallback to REST API
      return _getLatestRest(page);
    }
  }

  Future<List<Manga>> _getLatestRest(int page) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/source/$sourceId/latest/$page'),
        headers: _headers,
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final mangaList = data['mangaList'] as List? ?? [];
      return mangaList.map((m) => _parseMangaRest(m)).toList();
    } catch (e) {
      print('Tachidesk REST getLatest error: $e');
      return [];
    }
  }

  @override
  Future<List<Manga>> search(String query) async {
    try {
      final gql = '''
        query SearchManga(\$sourceId: LongString!, \$query: String!, \$page: Int!) {
          fetchSourceManga(
            sourceId: \$sourceId,
            type: SEARCH,
            query: \$query,
            page: \$page
          ) {
            hasNextPage
            mangas {
              id
              title
              thumbnailUrl
              author
              artist
              status
              description
              genre
              inLibrary
            }
          }
        }
      ''';

      final data = await _graphql(gql, {
        'sourceId': sourceId,
        'query': query,
        'page': 1,
      });

      final mangaList = data['fetchSourceManga']['mangas'] as List;
      return mangaList.map((m) => _parseManga(m)).toList();
    } catch (e) {
      print('Tachidesk search error: $e');
      // Fallback to REST API
      return _searchRest(query);
    }
  }

  Future<List<Manga>> _searchRest(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/source/$sourceId/search?searchTerm=$encodedQuery&pageNum=1'),
        headers: _headers,
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final mangaList = data['mangaList'] as List? ?? [];
      return mangaList.map((m) => _parseMangaRest(m)).toList();
    } catch (e) {
      print('Tachidesk REST search error: $e');
      return [];
    }
  }

  @override
  Future<Manga> getMangaDetails(String mangaId) async {
    try {
      final query = '''
        query GetManga(\$id: Int!) {
          manga(id: \$id) {
            id
            title
            thumbnailUrl
            author
            artist
            status
            description
            genre
            inLibrary
          }
        }
      ''';

      final data = await _graphql(query, {
        'id': int.parse(mangaId),
      });

      return _parseManga(data['manga']);
    } catch (e) {
      print('Tachidesk getMangaDetails error: $e');
      // Fallback to REST
      return _getMangaDetailsRest(mangaId);
    }
  }

  Future<Manga> _getMangaDetailsRest(String mangaId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/manga/$mangaId/?onlineFetch=true'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get manga details');
    }

    final data = json.decode(response.body);
    return _parseMangaRest(data);
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final query = '''
        query GetChapters(\$mangaId: Int!) {
          chapters(condition: { mangaId: \$mangaId }) {
            nodes {
              id
              name
              chapterNumber
              scanlator
              uploadDate
              isRead
              isDownloaded
              pageCount
            }
          }
        }
      ''';

      final data = await _graphql(query, {
        'mangaId': int.parse(mangaId),
      });

      final chapterList = data['chapters']['nodes'] as List;
      return chapterList.map((c) => _parseChapter(c, mangaId)).toList();
    } catch (e) {
      print('Tachidesk getChapters error: $e');
      // Fallback to REST
      return _getChaptersRest(mangaId);
    }
  }

  Future<List<Chapter>> _getChaptersRest(String mangaId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/manga/$mangaId/chapters?onlineFetch=true'),
        headers: _headers,
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as List;
      return data.map((c) => _parseChapterRest(c, mangaId)).toList();
    } catch (e) {
      print('Tachidesk REST getChapters error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    try {
      final query = '''
        query GetChapterPages(\$chapterId: Int!) {
          chapter(id: \$chapterId) {
            pageCount
          }
        }
      ''';

      final data = await _graphql(query, {
        'chapterId': int.parse(chapterId),
      });

      final pageCount = data['chapter']['pageCount'] as int;

      // Generate page URLs
      return List.generate(
        pageCount,
        (i) => '$baseUrl/api/v1/manga/chapter/$chapterId/page/$i',
      );
    } catch (e) {
      print('Tachidesk getChapterPages error: $e');
      // Fallback to REST
      return _getChapterPagesRest(chapterId);
    }
  }

  Future<List<String>> _getChapterPagesRest(String chapterId) async {
    try {
      // First, get the chapter to know page count
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/manga/chapter/$chapterId'),
        headers: _headers,
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final pageCount = data['pageCount'] as int? ?? 0;

      // Generate page URLs
      return List.generate(
        pageCount,
        (i) => '$baseUrl/api/v1/manga/chapter/$chapterId/page/$i',
      );
    } catch (e) {
      print('Tachidesk REST getChapterPages error: $e');
      return [];
    }
  }

  Manga _parseManga(Map<String, dynamic> data) {
    MangaStatus status = MangaStatus.ongoing;
    final statusStr = (data['status'] ?? '').toString().toUpperCase();
    if (statusStr.contains('COMPLETED') || statusStr.contains('FINISHED')) {
      status = MangaStatus.completed;
    } else if (statusStr.contains('HIATUS')) {
      status = MangaStatus.hiatus;
    } else if (statusStr.contains('CANCELLED') || statusStr.contains('CANCELED')) {
      status = MangaStatus.cancelled;
    }

    final genres = data['genre'] is List
        ? (data['genre'] as List).map((g) => g.toString()).toList()
        : <String>[];

    return Manga(
      id: data['id'].toString(),
      title: data['title'] ?? 'Unknown',
      author: data['author'],
      artist: data['artist'],
      status: status,
      synopsis: data['description'],
      coverUrl: data['thumbnailUrl'],
      genres: genres,
      source: MangaSource.custom,
      customSourceId: id,
      isFollowed: data['inLibrary'] ?? false,
    );
  }

  Manga _parseMangaRest(Map<String, dynamic> data) {
    MangaStatus status = MangaStatus.ongoing;
    final statusStr = (data['status'] ?? '').toString().toUpperCase();
    if (statusStr.contains('COMPLETED') || statusStr.contains('FINISHED')) {
      status = MangaStatus.completed;
    } else if (statusStr.contains('HIATUS')) {
      status = MangaStatus.hiatus;
    } else if (statusStr.contains('CANCELLED') || statusStr.contains('CANCELED')) {
      status = MangaStatus.cancelled;
    }

    final genres = data['genre'] is List
        ? (data['genre'] as List).map((g) => g.toString()).toList()
        : <String>[];

    // Construct thumbnail URL
    String? thumbnailUrl = data['thumbnailUrl'];
    if (thumbnailUrl != null && !thumbnailUrl.startsWith('http')) {
      thumbnailUrl = '$baseUrl$thumbnailUrl';
    }

    return Manga(
      id: data['id'].toString(),
      title: data['title'] ?? 'Unknown',
      author: data['author'],
      artist: data['artist'],
      status: status,
      synopsis: data['description'],
      coverUrl: thumbnailUrl,
      genres: genres,
      source: MangaSource.custom,
      customSourceId: id,
      isFollowed: data['inLibrary'] ?? false,
    );
  }

  Chapter _parseChapter(Map<String, dynamic> data, String mangaId) {
    return Chapter(
      id: data['id'].toString(),
      mangaId: mangaId,
      title: data['name'] ?? '',
      number: (data['chapterNumber'] ?? 0).toDouble(),
      scanlator: data['scanlator'],
      releaseDate: data['uploadDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['uploadDate'])
          : null,
      isRead: data['isRead'] ?? false,
      isDownloaded: data['isDownloaded'] ?? false,
      pageCount: data['pageCount'],
    );
  }

  Chapter _parseChapterRest(Map<String, dynamic> data, String mangaId) {
    return Chapter(
      id: data['index'].toString(),
      mangaId: mangaId,
      title: data['name'] ?? '',
      number: (data['chapterNumber'] ?? data['index'] ?? 0).toDouble(),
      scanlator: data['scanlator'],
      releaseDate: data['uploadDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['uploadDate'])
          : null,
      isRead: data['read'] ?? false,
      isDownloaded: data['downloaded'] ?? false,
      pageCount: data['pageCount'],
    );
  }
}

/// Service to connect to and manage a Tachidesk server
class TachideskService {
  final String serverUrl;
  final http.Client _client = http.Client();

  TachideskService(this.serverUrl);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Check if server is reachable
  Future<bool> checkConnection() async {
    try {
      final response = await _client.get(
        Uri.parse('$serverUrl/api/v1/settings/about'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get server info
  Future<Map<String, dynamic>?> getServerInfo() async {
    try {
      final response = await _client.get(
        Uri.parse('$serverUrl/api/v1/settings/about'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Failed to get server info: $e');
    }
    return null;
  }

  /// Get list of available sources (extensions)
  Future<List<Map<String, dynamic>>> getSources() async {
    try {
      final response = await _client.get(
        Uri.parse('$serverUrl/api/v1/source/list'),
        headers: _headers,
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as List;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Failed to get sources: $e');
      return [];
    }
  }

  /// Get list of installed extensions
  Future<List<Map<String, dynamic>>> getExtensions() async {
    try {
      final response = await _client.get(
        Uri.parse('$serverUrl/api/v1/extension/list'),
        headers: _headers,
      );

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body) as List;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Failed to get extensions: $e');
      return [];
    }
  }

  /// Install an extension by package name
  Future<bool> installExtension(String pkgName) async {
    try {
      final response = await _client.get(
        Uri.parse('$serverUrl/api/v1/extension/install/$pkgName'),
        headers: _headers,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Failed to install extension: $e');
      return false;
    }
  }

  /// Create a TachideskSource for a specific source on the server
  TachideskSource createSource({
    required String sourceId,
    required String sourceName,
  }) {
    return TachideskSource(
      id: 'tachidesk_$sourceId',
      name: sourceName,
      baseUrl: serverUrl,
      sourceId: sourceId,
    );
  }
}
