import XCTest
@testable import VCS

// MARK: - computeLineDiff Unit Tests

final class DiffLineTests: XCTestCase {

    // MARK: - Identical Content

    func testDiffIdenticalStringsReturnsAllContext() {
        let text = "line1\nline2\nline3"
        let result = computeLineDiff(old: text, new: text)
        XCTAssertEqual(result, [
            .context("line1"),
            .context("line2"),
            .context("line3"),
        ])
    }

    func testDiffBothEmptyReturnsContextForEmptyLine() {
        let result = computeLineDiff(old: "", new: "")
        XCTAssertEqual(result, [.context("")])
    }

    // MARK: - Additions

    func testDiffAddedLineAtEnd() {
        let result = computeLineDiff(old: "line1\nline2", new: "line1\nline2\nline3")
        XCTAssertEqual(result, [
            .context("line1"),
            .context("line2"),
            .added("line3"),
        ])
    }

    func testDiffAddedLineAtBeginning() {
        let result = computeLineDiff(old: "line2\nline3", new: "line1\nline2\nline3")
        XCTAssertEqual(result, [
            .added("line1"),
            .context("line2"),
            .context("line3"),
        ])
    }

    func testDiffAddedLineInMiddle() {
        let result = computeLineDiff(old: "line1\nline3", new: "line1\nline2\nline3")
        XCTAssertEqual(result, [
            .context("line1"),
            .added("line2"),
            .context("line3"),
        ])
    }

    func testDiffFromEmptyToContent() {
        let result = computeLineDiff(old: "", new: "line1\nline2")
        XCTAssertTrue(result.contains(.added("line1")))
        XCTAssertTrue(result.contains(.added("line2")))
    }

    // MARK: - Removals

    func testDiffRemovedLineAtEnd() {
        let result = computeLineDiff(old: "line1\nline2\nline3", new: "line1\nline2")
        XCTAssertEqual(result, [
            .context("line1"),
            .context("line2"),
            .removed("line3"),
        ])
    }

    func testDiffRemovedLineAtBeginning() {
        let result = computeLineDiff(old: "line1\nline2\nline3", new: "line2\nline3")
        XCTAssertEqual(result, [
            .removed("line1"),
            .context("line2"),
            .context("line3"),
        ])
    }

    func testDiffFromContentToEmpty() {
        let result = computeLineDiff(old: "line1\nline2", new: "")
        XCTAssertTrue(result.contains(.removed("line1")))
        XCTAssertTrue(result.contains(.removed("line2")))
    }

    // MARK: - Modifications

    func testDiffModifiedLine() {
        let result = computeLineDiff(old: "hello\nworld", new: "hello\nearth")
        XCTAssertEqual(result, [
            .context("hello"),
            .removed("world"),
            .added("earth"),
        ])
    }

    func testDiffMultipleChanges() {
        let old = "a\nb\nc\nd\ne"
        let new = "a\nB\nc\nD\ne"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .context("a"),
            .removed("b"),
            .added("B"),
            .context("c"),
            .removed("d"),
            .added("D"),
            .context("e"),
        ])
    }

    // MARK: - Ignore Whitespace

    func testDiffIgnoreWhitespaceNoChanges() {
        let old = "hello   world"
        let new = "hello world"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        // With ignoreWhitespace, these are treated as equal. The context line uses the old text.
        XCTAssertEqual(result, [.context("hello   world")])
    }

    func testDiffIgnoreWhitespaceStillShowsRealChanges() {
        let old = "hello\n  world"
        let new = "hello\n  earth"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [
            .context("hello"),
            .removed("  world"),
            .added("  earth"),
        ])
    }

    func testDiffIgnoreWhitespaceLeadingSpaces() {
        let old = "  line1\nline2"
        let new = "line1\nline2"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        // Leading whitespace difference only — should be treated as context
        XCTAssertEqual(result, [
            .context("  line1"),
            .context("line2"),
        ])
    }

    func testDiffIgnoreWhitespaceTrailingSpaces() {
        let old = "line1\nline2"
        let new = "line1   \nline2"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [
            .context("line1"),
            .context("line2"),
        ])
    }

    func testDiffWithoutIgnoreWhitespaceShowsWhitespaceChanges() {
        let old = "hello   world"
        let new = "hello world"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: false)
        XCTAssertEqual(result, [
            .removed("hello   world"),
            .added("hello world"),
        ])
    }

    // MARK: - Tab and Mixed Whitespace Handling

    func testDiffIgnoreWhitespaceTabsVsSpaces() {
        let old = "hello\tworld"
        let new = "hello world"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [.context("hello\tworld")])
    }

    func testDiffIgnoreWhitespaceMixedTabsAndSpaces() {
        let old = "hello \t world"
        let new = "hello world"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [.context("hello \t world")])
    }

    func testDiffIgnoreWhitespaceLeadingTabs() {
        let old = "\t\tindented"
        let new = "indented"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [.context("\t\tindented")])
    }

    func testDiffIgnoreWhitespaceTrailingTabs() {
        let old = "line1\t\t"
        let new = "line1"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [.context("line1\t\t")])
    }

    func testDiffIgnoreWhitespaceMultipleConsecutiveWhitespaceTypes() {
        let old = "\t  foo \t bar  "
        let new = "foo bar"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [.context("\t  foo \t bar  ")])
    }

    func testDiffWithoutIgnoreWhitespaceTabsVsSpacesShowsChanges() {
        let old = "hello\tworld"
        let new = "hello world"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: false)
        XCTAssertEqual(result, [
            .removed("hello\tworld"),
            .added("hello world"),
        ])
    }

    func testDiffWithoutIgnoreWhitespaceMixedWhitespaceShowsChanges() {
        let old = "\t  foo \t bar  "
        let new = "foo bar"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: false)
        XCTAssertEqual(result, [
            .removed("\t  foo \t bar  "),
            .added("foo bar"),
        ])
    }

    func testDiffIgnoreWhitespaceTabIndentVsSpaceIndent() {
        let old = "\tif true {\n\t\treturn\n\t}"
        let new = "    if true {\n        return\n    }"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [
            .context("\tif true {"),
            .context("\t\treturn"),
            .context("\t}"),
        ])
    }

    // MARK: - Edge Cases

    func testDiffSingleLineChange() {
        let result = computeLineDiff(old: "old", new: "new")
        XCTAssertEqual(result, [
            .removed("old"),
            .added("new"),
        ])
    }

    func testDiffCompletelyDifferent() {
        let result = computeLineDiff(old: "a\nb\nc", new: "x\ny\nz")
        // All lines should be removed and added
        let removals = result.filter { if case .removed = $0 { return true } else { return false } }
        let additions = result.filter { if case .added = $0 { return true } else { return false } }
        XCTAssertEqual(removals.count, 3)
        XCTAssertEqual(additions.count, 3)
    }

    func testDiffWithTrailingNewline() {
        let result = computeLineDiff(old: "line1\nline2\n", new: "line1\nchanged\n")
        XCTAssertTrue(result.contains(.context("line1")))
        XCTAssertTrue(result.contains(.removed("line2")))
        XCTAssertTrue(result.contains(.added("changed")))
        // Trailing newline produces an empty line that should be context in both
        XCTAssertTrue(result.contains(.context("")))
    }

    func testDiffReversedProducesOppositeChanges() {
        let forward = computeLineDiff(old: "a\nb", new: "a\nc")
        let reverse = computeLineDiff(old: "a\nc", new: "a\nb")

        // Forward: remove "b", add "c"
        XCTAssertTrue(forward.contains(.removed("b")))
        XCTAssertTrue(forward.contains(.added("c")))

        // Reverse: remove "c", add "b"
        XCTAssertTrue(reverse.contains(.removed("c")))
        XCTAssertTrue(reverse.contains(.added("b")))
    }

    // MARK: - Common Prefix/Suffix Trimming

    func testDiffChangeInMiddleWithLongPrefixAndSuffix() {
        // Large common prefix and suffix with a single change in the middle
        let old = "line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10"
        let new = "line1\nline2\nline3\nline4\nCHANGED\nline6\nline7\nline8\nline9\nline10"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .context("line1"),
            .context("line2"),
            .context("line3"),
            .context("line4"),
            .removed("line5"),
            .added("CHANGED"),
            .context("line6"),
            .context("line7"),
            .context("line8"),
            .context("line9"),
            .context("line10"),
        ])
    }

    func testDiffLongCommonPrefixChangeAtEnd() {
        // Long common prefix with a change only at the very end
        let old = "a\nb\nc\nd\ne\nold_ending"
        let new = "a\nb\nc\nd\ne\nnew_ending"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .context("a"),
            .context("b"),
            .context("c"),
            .context("d"),
            .context("e"),
            .removed("old_ending"),
            .added("new_ending"),
        ])
    }

    func testDiffLongCommonSuffixChangeAtBeginning() {
        // Change only at the beginning with a long common suffix
        let old = "old_start\nb\nc\nd\ne\nf"
        let new = "new_start\nb\nc\nd\ne\nf"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .removed("old_start"),
            .added("new_start"),
            .context("b"),
            .context("c"),
            .context("d"),
            .context("e"),
            .context("f"),
        ])
    }

    func testDiffCompletelyDifferentNoPrefixOrSuffix() {
        // No common prefix or suffix at all
        let result = computeLineDiff(old: "alpha\nbeta\ngamma", new: "one\ntwo\nthree")
        let removals = result.filter { if case .removed = $0 { return true } else { return false } }
        let additions = result.filter { if case .added = $0 { return true } else { return false } }
        let contexts = result.filter { if case .context = $0 { return true } else { return false } }
        XCTAssertEqual(removals.count, 3)
        XCTAssertEqual(additions.count, 3)
        XCTAssertEqual(contexts.count, 0)
    }

    func testDiffCompletelyIdenticalAllContext() {
        // Entirely identical files should produce all context lines
        let text = "first\nsecond\nthird\nfourth\nfifth"
        let result = computeLineDiff(old: text, new: text)
        XCTAssertEqual(result, [
            .context("first"),
            .context("second"),
            .context("third"),
            .context("fourth"),
            .context("fifth"),
        ])
        // No removals or additions
        let nonContext = result.filter { if case .context = $0 { return false } else { return true } }
        XCTAssertEqual(nonContext.count, 0)
    }

    func testDiffCommonPrefixAndSuffixWithInsertionInMiddle() {
        // Common prefix and suffix with an insertion (not replacement) in the middle
        let old = "header\na\nb\nfooter"
        let new = "header\na\nINSERTED\nb\nfooter"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .context("header"),
            .context("a"),
            .added("INSERTED"),
            .context("b"),
            .context("footer"),
        ])
    }

    func testDiffCommonPrefixAndSuffixWithDeletionInMiddle() {
        // Common prefix and suffix with a deletion in the middle
        let old = "header\na\nDELETED\nb\nfooter"
        let new = "header\na\nb\nfooter"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .context("header"),
            .context("a"),
            .removed("DELETED"),
            .context("b"),
            .context("footer"),
        ])
    }

    func testDiffPrefixSuffixTrimmingWithIgnoreWhitespace() {
        // Prefix/suffix trimming should work correctly with ignoreWhitespace
        let old = "  header\na\nold_middle\nb\n  footer"
        let new = "header\na\nnew_middle\nb\nfooter"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [
            .context("  header"),
            .context("a"),
            .removed("old_middle"),
            .added("new_middle"),
            .context("b"),
            .context("  footer"),
        ])
    }
}

// MARK: - Line Hashing Optimization Tests

final class DiffLineHashingTests: XCTestCase {

    // MARK: - Basic Modifications With Hashing

    func testHashingProducesCorrectDiffForSimpleModification() {
        let old = "func hello() {\n    print(\"hello\")\n}"
        let new = "func hello() {\n    print(\"goodbye\")\n}"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .context("func hello() {"),
            .removed("    print(\"hello\")"),
            .added("    print(\"goodbye\")"),
            .context("}"),
        ])
    }

    func testHashingProducesCorrectDiffForInsertionAndDeletion() {
        let old = "a\nb\nc\nd\ne"
        let new = "a\nc\nd\nf\ne"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .context("a"),
            .removed("b"),
            .context("c"),
            .context("d"),
            .added("f"),
            .context("e"),
        ])
    }

    // MARK: - Whitespace-Ignored Diff With Hashing

    func testHashingWithIgnoreWhitespaceMultipleSpaces() {
        let old = "int   x   =   1;\nreturn x;"
        let new = "int x = 1;\nreturn x;"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [
            .context("int   x   =   1;"),
            .context("return x;"),
        ])
    }

    func testHashingWithIgnoreWhitespaceTabsVsSpaces() {
        let old = "  indented\nnormal"
        let new = "indented\nnormal"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        XCTAssertEqual(result, [
            .context("  indented"),
            .context("normal"),
        ])
    }

    func testHashingWithIgnoreWhitespaceRealChangesStillDetected() {
        let old = "  alpha  \n  beta  \n  gamma  "
        let new = "alpha\n  BETA  \ngamma"
        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)
        // "alpha" matches (whitespace-normalized), "BETA" does not match "beta", "gamma" matches
        XCTAssertTrue(result.contains(.context("  alpha  ")))
        XCTAssertTrue(result.contains(.removed("  beta  ")))
        XCTAssertTrue(result.contains(.added("  BETA  ")))
        XCTAssertTrue(result.contains(.context("  gamma  ")))
    }

    // MARK: - Large Files With Few Changes

    func testHashingLargeFileWithSingleChange() {
        // Build a large file with 500 lines, change only one line in the middle
        let oldLines = (0..<500).map { "line number \($0) with some content to make it longer" }
        var newLines = oldLines
        newLines[250] = "CHANGED line number 250 with different content"

        let old = oldLines.joined(separator: "\n")
        let new = newLines.joined(separator: "\n")

        let result = computeLineDiff(old: old, new: new)

        // Should have exactly 1 removal and 1 addition
        let removals = result.filter { if case .removed = $0 { return true } else { return false } }
        let additions = result.filter { if case .added = $0 { return true } else { return false } }
        let contexts = result.filter { if case .context = $0 { return true } else { return false } }

        XCTAssertEqual(removals.count, 1)
        XCTAssertEqual(additions.count, 1)
        XCTAssertEqual(contexts.count, 499) // All other lines are context
        XCTAssertTrue(result.contains(.removed("line number 250 with some content to make it longer")))
        XCTAssertTrue(result.contains(.added("CHANGED line number 250 with different content")))
    }

    func testHashingLargeFileWithNoChanges() {
        let lines = (0..<1000).map { "line \($0)" }
        let text = lines.joined(separator: "\n")

        let result = computeLineDiff(old: text, new: text)

        // All lines should be context
        let contexts = result.filter { if case .context = $0 { return true } else { return false } }
        XCTAssertEqual(contexts.count, 1000)
        XCTAssertEqual(result.count, 1000)
    }

    func testHashingLargeFileWithChangesAtBothEnds() {
        let oldLines = (0..<200).map { "line \($0)" }
        var newLines = oldLines
        newLines[0] = "FIRST LINE CHANGED"
        newLines[199] = "LAST LINE CHANGED"

        let old = oldLines.joined(separator: "\n")
        let new = newLines.joined(separator: "\n")

        let result = computeLineDiff(old: old, new: new)

        let removals = result.filter { if case .removed = $0 { return true } else { return false } }
        let additions = result.filter { if case .added = $0 { return true } else { return false } }

        XCTAssertEqual(removals.count, 2)
        XCTAssertEqual(additions.count, 2)
        XCTAssertTrue(result.contains(.removed("line 0")))
        XCTAssertTrue(result.contains(.added("FIRST LINE CHANGED")))
        XCTAssertTrue(result.contains(.removed("line 199")))
        XCTAssertTrue(result.contains(.added("LAST LINE CHANGED")))
    }

    // MARK: - Many Similar Lines (Hash Collision Resistance)

    func testHashingWithManyDuplicateLines() {
        // Many identical lines — hashes will be the same but that is correct behavior
        let old = Array(repeating: "duplicate", count: 10).joined(separator: "\n")
        let new = Array(repeating: "duplicate", count: 10).joined(separator: "\n")

        let result = computeLineDiff(old: old, new: new)

        let contexts = result.filter { if case .context = $0 { return true } else { return false } }
        XCTAssertEqual(contexts.count, 10)
    }

    func testHashingWithSimilarButDistinctLines() {
        // Lines that are very similar but differ by one character —
        // tests that the string fallback catches any hash collision
        let old = "aaa\naab\naac\naad\naae\naaf\naag\naah\naai\naaj"
        let new = "aaa\naab\nAAC\naad\naae\naaf\nAAG\naah\naai\naaj"

        let result = computeLineDiff(old: old, new: new)

        XCTAssertEqual(result, [
            .context("aaa"),
            .context("aab"),
            .removed("aac"),
            .added("AAC"),
            .context("aad"),
            .context("aae"),
            .context("aaf"),
            .removed("aag"),
            .added("AAG"),
            .context("aah"),
            .context("aai"),
            .context("aaj"),
        ])
    }

    func testHashingWithSingleCharacterVariations() {
        // Single character lines that vary minimally
        let old = "a\nb\nc\nd\ne\nf\ng\nh"
        let new = "a\nB\nc\nD\ne\nF\ng\nH"

        let result = computeLineDiff(old: old, new: new)

        XCTAssertEqual(result, [
            .context("a"),
            .removed("b"),
            .added("B"),
            .context("c"),
            .removed("d"),
            .added("D"),
            .context("e"),
            .removed("f"),
            .added("F"),
            .context("g"),
            .removed("h"),
            .added("H"),
        ])
    }

    func testHashingDuplicateLinesWithOneChangedInMiddle() {
        // All lines are the same except one changed in the middle
        let oldLines = Array(repeating: "same line", count: 20)
        var newLines = oldLines
        newLines[10] = "different line"

        let old = oldLines.joined(separator: "\n")
        let new = newLines.joined(separator: "\n")

        let result = computeLineDiff(old: old, new: new)

        let removals = result.filter { if case .removed = $0 { return true } else { return false } }
        let additions = result.filter { if case .added = $0 { return true } else { return false } }
        let contexts = result.filter { if case .context = $0 { return true } else { return false } }

        XCTAssertEqual(removals.count, 1)
        XCTAssertEqual(additions.count, 1)
        XCTAssertEqual(contexts.count, 19)
        XCTAssertTrue(result.contains(.removed("same line")))
        XCTAssertTrue(result.contains(.added("different line")))
    }

    func testHashingIgnoreWhitespaceLargeFile() {
        // Large file where lines differ only in whitespace — all should be context
        let oldLines = (0..<100).map { "  line  \($0)  " }
        let newLines = (0..<100).map { "line \($0)" }

        let old = oldLines.joined(separator: "\n")
        let new = newLines.joined(separator: "\n")

        let result = computeLineDiff(old: old, new: new, ignoreWhitespace: true)

        let contexts = result.filter { if case .context = $0 { return true } else { return false } }
        XCTAssertEqual(contexts.count, 100)
        // Context lines should use the old text
        XCTAssertTrue(result.contains(.context("  line  0  ")))
        XCTAssertTrue(result.contains(.context("  line  99  ")))
    }
}

// MARK: - Myers Algorithm Tests

final class MyersAlgorithmTests: XCTestCase {

    // MARK: - Large Files with Small Diffs (O(ND) behavior)

    func testDiffLargeFileWithSmallChange() {
        // 500 identical lines with one change in the middle — Myers should handle this efficiently
        var oldLines: [String] = []
        var newLines: [String] = []
        for i in 0..<500 {
            oldLines.append("line \(i)")
            newLines.append("line \(i)")
        }
        oldLines[250] = "old line 250"
        newLines[250] = "new line 250"

        let old = oldLines.joined(separator: "\n")
        let new = newLines.joined(separator: "\n")

        let result = computeLineDiff(old: old, new: new)

        // Should have 499 context lines, 1 removed, 1 added
        let contextCount = result.filter { if case .context = $0 { return true } else { return false } }.count
        let removals = result.filter { if case .removed = $0 { return true } else { return false } }
        let additions = result.filter { if case .added = $0 { return true } else { return false } }

        XCTAssertEqual(contextCount, 499)
        XCTAssertEqual(removals.count, 1)
        XCTAssertEqual(additions.count, 1)
        XCTAssertTrue(result.contains(.removed("old line 250")))
        XCTAssertTrue(result.contains(.added("new line 250")))
    }

    func testDiffSingleLineChangeInLargeFile() {
        // 1000 lines, change only the last one
        let oldLines: [String] = (0..<1000).map { "line \($0)" }
        var newLines = oldLines
        newLines[999] = "modified last line"

        let result = computeLineDiff(old: oldLines.joined(separator: "\n"), new: newLines.joined(separator: "\n"))

        let contextCount = result.filter { if case .context = $0 { return true } else { return false } }.count
        XCTAssertEqual(contextCount, 999)
        XCTAssertTrue(result.contains(.removed("line 999")))
        XCTAssertTrue(result.contains(.added("modified last line")))
    }

    // MARK: - Completely Different Files (worst case)

    func testDiffCompletelyDifferentLargeFiles() {
        // Every line is different — worst case for Myers (D = n + m)
        let oldLines = (0..<100).map { "old_\($0)" }
        let newLines = (0..<100).map { "new_\($0)" }

        let result = computeLineDiff(old: oldLines.joined(separator: "\n"), new: newLines.joined(separator: "\n"))

        let removals = result.filter { if case .removed = $0 { return true } else { return false } }
        let additions = result.filter { if case .added = $0 { return true } else { return false } }
        let contextCount = result.filter { if case .context = $0 { return true } else { return false } }.count

        // All lines should be removed and added, no context
        XCTAssertEqual(removals.count, 100)
        XCTAssertEqual(additions.count, 100)
        XCTAssertEqual(contextCount, 0)
    }

    // MARK: - Adjacent Changes (consecutive inserts/deletes)

    func testDiffAdjacentInserts() {
        let old = "a\nd\ne"
        let new = "a\nb\nc\nd\ne"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .context("a"),
            .added("b"),
            .added("c"),
            .context("d"),
            .context("e"),
        ])
    }

    func testDiffAdjacentDeletes() {
        let old = "a\nb\nc\nd\ne"
        let new = "a\nd\ne"
        let result = computeLineDiff(old: old, new: new)
        XCTAssertEqual(result, [
            .context("a"),
            .removed("b"),
            .removed("c"),
            .context("d"),
            .context("e"),
        ])
    }

    func testDiffAdjacentMixedChanges() {
        // Replace two consecutive lines
        let old = "header\nold1\nold2\nfooter"
        let new = "header\nnew1\nnew2\nfooter"
        let result = computeLineDiff(old: old, new: new)

        XCTAssertTrue(result.contains(.context("header")))
        XCTAssertTrue(result.contains(.context("footer")))
        XCTAssertTrue(result.contains(.removed("old1")))
        XCTAssertTrue(result.contains(.removed("old2")))
        XCTAssertTrue(result.contains(.added("new1")))
        XCTAssertTrue(result.contains(.added("new2")))

        // Total should be 2 context + 2 removed + 2 added = 6
        XCTAssertEqual(result.count, 6)
    }

    func testDiffMultipleScatteredChanges() {
        // Changes at the beginning, middle, and end
        let old = "a\nb\nc\nd\ne\nf\ng\nh\ni\nj"
        let new = "A\nb\nc\nd\nE\nf\ng\nh\ni\nJ"
        let result = computeLineDiff(old: old, new: new)

        // Three pairs of remove/add scattered through context
        XCTAssertTrue(result.contains(.removed("a")))
        XCTAssertTrue(result.contains(.added("A")))
        XCTAssertTrue(result.contains(.removed("e")))
        XCTAssertTrue(result.contains(.added("E")))
        XCTAssertTrue(result.contains(.removed("j")))
        XCTAssertTrue(result.contains(.added("J")))

        // 7 context lines (b, c, d, f, g, h, i)
        let contextCount = result.filter { if case .context = $0 { return true } else { return false } }.count
        XCTAssertEqual(contextCount, 7)
    }
}

// MARK: - Repository Diff Integration Tests

final class RepositoryDiffTests: TempDirectoryTestCase {

    // MARK: - Basic Diff

    func testDiffIdenticalCommitsReturnsEmptyResult() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "hello world".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let hash = try repo.commit(message: "initial", author: "A")

        let result = try repo.diff(from: hash, to: hash)
        XCTAssertTrue(result.files.isEmpty)
    }

    func testDiffModifiedTextFile() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "line1\nline2\nline3".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "v1", author: "A")

        try "line1\nmodified\nline3".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "v2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "file.txt")

        guard case .modified(let lines) = result.files[0].diff else {
            return XCTFail("Expected modified diff")
        }
        XCTAssertTrue(lines.contains(.removed("line2")))
        XCTAssertTrue(lines.contains(.added("modified")))
        XCTAssertTrue(lines.contains(.context("line1")))
        XCTAssertTrue(lines.contains(.context("line3")))
    }

    // MARK: - Added Files

    func testDiffAddedFile() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "existing".write(to: tempDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "v1", author: "A")

        try "new content".write(to: tempDir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "v2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "b.txt")

        guard case .added(let lines) = result.files[0].diff else {
            return XCTFail("Expected added diff")
        }
        XCTAssertTrue(lines.contains(.added("new content")))
    }

    // MARK: - Removed Files

    func testDiffRemovedFile() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "content a".write(to: tempDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "content b".write(to: tempDir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "v1", author: "A")

        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("b.txt"))
        let hash2 = try repo.commit(message: "v2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "b.txt")

        guard case .removed(let lines) = result.files[0].diff else {
            return XCTFail("Expected removed diff")
        }
        XCTAssertTrue(lines.contains(.removed("content b")))
    }

    // MARK: - Multiple File Changes

    func testDiffMultipleFileChanges() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "a content".write(to: tempDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "b content".write(to: tempDir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "v1", author: "A")

        try "a modified".write(to: tempDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("b.txt"))
        try "c new".write(to: tempDir.appendingPathComponent("c.txt"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "v2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 3)

        let paths = result.files.map { $0.path }
        XCTAssertTrue(paths.contains("a.txt"))
        XCTAssertTrue(paths.contains("b.txt"))
        XCTAssertTrue(paths.contains("c.txt"))
    }

    // MARK: - Nested Files

    func testDiffWithNestedFiles() throws {
        let repo = try Repository.initialize(at: tempDir)
        let subdir = tempDir.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        try "old code".write(to: subdir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "v1", author: "A")

        try "new code".write(to: subdir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "v2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "src/main.swift")
    }

    // MARK: - Binary Files

    func testDiffBinaryFilesShowsSizeChange() throws {
        let repo = try Repository.initialize(at: tempDir)
        let oldBinary = Data([0x00, 0x01, 0xFF, 0xFE])
        try oldBinary.write(to: tempDir.appendingPathComponent("data.bin"))
        let hash1 = try repo.commit(message: "v1", author: "A")

        let newBinary = Data([0x00, 0x01, 0xFF, 0xFE, 0x80, 0x7F])
        try newBinary.write(to: tempDir.appendingPathComponent("data.bin"))
        let hash2 = try repo.commit(message: "v2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 1)

        guard case .binary(let oldSize, let newSize) = result.files[0].diff else {
            return XCTFail("Expected binary diff")
        }
        XCTAssertEqual(oldSize, 4)
        XCTAssertEqual(newSize, 6)
    }

    // MARK: - Ignore Whitespace

    func testDiffIgnoreWhitespace() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "hello   world\nline2".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "v1", author: "A")

        try "hello world\nline2".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "v2", author: "A")

        let resultWithWhitespace = try repo.diff(from: hash1, to: hash2, ignoreWhitespace: false)
        XCTAssertEqual(resultWithWhitespace.files.count, 1)

        let resultIgnoreWhitespace = try repo.diff(from: hash1, to: hash2, ignoreWhitespace: true)
        XCTAssertTrue(resultIgnoreWhitespace.files.isEmpty)
    }

    func testDiffIgnoreWhitespaceStillShowsSubstantiveChanges() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "  hello\nworld".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "v1", author: "A")

        try "hello\nearth".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "v2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2, ignoreWhitespace: true)
        XCTAssertEqual(result.files.count, 1)

        guard case .modified(let lines) = result.files[0].diff else {
            return XCTFail("Expected modified diff")
        }
        // "  hello" vs "hello" should be context (whitespace only)
        XCTAssertTrue(lines.contains(.context("  hello")))
        // "world" vs "earth" is a real change
        XCTAssertTrue(lines.contains(.removed("world")))
        XCTAssertTrue(lines.contains(.added("earth")))
    }

    // MARK: - Empty Commits

    func testDiffEmptyCommits() throws {
        let repo = try Repository.initialize(at: tempDir)
        let hash1 = try repo.commit(message: "empty1", author: "A")
        let hash2 = try repo.commit(message: "empty2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertTrue(result.files.isEmpty)
    }

    func testDiffFromEmptyToFiles() throws {
        let repo = try Repository.initialize(at: tempDir)
        let hash1 = try repo.commit(message: "empty", author: "A")

        try "content".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "add file", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "file.txt")

        guard case .added = result.files[0].diff else {
            return XCTFail("Expected added diff")
        }
    }

    func testDiffFromFilesToEmpty() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "content".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "with file", author: "A")

        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("file.txt"))
        let hash2 = try repo.commit(message: "remove file", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 1)

        guard case .removed = result.files[0].diff else {
            return XCTFail("Expected removed diff")
        }
    }

    // MARK: - File Paths Are Sorted

    func testDiffFilesAreSorted() throws {
        let repo = try Repository.initialize(at: tempDir)
        let hash1 = try repo.commit(message: "empty", author: "A")

        try "z".write(to: tempDir.appendingPathComponent("z.txt"), atomically: true, encoding: .utf8)
        try "a".write(to: tempDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "m".write(to: tempDir.appendingPathComponent("m.txt"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "add files", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        let paths = result.files.map { $0.path }
        XCTAssertEqual(paths, paths.sorted())
    }

    // MARK: - Deeply Nested Changes

    func testDiffDeeplyNestedFile() throws {
        let repo = try Repository.initialize(at: tempDir)
        let deep = tempDir.appendingPathComponent("a/b/c")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try "old value".write(to: deep.appendingPathComponent("leaf.txt"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "v1", author: "A")

        try "new value".write(to: deep.appendingPathComponent("leaf.txt"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "v2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 1)
        XCTAssertEqual(result.files[0].path, "a/b/c/leaf.txt")
    }

    // MARK: - Reverse Diff

    func testDiffReversedSwapsAddedAndRemoved() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "original".write(to: tempDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        let hash1 = try repo.commit(message: "v1", author: "A")

        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("a.txt"))
        try "brand new".write(to: tempDir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        let hash2 = try repo.commit(message: "v2", author: "A")

        // Forward: a.txt removed, b.txt added
        let forward = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(forward.files.count, 2)
        let forwardA = forward.files.first { $0.path == "a.txt" }
        let forwardB = forward.files.first { $0.path == "b.txt" }
        guard case .removed = forwardA?.diff else { return XCTFail("Expected a.txt removed") }
        guard case .added = forwardB?.diff else { return XCTFail("Expected b.txt added") }

        // Reverse: a.txt added, b.txt removed
        let reverse = try repo.diff(from: hash2, to: hash1)
        XCTAssertEqual(reverse.files.count, 2)
        let reverseA = reverse.files.first { $0.path == "a.txt" }
        let reverseB = reverse.files.first { $0.path == "b.txt" }
        guard case .added = reverseA?.diff else { return XCTFail("Expected a.txt added in reverse") }
        guard case .removed = reverseB?.diff else { return XCTFail("Expected b.txt removed in reverse") }
    }

    // MARK: - Mixed Text and Binary

    func testDiffMixedTextAndBinaryFiles() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "text v1".write(to: tempDir.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)
        try Data([0x00, 0xFF, 0x80]).write(to: tempDir.appendingPathComponent("image.bin"))
        let hash1 = try repo.commit(message: "v1", author: "A")

        try "text v2".write(to: tempDir.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)
        try Data([0x00, 0xFF, 0x80, 0x01]).write(to: tempDir.appendingPathComponent("image.bin"))
        let hash2 = try repo.commit(message: "v2", author: "A")

        let result = try repo.diff(from: hash1, to: hash2)
        XCTAssertEqual(result.files.count, 2)

        let textDiff = result.files.first { $0.path == "readme.txt" }
        let binaryDiff = result.files.first { $0.path == "image.bin" }

        guard case .modified = textDiff?.diff else { return XCTFail("Expected text modified") }
        guard case .binary(let oldSize, let newSize) = binaryDiff?.diff else {
            return XCTFail("Expected binary diff")
        }
        XCTAssertEqual(oldSize, 3)
        XCTAssertEqual(newSize, 4)
    }
}
