import 'package:smb_connect/smb_connect.dart';

import '../models/remote_settings.dart';

class SmbRemoteBrowser {
  SmbRemoteBrowser(this.settings);

  final SmbSettings settings;
  SmbConnect? _connect;
  bool _connected = false;

  Future<void> connect() async {
    if (_connected) return;
    _connect = await SmbConnect.connectAuth(
      host: settings.host.trim(),
      username: settings.username.trim(),
      password: settings.password,
      domain: settings.domain.trim(),
    );
    _connected = true;
  }

  Future<void> close() async {
    await _connect?.close();
    _connect = null;
    _connected = false;
  }

  /// [path] null = list SMB shares; otherwise list subfolders at [path].
  Future<List<RemoteDirectoryEntry>> listFolders(String? path) async {
    final connect = _connect;
    if (connect == null) {
      throw StateError('Not connected');
    }

    if (path == null) {
      final shares = await connect.listShares();
      shares.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return shares
          .where((share) =>
              share.name.isNotEmpty &&
              share.name != SmbConnect.IPC_SHARE &&
              !share.name.endsWith(r'$'))
          .map(
            (share) => RemoteDirectoryEntry(
              name: share.name,
              path: RemotePath.normalize('/${share.name}'),
            ),
          )
          .toList();
    }

    final normalized = RemotePath.normalize(path);
    final folder = await connect.file(normalized);
    if (!folder.isExists) {
      throw Exception('Path does not exist: $normalized');
    }
    if (!folder.isDirectory()) {
      throw Exception('Path is not a directory: $normalized');
    }

    final files = await connect.listFiles(folder);
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return files
        .where(
          (file) =>
              file.isDirectory() &&
              file.name != SmbFile.NAME_DOT &&
              file.name != SmbFile.NAME_DOT_DOT,
        )
        .map(
          (file) => RemoteDirectoryEntry(
            name: file.name,
            path: RemotePath.normalize(file.path),
          ),
        )
        .toList();
  }
}
