enum ScanSourceType {
  local,
  smb,
  sftp;

  String get label {
    switch (this) {
      case ScanSourceType.local:
        return 'Local';
      case ScanSourceType.smb:
        return 'SMB';
      case ScanSourceType.sftp:
        return 'SFTP';
    }
  }
}
