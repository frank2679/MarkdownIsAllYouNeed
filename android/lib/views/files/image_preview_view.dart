import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/file_manager_service.dart';

class ImagePreviewView extends StatelessWidget {
  final String filePath;

  const ImagePreviewView({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    final name = filePath.split('/').last;
    final size = FileManagerService.shared.fileSize(filePath);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Center(
                child: Image.file(
                  File(filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _formatSize(size),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
