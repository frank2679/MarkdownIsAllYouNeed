import Foundation

/// Myers diff algorithm for computing line-level diffs between two strings.
enum DiffEngine {

    /// Compute a FileDiff between original and modified text.
    /// - Parameters:
    ///   - original: The original file content
    ///   - modified: The modified file content
    ///   - path: File path for display
    ///   - contextLines: Number of context lines around each change (default 3)
    /// - Returns: A FileDiff with hunks, additions, and deletions
    static func diff(original: String, modified: String, path: String, contextLines: Int = 3) -> FileDiff {
        let oldLines = original.components(separatedBy: "\n")
        let newLines = modified.components(separatedBy: "\n")

        let editScript = computeEditScript(old: oldLines, new: newLines)
        let hunks = buildHunks(editScript: editScript, oldLines: oldLines, newLines: newLines, contextLines: contextLines)

        var totalAdditions = 0
        var totalDeletions = 0
        for hunk in hunks {
            for line in hunk.lines {
                switch line.type {
                case .addition: totalAdditions += 1
                case .deletion: totalDeletions += 1
                case .context: break
                }
            }
        }

        return FileDiff(
            originalPath: path,
            modifiedPath: path,
            hunks: hunks,
            additions: totalAdditions,
            deletions: totalDeletions
        )
    }

    // MARK: - Myers Diff Algorithm

    private enum EditOp {
        case equal(oldIdx: Int, newIdx: Int)
        case insert(newIdx: Int)
        case delete(oldIdx: Int)
    }

    private static func computeEditScript(old: [String], new: [String]) -> [EditOp] {
        let n = old.count
        let m = new.count
        let max = n + m

        if max == 0 { return [] }

        // V array indexed from -max to max; we use offset of max
        var v = Array(repeating: 0, count: 2 * max + 1)
        var trace: [[Int]] = []

        outer: for d in 0...max {
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                let idx = k + max
                var x: Int
                if d == 0 {
                    x = 0
                } else if k == -d || (k != d && v[idx - 1] < v[idx + 1]) {
                    x = v[idx + 1]
                } else {
                    x = v[idx - 1] + 1
                }
                var y = x - k

                while x < n && y < m && old[x] == new[y] {
                    x += 1
                    y += 1
                }

                v[idx] = x

                if x >= n && y >= m {
                    break outer
                }
            }
        }

        // Backtrack to build edit script
        var ops: [EditOp] = []
        var x = n
        var y = m

        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let v = trace[d]
            let k = x - y

            var prevK: Int
            if d == 0 {
                // At d=0, we only had k=0, just add remaining equals
                break
            } else if k == -d || (k != d && v[k - 1 + max] < v[k + 1 + max]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }

            let prevX = v[prevK + max]
            let prevY = prevX - prevK

            // Diagonal (equals)
            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                ops.append(.equal(oldIdx: x, newIdx: y))
            }

            if d > 0 {
                if x == prevX {
                    // Insert
                    y -= 1
                    ops.append(.insert(newIdx: y))
                } else {
                    // Delete
                    x -= 1
                    ops.append(.delete(oldIdx: x))
                }
            }
        }

        // Handle remaining equal lines at the start
        while x > 0 && y > 0 {
            x -= 1
            y -= 1
            ops.append(.equal(oldIdx: x, newIdx: y))
        }

        return ops.reversed()
    }

    // MARK: - Hunk Building

    private static func buildHunks(editScript: [EditOp], oldLines: [String], newLines: [String], contextLines: Int) -> [DiffHunk] {
        // Find ranges of changes
        var changeIndices: [Int] = []
        for (i, op) in editScript.enumerated() {
            switch op {
            case .insert, .delete:
                changeIndices.append(i)
            case .equal:
                break
            }
        }

        if changeIndices.isEmpty { return [] }

        // Group changes that are within contextLines*2 of each other
        var groups: [[Int]] = []
        var currentGroup: [Int] = [changeIndices[0]]

        for i in 1..<changeIndices.count {
            let gap = changeIndices[i] - changeIndices[i - 1]
            if gap <= contextLines * 2 + 1 {
                currentGroup.append(changeIndices[i])
            } else {
                groups.append(currentGroup)
                currentGroup = [changeIndices[i]]
            }
        }
        groups.append(currentGroup)

        // Build hunks from groups
        var hunks: [DiffHunk] = []

        for group in groups {
            let firstChange = group.first!
            let lastChange = group.last!

            let startIdx = Swift.max(0, firstChange - contextLines)
            let endIdx = Swift.min(editScript.count - 1, lastChange + contextLines)

            var lines: [DiffLine] = []
            var oldLineNum = 0
            var newLineNum = 0

            // Calculate starting line numbers
            for i in 0..<startIdx {
                switch editScript[i] {
                case .equal:
                    oldLineNum += 1
                    newLineNum += 1
                case .delete:
                    oldLineNum += 1
                case .insert:
                    newLineNum += 1
                }
            }

            let hunkOldStart = oldLineNum + 1
            let hunkNewStart = newLineNum + 1

            for i in startIdx...endIdx {
                switch editScript[i] {
                case .equal(let oldIdx, _):
                    oldLineNum += 1
                    newLineNum += 1
                    lines.append(DiffLine(
                        type: .context,
                        content: oldLines[oldIdx],
                        oldLineNumber: oldLineNum,
                        newLineNumber: newLineNum
                    ))
                case .delete(let oldIdx):
                    oldLineNum += 1
                    lines.append(DiffLine(
                        type: .deletion,
                        content: oldLines[oldIdx],
                        oldLineNumber: oldLineNum,
                        newLineNumber: nil
                    ))
                case .insert(let newIdx):
                    newLineNum += 1
                    lines.append(DiffLine(
                        type: .addition,
                        content: newLines[newIdx],
                        oldLineNumber: nil,
                        newLineNumber: newLineNum
                    ))
                }
            }

            let hunkOldCount = oldLineNum - hunkOldStart + 1
            let hunkNewCount = newLineNum - hunkNewStart + 1

            hunks.append(DiffHunk(
                oldStart: hunkOldStart,
                oldCount: hunkOldCount,
                newStart: hunkNewStart,
                newCount: hunkNewCount,
                lines: lines
            ))
        }

        return hunks
    }
}
