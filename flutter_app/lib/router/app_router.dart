import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/tabs/library_screen.dart';
import '../screens/tabs/updates_screen.dart';
import '../screens/tabs/browse_screen.dart';
import '../screens/tabs/history_screen.dart';
import '../screens/tabs/settings_screen.dart';
import '../screens/detail/manga_detail_screen.dart';
import '../screens/reader/reader_screen.dart';
import '../screens/extensions/extensions_screen.dart';
import '../screens/extensions/browse_extensions_screen.dart';
import '../screens/browse/source_browse_screen.dart';
import '../models/extension.dart';
import '../widgets/main_shell.dart';
import '../screens/webview/webview_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/library',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/library',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LibraryScreen(),
            ),
          ),
          GoRoute(
            path: '/updates',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: UpdatesScreen(),
            ),
          ),
          GoRoute(
            path: '/browse',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BrowseScreen(),
            ),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      // Manga detail screen - outside ShellRoute so no bottom tabs
      GoRoute(
        path: '/library/manga/:id',
        builder: (context, state) => MangaDetailScreen(
          mangaId: state.pathParameters['id']!,
        ),
      ),
      // Reader screen - outside ShellRoute so no bottom tabs
      GoRoute(
        path: '/reader/:mangaId/:chapterId',
        builder: (context, state) => ReaderScreen(
          mangaId: state.pathParameters['mangaId']!,
          chapterId: state.pathParameters['chapterId']!,
        ),
      ),
      // Extensions screen
      GoRoute(
        path: '/extensions',
        builder: (context, state) => const ExtensionsScreen(),
      ),
      // Browse extensions from repo
      GoRoute(
        path: '/extensions/browse',
        builder: (context, state) => BrowseExtensionsScreen(
          repo: state.extra as ExtensionRepo,
        ),
      ),
      // Browse source (Popular/Latest)
      GoRoute(
        path: '/browse/source/:sourceId',
        builder: (context, state) => SourceBrowseScreen(
          sourceId: state.pathParameters['sourceId']!,
        ),
      ),
      // WebView screen for Cloudflare bypass
      GoRoute(
        path: '/webview',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return WebViewScreen(
            url: extras['url'],
            title: extras['title'],
          );
        },
      ),
    ],
  );
});

