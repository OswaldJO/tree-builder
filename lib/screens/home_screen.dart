import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/scan_progress.dart';
import '../models/tree_build.dart';
import '../services/directory_scanner.dart';
import '../services/tree_storage_service.dart';
import '../widgets/collapsible_tree_view.dart';
import '../widgets/scan_loading_overlay.dart';
import 'library_screen.dart';
import 'tree_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scanner = const DirectoryScanner();
  final _storage = TreeStorageService();
  final _depthController = TextEditingController(text: '3');
  bool _scanning = false;
  bool _expandAllFolders = false;
  bool _limitDepth = false;
  TreeBuild? _currentBuild;
  ScanProgress _scanProgress = const ScanProgress(folders: 0, files: 0);

  @override
  void dispose() {
    _depthController.dispose();
    super.dispose();
  }

  int? _parsedMaxDepth() {
    final value = int.tryParse(_depthController.text.trim());
    if (value == null || value < 1) return null;
    return value;
  }

  void _updateScanProgress(ScanProgress progress) {
    if (!mounted) return;
    setState(() => _scanProgress = progress);
  }

  Future<void> _pickDirectory() async {
    int? maxDepth;
    if (_limitDepth) {
      maxDepth = _parsedMaxDepth();
      if (maxDepth == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a depth of at least 1'),
          ),
        );
        return;
      }
    }

    try {
      TreeBuild? build;

      if (Platform.isAndroid) {
        build = await _scanner.pickAndScan(
          maxDepth: maxDepth,
          onProgress: (progress) {
            if (!_scanning && mounted) {
              setState(() {
                _scanning = true;
                _currentBuild = null;
                _scanProgress = progress;
              });
            } else {
              _updateScanProgress(progress);
            }
          },
        );
      } else {
        final path = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select a directory to scan',
        );
        if (path == null) return;

        setState(() {
          _scanning = true;
          _currentBuild = null;
          _scanProgress = const ScanProgress(folders: 0, files: 0);
        });

        build = await _scanner.pickAndScan(
          path: path,
          maxDepth: maxDepth,
          onProgress: _updateScanProgress,
        );
      }

      if (build == null) {
        if (mounted) setState(() => _scanning = false);
        return;
      }

      _updateScanProgress(
        _scanProgress.copyWith(phase: ScanPhase.saving),
      );

      final saved = build.copyWith(expandAllFolders: _expandAllFolders);
      await _storage.save(saved);
      if (mounted) {
        setState(() {
          _currentBuild = saved;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to scan directory: $e')),
        );
      }
    }
  }

  void _openLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LibraryScreen()),
    );
  }

  void _openFullView() {
    final build = _currentBuild;
    if (build == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TreeViewScreen(treeBuild: build),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tree Builder'),
        actions: [
          IconButton(
            tooltip: 'Library',
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: _scanning ? null : _openLibrary,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.folder_open,
                                  size: 48,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Select a directory',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Generate an ASCII tree of all folders and files. '
                                  'Each build is saved to your library automatically.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: _scanning ? null : _pickDirectory,
                                  icon: const Icon(Icons.drive_folder_upload),
                                  label: const Text('Choose Directory'),
                                ),
                                const SizedBox(height: 8),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: const Text('Expand all folders'),
                                  subtitle: const Text(
                                    'Show every folder expanded in the generated tree',
                                  ),
                                  value: _expandAllFolders,
                                  onChanged: _scanning
                                      ? null
                                      : (value) => setState(
                                            () => _expandAllFolders =
                                                value ?? false,
                                          ),
                                ),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: const Text('Limit folder depth'),
                                  subtitle: _limitDepth
                                      ? Text(
                                          'Scan up to ${_parsedMaxDepth() ?? '…'} folder '
                                          'level${(_parsedMaxDepth() ?? 0) == 1 ? '' : 's'} deep',
                                        )
                                      : const Text(
                                          'Scan all subfolders (unlimited)',
                                        ),
                                  value: _limitDepth,
                                  onChanged: _scanning
                                      ? null
                                      : (value) => setState(
                                            () => _limitDepth = value ?? false,
                                          ),
                                ),
                                if (_limitDepth)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      bottom: 8,
                                    ),
                                    child: TextField(
                                      controller: _depthController,
                                      enabled: !_scanning,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Depth levels',
                                        hintText: 'e.g. 3',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_currentBuild != null) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _currentBuild!.rootName,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _openFullView,
                                icon: const Icon(Icons.open_in_full, size: 18),
                                label: const Text('Open'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ] else if (!_scanning) ...[
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _openLibrary,
                            icon: const Icon(Icons.collections_bookmark_outlined),
                            label: const Text('Browse Library'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_currentBuild != null) ...[
                  const SizedBox(height: 8),
                  Expanded(
                    child: CollapsibleTreeView(
                      key: ValueKey(_currentBuild!.id),
                      rootName: _currentBuild!.rootName,
                      root: _currentBuild!.root,
                      initialExpandAll: _currentBuild!.expandAllFolders,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_scanning) ScanLoadingOverlay(progress: _scanProgress),
        ],
      ),
    );
  }
}
