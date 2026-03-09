import XCTest
@testable import VCS

final class LibCompressionTests: XCTestCase {
    func testLZFSERoundTrip() throws {
        let original = "Hello from LibCompression streaming API!".data(using: .utf8)! as NSData
        let compressed = try original.compression(with: .LZFSE, for: .compress)
        let decompressed = try compressed.compression(with: .LZFSE, for: .decompress)
        XCTAssertEqual(original, decompressed)
    }

    func testZLIBRoundTrip() throws {
        let original = "Testing ZLIB via LibCompression".data(using: .utf8)! as NSData
        let compressed = try original.compression(with: .ZLIB, for: .compress)
        let decompressed = try compressed.compression(with: .ZLIB, for: .decompress)
        XCTAssertEqual(original, decompressed)
    }

    func testLZ4RoundTrip() throws {
        let original = "Testing LZ4 via LibCompression".data(using: .utf8)! as NSData
        let compressed = try original.compression(with: .LZ4, for: .compress)
        let decompressed = try compressed.compression(with: .LZ4, for: .decompress)
        XCTAssertEqual(original, decompressed)
    }

    func testLZMARoundTrip() throws {
        let original = "Testing LZMA via LibCompression".data(using: .utf8)! as NSData
        let compressed = try original.compression(with: .LZMA, for: .compress)
        let decompressed = try compressed.compression(with: .LZMA, for: .decompress)
        XCTAssertEqual(original, decompressed)
    }

    func testDefaultAlgorithmIsLZFSE() throws {
        let original = "Default algorithm test".data(using: .utf8)! as NSData
        let compressed = try original.compression(for: .compress)
        let decompressed = try compressed.compression(for: .decompress)
        XCTAssertEqual(original, decompressed)
    }

    func testLargeDataStreaming() throws {
        let repeated = String(repeating: "StreamingCompressionTest!", count: 1000)
        let original = repeated.data(using: .utf8)! as NSData
        let compressed = try original.compression(with: .LZFSE, for: .compress)
        XCTAssertLessThan(compressed.length, original.length)
        let decompressed = try compressed.compression(with: .LZFSE, for: .decompress)
        XCTAssertEqual(original, decompressed)
    }
}
