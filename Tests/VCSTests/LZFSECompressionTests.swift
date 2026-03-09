import XCTest
@testable import VCS

final class LZFSECompressionTests: XCTestCase {
    let strategy = LZFSECompression()

    func testName() {
        XCTAssertEqual(strategy.name, "lzfse")
    }

    func testRoundTrip() throws {
        let original = Data("Hello, LZFSE compression!".utf8)
        let compressed = try strategy.compress(original)
        let decompressed = try strategy.decompress(compressed)
        XCTAssertEqual(original, decompressed)
    }

    func testRoundTripLargeData() throws {
        // Generate data larger than the 10x decompression buffer heuristic
        let chunk = Data(repeating: 0x42, count: 1024)
        var large = Data()
        for _ in 0..<100 {
            large.append(chunk)
        }
        XCTAssertEqual(large.count, 102_400)

        let compressed = try strategy.compress(large)
        let decompressed = try strategy.decompress(compressed)
        XCTAssertEqual(large, decompressed)
    }

    func testCompressedSmallerThanOriginal() throws {
        let original = Data(repeating: 0xAA, count: 10_000)
        let compressed = try strategy.compress(original)
        XCTAssertLessThan(compressed.count, original.count,
            "Compressed size (\(compressed.count)) should be less than original (\(original.count)) for repetitive data")
    }

    func testRoundTripVariousPayloads() throws {
        let payloads: [Data] = [
            Data("Short".utf8),
            Data(String(repeating: "abcdefghij", count: 500).utf8),
            Data((0..<256).map { UInt8($0) }),
        ]

        for (i, original) in payloads.enumerated() {
            let compressed = try strategy.compress(original)
            let decompressed = try strategy.decompress(compressed)
            XCTAssertEqual(original, decompressed, "Round-trip failed for payload \(i)")
        }
    }

    func testDecompressInvalidDataThrows() {
        let garbage = Data([0xFF, 0xFE, 0xFD, 0x00, 0x01])
        XCTAssertThrowsError(try strategy.decompress(garbage)) { error in
            guard case CompressionError.decompressionFailed = error else {
                XCTFail("Expected CompressionError.decompressionFailed, got \(error)")
                return
            }
        }
    }

    func testRegistryContainsLZFSE() {
        let registry = CompressionRegistry()
        XCTAssertNotNil(registry.getStrategy(byName: "lzfse"))
    }

    func testRegistryLZFSEIsCorrectType() {
        let registry = CompressionRegistry()
        let strategy = registry.getStrategy(byName: "lzfse")
        XCTAssertTrue(strategy is LZFSECompression)
    }
}
