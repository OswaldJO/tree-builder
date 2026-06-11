class SmbSettings {
  const SmbSettings({
    this.host = '',
    this.domain = '',
    this.username = '',
    this.password = '',
  });

  final String host;
  final String domain;
  final String username;
  final String password;

  bool get isConfigured =>
      host.trim().isNotEmpty && username.trim().isNotEmpty;

  String displayUriForPath(String remotePath) {
    final path = RemotePath.normalize(remotePath);
    return 'smb://${host.trim()}$path';
  }

  SmbSettings copyWith({
    String? host,
    String? domain,
    String? username,
    String? password,
  }) {
    return SmbSettings(
      host: host ?? this.host,
      domain: domain ?? this.domain,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'domain': domain,
        'username': username,
        'password': password,
      };

  factory SmbSettings.fromJson(Map<String, dynamic> json) {
    return SmbSettings(
      host: json['host'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}

class SftpSettings {
  const SftpSettings({
    this.host = '',
    this.port = 22,
    this.username = '',
    this.password = '',
  });

  final String host;
  final int port;
  final String username;
  final String password;

  bool get isConfigured =>
      host.trim().isNotEmpty && username.trim().isNotEmpty;

  String displayUriForPath(String remotePath) {
    final path = RemotePath.normalize(remotePath);
    final portSuffix = port == 22 ? '' : ':$port';
    return 'sftp://${host.trim()}$portSuffix$path';
  }

  SftpSettings copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return SftpSettings(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
      };

  factory SftpSettings.fromJson(Map<String, dynamic> json) {
    return SftpSettings(
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 22,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
    );
  }
}

class RemotePath {
  RemotePath._();

  static String normalize(String path) {
    var normalized = path.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) return '/';
    if (!normalized.startsWith('/')) normalized = '/$normalized';
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static String basename(String path) {
    final normalized = normalize(path);
    if (normalized == '/') return '/';
    final segments = normalized.split('/')..removeWhere((s) => s.isEmpty);
    return segments.isEmpty ? normalized : segments.last;
  }

  static String? parent(String path) {
    final normalized = normalize(path);
    if (normalized == '/') return null;
    final segments = normalized.split('/')..removeWhere((s) => s.isEmpty);
    if (segments.length <= 1) return '/';
    segments.removeLast();
    return '/${segments.join('/')}';
  }

  static String join(String parent, String name) {
    final base = normalize(parent);
    if (base == '/') return '/$name';
    return '$base/$name';
  }
}

class RemoteSettings {
  const RemoteSettings({
    this.smb = const SmbSettings(),
    this.sftp = const SftpSettings(),
  });

  final SmbSettings smb;
  final SftpSettings sftp;

  RemoteSettings copyWith({
    SmbSettings? smb,
    SftpSettings? sftp,
  }) {
    return RemoteSettings(
      smb: smb ?? this.smb,
      sftp: sftp ?? this.sftp,
    );
  }

  Map<String, dynamic> toJson() => {
        'smb': smb.toJson(),
        'sftp': sftp.toJson(),
      };

  factory RemoteSettings.fromJson(Map<String, dynamic> json) {
    return RemoteSettings(
      smb: SmbSettings.fromJson(
        json['smb'] as Map<String, dynamic>? ?? const {},
      ),
      sftp: SftpSettings.fromJson(
        json['sftp'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class RemoteDirectoryEntry {
  const RemoteDirectoryEntry({
    required this.name,
    required this.path,
  });

  final String name;
  final String path;
}
