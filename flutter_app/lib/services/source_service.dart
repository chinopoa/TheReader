import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/extension.dart';
import '../../models/manga.dart';
import 'extension_service.dart';
import 'sources/base_source.dart';
import 'sources/imanga_source.dart';

/// Provider for SourceService
final sourceServiceProvider = Provider<SourceService>((ref) {
  final installedSources = ref.watch(installedSourcesProvider);
  return SourceService(installedSources);
});

class SourceService {
  final Map<String, BaseSource> _sources = {};
  
  // Pre-indexed sources from MangaReader app (imanga.co)
  // These are far more reliable than web scraping
  static final List<IMangaSource> _imangaSources = [
    IMangaSource(
      id: 'mangakakalot',
      name: 'MangaKakalot',
      baseUrl: 'https://mangakakalot.com',
      indexUrl: 'http://k.imanga.co/mangakakalot/indexs.gz',
      updateUrl: 'http://k.imanga.co/mangakakalot/updates_an/updates',
      tagsUrl: 'http://k.imanga.co/mangakakalot/taglist_an.gz',
      coverReferer: 'https://mangapark.net',
    ),
    IMangaSource(
      id: 'mangapark',
      name: 'MangaPark',
      baseUrl: 'https://mangapark.net',
      indexUrl: 'http://m.imanga.co/mangapark/indexs_an.gz',
      updateUrl: 'http://m.imanga.co/mangapark/updates_an/updates',
      tagsUrl: 'http://m.imanga.co/mangapark/taglist.gz',
      coverReferer: 'https://mangapark.net',
    ),
    IMangaSource(
      id: 'batoto',
      name: 'Batoto',
      baseUrl: 'https://bato.to',
      indexUrl: 'http://h.imanga.co/batoto/indexs_an.gz',
      updateUrl: 'http://h.imanga.co/batoto/updates_an/updates',
      tagsUrl: 'http://h.imanga.co/batoto/taglist.gz',
      coverReferer: 'https://bato.to/',
    ),
    IMangaSource(
      id: 'mangabuddy',
      name: 'MangaBuddy',
      baseUrl: 'https://mangabuddy.com',
      indexUrl: 'http://h.imanga.co/mangabuddy/indexs_an.gz',
      updateUrl: 'http://h.imanga.co/mangabuddy/updates_an/updates',
      tagsUrl: 'http://h.imanga.co/mangabuddy/taglist.gz',
      coverReferer: 'https://mangabuddy.com/',
    ),
    IMangaSource(
      id: 'mangadex-en',
      name: 'MangaDex (EN)',
      baseUrl: 'https://mangadex.org',
      indexUrl: 'http://f.imanga.co/mangadex-en/indexs_an.gz',
      updateUrl: 'http://f.imanga.co/mangadex-en/updates_an/updates',
      tagsUrl: 'http://f.imanga.co/mangadex-en/taglist.gz',
      coverReferer: 'https://mangadex.org/',
    ),
    IMangaSource(
      id: 'mangahere',
      name: 'MangaHere',
      baseUrl: 'https://www.mangahere.cc',
      indexUrl: 'https://s3-us-west-2.amazonaws.com/kmanga/mangahere/indexs_an.gz',
      updateUrl: 'https://s3-us-west-2.amazonaws.com/kmanga/mangahere/updates_an/updates',
      tagsUrl: 'https://s3-us-west-2.amazonaws.com/kmanga/mangahere/taglist.gz',
      coverReferer: 'http://www.mangahere.cc',
    ),
  ];

  SourceService(List<InstalledSource> installedSources) {
    // Register IManga pre-indexed sources only
    for (final source in _imangaSources) {
      _registerSource(source);
    }
  }

  void _registerSource(BaseSource source) {
    _sources[source.id] = source;
  }

  BaseSource? getSource(String id) => _sources[id];
  
  BaseSource? getSourceForManga(Manga manga) {
    if (manga.source == MangaSource.custom && manga.customSourceId != null) {
      return getSource(manga.customSourceId!);
    }
    // Return first available source as fallback
    return _sources.values.isNotEmpty ? _sources.values.first : null;
  }

  List<BaseSource> getSources() => _sources.values.toList();
}
