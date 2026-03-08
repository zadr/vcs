import XCTest
@testable import VCS

final class NoCompressionTests: TempDirectoryTestCase {

    // MARK: - name

    func testNameIsNone() {
        let sut = NoCompression()
        XCTAssertEqual(sut.name, "none")
    }

    // MARK: - compress

    func testCompressReturnsIdentityForHello() throws {
        let sut = NoCompression()
        let input = Data("hello".utf8)
        let result = try sut.compress(input)
        XCTAssertEqual(result, input)
    }

    func testCompressEmptyDataReturnsEmpty() throws {
        let sut = NoCompression()
        let input = Data()
        let result = try sut.compress(input)
        XCTAssertEqual(result, input)
        XCTAssertTrue(result.isEmpty)
    }

    func testCompressLargeDataReturnsSame() throws {
        let sut = NoCompression()
        let input = Data(repeating: 0xAB, count: 1_000_000)
        let result = try sut.compress(input)
        XCTAssertEqual(result, input)
        XCTAssertEqual(result.count, 1_000_000)
    }

    // MARK: - decompress

    func testDecompressReturnsIdentityForHello() throws {
        let sut = NoCompression()
        let input = Data("hello".utf8)
        let result = try sut.decompress(input)
        XCTAssertEqual(result, input)
    }

    func testDecompressEmptyDataReturnsEmpty() throws {
        let sut = NoCompression()
        let input = Data()
        let result = try sut.decompress(input)
        XCTAssertEqual(result, input)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - round-trip

    func testRoundTripDecompressCompressReturnsOriginal() throws {
        let sut = NoCompression()
        let original = Data("round-trip test payload 🚀".utf8)
        let compressed = try sut.compress(original)
        let decompressed = try sut.decompress(compressed)
        XCTAssertEqual(decompressed, original)
    }

    // MARK: - setObjectStore

    func testSetObjectStoreDoesNotCrash() throws {
        let sut = NoCompression()
        let store = makeObjectStore(at: tempDir)
        sut.setObjectStore(store)
        // Verify compression still works after setObjectStore
        let data = Data("test".utf8)
        let result = try sut.decompress(sut.compress(data))
        XCTAssertEqual(result, data)
    }
}
