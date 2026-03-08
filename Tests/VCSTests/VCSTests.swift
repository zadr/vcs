import XCTest
@testable import VCS

final class VCSTests: XCTestCase {
    func testExample() throws {
        XCTAssertTrue(true)
    }

    // --- LZFSE Round-Trip Tests ---

    func testLZFSERoundTrip() throws {
        let lzfse = LZFSECompression()
        let original = "Hello, LZFSE compression! This is a test string that should compress well when repeated. ".data(using: .utf8)!
        let compressed = try lzfse.compress(original)
        let decompressed = try lzfse.decompress(compressed)
        XCTAssertEqual(original, decompressed)
    }

    func testLZFSECompressesData() throws {
        let lzfse = LZFSECompression()
        let original = String(repeating: "ABCDEFGHIJ", count: 1000).data(using: .utf8)!
        let compressed = try lzfse.compress(original)
        XCTAssertLessThan(compressed.count, original.count, "Compressed data should be smaller")
    }

    // --- Registry Default Tests ---

    func testRegistryDefaultIsLZFSE() throws {
        let registry = CompressionRegistry()
        XCTAssertEqual(registry.defaultStrategy, "lzfse")
    }

    func testTextExtensionsMappedToLZFSE() throws {
        let registry = CompressionRegistry()
        let textExtensions = ["txt", "md", "swift", "rs", "js", "ts", "json", "xml", "html", "css"]
        for ext in textExtensions {
            let strategy = registry.getStrategy(forPath: "test.\(ext)")
            XCTAssertEqual(strategy.name, "lzfse", "Extension .\(ext) should use lzfse")
        }
    }

    func testZlibStillAvailable() throws {
        let registry = CompressionRegistry()
        let zlibStrategy = registry.getStrategy(byName: "zlib")
        XCTAssertNotNil(zlibStrategy)
        XCTAssertEqual(zlibStrategy?.name, "zlib")
    }

    func testZlibRoundTripStillWorks() throws {
        let zlib = ZlibCompression()
        let original = "Zlib backward compatibility test data that should compress and decompress correctly.".data(using: .utf8)!
        let compressed = try zlib.compress(original)
        let decompressed = try zlib.decompress(compressed)
        XCTAssertEqual(original, decompressed)
    }

    func testLZFSEEmptyDataRoundTrip() throws {
        let lzfse = LZFSECompression()
        let empty = Data()
        // Empty data may or may not compress; verify consistent behavior
        do {
            let compressed = try lzfse.compress(empty)
            let decompressed = try lzfse.decompress(compressed)
            XCTAssertEqual(empty, decompressed)
        } catch {
            // Throwing on empty data is acceptable behavior
        }
    }

    func testRegistryFallbackUsesLZFSE() throws {
        let registry = CompressionRegistry()
        // An unknown extension should fall back to the default strategy (lzfse)
        let strategy = registry.getStrategy(forPath: "file.unknownext")
        XCTAssertEqual(strategy.name, "lzfse")
    }

    func testLZFSEMultipleRoundTrips() throws {
        let lzfse = LZFSECompression()
        // Verify round-trip with several different payloads
        let payloads: [Data] = [
            "Short text".data(using: .utf8)!,
            String(repeating: "x", count: 256).data(using: .utf8)!,
            "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs.".data(using: .utf8)!,
        ]
        for original in payloads {
            let compressed = try lzfse.compress(original)
            let decompressed = try lzfse.decompress(compressed)
            XCTAssertEqual(original, decompressed, "Round-trip failed for payload of \(original.count) bytes")
        }
    }
}
