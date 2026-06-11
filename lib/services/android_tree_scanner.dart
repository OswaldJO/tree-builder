import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/scan_progress.dart';
import '../models/tree_build.dart';
import 'directory_scanner.dart';

class AndroidTreeScanner {
  static const _channel = MethodChannel('com.treebuilder/tree_scanner');
  static const _progressChannel = EventChannel('com.treebuilder/scan_progress');

  static Future<String?> pickDirectory() async {
    if (!Platform.isAndroid) return null;

    final result = await _channel.invokeMethod<String?>('pickDirectory');
    return result;
  }

  static Future<TreeBuild?> scanDirectory(
    String uri, {
    int? maxDepth,
    void Function(ScanProgress progress)? onProgress,
  }) async {
    if (!Platform.isAndroid) return null;

    StreamSubscription<dynamic>? subscription;
    if (onProgress != null) {
      subscription = _progressChannel.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          onProgress(
            ScanProgress(
              folders: (event['folders'] as num?)?.toInt() ?? 0,
              files: (event['files'] as num?)?.toInt() ?? 0,
              currentName: event['current'] as String?,
            ),
          );
        }
      });
    }

    try {
      onProgress?.call(const ScanProgress(folders: 0, files: 0));

      final result = await _channel.invokeMethod(
        'scanDirectory',
        {'uri': uri, 'maxDepth': maxDepth},
      );
      if (result == null) return null;

      onProgress?.call(
        const ScanProgress(folders: 0, files: 0, phase: ScanPhase.building),
      );

      return compute(_parseScanResult, {
        'data': Map<dynamic, dynamic>.from(result as Map),
        'maxDepth': maxDepth,
      });
    } finally {
      await subscription?.cancel();
    }
  }

  static TreeBuild _parseScanResult(Map<String, dynamic> args) {
    return DirectoryScanner.fromScanResult(
      Map<dynamic, dynamic>.from(args['data'] as Map),
      maxDepth: args['maxDepth'] as int?,
    );
  }
}
