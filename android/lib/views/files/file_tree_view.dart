import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_node.dart';
import '../../models/repository.dart';
import '../../providers/file_tree_provider.dart';
import '../editor/markdown_editor_screen.dart';
import '../git/git_panel_view.dart';
import '../git/sync_state_indicator.dart';
import 'binary_file_view.dart';
import 'file_node_row.dart';
import 'image_preview_view.dart';
import 'text_file_view.dart';

class FileTreeView extends StatefulWidget {
  final Repository repo;

  const FileTreeView({super.key, required this.repo});

  @override
  State<FileTreeView> createState() => _FileTreeViewState();
}

class _FileTreeViewState extends State<FileTreeView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileTree = context.watch<FileTreeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.repo.name),
            SyncStateIndicator(state: fileTree.syncState),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Git',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: fileTree,
                  child: GitPanelView(repo: widget.repo),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await fileTree.refresh();
              await fileTree.checkSyncState();
            },
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'new_file',
                child: ListTile(
                  leading: Icon(Icons.note_add_outlined),
                  title: Text('New File'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'new_folder',
                child: ListTile(
                  leading: Icon(Icons.create_new_folder_outlined),
                  title: Text('New Folder'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (v) async {
              final localPath = await widget.repo.localPath;
              if (v == 'new_file') {
                _showCreateDialog(context, fileTree, localPath, isFile: true);
              } else if (v == 'new_folder') {
                _showCreateDialog(context, fileTree, localPath, isFile: false);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Files'),
            Tab(text: 'Favorites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FilesList(
            repo: widget.repo,
            nodes: fileTree.nodes,
            recentPaths: fileTree.recentPaths,
            fileTree: fileTree,
          ),
          _FavoritesList(
            repo: widget.repo,
            favoritePaths: fileTree.favoritePaths.toList(),
            fileTree: fileTree,
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(
    BuildContext context,
    FileTreeProvider fileTree,
    String parentPath, {
    required bool isFile,
  }) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isFile ? 'New File' : 'New Folder'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isFile ? 'filename.md' : 'folder name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              if (isFile) {
                await fileTree.createFile(name, parentPath);
              } else {
                await fileTree.createDirectory(name, parentPath);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// MARK: - Files list tab

class _FilesList extends StatefulWidget {
  final Repository repo;
  final List<FileNode> nodes;
  final List<String> recentPaths;
  final FileTreeProvider fileTree;

  const _FilesList({
    required this.repo,
    required this.nodes,
    required this.recentPaths,
    required this.fileTree,
  });

  @override
  State<_FilesList> createState() => _FilesListState();
}

class _FilesListState extends State<_FilesList> {
  final Map<String, bool> _expanded = {};

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _flattenNodes(widget.nodes, 0);

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (node, depth) = items[i];
        return _buildRow(context, node, depth);
      },
    );
  }

  List<(FileNode, int)> _flattenNodes(List<FileNode> nodes, int depth) {
    final result = <(FileNode, int)>[];
    for (final node in nodes) {
      result.add((node, depth));
      if (node.isDirectory &&
          (_expanded[node.path] ?? false) &&
          node.children != null) {
        result.addAll(_flattenNodes(node.children!, depth + 1));
      }
    }
    return result;
  }

  Widget _buildRow(BuildContext context, FileNode node, int depth) {
    return FileNodeRow(
      key: ValueKey(node.path),
      node: node,
      depth: depth,
      isFavorite: widget.fileTree.isFavorite(node.path),
      onTap: () => _openFile(context, node),
      onToggleExpand: () {
        setState(() {
          _expanded[node.path] = !(_expanded[node.path] ?? false);
          node.isExpanded = _expanded[node.path]!;
        });
      },
      onFavoriteToggle: () => widget.fileTree.toggleFavorite(node.path),
      onDelete: () => _confirmDelete(context, node),
      onRename: () => _showRenameDialog(context, node),
      onCreateFile: node.isDirectory
          ? () => _showCreateDialog(context, node.path, isFile: true)
          : null,
      onCreateFolder: node.isDirectory
          ? () => _showCreateDialog(context, node.path, isFile: false)
          : null,
    );
  }

  Future<void> _openFile(BuildContext context, FileNode node) async {
    if (node.isDirectory) return;
    final localPath = await widget.repo.localPath;
    final fullPath = '$localPath/${node.path}';
    widget.fileTree.recordRecent(node.path);

    if (!mounted) return;
    Widget view;
    switch (node.fileType) {
      case FileType.markdown:
        view = ChangeNotifierProvider.value(
          value: widget.fileTree,
          child: MarkdownEditorScreen(
            filePath: fullPath,
            relativePath: node.path,
          ),
        );
      case FileType.text:
        view = ChangeNotifierProvider.value(
          value: widget.fileTree,
          child: TextFileView(
            filePath: fullPath,
            relativePath: node.path,
            fileType: node.fileType,
          ),
        );
      case FileType.image:
        view = ImagePreviewView(filePath: fullPath);
      case FileType.binary:
        view = BinaryFileView(filePath: fullPath);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => view));
  }

  void _confirmDelete(BuildContext context, FileNode node) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete?'),
        content: Text(
            'Delete "${node.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(context);
              final localPath = await widget.repo.localPath;
              await widget.fileTree.delete('$localPath/${node.path}');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, FileNode node) {
    final ctrl = TextEditingController(text: node.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty || newName == node.name) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context);
              final localPath = await widget.repo.localPath;
              await widget.fileTree.rename(
                  '$localPath/${node.path}', newName);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, String parentRelPath,
      {required bool isFile}) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isFile ? 'New File' : 'New Folder'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
              hintText: isFile ? 'filename.md' : 'folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              final localPath = await widget.repo.localPath;
              final fullParent = '$localPath/$parentRelPath';
              if (isFile) {
                await widget.fileTree.createFile(name, fullParent);
              } else {
                await widget.fileTree.createDirectory(name, fullParent);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// MARK: - Favorites tab

class _FavoritesList extends StatelessWidget {
  final Repository repo;
  final List<String> favoritePaths;
  final FileTreeProvider fileTree;

  const _FavoritesList({
    required this.repo,
    required this.favoritePaths,
    required this.fileTree,
  });

  @override
  Widget build(BuildContext context) {
    if (favoritePaths.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_outline,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            const Text('No favorites yet'),
            const SizedBox(height: 4),
            Text(
              'Long-press a file to add it',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: favoritePaths.length,
      itemBuilder: (_, i) {
        final rel = favoritePaths[i];
        return ListTile(
          leading: const Icon(Icons.star, color: Colors.amber),
          title: Text(rel.split('/').last),
          subtitle: Text(rel),
          onTap: () => _openFavorite(context, rel),
        );
      },
    );
  }

  Future<void> _openFavorite(BuildContext context, String relPath) async {
    final localPath = await repo.localPath;
    final fullPath = '$localPath/$relPath';
    if (!File(fullPath).existsSync()) return;

    final fileType = FileTypeDetector.detect(relPath.split('/').last);
    fileTree.recordRecent(relPath);

    if (!context.mounted) return;
    Widget view;
    switch (fileType) {
      case FileType.markdown:
        view = ChangeNotifierProvider.value(
          value: fileTree,
          child: MarkdownEditorScreen(
            filePath: fullPath,
            relativePath: relPath,
          ),
        );
      case FileType.text:
        view = ChangeNotifierProvider.value(
          value: fileTree,
          child: TextFileView(
            filePath: fullPath,
            relativePath: relPath,
            fileType: fileType,
          ),
        );
      case FileType.image:
        view = ImagePreviewView(filePath: fullPath);
      case FileType.binary:
        view = BinaryFileView(filePath: fullPath);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => view));
  }
}
