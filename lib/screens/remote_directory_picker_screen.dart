import 'package:flutter/material.dart';

import '../models/remote_settings.dart';
import '../models/scan_source_type.dart';
import '../services/sftp_remote_browser.dart';
import '../services/smb_remote_browser.dart';

Future<String?> pickRemoteDirectory(
  BuildContext context, {
  required ScanSourceType sourceType,
  required SmbSettings smbSettings,
  required SftpSettings sftpSettings,
}) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (context) => RemoteDirectoryPickerScreen(
        sourceType: sourceType,
        smbSettings: smbSettings,
        sftpSettings: sftpSettings,
      ),
    ),
  );
}

class RemoteDirectoryPickerScreen extends StatefulWidget {
  const RemoteDirectoryPickerScreen({
    super.key,
    required this.sourceType,
    required this.smbSettings,
    required this.sftpSettings,
  });

  final ScanSourceType sourceType;
  final SmbSettings smbSettings;
  final SftpSettings sftpSettings;

  @override
  State<RemoteDirectoryPickerScreen> createState() =>
      _RemoteDirectoryPickerScreenState();
}

class _RemoteDirectoryPickerScreenState
    extends State<RemoteDirectoryPickerScreen> {
  bool _loading = true;
  String? _error;
  List<RemoteDirectoryEntry> _entries = const [];

  SmbRemoteBrowser? _smbBrowser;
  SftpRemoteBrowser? _sftpBrowser;

  /// SMB: null = share list. SFTP: always a path starting at `/`.
  String? _smbPath;
  String _sftpPath = '/';

  bool get _isSmb => widget.sourceType == ScanSourceType.smb;

  String? get _selectedPath {
    if (_isSmb) return _smbPath;
    return _sftpPath;
  }

  bool get _canSelect {
    if (_loading || _error != null) return false;
    if (_isSmb) return _smbPath != null;
    return true;
  }

  String get _locationLabel {
    if (_isSmb) {
      return _smbPath ?? 'Shares on ${widget.smbSettings.host.trim()}';
    }
    return _sftpPath;
  }

  @override
  void initState() {
    super.initState();
    _connectAndLoad();
  }

  @override
  void dispose() {
    _smbBrowser?.close();
    _sftpBrowser?.close();
    super.dispose();
  }

  Future<void> _connectAndLoad() async {
    setState(() {
      _loading = true;
      _error = null;
      _entries = const [];
    });

    try {
      if (_isSmb) {
        _smbBrowser = SmbRemoteBrowser(widget.smbSettings);
        await _smbBrowser!.connect();
      } else {
        _sftpBrowser = SftpRemoteBrowser(widget.sftpSettings);
        await _sftpBrowser!.connect();
      }
      await _loadEntries();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = _isSmb
          ? await _smbBrowser!.listFolders(_smbPath)
          : await _sftpBrowser!.listFolders(_sftpPath);

      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _openFolder(RemoteDirectoryEntry entry) {
    if (_isSmb) {
      _smbPath = entry.path;
    } else {
      _sftpPath = entry.path;
    }
    _loadEntries();
  }

  void _goUp() {
    if (_isSmb) {
      if (_smbPath == null) return;
      final parent = RemotePath.parent(_smbPath!);
      _smbPath = parent == '/' ? null : parent;
    } else {
      final parent = RemotePath.parent(_sftpPath);
      if (parent == null) return;
      _sftpPath = parent;
    }
    _loadEntries();
  }

  bool get _canGoUp {
    if (_isSmb) return _smbPath != null;
    return _sftpPath != '/';
  }

  void _selectCurrent() {
    final path = _selectedPath;
    if (path == null) return;
    Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final protocol = widget.sourceType.label;

    return Scaffold(
      appBar: AppBar(
        title: Text('Choose $protocol folder'),
        leading: _canGoUp
            ? IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Up',
                onPressed: _loading ? null : _goUp,
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                _locationLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _connectAndLoad,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _entries.isEmpty
                        ? Center(
                            child: Text(
                              _isSmb && _smbPath == null
                                  ? 'No shares found'
                                  : 'No subfolders',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              return ListTile(
                                leading: const Icon(Icons.folder_outlined),
                                title: Text(entry.name),
                                trailing:
                                    const Icon(Icons.chevron_right),
                                onTap: () => _openFolder(entry),
                              );
                            },
                          ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _canSelect ? _selectCurrent : null,
                child: Text(
                  _canSelect
                      ? 'Select this folder'
                      : 'Open a share to select a folder',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
