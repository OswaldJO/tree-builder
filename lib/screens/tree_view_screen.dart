import 'package:flutter/material.dart';

import '../models/tree_build.dart';
import '../services/tree_export_service.dart';
import '../widgets/tree_text_view.dart';

class TreeViewScreen extends StatelessWidget {
  const TreeViewScreen({
    super.key,
    required this.treeBuild,
    this.onDelete,
  });

  final TreeBuild treeBuild;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final exportService = TreeExportService();

    return Scaffold(
      appBar: AppBar(
        title: Text(treeBuild.rootName),
        actions: [
          IconButton(
            tooltip: 'Copy tree',
            icon: const Icon(Icons.copy),
            onPressed: () =>
                TreeTextView.copyToClipboard(context, treeBuild.treeText),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              try {
                String? path;
                if (value == 'json') {
                  path = await exportService.exportAsJson(treeBuild);
                } else if (value == 'text') {
                  path = await exportService.exportAsText(treeBuild);
                }
                if (context.mounted && path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exported to $path')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'json', child: Text('Export as JSON')),
              PopupMenuItem(value: 'text', child: Text('Export as Text')),
            ],
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete tree?'),
                    content: Text(
                      'Remove "${treeBuild.rootName}" from your library?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  onDelete?.call();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(treeBuild: treeBuild),
          const SizedBox(height: 16),
          TreeTextView(treeText: treeBuild.treeText),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.treeBuild});

  final TreeBuild treeBuild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              treeBuild.rootPath,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(
                  icon: Icons.folder_outlined,
                  label: '${treeBuild.folderCount} folders',
                ),
                _StatChip(
                  icon: Icons.insert_drive_file_outlined,
                  label: '${treeBuild.fileCount} files',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
