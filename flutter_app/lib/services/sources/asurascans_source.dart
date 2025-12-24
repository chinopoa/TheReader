import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import '../../models/manga.dart';
import '../../models/chapter.dart';
import 'base_source.dart';

/// Source implementation for AsuraScans/AsuraComic (Next.js based sites)
class AsuraScansSource implements BaseSource {
  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;

  final http.Client _client = http.Client();
  
  // CORS proxy for web platform - use corsproxy.io which handles Cloudflare better
  static const String _corsProxy = 'https://corsproxy.io/?';

  Map<String, String> _cookies = {};
  String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  AsuraScansSource({
    required this.id,
    required this.name,
    required this.baseUrl,
  });
  
  /// Wrap URL with CORS proxy when running on web
  /// Set to false to disable proxy (use with --disable-web-security flag)
  static const bool _useCorsProxy = true; // Re-enabled since --disable-web-security doesn't work
  
  String _wrapWithCorsProxy(String url) {
    if (kIsWeb && _useCorsProxy) {
      return '$_corsProxy${Uri.encodeComponent(url)}';
    }
    return url;
  }
  
  /// Wrap image URL with image proxy when running on web
  /// Uses wsrv.nl which is a free image proxy that adds CORS headers
  String? _wrapImageWithProxy(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return imageUrl;
    if (!kIsWeb) return imageUrl;
    
    // wsrv.nl is a free image proxy that handles CORS
    return 'https://wsrv.nl/?url=${Uri.encodeComponent(imageUrl)}';
  }

  @override
  void setCookies(Map<String, String> cookies) {
    _cookies = cookies;
  }

  @override
  void setUserAgent(String userAgent) {
    _userAgent = userAgent;
  }

  Map<String, String> get _headers {
    final headers = {
      'User-Agent': _userAgent,
      'Referer': baseUrl,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
    };

    if (_cookies.isNotEmpty) {
      headers['Cookie'] =
          _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }

    return headers;
  }

  void _checkCloudflare(http.Response response) {
    if (response.statusCode == 503 || response.statusCode == 403) {
      if (response.body.contains('Cloudflare') ||
          response.body.contains('Just a moment')) {
        throw CloudflareException('Cloudflare protection detected', baseUrl);
      }
    }
  }

  /// Extract manga data from Next.js RSC payload
  List<Manga> _extractFromNextJsPayload(String html) {
    final results = <Manga>[];

    // Next.js embeds data in script tags with self.__next_f.push()
    // The data is in a complex RSC (React Server Components) format
    // We need to find JSON objects that contain series data

    // Pattern 1: Look for series data in the RSC payload
    // Format: ["$","a",null,{"href":"/series/slug","children":[...
    final seriesPattern = RegExp(
      r'\["[^"]*","a",[^,]*,\{"href":"(/series/[^"]+)"',
      multiLine: true,
    );

    final matches = seriesPattern.allMatches(html);
    final seenSlugs = <String>{};

    for (final match in matches) {
      final href = match.group(1);
      if (href == null) continue;

      final slug = href.replaceFirst('/series/', '');
      if (seenSlugs.contains(slug)) continue;
      seenSlugs.add(slug);

      // Try to find title and image near this match
      final startIndex = match.start;
      final endIndex = (startIndex + 2000).clamp(0, html.length);
      final context = html.substring(startIndex, endIndex);

      // Look for title in context
      String? title;
      final titleMatch = RegExp(r'"children":"([^"]{2,100})"').firstMatch(context);
      if (titleMatch != null) {
        title = titleMatch.group(1);
        // Decode unicode escapes
        title = _decodeUnicode(title ?? '');
      }

      // Look for image URL
      String? coverUrl;
      final imgMatch = RegExp(r'"src":"(https://[^"]*(?:storage|covers)[^"]*)"').firstMatch(context);
      if (imgMatch != null) {
        coverUrl = imgMatch.group(1);
        coverUrl = coverUrl?.replaceAll(r'\u002F', '/');
      }

      if (title != null && title.isNotEmpty && title.length > 1) {
        results.add(Manga(
          id: slug,
          title: title,
          coverUrl: _wrapImageWithProxy(coverUrl),
          source: MangaSource.custom,
          customSourceId: id,
          lastUpdated: DateTime.now(),
        ));
      }
    }

    // Pattern 2: Try to find JSON arrays with series data
    // Look for patterns like: {"series_slug":"...","title":"..."}
    final jsonPattern = RegExp(
      r'\{[^{}]*"(?:series_slug|comic_title|name)"\s*:\s*"([^"]+)"[^{}]*\}',
      multiLine: true,
    );

    for (final match in jsonPattern.allMatches(html)) {
      try {
        final jsonStr = match.group(0);
        if (jsonStr == null) continue;

        // Try to parse as JSON
        final decoded = json.decode(jsonStr);
        if (decoded is Map) {
          final slug = decoded['series_slug'] ?? decoded['slug'];
          final title = decoded['comic_title'] ?? decoded['title'] ?? decoded['name'];
          final cover = decoded['cover'] ?? decoded['thumb'] ?? decoded['image'];

          if (slug != null && title != null && !seenSlugs.contains(slug)) {
            seenSlugs.add(slug);
            results.add(Manga(
              id: slug,
              title: title,
              coverUrl: _wrapImageWithProxy(cover),
              source: MangaSource.custom,
              customSourceId: id,
              lastUpdated: DateTime.now(),
            ));
          }
        }
      } catch (e) {
        // Skip malformed JSON
      }
    }

    return results;
  }

  String _decodeUnicode(String input) {
    return input.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
    );
  }

  /// Convert slug to readable title (e.g., 'solo-leveling-bf72f955' -> 'Solo Leveling')
  String _slugToTitle(String slug) {
    // Remove UUID hash at the end (8 hex chars pattern)
    var cleanSlug = slug.replaceAll(RegExp(r'-[a-f0-9]{8}$'), '');
    
    // Convert hyphens to spaces and capitalize each word
    return cleanSlug
        .split('-')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ')
        .trim();
  }

  /// Parse manga from rendered HTML using official Keiyoushi selectors
  List<Manga> _parseFromHtml(String html) {
    final document = parser.parse(html);
    final results = <Manga>[];
    final seenIds = <String>{};

    // Debug: log first few div classes to understand structure
    final allDivs = document.querySelectorAll('div[class]');
    if (allDivs.isNotEmpty) {
      final sampleClasses = allDivs.take(10).map((d) => d.attributes['class']).join(', ');
      print('_parseFromHtml: sample div classes: $sampleClasses');
    }
    
    // Try multiple selectors in order of specificity
    var links = document.querySelectorAll('div.grid > a[href*="/series/"]');
    print('_parseFromHtml: div.grid > a found ${links.length}');
    
    if (links.isEmpty) {
      // Try without the child combinator
      links = document.querySelectorAll('div[class*="grid"] a[href*="/series/"]');
      print('_parseFromHtml: div[class*=grid] a found ${links.length}');
    }
    
    if (links.isEmpty) {
      // Fallback: links with images (manga cards)
      final allLinks = document.querySelectorAll('a[href*="/series/"]');
      links = allLinks.where((l) => l.querySelector('img') != null).toList();
      print('_parseFromHtml: fallback (links with img) found ${links.length}');
    }
    
    
    int skippedShort = 0;
    int skippedUuid = 0;
    int skippedDuplicate = 0;
    int skippedTitle = 0;
    for (final link in links) {
      try {
        final href = link.attributes['href'];
        if (href == null || !href.contains('/series/')) continue;

        // Extract slug (format: /series/name-uuid)
        final slugMatch = RegExp(r'/series/([^/\?]+)').firstMatch(href);
        if (slugMatch == null) continue;

        final slug = slugMatch.group(1)!;
        if (seenIds.contains(slug)) continue;

        // Skip navigation/menu links (usually short slugs or common words)
        if (slug.length < 5) continue;
        
        // Skip if it looks like just a UUID (no readable name part)
        if (RegExp(r'^[a-f0-9-]+$').hasMatch(slug)) continue;

        // Get title - ALWAYS use slug-derived title for reliability with Next.js sites
        // The HTML structure is too unreliable for title extraction
        String title = _slugToTitle(slug);
        
        // Skip if slug-derived title is too short
        if (title.length < 3) continue;

        // Get cover image
        String? coverUrl;
        final img = link.querySelector('img');
        if (img != null) {
          // Try various image attributes
          coverUrl = img.attributes['src'];
          
          // Handle Next.js image srcset
          if (coverUrl == null || coverUrl.contains('data:image')) {
            final srcset = img.attributes['srcset'];
            if (srcset != null && srcset.isNotEmpty) {
              // Get the last (highest resolution) image from srcset
              final srcsetParts = srcset.split(',');
              if (srcsetParts.isNotEmpty) {
                coverUrl = srcsetParts.last.trim().split(' ').first;
              }
            }
          }
          
          // Try data-src as fallback
          if (coverUrl == null || coverUrl.contains('data:image')) {
            coverUrl = img.attributes['data-src'];
          }
        }

        // Fix relative URLs
        if (coverUrl != null && !coverUrl.startsWith('http')) {
          if (coverUrl.startsWith('//')) {
            coverUrl = 'https:$coverUrl';
          } else if (coverUrl.startsWith('/')) {
            coverUrl = '$baseUrl$coverUrl';
          }
        }
        
        // Decode URL-encoded characters
        if (coverUrl != null) {
          coverUrl = Uri.decodeFull(coverUrl);
        }

        seenIds.add(slug);
        results.add(Manga(
          id: slug,
          title: title,
          coverUrl: _wrapImageWithProxy(coverUrl),
          source: MangaSource.custom,
          customSourceId: id,
          lastUpdated: DateTime.now(),
        ));
      } catch (e) {
        // Skip errors
      }
    }

    return results;
  }

  /// Combined parsing - try multiple methods
  List<Manga> _parsePage(String html) {
    // Try HTML parsing first (now more reliable with slug-to-title)
    var results = _parseFromHtml(html);

    // If HTML parsing didn't work well, try Next.js payload extraction
    if (results.length < 5) {
      final nextJsResults = _extractFromNextJsPayload(html);
      // Merge results
      final seenIds = results.map((m) => m.id).toSet();
      for (final manga in nextJsResults) {
        if (!seenIds.contains(manga.id)) {
          results.add(manga);
        }
      }
    }

    return results;
  }

  @override
  Future<List<Manga>> getPopular({int page = 1}) async {
    try {
      // AsuraComic uses order=rating for popular
      final url = '$baseUrl/series?page=$page&order=rating';
      final requestUrl = _wrapWithCorsProxy(url);
      print('AsuraScans getPopular: fetching $requestUrl');
      
      // Add timeout to detect hanging requests
      final response = await _client.get(
        Uri.parse(requestUrl), 
        headers: _headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('AsuraScans getPopular: REQUEST TIMED OUT after 15 seconds');
          throw Exception('Request timed out');
        },
      );
      
      print('AsuraScans getPopular: status=${response.statusCode}, bodyLength=${response.body.length}');
      _checkCloudflare(response);

      if (response.statusCode != 200) {
        throw Exception('Failed to get popular: ${response.statusCode}');
      }

      final results = _parsePage(response.body);
      print('AsuraScans getPopular: parsed ${results.length} results');
      return results;
    } catch (e, stackTrace) {
      if (e is CloudflareException) rethrow;
      print('AsuraScans getPopular error: $e');
      print('Stack: $stackTrace');
      return [];
    }
  }

  @override
  Future<List<Manga>> getLatest({int page = 1}) async {
    try {
      // AsuraComic uses order=update for latest
      final url = '$baseUrl/series?page=$page&order=update';
      final requestUrl = _wrapWithCorsProxy(url);
      print('AsuraScans getLatest: fetching $requestUrl');
      final response = await _client.get(Uri.parse(requestUrl), headers: _headers);
      _checkCloudflare(response);

      if (response.statusCode != 200) {
        throw Exception('Failed to get latest: ${response.statusCode}');
      }

      return _parsePage(response.body);
    } catch (e) {
      if (e is CloudflareException) rethrow;
      print('AsuraScans getLatest error: $e');
      return [];
    }
  }

  @override
  Future<List<Manga>> search(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$baseUrl/series?name=$encodedQuery';
      final requestUrl = _wrapWithCorsProxy(url);
      print('AsuraScans search: fetching $requestUrl for query "$query"');
      final response = await _client.get(Uri.parse(requestUrl), headers: _headers);
      
      print('AsuraScans search: status=${response.statusCode}, bodyLength=${response.body.length}');
      
      _checkCloudflare(response);

      if (response.statusCode != 200) {
        print('AsuraScans search: non-200 status, returning empty');
        return [];
      }

      final results = _parsePage(response.body);
      print('AsuraScans search: parsed ${results.length} results');
      for (var i = 0; i < results.length && i < 5; i++) {
        print('  - ${results[i].title} (id: ${results[i].id})');
      }
      return results;
    } catch (e, stackTrace) {
      if (e is CloudflareException) rethrow;
      print('AsuraScans search error: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  @override
  Future<Manga> getMangaDetails(String mangaId) async {
    try {
      final url = '$baseUrl/series/$mangaId';
      final requestUrl = _wrapWithCorsProxy(url);
      final response = await _client.get(Uri.parse(requestUrl), headers: _headers);
      _checkCloudflare(response);

      if (response.statusCode != 200) {
        throw Exception('Failed to get details: ${response.statusCode}');
      }

      final html = response.body;
      final document = parser.parse(html);

      // Extract title
      String title = 'Unknown';
      final h1 = document.querySelector('h1');
      if (h1 != null) {
        title = h1.text.trim();
      } else {
        // Try from RSC payload
        final titleMatch = RegExp(r'"comic_title"\s*:\s*"([^"]+)"').firstMatch(html);
        if (titleMatch != null) {
          title = _decodeUnicode(titleMatch.group(1) ?? 'Unknown');
        }
      }

      // Extract cover from meta or img
      String? coverUrl;
      final ogImage = document.querySelector('meta[property="og:image"]');
      if (ogImage != null) {
        coverUrl = ogImage.attributes['content'];
      } else {
        final imgMatch = RegExp(r'"thumb(?:nail)?"\s*:\s*"([^"]+)"').firstMatch(html);
        if (imgMatch != null) {
          coverUrl = imgMatch.group(1)?.replaceAll(r'\/', '/');
        }
      }

      // Extract description
      String synopsis = '';
      final descMatch = RegExp(r'"(?:description|summary)"\s*:\s*"([^"]*)"').firstMatch(html);
      if (descMatch != null) {
        synopsis = _decodeUnicode(descMatch.group(1) ?? '');
        synopsis = synopsis.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
      }

      // Extract genres
      final genres = <String>[];
      final genreMatches = RegExp(r'"genre(?:s)?"\s*:\s*\[([^\]]+)\]').firstMatch(html);
      if (genreMatches != null) {
        final genreList = genreMatches.group(1) ?? '';
        final genreNames = RegExp(r'"name"\s*:\s*"([^"]+)"').allMatches(genreList);
        for (final g in genreNames) {
          genres.add(g.group(1) ?? '');
        }
      }

      // Status
      MangaStatus status = MangaStatus.ongoing;
      if (html.toLowerCase().contains('"status":"completed"') ||
          html.toLowerCase().contains('completed')) {
        status = MangaStatus.completed;
      }

      // Author/Artist
      String author = 'Unknown';
      String artist = 'Unknown';
      final authorMatch = RegExp(r'"author"\s*:\s*"([^"]+)"').firstMatch(html);
      if (authorMatch != null) {
        author = _decodeUnicode(authorMatch.group(1) ?? 'Unknown');
      }
      final artistMatch = RegExp(r'"artist"\s*:\s*"([^"]+)"').firstMatch(html);
      if (artistMatch != null) {
        artist = _decodeUnicode(artistMatch.group(1) ?? 'Unknown');
      }

      return Manga(
        id: mangaId,
        title: title,
        author: author,
        artist: artist,
        status: status,
        synopsis: synopsis,
        coverUrl: coverUrl,
        genres: genres,
        source: MangaSource.custom,
        customSourceId: id,
      );
    } catch (e) {
      if (e is CloudflareException) rethrow;
      throw Exception('Failed to load manga details: $e');
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final url = '$baseUrl/series/$mangaId';
      final requestUrl = _wrapWithCorsProxy(url);
      final response = await _client.get(Uri.parse(requestUrl), headers: _headers);
      _checkCloudflare(response);

      if (response.statusCode != 200) return [];

      final html = response.body;
      final chapters = <Chapter>[];
      final seenIds = <String>{};

      // Find chapter links in HTML
      final document = parser.parse(html);
      final chapterLinks = document.querySelectorAll('a[href*="/chapter/"]');

      for (final link in chapterLinks) {
        try {
          final href = link.attributes['href'];
          if (href == null) continue;

          // Extract chapter number from URL
          final chapterMatch = RegExp(r'/chapter/(\d+)').firstMatch(href);
          if (chapterMatch == null) continue;

          final chapterId = chapterMatch.group(1)!;
          if (seenIds.contains(chapterId)) continue;
          seenIds.add(chapterId);

          // Get chapter title/number from text
          final text = link.text.trim();
          final numberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
          final number = numberMatch != null
              ? double.parse(numberMatch.group(1)!)
              : double.tryParse(chapterId) ?? 0.0;

          chapters.add(Chapter(
            id: '$mangaId/chapter/$chapterId',
            mangaId: mangaId,
            title: text.isNotEmpty ? text : 'Chapter $number',
            number: number,
            externalUrl: href.startsWith('http') ? href : '$baseUrl$href',
          ));
        } catch (e) {
          // Skip individual errors
        }
      }

      // Also try to extract from RSC payload
      final chapterPattern = RegExp(
        r'"chapter_(?:number|id)"\s*:\s*(\d+)',
        multiLine: true,
      );
      for (final match in chapterPattern.allMatches(html)) {
        try {
          final chapterId = match.group(1)!;
          if (seenIds.contains(chapterId)) continue;
          seenIds.add(chapterId);

          final number = double.tryParse(chapterId) ?? 0.0;
          chapters.add(Chapter(
            id: '$mangaId/chapter/$chapterId',
            mangaId: mangaId,
            title: 'Chapter $number',
            number: number,
            externalUrl: '$baseUrl/series/$mangaId/chapter/$chapterId',
          ));
        } catch (e) {
          // Skip
        }
      }

      // Sort by chapter number descending
      chapters.sort((a, b) => b.number.compareTo(a.number));
      return chapters;
    } catch (e) {
      if (e is CloudflareException) rethrow;
      print('AsuraScans getChapters error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    try {
      final url = '$baseUrl/series/$chapterId';
      final requestUrl = _wrapWithCorsProxy(url);
      final response = await _client.get(Uri.parse(requestUrl), headers: _headers);
      _checkCloudflare(response);

      if (response.statusCode != 200) return [];

      final html = response.body;
      final pages = <String>[];

      // Find image URLs in RSC payload
      // Pattern: "url":"https://...storage/media/.../...webp"
      final imgPattern = RegExp(
        r'"(?:url|src)"\s*:\s*"(https?://[^"]*(?:storage|chapter|media)[^"]*\.(?:jpg|jpeg|png|webp|gif))"',
        caseSensitive: false,
      );

      for (final match in imgPattern.allMatches(html)) {
        var imgUrl = match.group(1);
        if (imgUrl == null) continue;

        // Decode escaped slashes
        imgUrl = imgUrl.replaceAll(r'\/', '/').replaceAll(r'\u002F', '/');

        // Skip thumbnails
        if (imgUrl.contains('thumb') || imgUrl.contains('cover')) continue;

        if (!pages.contains(imgUrl)) {
          pages.add(imgUrl);
        }
      }

      // Also try parsing HTML for img tags
      if (pages.isEmpty) {
        final document = parser.parse(html);
        final images = document.querySelectorAll('img');

        for (final img in images) {
          var src = img.attributes['src'] ?? img.attributes['data-src'];
          if (src == null) continue;

          // Skip small images, icons, etc
          if (src.contains('thumb') || src.contains('icon') || src.contains('logo')) continue;

          if (!src.startsWith('http')) {
            src = '$baseUrl$src';
          }

          if (!pages.contains(src)) {
            pages.add(src);
          }
        }
      }

      return pages;
    } catch (e) {
      if (e is CloudflareException) rethrow;
      print('AsuraScans getChapterPages error: $e');
      return [];
    }
  }
}
