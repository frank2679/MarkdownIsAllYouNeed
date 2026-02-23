import 'package:flutter/material.dart';
import '../../models/git_status.dart';

class DiffView extends StatelessWidget {
  final FileDiff diff;

  const DiffView({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(diff.originalPath.split('/').last),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Icon(Icons.add, size: 14, color: Colors.green.shade700),
                Text(
                  ' ${diff.additions}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.green.shade700),
                ),
                const SizedBox(width: 12),
                Icon(Icons.remove, size: 14, color: Colors.red.shade700),
                Text(
                  ' ${diff.deletions}',
                  style:
                      TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
      body: diff.hunks.isEmpty
          ? const Center(child: Text('No changes'))
          : ListView.builder(
              itemCount: diff.hunks.length,
              itemBuilder: (_, i) => _HunkWidget(
                hunk: diff.hunks[i],
                theme: theme,
              ),
            ),
    );
  }
}

class _HunkWidget extends StatelessWidget {
  final DiffHunk hunk;
  final ThemeData theme;

  const _HunkWidget({required this.hunk, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hunk header
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            hunk.header,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        // Lines
        ...hunk.lines.map((line) => _DiffLineWidget(line: line, theme: theme)),
      ],
    );
  }
}

class _DiffLineWidget extends StatelessWidget {
  final DiffLine line;
  final ThemeData theme;

  const _DiffLineWidget({required this.line, required this.theme});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, prefix) = switch (line.type) {
      DiffLineType.addition => (
          Colors.green.withAlpha(30),
          Colors.green.shade700,
          '+',
        ),
      DiffLineType.deletion => (
          Colors.red.withAlpha(30),
          Colors.red.shade700,
          '-',
        ),
      DiffLineType.context => (
          Colors.transparent,
          theme.colorScheme.onSurface,
          ' ',
        ),
    };

    return Container(
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Old line number
          SizedBox(
            width: 40,
            child: Text(
              line.oldLineNumber != null ? '${line.oldLineNumber}' : '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // New line number
          SizedBox(
            width: 40,
            child: Text(
              line.newLineNumber != null ? '${line.newLineNumber}' : '',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Prefix +/-/space
          Text(
            prefix,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          // Content
          Expanded(
            child: Text(
              line.content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
