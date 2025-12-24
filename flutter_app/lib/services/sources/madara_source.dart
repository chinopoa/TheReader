import 'dart:convert';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import '../../models/manga.dart';
import '../../models/chapter.dart';
import 'base_source.dart';

class MadaraSource implements BaseSource {
  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  
  final http.Client _client = http.Client();

  Map<String, String> _cookies = {};
  String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  MadaraSource({
    required this.id,
    required this.name,
    required this.baseUrl,
  });

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
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
    };
    
    if (_cookies.isNotEmpty) {
      headers['Cookie'] = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    
    return headers;
  }
  
  void _checkCloudflare(http.Response response) {
    if (response.statusCode == 503 || response.statusCode == 403) {
      // Basic check for CF content
      // Often contains 'Just a moment...' or 'Cloudflare'
      if (response.body.contains('Cloudflare') || response.body.contains('Just a moment')) {
        throw CloudflareException('Cloudflare protection detected', baseUrl);
      }
    }
  }

  @override
  Future<List<Manga>> getPopular({int page = 1}) async {
    return _browseManga(page: page, orderBy: 'views');
  }

  @override
  Future<List<Manga>> getLatest({int page = 1}) async {
    return _browseManga(page: page, orderBy: 'latest');
  }

  /// Browse manga with pagination and ordering
  Future<List<Manga>> _browseManga({required int page, required String orderBy}) async {
    try {
      // Madara theme URL pattern: /manga/page/{page}/?m_orderby={orderBy}
      // Some sites use /page/{page}/ at root
      final urls = [
        '$baseUrl/manga/page/$page/?m_orderby=$orderBy',
        '$baseUrl/page/$page/?m_orderby=$orderBy',
        '$baseUrl/series/page/$page/?m_orderby=$orderBy',
      ];

      for (final url in urls) {
        try {
          final response = await _client.get(Uri.parse(url), headers: _headers);
          _checkCloudflare(response);

          if (response.statusCode != 200) continue;

          final results = _parseMangaList(response.body);
          if (results.isNotEmpty) return results;
        } catch (e) {
          if (e is CloudflareException) rethrow;
          continue;
        }
      }

      // Fallback: try AJAX browse
      return _browseAjax(page: page, orderBy: orderBy);
    } catch (e) {
      if (e is CloudflareException) rethrow;
      print('Madara browse error: $e');
      return [];
    }
  }

  /// AJAX-based browsing for some Madara sites
  Future<List<Manga>> _browseAjax({required int page, required String orderBy}) async {
    try {
      final ajaxUrl = '$baseUrl/wp-admin/admin-ajax.php';

      final response = await _client.post(
        Uri.parse(ajaxUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: {
          'action': 'madara_load_more',
          'page': (page - 1).toString(),
          'template': 'madara-core/content/content-archive',
          'vars[orderby]': orderBy == 'views' ? 'meta_value_num' : 'date',
          'vars[paged]': '1',
          'vars[posts_per_page]': '20',
          'vars[meta_key]': orderBy == 'views' ? '_wp_manga_views' : '',
          'vars[order]': 'desc',
          'vars[post_type]': 'wp-manga',
          'vars[post_status]': 'publish',
        },
      );
      _checkCloudflare(response);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return _parseMangaList(response.body);
      }
      return [];
    } catch (e) {
      if (e is CloudflareException) rethrow;
      return [];
    }
  }

  /// Parse manga list from HTML
  List<Manga> _parseMangaList(String html) {
    final document = parser.parse(html);
    final results = <Manga>[];

    // Check for Cloudflare
    if (document.querySelector('title')?.text.contains('Just a moment') == true ||
        document.body?.text.contains('Cloudflare Ray ID') == true) {
      throw CloudflareException('Cloudflare protection detected', baseUrl);
    }

    // Try multiple common selectors
    var elements = document.querySelectorAll('.page-item-detail');
    if (elements.isEmpty) {
      elements = document.querySelectorAll('.manga');
    }
    if (elements.isEmpty) {
      elements = document.querySelectorAll('.c-tabs-item__content');
    }
    if (elements.isEmpty) {
      elements = document.querySelectorAll('.bsx');
    }
    if (elements.isEmpty) {
      elements = document.querySelectorAll('.bs');
    }
    if (elements.isEmpty) {
      elements = document.querySelectorAll('.utao');
    }

    for (final element in elements) {
      try {
        String? title;
        String? url;

        // Try various title selectors
        var titleElement = element.querySelector('.post-title a') ??
                          element.querySelector('h3 a') ??
                          element.querySelector('h4 a') ??
                          element.querySelector('.manga-title a') ??
                          element.querySelector('.tt') ??
                          element.querySelector('a[title]');

        if (titleElement != null) {
          title = titleElement.attributes['title'] ?? titleElement.text.trim();
          url = titleElement.attributes['href'];
        } else {
          // Try finding link with manga/series path
          final link = element.querySelector('a[href*="/manga/"]') ??
                       element.querySelector('a[href*="/series/"]') ??
                       element.querySelector('a');
          if (link != null) {
            title = link.attributes['title'] ?? link.text.trim();
            url = link.attributes['href'];
          }
        }

        if (title == null || title.isEmpty || url == null) continue;

        final id = _extractIdFromUrl(url);
        if (id == null) continue;

        // Get cover image
        final imgElement = element.querySelector('img');
        var coverUrl = imgElement?.attributes['data-src'] ??
                      imgElement?.attributes['src'] ??
                      imgElement?.attributes['data-lazy-src'] ??
                      imgElement?.attributes['srcset']?.split(' ').first;

        if (coverUrl != null && !coverUrl.startsWith('http')) {
          if (coverUrl.startsWith('//')) {
            coverUrl = 'https:$coverUrl';
          } else {
            coverUrl = '$baseUrl$coverUrl';
          }
        }

        // Get rating if available
        final ratingText = element.querySelector('.score')?.text.trim() ??
                          element.querySelector('.rating')?.text.trim();
        final rating = ratingText != null ? double.tryParse(ratingText) : null;

        results.add(Manga(
          id: id,
          title: title,
          coverUrl: coverUrl,
          source: MangaSource.custom,
          customSourceId: this.id,
          rating: rating,
          lastUpdated: DateTime.now(),
        ));
      } catch (e) {
        // Skip single item errors
      }
    }

    return results;
  }

  @override
  Future<List<Manga>> search(String query) async {
    try {
      // Try AJAX search first as it's more standard across Madara themes
      final ajaxUrl = '$baseUrl/wp-admin/admin-ajax.php';
      
      final response = await _client.post(
        Uri.parse(ajaxUrl),
        headers: {
          ..._headers,
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: {
          'action': 'wp-manga-search-manga',
          'title': query,
        },
      );
      _checkCloudflare(response);
      
      if (response.statusCode != 200) {
        // Fallback to standard search if AJAX fails
        return _searchStandard(query);
      }

      final body = json.decode(response.body);
      if (body['success'] == false) return [];

      final data = body['data'];
      final results = <Manga>[];
      
      // If data is list, try to parse objects
      if (data is List) {
        for (final item in data) {
           if (item is Map) {
              final title = item['title'];
              final url = item['url'];
              if (title != null && url != null) {
                 results.add(Manga(
                   id: _extractIdFromUrl(url) ?? url, // Fallback to url if id fails
                   title: title,
                   coverUrl: null, 
                   source: MangaSource.custom,
                   customSourceId: this.id,
                   lastUpdated: DateTime.now(),
                 ));
              }
           }
        }
      }
      
      // If we found results, return them.
      if (results.isNotEmpty) return results;
      
      // If AJAX returned no results or data was not a list (e.g. HTML string),
      // FALLBACK to standard search.
      print('AJAX search yields 0 results or incompatible format. Falling back to standard.');
      return _searchStandard(query);
      
    } catch (e, stack) {
      print('Madara search error: $e');
      print(stack);
      // Fallback on error too
      return _searchStandard(query);
    }
  }

  String _constructUrl(String id) {
    if (id.contains('/')) {
      // ID already contains prefix (e.g. series/slug)
      return '$baseUrl/$id/';
    }
    // Fallback for legacy IDs
    return '$baseUrl/manga/$id/';
  }

  Future<List<Manga>> _searchStandard(String query) async {
    try {
      final uri = Uri.parse('$baseUrl/').replace(
        queryParameters: {
          's': query,
          'post_type': 'wp-manga',
        },
      );
      
      final response = await _client.get(uri, headers: _headers);
      _checkCloudflare(response);
      if (response.statusCode != 200) return [];

      final document = parser.parse(response.body);
      final results = <Manga>[];
      
      // Check for Cloudflare title in body if we haven't thrown yet
      if (document.querySelector('title')?.text.contains('Just a moment') == true ||
          document.body?.text.contains('Cloudflare Ray ID') == true) {
         throw CloudflareException('Cloudflare protection detected (Body check)', baseUrl);
      }

      // Try multiple common selectors for results
      // 1. Standard Madara (c-tabs-item__content)
      var elements = document.querySelectorAll('.c-tabs-item__content');
      
      // 2. Alternative Layout (tab-content-wrap)
      if (elements.isEmpty) {
        elements = document.querySelectorAll('.tab-content-wrap .c-tabs-item__content');
      }
      
      // 3. Search Page Layout (search-wrap)
      if (elements.isEmpty) {
         elements = document.querySelectorAll('.search-wrap .row');
      }

      // 4. Generic Item Layout (manga-list-item)
      if (elements.isEmpty) {
         elements = document.querySelectorAll('.manga-list-item');
      }

      // 5. Item Summary
      if (elements.isEmpty) {
         elements = document.querySelectorAll('.item-summary');
      }

      // 6. MangaReader "Box" Layout (bsx)
      if (elements.isEmpty) {
         elements = document.querySelectorAll('.bsx');
      }
      
      for (final element in elements) {
        try {
          String? title;
          String? url;
          var titleElement = element.querySelector('.post-title a') ?? 
                             element.querySelector('h3 a') ??
                             element.querySelector('.manga-title a');
                              
          if (titleElement != null) {
             title = titleElement.text.trim();
             url = titleElement.attributes['href'];
          } else {
            // Try .bsx style or generic link
            final tt = element.querySelector('.tt');
            if (tt != null) {
               title = tt.text.trim();
               url = element.querySelector('a')?.attributes['href'];
            } else {
               // Try finding any link with header-like class or common patterns
               titleElement = element.querySelector('a[href*="/manga/"]') ??
                              element.querySelector('a[href*="/series/"]') ??
                              element.querySelector('a[href*="/manhua/"]') ??
                              element.querySelector('a[href*="/comic/"]');
               if (titleElement != null) {
                  title = titleElement.text.trim();
                  url = titleElement.attributes['href'];
               }
            }
          }

          if (title == null || url == null) continue;
          
          final id = _extractIdFromUrl(url);
          
          final imgElement = element.querySelector('img');
          var coverUrl = imgElement?.attributes['data-src'] ?? 
                        imgElement?.attributes['src'] ?? 
                        imgElement?.attributes['srcset']?.split(' ').first;
          
          if (coverUrl != null && !coverUrl.startsWith('http')) {
             if (coverUrl.startsWith('//')) {
               coverUrl = 'https:$coverUrl';
             } else {
               coverUrl = '$baseUrl$coverUrl';
             }
          }

          final ratingText = element.querySelector('.score')?.text.trim();
          final rating = ratingText != null ? double.tryParse(ratingText) : null;

          if (id != null) {
            results.add(Manga(
              id: id,
              title: title,
              coverUrl: coverUrl,
              source: MangaSource.custom,
              customSourceId: this.id,
              rating: rating,
              lastUpdated: DateTime.now(),
            ));
          }
        } catch (e) {
          // ignore error for single item
        }
      }
      return results;
    } catch(e) {
       return [];
    }
  }

  @override
  Future<Manga> getMangaDetails(String mangaId) async {
    try {
      final url = _constructUrl(mangaId);
      final response = await _client.get(Uri.parse(url), headers: _headers);
      _checkCloudflare(response);
      
      if (response.statusCode != 200) throw Exception('Failed to get details: ${response.statusCode}');

      final document = parser.parse(response.body);
      
      final title = document.querySelector('.post-title h1')?.text.trim() ?? 'Unknown';
      final imgElement = document.querySelector('.summary_image img');
      var coverUrl = imgElement?.attributes['data-src'] ?? imgElement?.attributes['src'];

       // Handle relative URLs
      if (coverUrl != null && !coverUrl.startsWith('http')) {
          if (coverUrl.startsWith('//')) {
            coverUrl = 'https:$coverUrl';
          } else {
            coverUrl = '$baseUrl$coverUrl';
          }
      }

      final author = document.querySelector('.author-content a')?.text.trim() ?? 'Unknown';
      final artist = document.querySelector('.artist-content a')?.text.trim() ?? 'Unknown';
      final synopsis = document.querySelector('.summary__content')?.text.trim() ?? '';
      
      final genres = document.querySelectorAll('.genres-content a')
          .map((e) => e.text.trim())
          .toList();

      final statusText = document.querySelector('.post-status .summary-content')?.text.trim().toLowerCase() ?? '';
      MangaStatus status = MangaStatus.ongoing;
      if (statusText.contains('completed')) status = MangaStatus.completed;
      if (statusText.contains('cancelled')) status = MangaStatus.cancelled;
      if (statusText.contains('on hold')) status = MangaStatus.hiatus;

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
        customSourceId: this.id,
      );
    } catch (e) {
       if (e is CloudflareException) rethrow;
       throw Exception('Failed to load manga details: $e');
    }
  }

  @override
  Future<List<Chapter>> getChapters(String mangaId) async {
    try {
      final url = _constructUrl(mangaId);
      
      // First, check if chapters are loaded via AJAX (common in modern Madara)
      // Usually there's a POST request to admin-ajax.php
      // But scraping the main page often works for initial load or if AJAX is disabled.
      
      // Let's try scraping the listing from the manga page first (some sites serve it directly)
      var response = await _client.get(Uri.parse(url), headers: _headers);
      _checkCloudflare(response);
      var document = parser.parse(response.body);
      
      var chapterElements = document.querySelectorAll('.wp-manga-chapter');
      
      // If no chapters found, try the AJAX endpoint
      if (chapterElements.isEmpty) {
         final ajaxUrl = '$baseUrl/wp-admin/admin-ajax.php';
         final mangaIdAttr = document.querySelector('#manga-chapters-holder')?.attributes['data-id'];
         
         if (mangaIdAttr != null) {
            response = await _client.post(
              Uri.parse(ajaxUrl),
              headers: _headers,
              body: {
                'action': 'm_release_date_ajax_load_more',
                'manga': mangaIdAttr,
              },
            );
            document = parser.parse(response.body);
            chapterElements = document.querySelectorAll('.wp-manga-chapter');
         }
      }

      // If still empty, try "MangaReader" theme list (.eplister)
      if (chapterElements.isEmpty) {
         chapterElements = document.querySelectorAll('.eplister li');
      }

      final chapters = <Chapter>[];
      
      for (final element in chapterElements) {
        // Try standard madara link
        var link = element.querySelector('a');
        
        // If standard .wp-manga-chapter, the link is usually the direct child or inside
        // For .eplister, it's also inside.
        
        if (link == null) continue;

        // SKIP locked chapters (usually have data-bs-toggle="modal" or no href or href="#")
        if (!link.attributes.containsKey('href') || 
            link.attributes['href'] == '#' ||
            link.attributes.containsKey('data-bs-target')) {
           continue;
        }

        final chapterUrl = link.attributes['href'];
        if (chapterUrl == null) continue;

        var title = link.text.trim();
        var dateText = element.querySelector('.chapter-release-date')?.text.trim();
        
        // For .eplister layout, title might be in .chapternum
        final chapNumSpan = element.querySelector('.chapternum');
        if (chapNumSpan != null) {
           title = chapNumSpan.text.trim();
        }
        
        // For .eplister layout, date in .chapterdate
        final chapDateSpan = element.querySelector('.chapterdate');
        if (chapDateSpan != null) {
           dateText = chapDateSpan.text.trim();
        }
        
        // Clean title
        title = title.replaceAll(RegExp(r'\s+'), ' ');

        // Extract chapter number
        // Typically "Chapter 123" or "Vol.1 Ch.123"
        final number = _extractChapterNumber(title);
        final id = _extractChapterIdFromUrl(chapterUrl);

        if (id != null) {
          chapters.add(Chapter(
            id: id,
            mangaId: mangaId,
            title: title, 
            number: number,
            externalUrl: chapterUrl,
            releaseDate: _parseDate(dateText),
          ));
        }
      }
      
      // Sort desc by number (usually they come desc)
      // chapters.sort((a, b) => b.number.compareTo(a.number));
      return chapters;
    } catch (e) {
      print('Madara getChapters error: $e');
      return [];
    }
  }

  @override
  Future<List<String>> getChapterPages(String chapterId) async {
    try {
      final url = _constructUrl(chapterId);
       
      final response = await _client.get(Uri.parse(url), headers: _headers);
      _checkCloudflare(response);
      final document = parser.parse(response.body);
      
      // Madara page images are usually in .page-break img or .reading-content img
      var images = document.querySelectorAll('.page-break img');
      
      if (images.isEmpty) {
        images = document.querySelectorAll('.reading-content img');
      }

      if (images.isNotEmpty) {
        return images.map((img) => 
          (img.attributes['data-src'] ?? img.attributes['src'])?.trim() ?? ''
        ).where((s) => s.isNotEmpty).map((s) {
           if (s.startsWith('//')) return 'https:$s';
           if (!s.startsWith('http')) return '$baseUrl$s';
           return s;
        }).toList();
      }

      // Check for ts_reader.run script
      final scripts = document.querySelectorAll('script');
      for (final script in scripts) {
         if (script.text.contains('ts_reader.run')) {
             try {
               final content = script.text;
               final match = RegExp(r'ts_reader\.run\((\{.*?\})\);').firstMatch(content);
               if (match != null) {
                 final jsonStr = match.group(1);
                 if (jsonStr != null) {
                    final data = json.decode(jsonStr);
                    final sources = data['sources'] as List;
                    if (sources.isNotEmpty) {
                       final imagesList = sources[0]['images'] as List;
                       return imagesList.map((e) => e.toString()).toList();
                    }
                 }
               }
             } catch (e) {
               print('Failed to parse ts_reader script: $e');
             }
         }
      }
      
      return [];

    } catch (e) {
      if (e is CloudflareException) rethrow;
      throw Exception('Failed to get pages: $e');
    }
  }

  String? _extractIdFromUrl(String? url) {
    if (url == null) return null;
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // expected: /manga/manga-id/ OR /series/manga-id/ OR /manhua/manga-id/
    
    final validSegments = ['manga', 'series', 'manhua', 'comic', 'webtoon'];
    for (final type in validSegments) {
      if (segments.contains(type)) {
        final index = segments.indexOf(type);
        if (index + 1 < segments.length) {
          // Return "type/slug" e.g. "series/the-manga"
          return '${segments[index]}/${segments[index+1]}';
        }
      }
    }
    
    // Fallback: use first segment if it's not a common page
    if (segments.isNotEmpty && 
       !['page', 'category', 'tag', 'author'].contains(segments.first)) {
       // Riskier but needed for sites that use root paths like /manga-title/
       // But Madara usually has a prefix.
    }
    
    return null;
  }
  
  String? _extractChapterIdFromUrl(String? url) {
     if (url == null) return null;
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // expected: /manga/manga-id/chapter-id/
    
    final validSegments = ['manga', 'series', 'manhua', 'comic', 'webtoon'];
    for (final type in validSegments) {
      if (segments.contains(type)) {
        final index = segments.indexOf(type);
        if (index + 2 < segments.length) {
          // Return "type/manga-id/chapter-id"
          return '${segments[index]}/${segments[index+1]}/${segments[index+2]}';
        }
      }
    }
    
    // Some sites: /manga-title-chapter-1/ (Root path)
    // In this case, we might return just the last segment as ID?
    // But we need consistency.
    if (segments.isNotEmpty) return segments.last;

    return null;
  }

  double _extractChapterNumber(String title) {
    final regex = RegExp(r'(\d+(\.\d+)?)');
    final match = regex.firstMatch(title);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }
  
  DateTime? _parseDate(String? dateStr) {
     if (dateStr == null) return null;
     // Basic parsing for "Dec 24, 2023" etc.
     // For now return null or implement proper parser if critical
     return null;
  }
}
