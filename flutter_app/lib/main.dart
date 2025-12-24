import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/manga.dart';
import 'models/chapter.dart';
import 'models/history_item.dart';
import 'models/recent_search.dart';
import 'models/extension.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'services/source_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(MangaAdapter());
  Hive.registerAdapter(ChapterAdapter());
  Hive.registerAdapter(HistoryItemAdapter());
  Hive.registerAdapter(RecentSearchAdapter());
  Hive.registerAdapter(MangaStatusAdapter());
  Hive.registerAdapter(MangaSourceAdapter());
  Hive.registerAdapter(ExtensionRepoAdapter());
  Hive.registerAdapter(InstalledSourceAdapter());

  // Open boxes
  await Hive.openBox<Manga>('manga');
  await Hive.openBox<Chapter>('chapters');
  await Hive.openBox<HistoryItem>('history');
  await Hive.openBox<RecentSearch>('recent_searches');
  await Hive.openBox('settings');
  await Hive.openBox<ExtensionRepo>('extension_repos');
  await Hive.openBox<InstalledSource>('installed_sources');

  // NOTE: Removed database clearing - library data should persist!
  // If you need to reset, uncomment these lines temporarily:
  // await Hive.box<Manga>('manga').clear();
  // await Hive.box<Chapter>('chapters').clear();
  // await Hive.box<HistoryItem>('history').clear();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: TheReaderApp()));
}

class TheReaderApp extends ConsumerWidget {
  const TheReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);
    
    // Preload manga indexes in background for instant search
    // Using addPostFrameCallback so it runs after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sourceServiceProvider).preloadAllIndexes();
    });

    return MaterialApp.router(
      title: 'TheReader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
