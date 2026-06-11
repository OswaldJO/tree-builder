import 'package:flutter/material.dart';

import '../models/scan_progress.dart';

class ScanLoadingOverlay extends StatelessWidget {
  const ScanLoadingOverlay({
    super.key,
    required this.progress,
  });

  final ScanProgress progress;

  String get _title {
    return switch (progress.phase) {
      ScanPhase.scanning => 'Scanning directory',
      ScanPhase.building => 'Building tree',
      ScanPhase.saving => 'Saving to library',
    };
  }

  String get _subtitle {
    if (progress.phase != ScanPhase.scanning) {
      return 'Almost done...';
    }

    final current = progress.currentName;
    if (current != null && current.isNotEmpty) {
      return 'Reading: $current';
    }

    return 'Walking folders and files...';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AbsorbPointer(
      child: Container(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _title,
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (progress.phase == ScanPhase.scanning) ...[
                        const SizedBox(height: 24),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(minHeight: 6),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Stat(
                              icon: Icons.folder_outlined,
                              label: '${progress.folders} folders',
                            ),
                            _Stat(
                              icon: Icons.insert_drive_file_outlined,
                              label: '${progress.files} files',
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Large directories can take a minute or two.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
