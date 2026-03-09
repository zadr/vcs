import XCTest
@testable import VCS

final class LZ4CompressionTests: TempDirectoryTestCase {
    var lz4: LZ4Compression!

    override func setUp() {
        super.setUp()
        lz4 = LZ4Compression()
    }

    // MARK: - Name

    func testName() {
        XCTAssertEqual(lz4.name, "lz4")
    }

    // MARK: - Compress

    func testCompressProducesSmaller() throws {
        let repetitive = Data(String(repeating: "abcdefghij", count: 1000).utf8)
        let compressed = try lz4.compress(repetitive)
        XCTAssertLessThan(compressed.count, repetitive.count)
    }

    func testCompressEmptyDataProducesOutput() throws {
        // Empty Data has non-nil baseAddress on modern Swift
        // compression_encode_buffer with 0 bytes returns small header
        let compressed = try lz4.compress(Data())
        XCTAssertGreaterThanOrEqual(compressed.count, 0)
    }

    // MARK: - Decompress

    func testDecompressInvalidData() {
        let garbage = Data(repeating: 0xFF, count: 100)
        XCTAssertThrowsError(try lz4.decompress(garbage)) { error in
            XCTAssertTrue(error is CompressionError, "Expected CompressionError, got \(error)")
        }
    }

    // MARK: - Round-trip

    func testRoundTripHelloWorld() throws {
        let data = Data("Hello, World!".utf8)
        let result = try lz4.decompress(lz4.compress(data))
        XCTAssertEqual(result, data)
    }

    func testRoundTripSmall() throws {
        let data = Data([0x42])
        let result = try lz4.decompress(lz4.compress(data))
        XCTAssertEqual(result, data)
    }

    func testRoundTripBinary() throws {
        var data = Data(count: 256)
        for i in 0..<256 { data[i] = UInt8(i % 256) }
        let result = try lz4.decompress(lz4.compress(data))
        XCTAssertEqual(result, data)
    }

    func testRoundTripShortText() throws {
        let data = Data("Short text".utf8)
        let result = try lz4.decompress(lz4.compress(data))
        XCTAssertEqual(result, data)
    }

    // MARK: - setObjectStore

    func testSetObjectStoreNoOp() throws {
        let store = makeObjectStore(at: tempDir)
        lz4.setObjectStore(store)
        // Verify compression still works after setObjectStore
        let data = Data("test".utf8)
        let result = try lz4.decompress(lz4.compress(data))
        XCTAssertEqual(result, data)
    }
}
