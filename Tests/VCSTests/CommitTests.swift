import XCTest
@testable import VCS

final class CommitTests: XCTestCase {

    // MARK: - Init: with parent

    func testInitWithParent() {
        let date = Date()
        let commit = Commit(tree: "abc123", parent: "def456", author: "Alice", timestamp: date, message: "Initial commit")
        XCTAssertEqual(commit.tree, "abc123")
        XCTAssertEqual(commit.parent, "def456")
        XCTAssertEqual(commit.author, "Alice")
        XCTAssertEqual(commit.timestamp.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(commit.message, "Initial commit")
    }

    // MARK: - Init: without parent (nil)

    func testInitWithoutParent() {
        let commit = Commit(tree: "abc123", parent: nil, author: "Bob", timestamp: Date(), message: "Root commit")
        XCTAssertNil(commit.parent)
    }

    // MARK: - Init: empty message

    func testInitWithEmptyMessage() {
        let commit = Commit(tree: "aaa", parent: nil, author: "Eve", timestamp: Date(), message: "")
        XCTAssertEqual(commit.message, "")
    }

    // MARK: - Init: long message

    func testInitWithLongMessage() {
        let longMessage = String(repeating: "a", count: 10_000)
        let commit = Commit(tree: "bbb", parent: nil, author: "Mallory", timestamp: Date(), message: longMessage)
        XCTAssertEqual(commit.message, longMessage)
        XCTAssertEqual(commit.message.count, 10_000)
    }

    // MARK: - Init: unicode author

    func testInitWithUnicodeAuthor() {
        let commit = Commit(tree: "ccc", parent: nil, author: "用户🧑‍💻", timestamp: Date(), message: "unicode test")
        XCTAssertEqual(commit.author, "用户🧑‍💻")
    }

    // MARK: - Init: empty author

    func testInitWithEmptyAuthor() {
        let commit = Commit(tree: "ddd", parent: nil, author: "", timestamp: Date(), message: "no author")
        XCTAssertEqual(commit.author, "")
    }

    // MARK: - Init: various dates

    func testInitWithDistantPast() {
        let commit = Commit(tree: "eee", parent: nil, author: "A", timestamp: .distantPast, message: "past")
        XCTAssertEqual(commit.timestamp, .distantPast)
    }

    func testInitWithDistantFuture() {
        let commit = Commit(tree: "fff", parent: nil, author: "A", timestamp: .distantFuture, message: "future")
        XCTAssertEqual(commit.timestamp, .distantFuture)
    }

    func testInitWithNow() {
        let now = Date()
        let commit = Commit(tree: "ggg", parent: nil, author: "A", timestamp: now, message: "now")
        XCTAssertEqual(commit.timestamp.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - encode(): verify "commit\n" prefix

    func testEncodeHasCommitPrefix() throws {
        let commit = Commit(tree: "abc", parent: nil, author: "A", timestamp: Date(), message: "m")
        let data = try commit.encode()
        let str = String(data: data, encoding: .utf8)!
        XCTAssertTrue(str.hasPrefix("commit\n"))
    }

    // MARK: - encode(): valid JSON after prefix

    func testEncodeProducesValidJSONAfterPrefix() throws {
        let commit = Commit(tree: "abc", parent: "def", author: "A", timestamp: Date(), message: "m")
        let data = try commit.encode()
        let parts = data.split(separator: 0x0A, maxSplits: 1, omittingEmptySubsequences: false)
        XCTAssertEqual(parts.count, 2)
        let jsonData = Data(parts[1])
        let parsed = try JSONDecoder().decode(Commit.self, from: jsonData)
        XCTAssertEqual(parsed.tree, "abc")
        XCTAssertEqual(parsed.parent, "def")
    }

    // MARK: - encode(): nil parent in JSON

    func testEncodeNilParentInJSON() throws {
        let commit = Commit(tree: "abc", parent: nil, author: "A", timestamp: Date(), message: "m")
        let data = try commit.encode()
        let parts = data.split(separator: 0x0A, maxSplits: 1, omittingEmptySubsequences: false)
        let jsonData = Data(parts[1])
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        XCTAssertTrue(json["parent"] is NSNull || json["parent"] == nil)
    }

    // MARK: - decode(): valid data

    func testDecodeValidData() throws {
        let commit = Commit(tree: "abc", parent: "def", author: "Alice", timestamp: Date(), message: "hello")
        let encoded = try commit.encode()
        let decoded = try Commit.decode(encoded)
        XCTAssertEqual(decoded.tree, "abc")
        XCTAssertEqual(decoded.parent, "def")
        XCTAssertEqual(decoded.author, "Alice")
        XCTAssertEqual(decoded.message, "hello")
    }

    // MARK: - decode(): invalid prefix

    func testDecodeInvalidPrefixThrows() {
        let badData = "blob\n{}".data(using: .utf8)!
        XCTAssertThrowsError(try Commit.decode(badData)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Invalid commit format"), "Message was: \(msg)")
        }
    }

    // MARK: - decode(): no newline

    func testDecodeNoNewlineThrows() {
        let badData = "commit{}".data(using: .utf8)!
        XCTAssertThrowsError(try Commit.decode(badData)) { error in
            guard case CompressionError.decompressionFailed = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
        }
    }

    // MARK: - decode(): invalid JSON

    func testDecodeInvalidJSONThrows() {
        let badData = "commit\nnot-valid-json".data(using: .utf8)!
        XCTAssertThrowsError(try Commit.decode(badData))
    }

    // MARK: - decode(): empty Data

    func testDecodeEmptyDataThrows() {
        XCTAssertThrowsError(try Commit.decode(Data())) { error in
            guard case CompressionError.decompressionFailed = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
        }
    }

    // MARK: - Round-trip: all fields preserved with parent

    func testRoundTripWithParent() throws {
        let date = Date()
        let original = Commit(tree: "tree123", parent: "parent456", author: "用户🧑‍💻", timestamp: date, message: "A meaningful message")
        let encoded = try original.encode()
        let decoded = try Commit.decode(encoded)
        XCTAssertEqual(decoded.tree, original.tree)
        XCTAssertEqual(decoded.parent, original.parent)
        XCTAssertEqual(decoded.author, original.author)
        XCTAssertEqual(decoded.message, original.message)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, original.timestamp.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - Round-trip: without parent

    func testRoundTripWithoutParent() throws {
        let original = Commit(tree: "tree789", parent: nil, author: "Bob", timestamp: Date(), message: "root")
        let encoded = try original.encode()
        let decoded = try Commit.decode(encoded)
        XCTAssertEqual(decoded.tree, original.tree)
        XCTAssertNil(decoded.parent)
        XCTAssertEqual(decoded.author, original.author)
        XCTAssertEqual(decoded.message, original.message)
    }

    // MARK: - Date precision: timestamp survives encode/decode

    func testDatePrecisionSurvivesRoundTrip() throws {
        let precise = Date(timeIntervalSince1970: 1_700_000_000.123)
        let original = Commit(tree: "t", parent: nil, author: "A", timestamp: precise, message: "m")
        let encoded = try original.encode()
        let decoded = try Commit.decode(encoded)
        XCTAssertEqual(decoded.timestamp.timeIntervalSince1970, precise.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - Codable: direct JSONEncoder/Decoder round-trip

    func testCodableDirectRoundTrip() throws {
        let original = Commit(tree: "t1", parent: "p1", author: "Author", timestamp: Date(), message: "msg")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let restored = try decoder.decode(Commit.self, from: data)
        XCTAssertEqual(restored.tree, original.tree)
        XCTAssertEqual(restored.parent, original.parent)
        XCTAssertEqual(restored.author, original.author)
        XCTAssertEqual(restored.message, original.message)
        XCTAssertEqual(restored.timestamp.timeIntervalSince1970, original.timestamp.timeIntervalSince1970, accuracy: 0.001)
    }
}
