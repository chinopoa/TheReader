import 'package:hive_flutter/hive_flutter.dart';

part 'extension.g.dart';

/// Represents an extension repository URL
@HiveType(typeId: 10)
class ExtensionRepo extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String url;

  @HiveField(2)
  DateTime? lastUpdated;

  ExtensionRepo({
    required this.name,
    required this.url,
    this.lastUpdated,
  });
}

/// Represents an extension package from a repo (contains multiple sources)
class Extension {
  final String name;
  final String pkg;
  final String apk;
  final String lang;
  final int code;
  final String version;
  final int nsfw; // 0 = safe, 1 = nsfw
  final List<ExtensionSource> sources;

  Extension({
    required this.name,
    required this.pkg,
    required this.apk,
    required this.lang,
    required this.code,
    required this.version,
    required this.nsfw,
    required this.sources,
  });

  factory Extension.fromJson(Map<String, dynamic> json) {
    final sourcesList = (json['sources'] as List<dynamic>?)
        ?.map((s) => ExtensionSource.fromJson(s as Map<String, dynamic>))
        .toList() ?? [];
    
    return Extension(
      name: json['name'] as String? ?? '',
      pkg: json['pkg'] as String? ?? '',
      apk: json['apk'] as String? ?? '',
      lang: json['lang'] as String? ?? 'all',
      code: json['code'] as int? ?? 0,
      version: json['version'] as String? ?? '1.0.0',
      nsfw: json['nsfw'] as int? ?? 0,
      sources: sourcesList,
    );
  }

  /// Clean display name (removes "Tachiyomi: " prefix)
  String get displayName {
    if (name.startsWith('Tachiyomi: ')) {
      return name.substring(11);
    }
    return name;
  }

  bool get isSafe => nsfw == 0;
}

/// Represents an individual source within an extension
class ExtensionSource {
  final String name;
  final String lang;
  final String id;
  final String baseUrl;

  ExtensionSource({
    required this.name,
    required this.lang,
    required this.id,
    required this.baseUrl,
  });

  factory ExtensionSource.fromJson(Map<String, dynamic> json) {
    return ExtensionSource(
      name: json['name'] as String? ?? '',
      lang: json['lang'] as String? ?? 'all',
      id: json['id'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
    );
  }

  /// Get a clean base URL (first one if multiple)
  String get cleanBaseUrl {
    // Some sources have multiple URLs separated by ", "
    final urls = baseUrl.split(', ');
    if (urls.isNotEmpty) {
      return urls.first.replaceAll('#', '');
    }
    return baseUrl.replaceAll('#', '');
  }
}

/// Installed/enabled source stored in Hive
@HiveType(typeId: 11)
class InstalledSource extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String lang;

  @HiveField(3)
  final String baseUrl;

  @HiveField(4)
  final String extensionPkg;

  @HiveField(5)
  bool enabled;

  InstalledSource({
    required this.id,
    required this.name,
    required this.lang,
    required this.baseUrl,
    required this.extensionPkg,
    this.enabled = true,
  });

  factory InstalledSource.fromExtensionSource(
    ExtensionSource source,
    String extensionPkg,
  ) {
    return InstalledSource(
      id: source.id,
      name: source.name,
      lang: source.lang,
      baseUrl: source.cleanBaseUrl,
      extensionPkg: extensionPkg,
    );
  }
}
