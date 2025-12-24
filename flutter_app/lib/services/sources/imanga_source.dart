import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'base_source.dart';
import '../../models/manga.dart';
import '../../models/chapter.dart';

/// A manga source that consumes pre-indexed data from imanga.co servers
/// Used by MangaReader iOS app - much more reliable than web scraping
class IMangaSource extends BaseSource {
  @override
  final String id;
  
  @override
  final String name;
  
  @override
  final String baseUrl;
  
  final String indexUrl;      // URL to gzipped manga index
  final String? updateUrl;    // Base URL for updates
  final String? tagsUrl;      // URL to genre/tag definitions
  final String? coverReferer; // Referer header for cover images
  final String? userAgent;    // Custom user agent
  
  // Cached manga list - kept in memory for instant search
  List<Manga>? _cachedMangaList;
  DateTime? _cacheTime;
  bool _isLoading = false;
  static const _cacheDuration = Duration(hours: 24); // Cache for 24 hours like MangaReader
  
  final http.Client _client = http.Client();
  
  /// Check if index is already loaded in memory
  bool get isIndexLoaded => _cachedMangaList != null;
  
  /// Preload the index in background (call on app startup)
  Future<void> preloadIndex() async {
    if (_cachedMangaList != null || _isLoading) return;
    _isLoading = true;
    try {
      await _loadIndex();
    } finally {
      _isLoading = false;
    }
  }
  
  IMangaSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.indexUrl,
    this.updateUrl,
    this.tagsUrl,
    this.coverReferer,
    this.userAgent,
  });
  
  Map<String, String> get _headers => {
    'User-Agent': userAgent ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    if (coverReferer != null) 'Referer': coverReferer!,
  };
  
  /// Wrap URL with CORS proxy for web platform
  String _wrapWithCorsProxy(String url) {
    if (kIsWeb) {
      return 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
    }
    return url;
  }
  
  /// Fetch and decompress gzipped JSON from URL
  Future<dynamic> _fetchGzippedJson(String url) async {
    final requestUrl = _wrapWithCorsProxy(url);
    print('IManga [$name]: fetching $requestUrl');
    
    try {
      final response = await _client.get(Uri.parse(requestUrl), headers: _headers)
          .timeout(const Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      // Check if response is gzipped
      final bytes = response.bodyBytes;
      List<int> decompressed;
      
      // GZip magic number is 1f 8b
      if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
        decompressed = gzip.decode(bytes);
      } else {
        // Already decompressed (some proxies decompress automatically)
        decompressed = bytes;
      }
      
      final jsonStr = utf8.decode(decompressed);
      return json.decode(jsonStr);
    } catch (e) {
      print('IManga [$name]: fetch error: $e');
      rethrow;
    }
  }
  
  /// Get the disk cache file path for this source's index
  Future<String> _getDiskCachePath() async {
    if (kIsWeb) return ''; // Web doesn't support disk caching
    final dir = await getApplicationCacheDirectory();
    return '${dir.path}/imanga_${id}_index.json';
  }
  
  /// Load index from disk cache (INSTANT - no network!)
  Future<List<Manga>?> _loadFromDisk() async {
    if (kIsWeb) return null;
    
    try {
      final path = await _getDiskCachePath();
      final file = File(path);
      
      if (!await file.exists()) {
        print('IManga [$name]: no disk cache found');
        return null;
      }
      
      // Check if cache is expired (7 days)
      final stat = await file.stat();
      final age = DateTime.now().difference(stat.modified);
      if (age.inDays > 7) {
        print('IManga [$name]: disk cache expired (${age.inDays} days old)');
        return null;
      }
      
      print('IManga [$name]: loading from disk cache...');
      final jsonStr = await file.readAsString();
      final data = json.decode(jsonStr) as List;
      
      final mangaList = _parseIndexData(data);
      print('IManga [$name]: loaded ${mangaList.length} manga from disk (instant!)');
      return mangaList;
    } catch (e) {
      print('IManga [$name]: disk cache error: $e');
      return null;
    }
  }
  
  /// Save index to disk for instant loading next time
  Future<void> _saveToDisk(List<dynamic> rawData) async {
    if (kIsWeb) return;
    
    try {
      final path = await _getDiskCachePath();
      final file = File(path);
      await file.writeAsString(json.encode(rawData));
      print('IManga [$name]: saved ${rawData.length} items to disk cache');
    } catch (e) {
      print('IManga [$name]: failed to save disk cache: $e');
    }
  }
  
  /// Parse raw JSON data into Manga list
  List<Manga> _parseIndexData(List<dynamic> data) {
    final mangaList = <Manga>[];
    
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      
      // Skip inactive manga
      if (item['isOn'] == false) continue;
      
      final mangaName = item['name'] as String? ?? '';
      if (mangaName.isEmpty) continue;
      
      // Extract ID from mJLink
      final mJLink = item['mJLink'] as String? ?? '';
      final mangaId = Uri.decodeComponent(
        mJLink.split('/mangas/').last.replaceAll('/detail.gz', '')
      );
      
      mangaList.add(Manga(
        id: mangaId,
        title: mangaName,
        coverUrl: _proxyCoverUrl(item['cover'] as String? ?? ''),
        author: (item['author'] as String?) ?? 'Unknown',
        genres: (item['genres'] as String?)?.split(',').map((g) => g.trim()).toList() ?? [],
        source: MangaSource.custom,
        customSourceId: id,
      ));
    }
    
    return mangaList;
  }
  
  /// Load the full manga index (disk-cached for instant search)
  Future<List<Manga>> _loadIndex() async {
    // 1. Check memory cache (instant)
    if (_cachedMangaList != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        print('IManga [$name]: using memory cache (${_cachedMangaList!.length} items)');
        return _cachedMangaList!;
      }
    }
    
    // 2. Check disk cache (instant - no network!)
    final diskData = await _loadFromDisk();
    if (diskData != null) {
      _cachedMangaList = diskData;
      _cacheTime = DateTime.now();
      return diskData;
    }
    
    // 3. Download from network (slow, but only first time or when expired)
    print('IManga [$name]: downloading index from network...');
    
    try {
      final data = await _fetchGzippedJson(indexUrl);
      
      if (data is! List) {
        throw Exception('Index is not a list');
      }
      
      // Save to disk for next time
      await _saveToDisk(data);
      
      final mangaList = _parseIndexData(data);
      
      // Cache the result in memory
      _cachedMangaList = mangaList;
      _cacheTime = DateTime.now();
      
      print('IManga [$name]: loaded ${mangaList.length} manga from network');
      return mangaList;
    } catch (e) {
      print('IManga [$name]: failed to load index: $e');
      return [];
    }
  }
  
  /// Proxy cover URL to avoid CORS issues on web
  String _proxyCoverUrl(String url) {
    if (url.isEmpty) return '';
    
    // Use wsrv.nl image proxy on web
    if (kIsWeb) {
      return 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }
  
  @override
  Future<List<Manga>> getPopular({int page = 1}) async {
    final allManga = await _loadIndex();
    
    // Sort by rating (descending) for "popular"
    // The index doesn't have view counts, so rating is best proxy
    final sorted = List<Manga>.from(allManga);
    // Note: We don't have rating in Manga model, so just return as-is
    // In a full implementation, we'd parse and sort by rating
    
    // Paginate (50 per page)
    const pageSize = 50;
    final start = (page - 1) * pageSize;
    if (start >= sorted.length) return [];
    
    final end = start + pageSize;
    return sorted.sublist(start, end > sorted.length ? sorted.length : end);
  }
  
  @override
  Future<List<Manga>> getLatest({int page = 1}) async {
    // For latest, we'd ideally fetch from updateUrl
    // For now, just return from index (already sorted by update time)
    return getPopular(page: page);
  }
  
  @override
  Future<List<Manga>> search(String query) async {
    final allManga = await _loadIndex();
    final queryLower = query.toLowerCase();
    
    print('IManga [$name]: searching for "$query" in ${allManga.length} manga');
    
    // Filter by title match
    final results = allManga.where((manga) {
      return manga.title.toLowerCase().contains(queryLower);
    }).take(50).toList();
    
    print('IManga [$name]: found ${results.length} results for "$query"');
    
    return results;
  }
  
  @override
  Future<Manga> getMangaDetails(String mangaId) async {
    // Find in cached list first
    final allManga = await _loadIndex();
    final manga = allManga.firstWhere(
      (m) => m.id == mangaId,
      orElse: () => Manga(
        id: mangaId,
        title: mangaId,
        source: MangaSource.custom,
        customSourceId: id,
      ),
    );
    
    // For full details, we'd fetch from mJLink (detail.gz)
    // This would give us synopsis, status, etc.
    // For now, return basic info from index
    
    return manga;
  }
  
  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    // Construct the detail URL from the indexUrl pattern
    // indexUrl format: http://k.imanga.co/mangakakalot/indexs.gz
    // detail format:   http://k.imanga.co/mangakakalot/mangas/{mangaId}/detail.gz
    final baseIndexUrl = indexUrl.replaceAll('/indexs.gz', '').replaceAll('/indexs_an.gz', '');
    final detailUrl = '$baseIndexUrl/mangas/${Uri.encodeComponent(mangaId)}/detail.gz';
    
    print('IManga [$name]: fetching chapters from $detailUrl');
    
    try {
      final data = await _fetchGzippedJson(detailUrl);
      
      if (data is! Map<String, dynamic>) {
        throw Exception('Detail is not a map');
      }
      
      // Chapters are in 'chs' array with cTitle, cName, cJLink
      final chaptersData = data['chs'] as List? ?? [];
      final chapters = <Chapter>[];
      
      for (int i = 0; i < chaptersData.length; i++) {
        final ch = chaptersData[i];
        if (ch is! Map<String, dynamic>) continue;
        
        final cName = ch['cName'] as String? ?? '${i + 1}';
        final cTitle = ch['cTitle'] as String? ?? 'Chapter $cName';
        final cJLink = ch['cJLink'] as String? ?? '';
        
        // Parse chapter number from cName (e.g., "135" or "128 - Asura Scans")
        final numberMatch = RegExp(r'^\d+').firstMatch(cName);
        final chapterNum = numberMatch != null 
            ? double.tryParse(numberMatch.group(0)!) ?? (chaptersData.length - i).toDouble()
            : (chaptersData.length - i).toDouble();
        
        chapters.add(Chapter(
          id: 'ch-${cName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-')}',
          mangaId: mangaId,
          title: cTitle.split('  ').first, // Remove timestamp
          number: chapterNum,
          externalUrl: cJLink, // URL to chapter pages JSON
        ));
      }
      
      // Sort by chapter number (descending - newest first)
      chapters.sort((a, b) => b.number.compareTo(a.number));
      
      print('IManga [$name]: found ${chapters.length} chapters for $mangaId');
      return chapters;
    } catch (e) {
      print('IManga [$name]: failed to get chapters: $e');
      return [];
    }
  }
  
  @override
  Future<List<String>> getChapterPages(String chapterUrl) async {
    if (chapterUrl.isEmpty) return [];
    
    print('IManga [$name]: fetching chapter pages from $chapterUrl');
    
    try {
      // Chapter URL points to gzipped JSON with page data
      final data = await _fetchGzippedJson(chapterUrl);
      
      if (data is List) {
        // Format: [{pRef, pId, pUrl}, ...] - extract pUrl from each
        final pages = <String>[];
        for (final page in data) {
          if (page is Map<String, dynamic> && page['pUrl'] != null) {
            pages.add(_proxyCoverUrl(page['pUrl'] as String));
          } else if (page is String) {
            // Fallback if just plain URL strings
            pages.add(_proxyCoverUrl(page));
          }
        }
        print('IManga [$name]: found ${pages.length} pages');
        return pages;
      } else if (data is Map && data['images'] is List) {
        // Alternative format with images array
        return (data['images'] as List).map((url) => _proxyCoverUrl(url.toString())).toList();
      }
      
      print('IManga [$name]: unexpected chapter data format');
      return [];
    } catch (e) {
      print('IManga [$name]: failed to get pages: $e');
      return [];
    }
  }
}
