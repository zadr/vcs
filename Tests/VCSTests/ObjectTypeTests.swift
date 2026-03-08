import XCTest
@testable import VCS

final class ObjectTypeTests: XCTestCase {

    // MARK: - Case Existence

    func testAllCasesExist() {
        // Verify the three expected cases can be constructed.
        let cases: [ObjectType] = [.blob, .tree, .commit]
        XCTAssertEqual(cases.count, 3)
    }

    func testCasesAreDistinct() {
        XCTAssertNotEqual(ObjectType.blob, ObjectType.tree)
        XCTAssertNotEqual(ObjectType.blob, ObjectType.commit)
        XCTAssertNotEqual(ObjectType.tree, ObjectType.commit)
    }

    // MARK: - Raw Values

    func testBlobRawValue() {
        XCTAssertEqual(ObjectType.blob.rawValue, "blob")
    }

    func testTreeRawValue() {
        XCTAssertEqual(ObjectType.tree.rawValue, "tree")
    }

    func testCommitRawValue() {
        XCTAssertEqual(ObjectType.commit.rawValue, "commit")
    }

    // MARK: - Init From Raw Value

    func testInitFromRawValueBlob() {
        let type = ObjectType(rawValue: "blob")
        XCTAssertEqual(type, .blob)
    }

    func testInitFromRawValueTree() {
        let type = ObjectType(rawValue: "tree")
        XCTAssertEqual(type, .tree)
    }

    func testInitFromRawValueCommit() {
        let type = ObjectType(rawValue: "commit")
        XCTAssertEqual(type, .commit)
    }

    func testInitFromInvalidRawValueTag() {
        XCTAssertNil(ObjectType(rawValue: "tag"))
    }

    func testInitFromEmptyRawValue() {
        XCTAssertNil(ObjectType(rawValue: ""))
    }

    // MARK: - Codable: Encode

    func testEncodeEachCase() throws {
        let encoder = JSONEncoder()
        for (objectType, expected) in [
            (ObjectType.blob, "blob"),
            (ObjectType.tree, "tree"),
            (ObjectType.commit, "commit"),
        ] {
            let data = try encoder.encode(objectType)
            let jsonString = String(data: data, encoding: .utf8)
            XCTAssertEqual(jsonString, "\"\(expected)\"")
        }
    }

    // MARK: - Codable: Decode

    func testDecodeValidCases() throws {
        let decoder = JSONDecoder()
        for (json, expected) in [
            ("\"blob\"", ObjectType.blob),
            ("\"tree\"", ObjectType.tree),
            ("\"commit\"", ObjectType.commit),
        ] {
            let data = Data(json.utf8)
            let decoded = try decoder.decode(ObjectType.self, from: data)
            XCTAssertEqual(decoded, expected)
        }
    }

    func testDecodeInvalidValueThrows() {
        let data = Data("\"tag\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ObjectType.self, from: data))
    }

    // MARK: - Codable: Round-Trip

    func testRoundTripAllCases() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in [ObjectType.blob, .tree, .commit] {
            let data = try encoder.encode(original)
            let restored = try decoder.decode(ObjectType.self, from: data)
            XCTAssertEqual(original, restored)
        }
    }
}
