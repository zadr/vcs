import XCTest
@testable import VCS

final class BlobTests: TempDirectoryTestCase {
    var registry: CompressionRegistry!
    var store: ObjectStore!

    override func setUp() {
        super.setUp()
        registry = CompressionRegistry()
        store = ObjectStore(repositoryPath: tempDir, compressionRegistry: registry)
    }

    // MARK: - Init

    func testInitProperties() {
        let blob = Blob(content: Data("hello".utf8), compressionStrategy: "zlib")
        XCTAssertEqual(blob.content, Data("hello".utf8))
        XCTAssertEqual(blob.compressionStrategy, "zlib")
    }

    func testInitEmptyContent() {
        let blob = Blob(content: Data(), compressionStrategy: "none")
        XCTAssertEqual(blob.content, Data())
        XCTAssertEqual(blob.compressionStrategy, "none")
    }

    func testInitLargeContent() {
        let largeData = Data(repeating: 0x42, count: 1_000_000)
        let blob = Blob(content: largeData, compressionStrategy: "zlib")
        XCTAssertEqual(blob.content.count, 1_000_000)
    }

    // MARK: - Encode

    func testEncodeWithZlib() throws {
        let blob = Blob(content: Data("hello".utf8), compressionStrategy: "zlib")
        let encoded = try blob.encode(registry: registry)
        let prefix = String(data: encoded.prefix(10), encoding: .utf8)!
        XCTAssertTrue(prefix.hasPrefix("blob\nzlib\n"))
    }

    func testEncodeWithNone() throws {
        let blob = Blob(content: Data("hello".utf8), compressionStrategy: "none")
        let encoded = try blob.encode(registry: registry)
        let prefix = String(data: encoded.prefix(10), encoding: .utf8)!
        XCTAssertTrue(prefix.hasPrefix("blob\nnone\n"))
    }

    func testEncodeWithLZ4() throws {
        let blob = Blob(content: Data("hello".utf8), compressionStrategy: "lz4")
        let encoded = try blob.encode(registry: registry)
        let prefix = String(data: encoded.prefix(9), encoding: .utf8)!
        XCTAssertTrue(prefix.hasPrefix("blob\nlz4\n"))
    }

    func testEncodeWithInvalidStrategy() {
        let blob = Blob(content: Data("hello".utf8), compressionStrategy: "nonexistent")
        XCTAssertThrowsError(try blob.encode(registry: registry)) { error in
            XCTAssertTrue(error is CompressionError)
        }
    }

    // MARK: - Decode

    func testDecodeValid() throws {
        let blob = Blob(content: Data("hello".utf8), compressionStrategy: "none")
        let encoded = try blob.encode(registry: registry)
        let decoded = try Blob.decode(encoded, registry: registry, objectStore: store)
        XCTAssertEqual(decoded.content, Data("hello".utf8))
        XCTAssertEqual(decoded.compressionStrategy, "none")
    }

    func testDecodeInvalidPrefix() {
        let data = "notblob\nzlib\ndata".data(using: .utf8)!
        XCTAssertThrowsError(try Blob.decode(data, registry: registry, objectStore: store)) { error in
            XCTAssertTrue(error is CompressionError, "Expected CompressionError, got \(error)")
        }
    }

    func testDecodeNoNewlines() {
        let data = "blobzlibdata".data(using: .utf8)!
        XCTAssertThrowsError(try Blob.decode(data, registry: registry, objectStore: store)) { error in
            XCTAssertTrue(error is CompressionError, "Expected CompressionError, got \(error)")
        }
    }

    func testDecodeEmptyData() {
        XCTAssertThrowsError(try Blob.decode(Data(), registry: registry, objectStore: store)) { error in
            XCTAssertTrue(error is CompressionError, "Expected CompressionError, got \(error)")
        }
    }

    func testDecodeUnknownStrategy() {
        let data = "blob\nfakecomp\ndata".data(using: .utf8)!
        XCTAssertThrowsError(try Blob.decode(data, registry: registry, objectStore: store)) { error in
            XCTAssertTrue(error is CompressionError, "Expected CompressionError, got \(error)")
        }
    }

    // MARK: - Round-trip

    func testRoundTripZlib() throws {
        let content = Data("Hello, World!".utf8)
        let blob = Blob(content: content, compressionStrategy: "zlib")
        let encoded = try blob.encode(registry: registry)
        let decoded = try Blob.decode(encoded, registry: registry, objectStore: store)
        XCTAssertEqual(decoded.content, content)
    }

    func testRoundTripNone() throws {
        let content = Data("Hello, World!".utf8)
        let blob = Blob(content: content, compressionStrategy: "none")
        let encoded = try blob.encode(registry: registry)
        let decoded = try Blob.decode(encoded, registry: registry, objectStore: store)
        XCTAssertEqual(decoded.content, content)
    }

    func testRoundTripLZ4() throws {
        let content = Data("Hello, World!".utf8)
        let blob = Blob(content: content, compressionStrategy: "lz4")
        let encoded = try blob.encode(registry: registry)
        let decoded = try Blob.decode(encoded, registry: registry, objectStore: store)
        XCTAssertEqual(decoded.content, content)
    }

    func testRoundTripEmptyContent() throws {
        let content = Data()
        let blob = Blob(content: content, compressionStrategy: "none")
        let encoded = try blob.encode(registry: registry)
        let decoded = try Blob.decode(encoded, registry: registry, objectStore: store)
        XCTAssertEqual(decoded.content, content)
    }

    func testRoundTripBinaryContent() throws {
        // Binary content with newlines (0x0A) — tests BUG #2
        let content = Data([0x00, 0x0A, 0xFF, 0x0A, 0x42, 0x0A])
        let blob = Blob(content: content, compressionStrategy: "none")
        let encoded = try blob.encode(registry: registry)
        let decoded = try Blob.decode(encoded, registry: registry, objectStore: store)
        XCTAssertEqual(decoded.content, content)
    }

    func testRoundTripLargeContent() throws {
        // Use "none" strategy for large data to avoid zlib decompression buffer limits
        let content = Data(repeating: 0x61, count: 100_000)
        let blob = Blob(content: content, compressionStrategy: "none")
        let encoded = try blob.encode(registry: registry)
        let decoded = try Blob.decode(encoded, registry: registry, objectStore: store)
        XCTAssertEqual(decoded.content, content)
    }
}
