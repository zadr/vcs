import XCTest
@testable import VCS

final class HashTests: XCTestCase {

    // MARK: - init with Data

    func testInitWithEmptyData() {
        let hash = Hash(Data())
        XCTAssertEqual(hash.data, Data())
        XCTAssertEqual(hash.hex, "")
    }

    func testInitWithSmallData() {
        let hash = Hash(Data([0xAB, 0xCD]))
        XCTAssertEqual(hash.data, Data([0xAB, 0xCD]))
        XCTAssertEqual(hash.hex, "abcd")
    }

    func testInitWithLargeData() {
        let largeData = Data(repeating: 0x42, count: 1_000_000)
        let hash = Hash(largeData)
        XCTAssertEqual(hash.data.count, 1_000_000)
        XCTAssertEqual(hash.data, largeData)
    }

    // MARK: - init?(hex:)

    func testInitHexWithValidLowercase() {
        let hash = Hash(hex: "abcdef01")
        XCTAssertNotNil(hash)
        XCTAssertEqual(hash?.data, Data([0xAB, 0xCD, 0xEF, 0x01]))
    }

    func testInitHexWithValidUppercase() {
        let hash = Hash(hex: "ABCDEF01")
        XCTAssertNotNil(hash)
        XCTAssertEqual(hash?.data, Data([0xAB, 0xCD, 0xEF, 0x01]))
    }

    func testInitHexWithMixedCase() {
        let hash = Hash(hex: "aBcDeF01")
        XCTAssertNotNil(hash)
        XCTAssertEqual(hash?.data, Data([0xAB, 0xCD, 0xEF, 0x01]))
    }

    func testInitHexWithEmptyString() {
        let hash = Hash(hex: "")
        XCTAssertNotNil(hash)
        XCTAssertEqual(hash?.data, Data())
    }

    func testInitHexWithInvalidChars() {
        let hash = Hash(hex: "ZZZZ")
        XCTAssertNil(hash)
    }

    func testInitHexWithPartiallyInvalidChars() {
        let hash = Hash(hex: "ab__cd")
        XCTAssertNil(hash)
    }

    func testInitHexWithOddLengthReturnsNil() {
        // Regression test for issue #6: odd-length hex strings should return nil, not crash
        XCTAssertNil(Hash(hex: "a"))
        XCTAssertNil(Hash(hex: "abc"))
        XCTAssertNil(Hash(hex: "abcde"))
    }

    func testInitHexWithValidEvenLengthSucceeds() {
        // Short even-length strings should succeed (complement to odd-length regression test)
        XCTAssertNotNil(Hash(hex: "ab"))
        XCTAssertNotNil(Hash(hex: "abcd"))
    }

    // MARK: - hex property

    func testHexRoundTrip() {
        let original = "abcdef0123456789"
        let hash = Hash(hex: original)
        XCTAssertNotNil(hash)
        XCTAssertEqual(hash?.hex, original)
    }

    func testHexOutputIsLowercase() {
        let hash = Hash(Data([0x00, 0xFF]))
        XCTAssertEqual(hash.hex, "00ff")
    }

    func testHexUppercaseInputProducesLowercaseOutput() {
        let hash = Hash(hex: "AABB")
        XCTAssertEqual(hash?.hex, "aabb")
    }

    // MARK: - description

    func testDescriptionEqualsHex() {
        let hash = Hash(Data([0xDE, 0xAD, 0xBE, 0xEF]))
        XCTAssertEqual(hash.description, hash.hex)
    }

    func testDescriptionEqualsHexForEmpty() {
        let hash = Hash(Data())
        XCTAssertEqual(hash.description, hash.hex)
        XCTAssertEqual(hash.description, "")
    }

    // MARK: - compute(Data)

    func testComputeEmptyData() {
        let hash = Hash.compute(Data())
        XCTAssertEqual(
            hash.hex,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testComputeHelloData() {
        let hash = Hash.compute(Data("hello".utf8))
        XCTAssertEqual(
            hash.hex,
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }

    func testComputeLargeData() {
        let largeData = Data(repeating: 0x00, count: 1_000_000)
        let hash = Hash.compute(largeData)
        XCTAssertEqual(hash.data.count, 32)
        XCTAssertFalse(hash.hex.isEmpty)
    }

    func testComputeIsDeterministic() {
        let data = Data("determinism check".utf8)
        let hash1 = Hash.compute(data)
        let hash2 = Hash.compute(data)
        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash1.hex, hash2.hex)
    }

    // MARK: - compute(String)

    func testComputeStringHelloMatchesDataOverload() {
        let fromString = Hash.compute("hello")
        let fromData = Hash.compute(Data("hello".utf8))
        XCTAssertEqual(fromString, fromData)
        XCTAssertEqual(fromString.hex, fromData.hex)
    }

    func testComputeEmptyString() {
        let hash = Hash.compute("")
        XCTAssertEqual(
            hash.hex,
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testComputeUnicodeString() {
        let hash = Hash.compute("你好🌍")
        XCTAssertEqual(hash.data.count, 32)
        // Verify it matches the Data-based overload with the same UTF-8 bytes.
        let fromData = Hash.compute(Data("你好🌍".utf8))
        XCTAssertEqual(hash, fromData)
    }

    // MARK: - Hashable

    func testEqualHashesAreEqual() {
        let a = Hash(Data([0x01, 0x02]))
        let b = Hash(Data([0x01, 0x02]))
        XCTAssertEqual(a, b)
    }

    func testDifferentHashesAreNotEqual() {
        let a = Hash(Data([0x01, 0x02]))
        let b = Hash(Data([0x03, 0x04]))
        XCTAssertNotEqual(a, b)
    }

    func testSetInsertionDeduplicates() {
        let hash = Hash.compute("duplicate")
        var set: Set<Hash> = []
        set.insert(hash)
        set.insert(hash)
        XCTAssertEqual(set.count, 1)
    }

    func testDictionaryKeyUsage() {
        let key = Hash.compute("key")
        var dict: [Hash: String] = [:]
        dict[key] = "value"
        XCTAssertEqual(dict[key], "value")

        // Lookup with an independently computed identical hash must succeed.
        let sameKey = Hash.compute("key")
        XCTAssertEqual(dict[sameKey], "value")
    }
}
