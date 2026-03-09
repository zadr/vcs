import XCTest
@testable import VCS

final class CompressionTests: XCTestCase {

    // MARK: - Zlib

    func testZlibHighlyCompressibleRoundTrip() throws {
        let zlib = ZlibCompression()
        let original = Data(repeating: 0x00, count: 100_000)
        let compressed = try zlib.compress(original)
        let decompressed = try zlib.decompress(compressed)
        XCTAssertEqual(decompressed, original, "Zlib round-trip must preserve all data for highly compressible input")
    }

    func testZlibModeratelyCompressibleRoundTrip() throws {
        let zlib = ZlibCompression()
        var data = Data(count: 50_000)
        for i in 0..<data.count { data[i] = UInt8(i % 4) }
        let decompressed = try zlib.decompress(try zlib.compress(data))
        XCTAssertEqual(decompressed, data)
    }

    func testZlibRandomDataRoundTrip() throws {
        let zlib = ZlibCompression()
        var data = Data(count: 10_000)
        for i in 0..<data.count { data[i] = UInt8.random(in: 0...255) }
        let decompressed = try zlib.decompress(try zlib.compress(data))
        XCTAssertEqual(decompressed, data)
    }

    // MARK: - LZ4

    func testLZ4HighlyCompressibleRoundTrip() throws {
        let lz4 = LZ4Compression()
        let original = Data(repeating: 0x00, count: 100_000)
        let compressed = try lz4.compress(original)
        let decompressed = try lz4.decompress(compressed)
        XCTAssertEqual(decompressed, original, "LZ4 round-trip must preserve all data for highly compressible input")
    }

    func testLZ4ModeratelyCompressibleRoundTrip() throws {
        let lz4 = LZ4Compression()
        var data = Data(count: 50_000)
        for i in 0..<data.count { data[i] = UInt8(i % 4) }
        let decompressed = try lz4.decompress(try lz4.compress(data))
        XCTAssertEqual(decompressed, data)
    }

    func testLZ4RandomDataRoundTrip() throws {
        let lz4 = LZ4Compression()
        var data = Data(count: 10_000)
        for i in 0..<data.count { data[i] = UInt8.random(in: 0...255) }
        let decompressed = try lz4.decompress(try lz4.compress(data))
        XCTAssertEqual(decompressed, data)
    }

    // MARK: - Edge cases

    func testZlibSmallDataRoundTrip() throws {
        let zlib = ZlibCompression()
        let original = Data([0x42])
        let decompressed = try zlib.decompress(try zlib.compress(original))
        XCTAssertEqual(decompressed, original)
    }

    func testLZ4SmallDataRoundTrip() throws {
        let lz4 = LZ4Compression()
        let original = Data([0x42])
        let decompressed = try lz4.decompress(try lz4.compress(original))
        XCTAssertEqual(decompressed, original)
    }

    func testZlibHighCompressionRatioExceedsInitialBuffer() throws {
        let zlib = ZlibCompression()
        let original = Data(repeating: 0x00, count: 100_000)
        let compressed = try zlib.compress(original)
        // Verify the compression ratio is extreme enough that the old fixed 10x buffer would truncate
        let ratio = Double(original.count) / Double(compressed.count)
        XCTAssertGreaterThan(ratio, 10.0, "Compression ratio must exceed 10x to validate the buffer growth fix")
        let decompressed = try zlib.decompress(compressed)
        XCTAssertEqual(decompressed.count, original.count, "Decompressed size must match original — old code would truncate here")
    }

    func testLZ4HighCompressionRatioExceedsInitialBuffer() throws {
        let lz4 = LZ4Compression()
        let original = Data(repeating: 0x00, count: 100_000)
        let compressed = try lz4.compress(original)
        let ratio = Double(original.count) / Double(compressed.count)
        XCTAssertGreaterThan(ratio, 10.0, "Compression ratio must exceed 10x to validate the buffer growth fix")
        let decompressed = try lz4.decompress(compressed)
        XCTAssertEqual(decompressed.count, original.count, "Decompressed size must match original — old code would truncate here")
    }
}
