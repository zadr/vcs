import XCTest
@testable import VCS

final class ObjectStoreTests: TempDirectoryTestCase {
    var store: ObjectStore!
    var registry: CompressionRegistry!

    override func setUp() {
        super.setUp()
        registry = CompressionRegistry()
        store = ObjectStore(repositoryPath: tempDir, compressionRegistry: registry)
    }

    // MARK: - Write / Read

    func testWriteAndRead() throws {
        let data = Data("hello world".utf8)
        let hash = try store.write(data)
        let readData = try store.read(hash)
        XCTAssertEqual(readData, data)
    }

    func testWriteEmptyData() throws {
        let hash = try store.write(Data())
        let readData = try store.read(hash)
        XCTAssertEqual(readData, Data())
    }

    func testWriteLargeData() throws {
        let data = Data(repeating: 0x42, count: 5_000_000)
        let hash = try store.write(data)
        let readData = try store.read(hash)
        XCTAssertEqual(readData, data)
    }

    func testWriteDeterministic() throws {
        let data = Data("deterministic".utf8)
        let hash1 = try store.write(data)
        let hash2 = try store.write(data)
        XCTAssertEqual(hash1, hash2)
    }

    func testWriteIdempotent() throws {
        let data = Data("idempotent".utf8)
        let hash1 = try store.write(data)
        // Writing same data again should not error
        let hash2 = try store.write(data)
        XCTAssertEqual(hash1, hash2)
    }

    // MARK: - Read nonexistent

    func testReadNonexistent() {
        let randomHash = Hash(Data(repeating: 0xAB, count: 32))
        XCTAssertThrowsError(try store.read(randomHash))
    }

    // MARK: - Exists

    func testExistsWrittenHash() throws {
        let data = Data("exists".utf8)
        let hash = try store.write(data)
        XCTAssertTrue(store.exists(hash))
    }

    func testExistsNonexistent() {
        let randomHash = Hash(Data(repeating: 0xCD, count: 32))
        XCTAssertFalse(store.exists(randomHash))
    }

    // MARK: - Object path sharding

    func testObjectPathSharding() throws {
        let data = Data("shard test".utf8)
        let hash = try store.write(data)
        let hex = hash.hex
        let prefix = String(hex.prefix(2))
        let suffix = String(hex.dropFirst(2))

        let expectedPath = tempDir.appendingPathComponent(".vcs/objects")
            .appendingPathComponent(prefix)
            .appendingPathComponent(suffix)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    // MARK: - writeBlob / readBlob

    func testWriteBlobAndReadBlob() throws {
        let content = Data("file content".utf8)
        let hash = try store.writeBlob(content: content, path: "file.txt")
        let blob = try store.readBlob(hash)
        XCTAssertEqual(blob.content, content)
    }

    func testWriteBlobJPEGCustomTables() throws {
        let jpegData = buildCustomQuantJPEG()
        let hash = try store.writeBlob(content: jpegData, path: "photo.jpg")

        // readBlob should succeed without any manual setObjectStore call —
        // Blob.decode wires up the object store automatically
        let blob = try store.readBlob(hash)
        XCTAssertEqual(blob.compressionStrategy, "jpeg-header-strip")
        // Verify the decompressed content is a valid JPEG starting with SOI
        XCTAssertGreaterThanOrEqual(blob.content.count, 2)
        XCTAssertEqual(blob.content[0], 0xFF)
        XCTAssertEqual(blob.content[1], 0xD8)
    }

    func testWriteBlobJPEGCustomTablesStoresTablesAtCorrectHash() throws {
        let jpegData = buildCustomQuantJPEG()
        _ = try store.writeBlob(content: jpegData, path: "photo.jpg")

        // Verify the tables object is stored at Hash.compute(tablesData), not Hash.compute(headerObj)
        let jpegStrategy = registry.getStrategy(byName: "jpeg-header-strip") as! JPEGHeaderCompression
        let tablesData = try jpegStrategy.getTablesData(jpegData)!
        let tablesHash = Hash.compute(tablesData)
        XCTAssertTrue(store.exists(tablesHash), "Tables should be stored at the tablesData hash")

        // Verify the stored header object is correctly formatted
        let storedData = try store.read(tablesHash)
        let lines = storedData.split(separator: 0x0A, maxSplits: 2, omittingEmptySubsequences: false)
        XCTAssertEqual(String(data: Data(lines[0]), encoding: .utf8), "header")
        XCTAssertEqual(String(data: Data(lines[1]), encoding: .utf8), "jpeg-tables")
        XCTAssertEqual(Data(lines[2]), tablesData)
    }

    // MARK: - write(_:at:)

    func testWriteAtHashAndRead() throws {
        let data = Data("stored at specific hash".utf8)
        let hash = Hash.compute(Data("different content".utf8))
        try store.write(data, at: hash)

        let readData = try store.read(hash)
        XCTAssertEqual(readData, data)
    }

    func testWriteAtHashCreatesDirectoryStructure() throws {
        let data = Data("test".utf8)
        let hash = Hash.compute(data)
        try store.write(data, at: hash)
        XCTAssertTrue(store.exists(hash))
    }

    func testWriteBlobJPEGStandardTables() throws {
        let jpegData = buildMinimalJPEG()
        let hash = try store.writeBlob(content: jpegData, path: "photo.jpg")
        let blob = try store.readBlob(hash)
        XCTAssertEqual(blob.compressionStrategy, "jpeg-header-strip")
    }

    // MARK: - writeTree / readTree

    func testWriteTreeAndReadTree() throws {
        let tree = Tree(entries: [
            TreeEntry(name: "file.txt", hash: "abc123", isDirectory: false),
            TreeEntry(name: "dir", hash: "def456", isDirectory: true)
        ])
        let hash = try store.writeTree(tree)
        let readTree = try store.readTree(hash)
        XCTAssertEqual(readTree.entries.count, 2)
        XCTAssertEqual(readTree.entries[0].name, "file.txt")
        XCTAssertEqual(readTree.entries[1].name, "dir")
    }

    // MARK: - writeCommit / readCommit

    func testWriteCommitAndReadCommit() throws {
        let commit = Commit(
            tree: "treehash123",
            parent: nil,
            author: "Test Author",
            timestamp: Date(),
            message: "Initial commit"
        )
        let hash = try store.writeCommit(commit)
        let readCommit = try store.readCommit(hash)
        XCTAssertEqual(readCommit.tree, "treehash123")
        XCTAssertNil(readCommit.parent)
        XCTAssertEqual(readCommit.author, "Test Author")
        XCTAssertEqual(readCommit.message, "Initial commit")
    }

    // MARK: - Cross-type read errors

    func testReadBlobOnTreeData() throws {
        let tree = Tree(entries: [])
        let hash = try store.writeTree(tree)
        XCTAssertThrowsError(try store.readBlob(hash))
    }

    func testReadTreeOnBlobData() throws {
        let hash = try store.writeBlob(content: Data("hello".utf8), path: "file.txt")
        XCTAssertThrowsError(try store.readTree(hash))
    }

    func testReadCommitOnBlobData() throws {
        let hash = try store.writeBlob(content: Data("hello".utf8), path: "file.txt")
        XCTAssertThrowsError(try store.readCommit(hash))
    }
}
