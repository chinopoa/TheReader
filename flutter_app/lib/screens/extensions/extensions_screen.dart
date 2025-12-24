import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/extension.dart';
import '../../services/extension_service.dart';
import '../../theme/app_theme.dart';

class ExtensionsScreen extends ConsumerStatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  ConsumerState<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends ConsumerState<ExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _addRepo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Extension Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Repository URL',
                hintText: 'https://raw.githubusercontent.com/.../index.min.json',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Quick add buttons
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Keiyoushi'),
                  onPressed: () {
                    _urlController.text = 'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json';
                  },
                ),
                ActionChip(
                  label: const Text('Everfio'),
                  onPressed: () {
                    _urlController.text = 'https://raw.githubusercontent.com/everfio/tachiyomi-extensions/repo/index.min.json';
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = _urlController.text.trim();
              if (url.isNotEmpty) {
                // Extract name from URL
                final name = _extractRepoName(url);
                ref.read(extensionRepoNotifierProvider.notifier).addRepo(name, url);
                _urlController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _extractRepoName(String url) {
    // Try to extract a meaningful name from the URL
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.length >= 2) {
      return uri.pathSegments[1]; // Usually the repo owner/name
    }
    return 'Repository';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extensions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Installed'),
            Tab(text: 'Repositories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InstalledSourcesTab(),
          _RepositoriesTab(onAddRepo: _addRepo),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRepo,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Tab showing installed sources
class _InstalledSourcesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(installedSourceNotifierProvider);

    if (sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.extension_off, size: 64, color: context.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              'No Sources Installed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.glassTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a repository and install sources\nto start browsing manga.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: source.enabled ? Colors.green : Colors.grey,
              child: Text(
                source.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(source.name),
            subtitle: Text('${source.lang.toUpperCase()} • ${source.baseUrl}'),
            trailing: Switch(
              value: source.enabled,
              onChanged: (_) {
                ref.read(installedSourceNotifierProvider.notifier).toggleSource(source);
              },
            ),
            onLongPress: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Uninstall Source'),
                  content: Text('Remove ${source.name} from installed sources?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(installedSourceNotifierProvider.notifier).uninstallSource(source);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Uninstall'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Tab showing extension repositories
class _RepositoriesTab extends ConsumerWidget {
  final VoidCallback onAddRepo;

  const _RepositoriesTab({required this.onAddRepo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repos = ref.watch(extensionRepoNotifierProvider);

    if (repos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: context.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              'No Repositories Added',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.glassTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add an extension repository.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.secondaryTextColor),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddRepo,
              icon: const Icon(Icons.add),
              label: const Text('Add Repository'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: repos.length,
      itemBuilder: (context, index) {
        final repo = repos[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.extension, color: Colors.white),
            ),
            title: Text(repo.name),
            subtitle: Text(
              repo.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                ref.read(extensionRepoNotifierProvider.notifier).removeRepo(repo);
              },
            ),
            onTap: () {
              // Navigate to browse extensions from this repo
              context.push('/extensions/browse', extra: repo);
            },
          ),
        );
      },
    );
  }
}
