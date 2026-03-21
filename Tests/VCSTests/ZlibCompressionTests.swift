import XCTest
@testable import VCS

final class ZlibCompressionTests: TempDirectoryTestCase {
    var zlib: ZlibCompression!

    override func setUp() {
        super.setUp()
        zlib = ZlibCompression()
    }

    // MARK: - Name

    func testName() {
        XCTAssertEqual(zlib.name, "zlib")
    }

    // MARK: - Compress

    func testCompressProducesSmaller() throws {
        let repetitive = Data(String(repeating: "abcdefghij", count: 1000).utf8)
        let compressed = try zlib.compress(repetitive)
        XCTAssertLessThan(compressed.count, repetitive.count)
    }

    func testCompressEmptyDataProducesOutput() throws {
        // On modern Swift, empty Data has non-nil baseAddress
        // compression_encode_buffer with 0 bytes produces a small zlib header (2 bytes)
        let compressed = try zlib.compress(Data())
        XCTAssertGreaterThan(compressed.count, 0)
    }

    func testCompressProducesNonEmptyOutput() throws {
        let data = Data([0x42])
        let compressed = try zlib.compress(data)
        XCTAssertGreaterThan(compressed.count, 0)
    }

    // MARK: - Decompress

    func testDecompressInvalidData() throws {
        // All 0xFF bytes are not valid zlib — decompress returns 0
        let garbage = Data(repeating: 0xFF, count: 100)
        XCTAssertThrowsError(try zlib.decompress(garbage))
    }

    func testDecompressEmptyCompressedData() {
        // Empty data is not valid zlib — decompress should throw
        XCTAssertThrowsError(try zlib.decompress(Data())) { error in
            XCTAssertTrue(error is CompressionError, "Expected CompressionError, got \(error)")
        }
    }

    // MARK: - Round-trip

    func testRoundTripHelloWorld() throws {
        let data = Data("Hello, World!".utf8)
        let result = try zlib.decompress(zlib.compress(data))
        XCTAssertEqual(result, data)
    }

    func testRoundTripSmall() throws {
        let data = Data([0x42])
        let result = try zlib.decompress(zlib.compress(data))
        XCTAssertEqual(result, data)
    }

    func testRoundTripBinary() throws {
        // 256 unique bytes — low compression ratio
        var data = Data(count: 256)
        for i in 0..<256 { data[i] = UInt8(i) }
        let result = try zlib.decompress(zlib.compress(data))
        XCTAssertEqual(result, data)
    }

    func testRoundTripShortText() throws {
        let data = Data("Short text".utf8)
        let result = try zlib.decompress(zlib.compress(data))
        XCTAssertEqual(result, data)
    }

    func testRoundTripHighEntropyData() throws {
        // Data that doesn't compress much — buffer is sufficient
        var data = Data(count: 500)
        for i in 0..<500 { data[i] = UInt8(i % 256) }
        let result = try zlib.decompress(zlib.compress(data))
        XCTAssertEqual(result, data)
    }

    // MARK: - Decompression buffer growth

    func testLargeCompressibleDataDecompressBufferGrowth() throws {
        // Highly compressible data: compressed * 10 < original size
        // Verifies that the retry loop grows the buffer and decompresses correctly
        let data = Data(repeating: 0x00, count: 100_000)
        let compressed = try zlib.compress(data)
        XCTAssertLessThan(compressed.count * 10, data.count,
            "Expected compressed*10 < original to exercise buffer growth")
        let decompressed = try zlib.decompress(compressed)
        XCTAssertEqual(decompressed, data, "Decompression should recover all data via buffer growth")
    }

    // MARK: - Determinism

    func testCompressDeterministic() throws {
        let data = Data("deterministic test input".utf8)
        let result1 = try zlib.compress(data)
        let result2 = try zlib.compress(data)
        XCTAssertEqual(result1, result2)
    }

    // MARK: - setObjectStore

    func testSetObjectStoreNoOp() throws {
        let store = makeObjectStore(at: tempDir)
        zlib.setObjectStore(store)
        // Verify compression still works after setObjectStore
        let data = Data("test".utf8)
        let result = try zlib.decompress(zlib.compress(data))
        XCTAssertEqual(result, data)
    }
}
