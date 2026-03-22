import Foundation

/// Represents a single line change in a diff.
public enum DiffLine: Equatable {
    case context(String)
    case added(String)
    case removed(String)
}

/// Represents the diff result for a single file.
public enum FileDiff: Equatable {
    case added([DiffLine])
    case removed([DiffLine])
    case modified([DiffLine])
    case binary(oldSize: Int, newSize: Int)
}

/// Represents the complete diff between two commits.
public struct DiffResult {
    public let files: [(path: String, diff: FileDiff)]
}

/// Computes a line-based diff between two strings using Myers' O(ND) diff algorithm.
/// When `ignoreWhitespace` is true, lines that differ only in whitespace are treated as equal.
///
/// Myers' algorithm (Eugene Myers, 1986) finds the shortest edit script (SES) in O(ND) time,
/// where N is the total length of both sequences and D is the number of differences.
/// When D is small (files are similar), this runs in nearly O(N) time.
///
/// Lines are hashed upfront so that comparisons are O(1) integer operations,
/// with a full string comparison fallback to guard against hash collisions.
/// Common prefix and suffix lines are stripped before running the algorithm
/// to further reduce the problem size.
public func computeLineDiff(old: String, new: String, ignoreWhitespace: Bool = false) -> [DiffLine] {
    let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    let normalizeWhitespace: (String) -> String = { line in
        line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    // Pre-compute hashes for each line so comparisons are O(1).
    let oldHashes: [Int]
    let newHashes: [Int]

    if ignoreWhitespace {
        oldHashes = oldLines.map { normalizeWhitespace($0).hashValue }
        newHashes = newLines.map { normalizeWhitespace($0).hashValue }
    } else {
        oldHashes = oldLines.map { $0.hashValue }
        newHashes = newLines.map { $0.hashValue }
    }

    // Compare two lines by index: first by hash (O(1)), then by full string on hash match.
    let linesEqual: (Int, Int) -> Bool
    if ignoreWhitespace {
        linesEqual = { (i: Int, j: Int) -> Bool in
            oldHashes[i] == newHashes[j]
                && normalizeWhitespace(oldLines[i]) == normalizeWhitespace(newLines[j])
        }
    } else {
        linesEqual = { (i: Int, j: Int) -> Bool in
            oldHashes[i] == newHashes[j] && oldLines[i] == newLines[j]
        }
    }

    // Strip common prefix lines to reduce the problem size
    var prefixLen = 0
    while prefixLen < oldLines.count && prefixLen < newLines.count
        && linesEqual(prefixLen, prefixLen) {
        prefixLen += 1
    }

    // Strip common suffix lines (after the prefix)
    var suffixLen = 0
    while suffixLen < (oldLines.count - prefixLen) && suffixLen < (newLines.count - prefixLen)
        && linesEqual(oldLines.count - 1 - suffixLen, newLines.count - 1 - suffixLen) {
        suffixLen += 1
    }

    // Extract the middle slices that actually differ
    let oldMiddle = Array(oldLines[prefixLen..<(oldLines.count - suffixLen)])
    let newMiddle = Array(newLines[prefixLen..<(newLines.count - suffixLen)])
    let oldMiddleHashes = Array(oldHashes[prefixLen..<(oldHashes.count - suffixLen)])
    let newMiddleHashes = Array(newHashes[prefixLen..<(newHashes.count - suffixLen)])

    // Compare middle lines by index into the middle arrays
    let middleLinesEqual: (Int, Int) -> Bool
    if ignoreWhitespace {
        middleLinesEqual = { (i: Int, j: Int) -> Bool in
            oldMiddleHashes[i] == newMiddleHashes[j]
                && normalizeWhitespace(oldMiddle[i]) == normalizeWhitespace(newMiddle[j])
        }
    } else {
        middleLinesEqual = { (i: Int, j: Int) -> Bool in
            oldMiddleHashes[i] == newMiddleHashes[j] && oldMiddle[i] == newMiddle[j]
        }
    }

    let n = oldMiddle.count
    let m = newMiddle.count
    let maxD = n + m

    // Build prefix context
    var result: [DiffLine] = []
    for k in 0..<prefixLen {
        result.append(.context(oldLines[k]))
    }

    guard maxD > 0 else {
        // Append suffix context and return
        for k in 0..<suffixLen {
            result.append(.context(oldLines[oldLines.count - suffixLen + k]))
        }
        return result
    }

    // Myers' diff: forward pass
    // V[k] = furthest x on diagonal k (where k = x - y)
    let vOffset = maxD
    let vSize = 2 * maxD + 1
    var v = Array(repeating: 0, count: vSize)

    // Store a snapshot of V after each d iteration for backtracking
    var trace: [[Int]] = []

    var shortestD = 0
    outer: for d in 0...maxD {
        trace.append(v)

        for k in stride(from: -d, through: d, by: 2) {
            var x: Int
            if k == -d || (k != d && v[k - 1 + vOffset] < v[k + 1 + vOffset]) {
                x = v[k + 1 + vOffset]       // move down (insert)
            } else {
                x = v[k - 1 + vOffset] + 1   // move right (delete)
            }
            var y = x - k

            // Follow diagonal (snake): matching lines
            while x < n && y < m && middleLinesEqual(x, y) {
                x += 1
                y += 1
            }

            v[k + vOffset] = x

            if x >= n && y >= m {
                shortestD = d
                break outer
            }
        }
    }

    // Backtrack to find the sequence of snakes.
    var snakes: [(startX: Int, startY: Int, endX: Int, endY: Int)] = []
    var bx = n
    var by = m

    for d in stride(from: shortestD, to: 0, by: -1) {
        let vSnap = trace[d]
        let k = bx - by

        let prevK: Int
        if k == -d || (k != d && vSnap[k - 1 + vOffset] < vSnap[k + 1 + vOffset]) {
            prevK = k + 1   // came from diagonal k+1 (insert/down)
        } else {
            prevK = k - 1   // came from diagonal k-1 (delete/right)
        }

        let prevEndX = vSnap[prevK + vOffset]
        let prevEndY = prevEndX - prevK

        let snakeStartX: Int
        let snakeStartY: Int
        if prevK == k + 1 {
            snakeStartX = prevEndX
            snakeStartY = prevEndY + 1
        } else {
            snakeStartX = prevEndX + 1
            snakeStartY = prevEndY
        }

        snakes.append((startX: snakeStartX, startY: snakeStartY, endX: bx, endY: by))

        bx = prevEndX
        by = prevEndY
    }

    // Add the d=0 snake
    snakes.append((startX: 0, startY: 0, endX: bx, endY: by))
    snakes.reverse()

    // Emit edits and context from snakes
    for (i, snake) in snakes.enumerated() {
        if i > 0 {
            let prevEnd = snakes[i - 1]
            let dx = snake.startX - prevEnd.endX
            let dy = snake.startY - prevEnd.endY

            if dx == 1 && dy == 0 {
                result.append(.removed(oldMiddle[prevEnd.endX]))
            } else if dx == 0 && dy == 1 {
                result.append(.added(newMiddle[prevEnd.endY]))
            }
        }

        var sx = snake.startX
        var sy = snake.startY
        while sx < snake.endX && sy < snake.endY {
            result.append(.context(oldMiddle[sx]))
            sx += 1
            sy += 1
        }
    }

    // Append suffix context
    for k in 0..<suffixLen {
        result.append(.context(oldLines[oldLines.count - suffixLen + k]))
    }

    return result
}
