import 'package:dartssh2/dartssh2.dart';

import '../models/remote_settings.dart';

class SftpRemoteBrowser {
  SftpRemoteBrowser(this.settings);

  final SftpSettings settings;
  SSHClient? _client;
  bool _connected = false;

  Future<void> connect() async {
    if (_connected) return;
    final socket = await SSHSocket.connect(
      settings.host.trim(),
      settings.port,
    );
    _client = SSHClient(
      socket,
      username: settings.username.trim(),
      onPasswordRequest: () => settings.password,
    );
    await _client!.sftp();
    _connected = true;
  }

  Future<void> close() async {
    _client?.close();
    _client = null;
    _connected = false;
  }

  Future<List<RemoteDirectoryEntry>> listFolders(String path) async {
    final client = _client;
    if (client == null) {
      throw StateError('Not connected');
    }

    final sftp = await client.sftp();
    final normalized = RemotePath.normalize(path);
    final entries = await sftp.listdir(normalized);
    entries.sort(
      (a, b) => a.filename.toLowerCase().compareTo(b.filename.toLowerCase()),
    );

    return entries
        .where(
          (entry) =>
              entry.attr.isDirectory &&
              entry.filename != '.' &&
              entry.filename != '..',
        )
        .map(
          (entry) => RemoteDirectoryEntry(
            name: entry.filename,
            path: RemotePath.join(normalized, entry.filename),
          ),
        )
        .toList();
  }
}
