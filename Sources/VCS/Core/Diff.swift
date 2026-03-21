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
        line.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    let linesEqual: (String, String) -> Bool = ignoreWhitespace
        ? { normalizeWhitespace($0) == normalizeWhitespace($1) }
        : { $0 == $1 }

    // Compute LCS using dynamic programming, then derive diff from it
    let n = oldLines.count
    let m = newLines.count

    // Build LCS table
    var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
    for i in 1...max(n, 1) {
        guard i <= n else { break }
        for j in 1...max(m, 1) {
            guard j <= m else { break }
            if linesEqual(oldLines[i - 1], newLines[j - 1]) {
                dp[i][j] = dp[i - 1][j - 1] + 1
            } else {
                dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
            }
        }
    }

    // Backtrack to produce diff
    var result: [DiffLine] = []
    var i = n
    var j = m

    while i > 0 || j > 0 {
        if i > 0 && j > 0 && linesEqual(oldLines[i - 1], newLines[j - 1]) {
            result.append(.context(oldLines[i - 1]))
            i -= 1
            j -= 1
        } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
            result.append(.added(newLines[j - 1]))
            j -= 1
        } else if i > 0 {
            result.append(.removed(oldLines[i - 1]))
            i -= 1
        }
    }

    result.reverse()
    return result
}
