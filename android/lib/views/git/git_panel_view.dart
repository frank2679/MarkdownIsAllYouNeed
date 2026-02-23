import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/git_status.dart';
import '../../models/repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/file_tree_provider.dart';
import '../../services/git_service.dart';
import 'diff_view.dart';
import 'sync_state_indicator.dart';

class GitPanelView extends StatefulWidget {
  final Repository repo;

  const GitPanelView({super.key, required this.repo});

  @override
  State<GitPanelView> createState() => _GitPanelViewState();
}

class _GitPanelViewState extends State<GitPanelView> {
  final _commitController = TextEditingController();
  bool _isWorking = false;
  String? _workMessage;

  @override
  void dispose() {
    _commitController.dispose();
    super.dispose();
  }

  Future<void> _pull() async {
    final fileTree = context.read<FileTreeProvider>();
    setState(() {
      _isWorking = true;
      _workMessage = 'Pulling...';
    });
    try {
      final result = await fileTree.pull();
      if (mounted) {
        final msg = switch (result) {
          PullResultUpToDate() => 'Already up to date',
          PullResultUpdated(filesChanged: final n) =>
            'Updated $n file${n == 1 ? '' : 's'}',
          PullResultConflicts(files: final f) =>
            'Conflicts in ${f.length} file${f.length == 1 ? '' : 's'}',
        };
        _showSnack(msg);
      }
    } catch (e) {
      if (mounted) _showSnack('Pull failed: $e', isError: true);
    }
    if (mounted) setState(() => _isWorking = false);
  }

  Future<void> _commit({bool force = false}) async {
    final msg = _commitController.text.trim();
    if (msg.isEmpty) {
      _showSnack('Enter a commit message', isError: true);
      return;
    }

    final fileTree = context.read<FileTreeProvider>();
    final auth = context.read<AuthProvider>();
    final token = await auth.token;
    if (token == null) return;

    final selected =
        fileTree.changes.where((c) => c.isSelected).toList();
    if (selected.isEmpty) {
      _showSnack('No files selected', isError: true);
      return;
    }

    setState(() {
      _isWorking = true;
      _workMessage = 'Committing...';
    });

    try {
      await GitService.shared.commitAndPush(
        repo: widget.repo,
        changes: selected,
        message: msg,
        token: token,
        force: force,
      );
      _commitController.clear();
      await fileTree.refresh();
      await fileTree.checkSyncState();
      if (mounted) _showSnack('Pushed successfully');
    } on GitError catch (e) {
      if (e.isConflict && !force && mounted) {
        _showForceDialog();
      } else if (mounted) {
        _showSnack(e.message, isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Push failed: $e', isError: true);
    }

    if (mounted) setState(() => _isWorking = false);
  }

  void _showForceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Force Push?'),
        content: const Text(
            'Remote has new commits. Force pushing will overwrite remote history. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(context);
              _commit(force: true);
            },
            child: const Text('Force Push'),
          ),
        ],
      ),
    );
  }

  Future<void> _discard(FileChange change) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: Text(
            'Discard all changes to "${change.path.split('/').last}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await context.read<FileTreeProvider>().discardChanges(change);
    } catch (e) {
      if (mounted) _showSnack('Discard failed: $e', isError: true);
    }
  }

  Future<void> _openDiff(FileChange change) async {
    final auth = context.read<AuthProvider>();
    final token = await auth.token;
    if (token == null) return;

    final diff = await GitService.shared.diffAsync(
      path: change.path,
      repo: widget.repo,
      token: token,
    );

    if (!mounted) return;
    if (diff == null) {
      _showSnack('Cannot compute diff for this file');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DiffView(diff: diff)),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Theme.of(context).colorScheme.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fileTree = context.watch<FileTreeProvider>();
    final changes = fileTree.changes;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Changes'),
        actions: [
          // Sync state
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: SyncStateIndicator(state: fileTree.syncState),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Pull',
            onPressed: _isWorking ? null : _pull,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isWorking
                ? null
                : () async {
                    await fileTree.refresh();
                    await fileTree.checkSyncState();
                  },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Branch info
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.surfaceContainerLow,
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      widget.repo.defaultBranch,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Changed files
              Expanded(
                child: changes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 8),
                            Text(
                              'No changes',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: changes.length,
                        itemBuilder: (_, i) => _changeRow(changes[i], theme),
                      ),
              ),
              // Commit area
              if (changes.isNotEmpty)
                _CommitArea(
                  controller: _commitController,
                  onCommit: _isWorking ? null : () => _commit(),
                  isWorking: _isWorking,
                  workMessage: _workMessage ?? '',
                ),
            ],
          ),
          if (_isWorking)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(_workMessage ?? ''),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _changeRow(FileChange change, ThemeData theme) {
    final (icon, color) = switch (change.changeType) {
      FileChangeType.added => (Icons.add_circle_outline, Colors.green),
      FileChangeType.deleted => (Icons.remove_circle_outline, Colors.red),
      FileChangeType.modified => (Icons.edit_outlined, Colors.orange),
    };

    return Dismissible(
      key: ValueKey('change-${change.path}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.orange,
        child: const Icon(Icons.undo, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _discard(change);
        return false; // Let the provider handle list update
      },
      child: ListTile(
        leading: Checkbox(
          value: change.isSelected,
          onChanged: (v) {
            change.isSelected = v ?? false;
            (context as Element).markNeedsBuild();
          },
        ),
        title: Text(
          change.path.split('/').last,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          change.path,
          style: theme.textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(icon, color: color),
        onTap: change.changeType != FileChangeType.added
            ? () => _openDiff(change)
            : null,
      ),
    );
  }
}

class _CommitArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onCommit;
  final bool isWorking;
  final String workMessage;

  const _CommitArea({
    required this.controller,
    required this.onCommit,
    required this.isWorking,
    required this.workMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Commit message...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onCommit,
            child: const Text('Push'),
          ),
        ],
      ),
    );
  }
}
