import 'package:flutter/material.dart';

import '../models/tree_build.dart';
import '../services/tree_export_service.dart';
import '../widgets/collapsible_tree_view.dart';
import '../widgets/tree_text_view.dart';

class TreeViewScreen extends StatefulWidget {
  const TreeViewScreen({
    super.key,
    required this.treeBuild,
    this.onDelete,
  });

  final TreeBuild treeBuild;
  final VoidCallback? onDelete;

  @override
  State<TreeViewScreen> createState() => _TreeViewScreenState();
}

class _TreeViewScreenState extends State<TreeViewScreen> {
  final _treeKey = GlobalKey<CollapsibleTreeViewState>();
  final _exportService = TreeExportService();

  String get _visibleTreeText =>
      _treeKey.currentState?.visibleTreeText ?? widget.treeBuild.treeText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.treeBuild.rootName),
        actions: [
          IconButton(
            tooltip: 'Expand all folders',
            icon: const Icon(Icons.unfold_more),
            onPressed: () => _treeKey.currentState?.expandAll(),
          ),
          IconButton(
            tooltip: 'Collapse all folders',
            icon: const Icon(Icons.unfold_less),
            onPressed: () => _treeKey.currentState?.collapseAll(),
          ),
          IconButton(
            tooltip: 'Copy visible tree',
            icon: const Icon(Icons.copy),
            onPressed: () =>
                TreeTextView.copyToClipboard(context, _visibleTreeText),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _export(value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'json', child: Text('Export as JSON')),
              PopupMenuItem(value: 'text', child: Text('Export as Text')),
            ],
          ),
          if (widget.onDelete != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(treeBuild: widget.treeBuild),
          const SizedBox(height: 8),
          Text(
            'Tap folders to expand or collapse. Copy and text export use the visible tree only.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: CollapsibleTreeView(
              key: _treeKey,
              rootName: widget.treeBuild.rootName,
              root: widget.treeBuild.root,
              initialExpandAll: widget.treeBuild.expandAllFolders,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(String value) async {
    try {
      String? path;
      final visibleText = _visibleTreeText;
      if (value == 'json') {
        path = await _exportService.exportAsJson(
          widget.treeBuild,
          treeText: visibleText,
        );
      } else if (value == 'text') {
        path = await _exportService.exportAsText(
          widget.treeBuild,
          treeText: visibleText,
        );
      }
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported visible tree to $path')),
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tree?'),
        content: Text(
          'Remove "${widget.treeBuild.rootName}" from your library?',
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
      widget.onDelete?.call();
      if (mounted) Navigator.pop(context);
    }
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
