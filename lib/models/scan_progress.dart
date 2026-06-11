class ScanProgress {
  const ScanProgress({
    required this.folders,
    required this.files,
    this.currentName,
    this.phase = ScanPhase.scanning,
  });

  final int folders;
  final int files;
  final String? currentName;
  final ScanPhase phase;

  ScanProgress copyWith({
    int? folders,
    int? files,
    String? currentName,
    ScanPhase? phase,
  }) {
    return ScanProgress(
      folders: folders ?? this.folders,
      files: files ?? this.files,
      currentName: currentName ?? this.currentName,
      phase: phase ?? this.phase,
    );
  }
}

enum ScanPhase {
  scanning,
  building,
  saving,
}
