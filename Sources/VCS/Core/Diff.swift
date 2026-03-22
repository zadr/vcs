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

/// Computes a line-based diff between two strings using LCS (Longest Common Subsequence) dynamic programming.
/// When `ignoreWhitespace` is true, lines that differ only in whitespace are treated as equal.
///
/// Lines are hashed upfront so that the DP loop performs O(1) integer comparisons
/// instead of O(line-length) string comparisons. A full string comparison is used as
/// a fallback when hashes match to guard against hash collisions.
public func computeLineDiff(old: String, new: String, ignoreWhitespace: Bool = false) -> [DiffLine] {
    let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    let normalizeWhitespace: (String) -> String = { line in
        line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    // Pre-compute hashes for each line so comparisons in the DP loop are O(1).
    // When ignoreWhitespace is true, hash the normalized form of the line.
    let oldHashes: [Int]
    let newHashes: [Int]

    if ignoreWhitespace {
        oldHashes = oldLines.map { normalizeWhitespace($0).hashValue }
        newHashes = newLines.map { normalizeWhitespace($0).hashValue }
    } else {
        oldHashes = oldLines.map { $0.hashValue }
        newHashes = newLines.map { $0.hashValue }
    }

    // Compare two lines by index: first by hash (O(1)), then by full string on hash match
    // to handle potential collisions.
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

    // Strip common prefix lines to reduce the problem size for the DP algorithm
    var prefixLen = 0
    while prefixLen < oldLines.count && prefixLen < newLines.count
        && linesEqual(prefixLen, prefixLen) {
        prefixLen += 1
    }

    // Strip common suffix lines (after the prefix) to further reduce the problem size
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

    // Compute LCS using dynamic programming on the middle section only
    let n = oldMiddle.count
    let m = newMiddle.count

    // Build LCS table
    var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
    for i in 1...max(n, 1) {
        guard i <= n else { break }
        for j in 1...max(m, 1) {
            guard j <= m else { break }
            if middleLinesEqual(i - 1, j - 1) {
                dp[i][j] = dp[i - 1][j - 1] + 1
            } else {
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
            }
        }
    }

    // Backtrack to produce diff for the middle section
    var middleResult: [DiffLine] = []
    var i = n
    var j = m

    while i > 0 || j > 0 {
        if i > 0 && j > 0 && middleLinesEqual(i - 1, j - 1) {
            middleResult.append(.context(oldMiddle[i - 1]))
            i -= 1
            j -= 1
        } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
            middleResult.append(.added(newMiddle[j - 1]))
            j -= 1
        } else if i > 0 {
            middleResult.append(.removed(oldMiddle[i - 1]))
            i -= 1
        }
    }

    middleResult.reverse()

    // Reconstruct full result: prefix context + middle diff + suffix context
    var result: [DiffLine] = []
    for k in 0..<prefixLen {
        result.append(.context(oldLines[k]))
    }
    result.append(contentsOf: middleResult)
    for k in 0..<suffixLen {
        result.append(.context(oldLines[oldLines.count - suffixLen + k]))
    }

    return result
}
