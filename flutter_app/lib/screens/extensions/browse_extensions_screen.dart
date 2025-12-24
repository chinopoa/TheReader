import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/extension.dart';
import '../../services/extension_service.dart';
import '../../theme/app_theme.dart';

/// Screen to browse extensions from a repository
class BrowseExtensionsScreen extends ConsumerStatefulWidget {
  final ExtensionRepo repo;

  const BrowseExtensionsScreen({super.key, required this.repo});

  @override
  ConsumerState<BrowseExtensionsScreen> createState() => _BrowseExtensionsScreenState();
}

class _BrowseExtensionsScreenState extends ConsumerState<BrowseExtensionsScreen> {
  String _searchQuery = '';
  String _selectedLang = 'all';
  bool _hideNsfw = true;

  final List<String> _languages = [
    'all', 'en', 'ja', 'ko', 'zh', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'id', 'vi', 'th', 'ar', 'tr', 'pl',
  ];

  @override
  Widget build(BuildContext context) {
    final extensionsAsync = ref.watch(extensionsFromRepoProvider(widget.repo.url));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.repo.name),
        actions: [
          // Language filter
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (lang) => setState(() => _selectedLang = lang),
            itemBuilder: (context) => _languages.map((lang) => 
              PopupMenuItem(
                value: lang,
                child: Row(
                  children: [
                    if (lang == _selectedLang) 
                      const Icon(Icons.check, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(lang.toUpperCase()),
                  ],
                ),
              ),
            ).toList(),
          ),
          // NSFW filter
          IconButton(
            icon: Icon(_hideNsfw ? Icons.visibility_off : Icons.visibility),
            tooltip: _hideNsfw ? 'Show NSFW' : 'Hide NSFW',
            onPressed: () => setState(() => _hideNsfw = !_hideNsfw),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search extensions...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.glassColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Extensions list
          Expanded(
            child: extensionsAsync.when(
              data: (extensions) {
                var filtered = extensions;
                
                // Filter by language
                if (_selectedLang != 'all') {
                  filtered = filtered.where((e) => 
                    e.lang == _selectedLang || e.lang == 'all'
                  ).toList();
                }

                // Filter NSFW
                if (_hideNsfw) {
                  filtered = filtered.where((e) => e.isSafe).toList();
                }

                // Search filter
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filtered = filtered.where((e) => 
                    e.displayName.toLowerCase().contains(query)
                  ).toList();
                }

                // Sort by name
                filtered.sort((a, b) => a.displayName.compareTo(b.displayName));

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No extensions found',
                      style: TextStyle(color: context.secondaryTextColor),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ext = filtered[index];
                    return _ExtensionCard(extension: ext);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading extensions'),
                    Text(e.toString(), style: TextStyle(fontSize: 12, color: context.secondaryTextColor)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(extensionsFromRepoProvider(widget.repo.url)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing an extension and its sources
class _ExtensionCard extends ConsumerStatefulWidget {
  final Extension extension;

  const _ExtensionCard({required this.extension});

  @override
  ConsumerState<_ExtensionCard> createState() => _ExtensionCardState();
}

class _ExtensionCardState extends ConsumerState<_ExtensionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ext = widget.extension;
    final installedSources = ref.watch(installedSourceNotifierProvider);

    // Check how many sources are installed
    final installedCount = ext.sources.where((s) => 
      installedSources.any((is_) => is_.id == s.id)
    ).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: ext.isSafe ? Colors.blue : Colors.orange,
              child: Text(
                ext.displayName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(ext.displayName),
            subtitle: Text(
              '${ext.lang.toUpperCase()} • ${ext.sources.length} sources${installedCount > 0 ? ' • $installedCount installed' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!ext.isSafe)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('18+', style: TextStyle(fontSize: 10, color: Colors.orange)),
                  ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: ext.sources.map((source) {
                  final isInstalled = installedSources.any((is_) => is_.id == source.id);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isInstalled ? Icons.check_circle : Icons.circle_outlined,
                      color: isInstalled ? Colors.green : null,
                      size: 20,
                    ),
                    title: Text(source.name),
                    subtitle: Text('${source.lang.toUpperCase()} • ${source.cleanBaseUrl}'),
                    trailing: isInstalled
                        ? TextButton(
                            onPressed: () {
                              final installed = installedSources.where((is_) => is_.id == source.id).firstOrNull;
                              if (installed != null) {
                                ref.read(installedSourceNotifierProvider.notifier).uninstallSource(installed);
                              }
                            },
                            child: const Text('Uninstall', style: TextStyle(color: Colors.red)),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              ref.read(installedSourceNotifierProvider.notifier).installSource(source, ext.pkg);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Installed ${source.name}')),
                              );
                            },
                            child: const Text('Install'),
                          ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
