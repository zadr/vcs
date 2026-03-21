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
