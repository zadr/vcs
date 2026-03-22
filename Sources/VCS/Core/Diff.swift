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
public func computeLineDiff(old: String, new: String, ignoreWhitespace: Bool = false) -> [DiffLine] {
    let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    let normalizeWhitespace: (String) -> String = { line in
        line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    let linesEqual: (String, String) -> Bool = ignoreWhitespace
        ? { normalizeWhitespace($0) == normalizeWhitespace($1) }
        : { $0 == $1 }

    // Strip common prefix lines to reduce the problem size for the DP algorithm
    var prefixLen = 0
    while prefixLen < oldLines.count && prefixLen < newLines.count
        && linesEqual(oldLines[prefixLen], newLines[prefixLen]) {
        prefixLen += 1
    }

    // Strip common suffix lines (after the prefix) to further reduce the problem size
    var suffixLen = 0
    while suffixLen < (oldLines.count - prefixLen) && suffixLen < (newLines.count - prefixLen)
        && linesEqual(oldLines[oldLines.count - 1 - suffixLen], newLines[newLines.count - 1 - suffixLen]) {
        suffixLen += 1
    }

    // Extract the middle slices that actually differ
    let oldMiddle = Array(oldLines[prefixLen..<(oldLines.count - suffixLen)])
    let newMiddle = Array(newLines[prefixLen..<(newLines.count - suffixLen)])

    // Compute LCS using dynamic programming on the middle section only
    let n = oldMiddle.count
    let m = newMiddle.count

    // Build LCS table
    var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
    for i in 1...max(n, 1) {
        guard i <= n else { break }
        for j in 1...max(m, 1) {
            guard j <= m else { break }
            if linesEqual(oldMiddle[i - 1], newMiddle[j - 1]) {
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
        if i > 0 && j > 0 && linesEqual(oldMiddle[i - 1], newMiddle[j - 1]) {
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
