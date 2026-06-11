import '../models/scan_progress.dart';

class ScanCounters {
  int folders = 0;
  int files = 0;
  int _itemsSinceReport = 0;

  Future<void> maybeReport(
    String name,
    void Function(ScanProgress)? onProgress,
  ) async {
    _itemsSinceReport++;
    if (_itemsSinceReport >= 25) {
      _itemsSinceReport = 0;
      onProgress?.call(toProgress(currentName: name));
      await Future<void>.delayed(Duration.zero);
    }
  }

  ScanProgress toProgress({String? currentName}) {
    return ScanProgress(
      folders: folders,
      files: files,
      currentName: currentName,
    );
  }
}
