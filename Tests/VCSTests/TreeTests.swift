import XCTest
@testable import VCS

final class TreeTests: XCTestCase {

    // MARK: - TreeEntry init

    func testTreeEntryInitFileEntry() {
        let entry = TreeEntry(name: "readme.txt", hash: "abc123", isDirectory: false)
        XCTAssertEqual(entry.name, "readme.txt")
        XCTAssertEqual(entry.hash, "abc123")
        XCTAssertFalse(entry.isDirectory)
    }

    func testTreeEntryInitDirectoryEntry() {
        let entry = TreeEntry(name: "src", hash: "def456", isDirectory: true)
        XCTAssertEqual(entry.name, "src")
        XCTAssertEqual(entry.hash, "def456")
        XCTAssertTrue(entry.isDirectory)
    }

    func testTreeEntryInitEmptyName() {
        let entry = TreeEntry(name: "", hash: "abc123", isDirectory: false)
        XCTAssertEqual(entry.name, "")
        XCTAssertEqual(entry.hash, "abc123")
        XCTAssertFalse(entry.isDirectory)
    }

    func testTreeEntryInitEmptyHash() {
        let entry = TreeEntry(name: "file.txt", hash: "", isDirectory: false)
        XCTAssertEqual(entry.name, "file.txt")
        XCTAssertEqual(entry.hash, "")
        XCTAssertFalse(entry.isDirectory)
    }

    // MARK: - Tree init

    func testTreeInitEmptyEntries() {
        let tree = Tree(entries: [])
        XCTAssertTrue(tree.entries.isEmpty)
    }

    func testTreeInitSingleFile() {
        let entry = TreeEntry(name: "file.txt", hash: "aaa", isDirectory: false)
        let tree = Tree(entries: [entry])
        XCTAssertEqual(tree.entries.count, 1)
        XCTAssertEqual(tree.entries[0].name, "file.txt")
        XCTAssertFalse(tree.entries[0].isDirectory)
    }

    func testTreeInitSingleDirectory() {
        let entry = TreeEntry(name: "lib", hash: "bbb", isDirectory: true)
        let tree = Tree(entries: [entry])
        XCTAssertEqual(tree.entries.count, 1)
        XCTAssertEqual(tree.entries[0].name, "lib")
        XCTAssertTrue(tree.entries[0].isDirectory)
    }

    func testTreeInitMixedEntries() {
        let entries = [
            TreeEntry(name: "file.txt", hash: "aaa", isDirectory: false),
            TreeEntry(name: "src", hash: "bbb", isDirectory: true),
            TreeEntry(name: "readme.md", hash: "ccc", isDirectory: false),
        ]
        let tree = Tree(entries: entries)
        XCTAssertEqual(tree.entries.count, 3)
        XCTAssertFalse(tree.entries[0].isDirectory)
        XCTAssertTrue(tree.entries[1].isDirectory)
        XCTAssertFalse(tree.entries[2].isDirectory)
    }

    func testTreeInitManyEntries() {
        let entries = (0..<150).map { i in
            TreeEntry(name: "file_\(i).txt", hash: "hash_\(i)", isDirectory: i % 2 == 0)
        }
        let tree = Tree(entries: entries)
        XCTAssertEqual(tree.entries.count, 150)
        XCTAssertEqual(tree.entries[0].name, "file_0.txt")
        XCTAssertEqual(tree.entries[149].name, "file_149.txt")
    }

    // MARK: - encode()

    func testEncodeProducesTreePrefix() throws {
        let tree = Tree(entries: [TreeEntry(name: "a.txt", hash: "h1", isDirectory: false)])
        let data = try tree.encode()
        let str = String(data: data, encoding: .utf8)!
        XCTAssertTrue(str.hasPrefix("tree\n"))
    }

    func testEncodeProducesValidJSONAfterPrefix() throws {
        let entry = TreeEntry(name: "a.txt", hash: "h1", isDirectory: false)
        let tree = Tree(entries: [entry])
        let data = try tree.encode()
        let parts = data.split(separator: 0x0A, maxSplits: 1, omittingEmptySubsequences: false)
        XCTAssertEqual(parts.count, 2)
        let jsonData = Data(parts[1])
        let decoded = try JSONDecoder().decode([TreeEntry].self, from: jsonData)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].name, "a.txt")
    }

    func testEncodeEmptyTreeProducesExpectedOutput() throws {
        let tree = Tree(entries: [])
        let data = try tree.encode()
        let str = String(data: data, encoding: .utf8)!
        XCTAssertEqual(str, "tree\n[]")
    }

    // MARK: - decode()

    func testDecodeValidEncodedData() throws {
        let json = try JSONEncoder().encode([TreeEntry(name: "f.txt", hash: "h", isDirectory: false)])
        var raw = "tree\n".data(using: .utf8)!
        raw.append(json)
        let tree = try Tree.decode(raw)
        XCTAssertEqual(tree.entries.count, 1)
        XCTAssertEqual(tree.entries[0].name, "f.txt")
    }

    func testDecodeEmptyEntries() throws {
        let raw = "tree\n[]".data(using: .utf8)!
        let tree = try Tree.decode(raw)
        XCTAssertTrue(tree.entries.isEmpty)
    }

    func testDecodeInvalidPrefixThrows() {
        let raw = "nottree\n[]".data(using: .utf8)!
        XCTAssertThrowsError(try Tree.decode(raw)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                XCTFail("Expected CompressionError.decompressionFailed, got \(error)")
                return
            }
            XCTAssertEqual(msg, "Invalid tree format")
        }
    }

    func testDecodeNoNewlineThrows() {
        let raw = "tree[]".data(using: .utf8)!
        XCTAssertThrowsError(try Tree.decode(raw)) { error in
            guard case CompressionError.decompressionFailed = error else {
                XCTFail("Expected CompressionError.decompressionFailed, got \(error)")
                return
            }
        }
    }

    func testDecodeInvalidJSONThrows() {
        let raw = "tree\n{not valid json}".data(using: .utf8)!
        XCTAssertThrowsError(try Tree.decode(raw))
    }

    func testDecodeEmptyDataThrows() {
        let raw = Data()
        XCTAssertThrowsError(try Tree.decode(raw)) { error in
            guard case CompressionError.decompressionFailed = error else {
                XCTFail("Expected CompressionError.decompressionFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - Round-trip

    func testRoundTripEncodeDecode() throws {
        let entries = [
            TreeEntry(name: "main.swift", hash: "abc", isDirectory: false),
            TreeEntry(name: "lib", hash: "def", isDirectory: true),
        ]
        let original = Tree(entries: entries)
        let encoded = try original.encode()
        let decoded = try Tree.decode(encoded)
        XCTAssertEqual(decoded.entries.count, original.entries.count)
        for (orig, dec) in zip(original.entries, decoded.entries) {
            XCTAssertEqual(orig.name, dec.name)
            XCTAssertEqual(orig.hash, dec.hash)
            XCTAssertEqual(orig.isDirectory, dec.isDirectory)
        }
    }

    func testRoundTripManyEntries() throws {
        let entries = (0..<120).map { i in
            TreeEntry(name: "item_\(i)", hash: String(format: "%040d", i), isDirectory: i % 3 == 0)
        }
        let original = Tree(entries: entries)
        let encoded = try original.encode()
        let decoded = try Tree.decode(encoded)
        XCTAssertEqual(decoded.entries.count, 120)
        for (orig, dec) in zip(original.entries, decoded.entries) {
            XCTAssertEqual(orig.name, dec.name)
            XCTAssertEqual(orig.hash, dec.hash)
            XCTAssertEqual(orig.isDirectory, dec.isDirectory)
        }
    }

    // MARK: - TreeEntry Codable

    func testTreeEntryCodableRoundTrip() throws {
        let entry = TreeEntry(name: "test.swift", hash: "deadbeef", isDirectory: false)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TreeEntry.self, from: data)
        XCTAssertEqual(decoded.name, entry.name)
        XCTAssertEqual(decoded.hash, entry.hash)
        XCTAssertEqual(decoded.isDirectory, entry.isDirectory)
    }
}
