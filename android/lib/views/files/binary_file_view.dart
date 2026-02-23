import 'package:flutter/material.dart';
import '../../services/file_manager_service.dart';

class BinaryFileView extends StatelessWidget {
  final String filePath;

  const BinaryFileView({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    final name = filePath.split('/').last;
    final size = FileManagerService.shared.fileSize(filePath);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _formatSize(size),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Preview not available for this file type',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
