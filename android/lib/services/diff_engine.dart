import '../models/git_status.dart';

/// Myers diff algorithm — ported from Swift DiffEngine.
class DiffEngine {
  static FileDiff diff({
    required String original,
    required String modified,
    required String path,
    int contextLines = 3,
  }) {
    final oldLines = original.split('\n');
    final newLines = modified.split('\n');

    final editScript = _computeEditScript(oldLines, newLines);
    final hunks = _buildHunks(
      editScript: editScript,
      oldLines: oldLines,
      newLines: newLines,
      contextLines: contextLines,
    );

    var totalAdditions = 0;
    var totalDeletions = 0;
    for (final hunk in hunks) {
      for (final line in hunk.lines) {
        if (line.type == DiffLineType.addition) totalAdditions++;
        if (line.type == DiffLineType.deletion) totalDeletions++;
      }
    }

    return FileDiff(
      originalPath: path,
      modifiedPath: path,
      hunks: hunks,
      additions: totalAdditions,
      deletions: totalDeletions,
    );
  }

  // MARK: - Myers Diff

  static List<_EditOp> _computeEditScript(List<String> old, List<String> newL) {
    final n = old.length;
    final m = newL.length;
    final maxD = n + m;

    if (maxD == 0) return [];

    // V indexed from -maxD to maxD, offset by maxD
    final v = List<int>.filled(2 * maxD + 1, 0);
    final trace = <List<int>>[];

    outer:
    for (var d = 0; d <= maxD; d++) {
      trace.add(List<int>.from(v));
      for (var k = -d; k <= d; k += 2) {
        final idx = k + maxD;
        int x;
        if (d == 0) {
          x = 0;
        } else if (k == -d || (k != d && v[idx - 1] < v[idx + 1])) {
          x = v[idx + 1];
        } else {
          x = v[idx - 1] + 1;
        }
        var y = x - k;

        while (x < n && y < m && old[x] == newL[y]) {
          x++;
          y++;
        }

        v[idx] = x;

        if (x >= n && y >= m) break outer;
      }
    }

    // Backtrack
    final ops = <_EditOp>[];
    var x = n;
    var y = m;

    for (var d = trace.length - 1; d >= 0; d--) {
      final tv = trace[d];
      final k = x - y;

      int prevK;
      if (d == 0) break;
      if (k == -d || (k != d && tv[k - 1 + maxD] < tv[k + 1 + maxD])) {
        prevK = k + 1;
      } else {
        prevK = k - 1;
      }

      final prevX = tv[prevK + maxD];
      final prevY = prevX - prevK;

      while (x > prevX && y > prevY) {
        x--;
        y--;
        ops.add(_EditOpEqual(x, y));
      }

      if (d > 0) {
        if (x == prevX) {
          y--;
          ops.add(_EditOpInsert(y));
        } else {
          x--;
          ops.add(_EditOpDelete(x));
        }
      }
    }

    while (x > 0 && y > 0) {
      x--;
      y--;
      ops.add(_EditOpEqual(x, y));
    }

    return ops.reversed.toList();
  }

  static List<DiffHunk> _buildHunks({
    required List<_EditOp> editScript,
    required List<String> oldLines,
    required List<String> newLines,
    required int contextLines,
  }) {
    final changeIndices = <int>[];
    for (var i = 0; i < editScript.length; i++) {
      final op = editScript[i];
      if (op is _EditOpInsert || op is _EditOpDelete) {
        changeIndices.add(i);
      }
    }

    if (changeIndices.isEmpty) return [];

    // Group nearby changes
    final groups = <List<int>>[];
    var currentGroup = [changeIndices[0]];

    for (var i = 1; i < changeIndices.length; i++) {
      if (changeIndices[i] - changeIndices[i - 1] <= contextLines * 2 + 1) {
        currentGroup.add(changeIndices[i]);
      } else {
        groups.add(currentGroup);
        currentGroup = [changeIndices[i]];
      }
    }
    groups.add(currentGroup);

    final hunks = <DiffHunk>[];

    for (final group in groups) {
      final firstChange = group.first;
      final lastChange = group.last;

      final startIdx = (firstChange - contextLines).clamp(0, editScript.length - 1);
      final endIdx = (lastChange + contextLines).clamp(0, editScript.length - 1);

      final lines = <DiffLine>[];
      var oldLineNum = 0;
      var newLineNum = 0;

      for (var i = 0; i < startIdx; i++) {
        final op = editScript[i];
        if (op is _EditOpEqual) {
          oldLineNum++;
          newLineNum++;
        } else if (op is _EditOpDelete) {
          oldLineNum++;
        } else if (op is _EditOpInsert) {
          newLineNum++;
        }
      }

      final hunkOldStart = oldLineNum + 1;
      final hunkNewStart = newLineNum + 1;

      for (var i = startIdx; i <= endIdx; i++) {
        final op = editScript[i];
        if (op is _EditOpEqual) {
          oldLineNum++;
          newLineNum++;
          lines.add(DiffLine(
            type: DiffLineType.context,
            content: oldLines[op.oldIdx],
            oldLineNumber: oldLineNum,
            newLineNumber: newLineNum,
          ));
        } else if (op is _EditOpDelete) {
          oldLineNum++;
          lines.add(DiffLine(
            type: DiffLineType.deletion,
            content: oldLines[op.oldIdx],
            oldLineNumber: oldLineNum,
          ));
        } else if (op is _EditOpInsert) {
          newLineNum++;
          lines.add(DiffLine(
            type: DiffLineType.addition,
            content: newLines[op.newIdx],
            newLineNumber: newLineNum,
          ));
        }
      }

      hunks.add(DiffHunk(
        oldStart: hunkOldStart,
        oldCount: oldLineNum - hunkOldStart + 1,
        newStart: hunkNewStart,
        newCount: newLineNum - hunkNewStart + 1,
        lines: lines,
      ));
    }

    return hunks;
  }
}

// MARK: - Internal edit op types

sealed class _EditOp {}

class _EditOpEqual extends _EditOp {
  final int oldIdx;
  final int newIdx;
  _EditOpEqual(this.oldIdx, this.newIdx);
}

class _EditOpInsert extends _EditOp {
  final int newIdx;
  _EditOpInsert(this.newIdx);
}

class _EditOpDelete extends _EditOp {
  final int oldIdx;
  _EditOpDelete(this.oldIdx);
}
