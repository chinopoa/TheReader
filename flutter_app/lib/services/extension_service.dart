import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/extension.dart';

/// Provider for extension repos box
final extensionRepoBoxProvider = Provider<Box<ExtensionRepo>>((ref) {
  return Hive.box<ExtensionRepo>('extension_repos');
});

/// Provider for installed sources box
final installedSourceBoxProvider = Provider<Box<InstalledSource>>((ref) {
  return Hive.box<InstalledSource>('installed_sources');
});

/// Provider to get all extension repos
final extensionReposProvider = Provider<List<ExtensionRepo>>((ref) {
  final box = ref.watch(extensionRepoBoxProvider);
  return box.values.toList();
});

/// Provider to get all installed sources
final installedSourcesProvider = Provider<List<InstalledSource>>((ref) {
  final sources = ref.watch(installedSourceNotifierProvider);
  return sources.where((s) => s.enabled).toList();
});

/// Service to manage extensions
class ExtensionService {
  final http.Client _client = http.Client();

  /// Fetch extensions from a repo URL or local file
  Future<List<Extension>> fetchExtensions(String repoUrl) async {
    try {
      String jsonContent;
      
      if (repoUrl.startsWith('/') || repoUrl.contains(r'\') || repoUrl.startsWith('file:')) {
         // Local file
         // Remove file:// prefix if present to get path
         var path = repoUrl;
         if (path.startsWith('file:///')) {
           path = path.substring(8);
         } else if (path.startsWith('file://')) {
           path = path.substring(7);
         }
         
         // On Windows, valid file URIs might leave a leading slash before drive letter (e.g. /C:/...)
         // Dart File constructor handles standard paths.
         // If input is "c:\Users...", just use it.
         
         final file = File(path);
         if (!await file.exists()) {
            throw Exception('File not found: $path');
         }
         jsonContent = await file.readAsString();
      } else {
        // HTTP URL
        final response = await _client.get(Uri.parse(repoUrl));
        if (response.statusCode != 200) {
          throw Exception('Failed to fetch extensions: ${response.statusCode}');
        }
        jsonContent = response.body;
      }

      final List<dynamic> jsonList = json.decode(jsonContent);
      return jsonList
          .map((item) => Extension.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch extensions: $e');
    }
  }

  /// Get extensions filtered by language
  List<Extension> filterByLanguage(List<Extension> extensions, String lang) {
    if (lang == 'all') return extensions;
    return extensions.where((ext) => 
      ext.lang == lang || ext.lang == 'all'
    ).toList();
  }

  /// Get safe-for-work extensions only
  List<Extension> filterSafe(List<Extension> extensions) {
    return extensions.where((ext) => ext.isSafe).toList();
  }

  /// Search extensions by name
  List<Extension> search(List<Extension> extensions, String query) {
    if (query.isEmpty) return extensions;
    final lowerQuery = query.toLowerCase();
    return extensions.where((ext) => 
      ext.displayName.toLowerCase().contains(lowerQuery)
    ).toList();
  }
}

final extensionServiceProvider = Provider<ExtensionService>((ref) {
  return ExtensionService();
});

/// Provider to fetch extensions from a repo URL
final extensionsFromRepoProvider = FutureProvider.family<List<Extension>, String>((ref, url) async {
  final service = ref.read(extensionServiceProvider);
  return service.fetchExtensions(url);
});

/// Notifier to manage extension repos
class ExtensionRepoNotifier extends StateNotifier<List<ExtensionRepo>> {
  final Box<ExtensionRepo> _box;

  ExtensionRepoNotifier(this._box) : super(_box.values.toList());

  void addRepo(String name, String url) {
    final repo = ExtensionRepo(name: name, url: url, lastUpdated: DateTime.now());
    _box.add(repo);
    state = _box.values.toList();
  }

  void removeRepo(ExtensionRepo repo) {
    repo.delete();
    state = _box.values.toList();
  }

  void refresh() {
    state = _box.values.toList();
  }
}

final extensionRepoNotifierProvider = StateNotifierProvider<ExtensionRepoNotifier, List<ExtensionRepo>>((ref) {
  final box = ref.watch(extensionRepoBoxProvider);
  return ExtensionRepoNotifier(box);
});

/// Notifier to manage installed sources
class InstalledSourceNotifier extends StateNotifier<List<InstalledSource>> {
  final Box<InstalledSource> _box;

  InstalledSourceNotifier(this._box) : super(_box.values.toList());

  void installSource(ExtensionSource source, String extensionPkg) {
    // Check if already installed
    final existing = _box.values.where((s) => s.id == source.id).firstOrNull;
    if (existing != null) {
      // Already installed, just enable it
      existing.enabled = true;
      existing.save();
    } else {
      final installed = InstalledSource.fromExtensionSource(source, extensionPkg);
      _box.add(installed);
    }
    state = _box.values.toList();
  }

  void uninstallSource(InstalledSource source) {
    source.delete();
    state = _box.values.toList();
  }

  void toggleSource(InstalledSource source) {
    source.enabled = !source.enabled;
    source.save();
    state = _box.values.toList();
  }

  bool isInstalled(String sourceId) {
    return _box.values.any((s) => s.id == sourceId);
  }

  InstalledSource? getSource(String sourceId) {
    return _box.values.where((s) => s.id == sourceId).firstOrNull;
  }

  void refresh() {
    state = _box.values.toList();
  }
}

final installedSourceNotifierProvider = StateNotifierProvider<InstalledSourceNotifier, List<InstalledSource>>((ref) {
  final box = ref.watch(installedSourceBoxProvider);
  return InstalledSourceNotifier(box);
});
