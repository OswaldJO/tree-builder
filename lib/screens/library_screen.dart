import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/library_sort_option.dart';
import '../models/tree_build.dart';
import '../services/tree_export_service.dart';
import '../services/tree_storage_service.dart';
import 'tree_view_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _storage = TreeStorageService();
  final _exportService = TreeExportService();
  List<TreeBuild> _builds = [];
  bool _loading = true;
  LibrarySortOption _sortOption = LibrarySortOption.newest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final builds = await _storage.loadAll();
    if (mounted) {
      setState(() {
        _builds = builds;
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    try {
      final imported = await _exportService.importFromFile();
      if (imported.isEmpty) return;

      await _storage.importBuilds(imported);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${imported.length} tree${imported.length == 1 ? '' : 's'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _exportAll() async {
    if (_builds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No trees to export')),
      );
      return;
    }

    try {
      final path = await _exportService.exportLibraryAsJson(_builds);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Library exported to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _delete(TreeBuild build) async {
    await _storage.delete(build.id);
    await _load();
  }

  Future<void> _toggleFavorite(TreeBuild build) async {
    await _storage.save(build.copyWith(isFavorite: !build.isFavorite));
    await _load();
  }

  List<_LibraryRow> _buildRows() {
    final favorites = sortTreeBuilds(
      _builds.where((b) => b.isFavorite).toList(),
      _sortOption,
    );
    final others = sortTreeBuilds(
      _builds.where((b) => !b.isFavorite).toList(),
      _sortOption,
    );

    final rows = <_LibraryRow>[];
    if (favorites.isNotEmpty) {
      rows.add(const _LibraryRow.header('Favorites'));
      rows.addAll(favorites.map(_LibraryRow.build));
    }
    if (others.isNotEmpty) {
      if (favorites.isNotEmpty) {
        rows.add(const _LibraryRow.header('All trees'));
      }
      rows.addAll(others.map(_LibraryRow.build));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_jm();
    final rows = _buildRows();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tree Library'),
        actions: [
          PopupMenuButton<LibrarySortOption>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sortOption,
            onSelected: (option) => setState(() => _sortOption = option),
            itemBuilder: (context) => LibrarySortOption.values
                .map(
                  (option) => PopupMenuItem(
                    value: option,
                    child: Row(
                      children: [
                        if (option == _sortOption)
                          Icon(
                            Icons.check,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(option.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: 'Import',
            icon: const Icon(Icons.upload_file),
            onPressed: _import,
          ),
          IconButton(
            tooltip: 'Export all',
            icon: const Icon(Icons.download),
            onPressed: _exportAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _builds.isEmpty
              ? _EmptyLibrary(onImport: _import)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    separatorBuilder: (context, index) {
                      final next = index + 1 < rows.length ? rows[index + 1] : null;
                      if (rows[index].isHeader || (next?.isHeader ?? false)) {
                        return const SizedBox(height: 4);
                      }
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row.isHeader) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            top: 8,
                            bottom: 4,
                          ),
                          child: Text(
                            row.title!,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        );
                      }

                      final build = row.build!;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              Icons.folder,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          title: Text(build.rootName),
                          subtitle: Text(
                            '${dateFormat.format(build.createdAt)} · '
                            '${build.folderCount} folders · ${build.fileCount} files',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  build.isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: build.isFavorite
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                                tooltip: build.isFavorite
                                    ? 'Remove from favorites'
                                    : 'Add to favorites',
                                onPressed: () => _toggleFavorite(build),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TreeViewScreen(
                                  treeBuild: build,
                                  onDelete: () => _delete(build),
                                ),
                              ),
                            );
                            await _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _LibraryRow {
  const _LibraryRow.header(this.title) : build = null;

  const _LibraryRow.build(this.build) : title = null;

  final String? title;
  final TreeBuild? build;

  bool get isHeader => title != null;
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved trees yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Build a tree from a directory or import one from a JSON file.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import Tree'),
            ),
          ],
        ),
      ),
    );
  }
}
