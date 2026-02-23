import 'package:flutter/material.dart';
import '../../models/file_node.dart';
import '../../models/git_status.dart';

class FileNodeRow extends StatelessWidget {
  final FileNode node;
  final int depth;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onCreateFile;
  final VoidCallback? onCreateFolder;

  const FileNodeRow({
    super.key,
    required this.node,
    required this.depth,
    required this.isFavorite,
    this.onTap,
    this.onToggleExpand,
    this.onFavoriteToggle,
    this.onDelete,
    this.onRename,
    this.onCreateFile,
    this.onCreateFolder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: InkWell(
        onTap: node.isDirectory ? onToggleExpand : onTap,
        child: Padding(
          padding: EdgeInsets.only(left: 12.0 + depth * 16.0, right: 8, top: 4, bottom: 4),
          child: Row(
            children: [
              // Expand arrow for directories
              if (node.isDirectory)
                Icon(
                  node.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              else
                const SizedBox(width: 16),
              const SizedBox(width: 4),
              // File icon
              Icon(
                _iconForNode(node),
                size: 18,
                color: _colorForNode(node, theme),
              ),
              const SizedBox(width: 8),
              // Name
              Expanded(
                child: Text(
                  node.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              // Change indicator
              if (node.changeType != null)
                _changeIcon(node.changeType!, theme),
              // Favorite star
              if (isFavorite)
                Icon(Icons.star, size: 14, color: Colors.amber.shade700),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForNode(FileNode node) {
    if (node.isDirectory) return Icons.folder_outlined;
    return switch (node.fileType) {
      FileType.markdown => Icons.description_outlined,
      FileType.text => Icons.article_outlined,
      FileType.image => Icons.image_outlined,
      FileType.binary => Icons.insert_drive_file_outlined,
    };
  }

  Color _colorForNode(FileNode node, ThemeData theme) {
    if (node.isDirectory) return Colors.amber.shade700;
    return theme.colorScheme.onSurface;
  }

  Widget _changeIcon(FileChangeType changeType, ThemeData theme) {
    final (icon, color) = switch (changeType) {
      FileChangeType.added => (Icons.add_circle_outline, Colors.green),
      FileChangeType.deleted => (Icons.remove_circle_outline, Colors.red),
      FileChangeType.modified => (Icons.edit_outlined, Colors.orange),
    };
    return Icon(icon, size: 14, color: color);
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isFavorite ? Icons.star : Icons.star_outline),
              title: Text(isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              onTap: () {
                Navigator.pop(context);
                onFavoriteToggle?.call();
              },
            ),
            if (node.isDirectory) ...[
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: const Text('New File'),
                onTap: () {
                  Navigator.pop(context);
                  onCreateFile?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: const Text('New Folder'),
                onTap: () {
                  Navigator.pop(context);
                  onCreateFolder?.call();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                onRename?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}
