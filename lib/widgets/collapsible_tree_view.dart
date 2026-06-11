import 'package:flutter/material.dart';

import '../models/tree_node.dart';
import '../utils/tree_renderer.dart';

class CollapsibleTreeView extends StatefulWidget {
  const CollapsibleTreeView({
    super.key,
    required this.rootName,
    required this.root,
    this.initialExpandAll = false,
    this.onVisibleTextChanged,
    this.padding = const EdgeInsets.all(16),
  });

  final String rootName;
  final TreeNode root;
  final bool initialExpandAll;
  final ValueChanged<String>? onVisibleTextChanged;
  final EdgeInsets padding;

  @override
  State<CollapsibleTreeView> createState() => CollapsibleTreeViewState();
}

class CollapsibleTreeViewState extends State<CollapsibleTreeView> {
  late Set<String> _expandedPaths;

  @override
  void initState() {
    super.initState();
    _expandedPaths = widget.initialExpandAll
        ? TreeRenderer.allFolderPaths(widget.root)
        : {};
  }

  String get visibleTreeText => TreeRenderer.renderVisible(
        widget.rootName,
        widget.root.children,
        _expandedPaths,
      );

  void expandAll() {
    setState(() {
      _expandedPaths
        ..clear()
        ..addAll(TreeRenderer.allFolderPaths(widget.root));
    });
    _notifyTextChanged();
  }

  void collapseAll() {
    setState(_expandedPaths.clear);
    _notifyTextChanged();
  }

  void _toggleFolder(String pathKey) {
    setState(() {
      if (_expandedPaths.contains(pathKey)) {
        _expandedPaths.remove(pathKey);
      } else {
        _expandedPaths.add(pathKey);
      }
    });
    _notifyTextChanged();
  }

  void _notifyTextChanged() {
    widget.onVisibleTextChanged?.call(visibleTreeText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _buildRows();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: ListView(
        padding: widget.padding,
        children: [
          Text(
            '${widget.rootName}/',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          ...rows.map((row) => _TreeRow(
                row: row,
                onToggle: row.pathKey == null
                    ? null
                    : () => _toggleFolder(row.pathKey!),
              )),
        ],
      ),
    );
  }

  List<_TreeRowData> _buildRows() {
    final rows = <_TreeRowData>[];
    _collectRows(widget.root.children, const [], rows, '');
    return rows;
  }

  void _collectRows(
    List<TreeNode> children,
    List<String> pathSegments,
    List<_TreeRowData> rows,
    String prefix,
  ) {
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final isLast = i == children.length - 1;
      final connector = isLast ? '└── ' : '├── ';
      final childPrefix = isLast ? '    ' : '│   ';
      final segments = child.isDirectory ? [...pathSegments, child.name] : pathSegments;
      final pathKey =
          child.isDirectory ? TreeRenderer.pathKey(segments) : null;
      final isExpanded =
          pathKey != null && _expandedPaths.contains(pathKey);

      rows.add(
        _TreeRowData(
          linePrefix: prefix + connector,
          name: child.name,
          isDirectory: child.isDirectory,
          pathKey: pathKey,
          isExpanded: isExpanded,
          hasChildren: child.isDirectory && child.children.isNotEmpty,
        ),
      );

      if (child.isDirectory && isExpanded) {
        _collectRows(child.children, segments, rows, prefix + childPrefix);
      }
    }
  }
}

class _TreeRowData {
  const _TreeRowData({
    required this.linePrefix,
    required this.name,
    required this.isDirectory,
    required this.pathKey,
    required this.isExpanded,
    required this.hasChildren,
  });

  final String linePrefix;
  final String name;
  final bool isDirectory;
  final String? pathKey;
  final bool isExpanded;
  final bool hasChildren;
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.row,
    required this.onToggle,
  });

  final _TreeRowData row;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = row.isDirectory ? '${row.name}/' : row.name;

    final content = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: row.linePrefix,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
          TextSpan(
            text: displayName,
            style: TextStyle(
              color: row.isDirectory
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight:
                  row.isDirectory ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
      style: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        height: 1.4,
      ),
    );

    if (!row.isDirectory || !row.hasChildren) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                row.isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}
