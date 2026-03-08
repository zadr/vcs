import XCTest
@testable import VCS

final class JPEGHeaderCompressionTests: TempDirectoryTestCase {

    private var jpeg: JPEGHeaderCompression!

    override func setUp() {
        super.setUp()
        jpeg = JPEGHeaderCompression()
    }

    override func tearDown() {
        jpeg = nil
        super.tearDown()
    }

    // MARK: - A) compress() tests

    func testCompressNotJPEGThrows() {
        let data = Data([0x00, 0x00])
        XCTAssertThrowsError(try jpeg.compress(data)) { error in
            guard case CompressionError.compressionFailed(let msg) = error else {
                return XCTFail("Expected compressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Not a valid JPEG"), "Message was: \(msg)")
        }
    }

    func testCompressTooShortThrows() {
        let data = Data([0xFF])
        XCTAssertThrowsError(try jpeg.compress(data)) { error in
            guard case CompressionError.compressionFailed(let msg) = error else {
                return XCTFail("Expected compressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Not a valid JPEG"), "Message was: \(msg)")
        }
    }

    func testCompressEmptyDataThrows() {
        let data = Data()
        XCTAssertThrowsError(try jpeg.compress(data)) { error in
            guard case CompressionError.compressionFailed(let msg) = error else {
                return XCTFail("Expected compressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Not a valid JPEG"), "Message was: \(msg)")
        }
    }

    func testCompressStandardTablesProducesVersion02() throws {
        let data = buildMinimalJPEG()
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x02)
    }

    func testCompressStandardTablesDimensionsEncoded() throws {
        let width: UInt16 = 320
        let height: UInt16 = 240
        let data = buildMinimalJPEG(width: width, height: height)
        let compressed = try jpeg.compress(data)

        let encodedWidth = UInt16(compressed[1]) << 8 | UInt16(compressed[2])
        let encodedHeight = UInt16(compressed[3]) << 8 | UInt16(compressed[4])
        XCTAssertEqual(encodedWidth, width)
        XCTAssertEqual(encodedHeight, height)
    }

    func testCompressCustomTablesProducesVersion04() throws {
        let data = buildCustomQuantJPEG()
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x04)
    }

    func testCompressCustomTablesHas32ByteHashAfterHeader() throws {
        let data = buildCustomQuantJPEG()
        let compressed = try jpeg.compress(data)
        // Version (1) + dims (4) + hash (32) + scan data
        XCTAssertGreaterThanOrEqual(compressed.count, 37)
        // Hash is bytes 5..<37
        let hashBytes = compressed[5..<37]
        XCTAssertEqual(hashBytes.count, 32)
    }

    func testCompressSmallDimensions1x1() throws {
        let data = buildMinimalJPEG(width: 1, height: 1)
        let compressed = try jpeg.compress(data)
        let w = UInt16(compressed[1]) << 8 | UInt16(compressed[2])
        let h = UInt16(compressed[3]) << 8 | UInt16(compressed[4])
        XCTAssertEqual(w, 1)
        XCTAssertEqual(h, 1)
    }

    func testCompressLargeDimensions65535x65535() throws {
        let data = buildMinimalJPEG(width: 65535, height: 65535)
        let compressed = try jpeg.compress(data)
        let w = UInt16(compressed[1]) << 8 | UInt16(compressed[2])
        let h = UInt16(compressed[3]) << 8 | UInt16(compressed[4])
        XCTAssertEqual(w, 65535)
        XCTAssertEqual(h, 65535)
    }

    func testCompressZeroDimensions() throws {
        let data = buildMinimalJPEG(width: 0, height: 0)
        let compressed = try jpeg.compress(data)
        let w = UInt16(compressed[1]) << 8 | UInt16(compressed[2])
        let h = UInt16(compressed[3]) << 8 | UInt16(compressed[4])
        XCTAssertEqual(w, 0)
        XCTAssertEqual(h, 0)
    }

    func testCompressTruncatedSegmentThrows() {
        // Build a JPEG SOI + start of a DQT marker but truncate before length can be read
        let data = Data([0xFF, 0xD8, 0xFF, 0xDB])
        // No length bytes follow -- position + 2 > data.count
        XCTAssertThrowsError(try jpeg.compress(data)) { error in
            guard case CompressionError.compressionFailed(let msg) = error else {
                return XCTFail("Expected compressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Truncated"), "Message was: \(msg)")
        }
    }

    func testCompressTruncatedSOFThrows() {
        // Build a valid JPEG but with SOF segment too short for dimensions
        var data = Data()
        data.append(contentsOf: [0xFF, 0xD8]) // SOI
        data.append(contentsOf: [0xFF, 0xC0]) // SOF
        data.append(contentsOf: [0x00, 0x05]) // length = 5 (too short: need pos+7 <= count)
        data.append(0x08) // precision
        // Only 2 more bytes but need 4 for height+width
        data.append(contentsOf: [0x00, 0x08])
        XCTAssertThrowsError(try jpeg.compress(data)) { error in
            guard case CompressionError.compressionFailed(let msg) = error else {
                return XCTFail("Expected compressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Truncated SOF"), "Message was: \(msg)")
        }
    }

    func testCompressNoSOFMarkerThrows() {
        let data = buildMinimalJPEG(includeSOF: false)
        XCTAssertThrowsError(try jpeg.compress(data)) { error in
            guard case CompressionError.compressionFailed(let msg) = error else {
                return XCTFail("Expected compressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Could not find"), "Message was: \(msg)")
        }
    }

    func testCompressNoSOSMarkerThrows() {
        let data = buildMinimalJPEG(includeSOS: false)
        XCTAssertThrowsError(try jpeg.compress(data)) { error in
            guard case CompressionError.compressionFailed(let msg) = error else {
                return XCTFail("Expected compressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Could not find"), "Message was: \(msg)")
        }
    }

    func testCompressProgressiveJPEG() throws {
        let data = buildMinimalJPEG(width: 100, height: 200, sofMarker: 0xC2)
        let compressed = try jpeg.compress(data)
        let w = UInt16(compressed[1]) << 8 | UInt16(compressed[2])
        let h = UInt16(compressed[3]) << 8 | UInt16(compressed[4])
        XCTAssertEqual(w, 100)
        XCTAssertEqual(h, 200)
    }

    func testCompressRSTMarkersSkipped() throws {
        // RST markers (0xD0-0xD7) should be skipped without issue
        let extraMarkers: [(UInt8, Data)] = [
            (0xD0, Data()),
            (0xD3, Data()),
            (0xD7, Data()),
        ]
        let data = buildMinimalJPEG(extraMarkers: extraMarkers)
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x02)
    }

    func testCompressTEMMarkerSkipped() throws {
        let extraMarkers: [(UInt8, Data)] = [(0x01, Data())]
        let data = buildMinimalJPEG(extraMarkers: extraMarkers)
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x02)
    }

    func testCompressMultipleQuantTablesCaptured() throws {
        // Standard JPEG already has 2 quant tables; verify compress succeeds
        let data = buildMinimalJPEG()
        let compressed = try jpeg.compress(data)
        // Standard tables -> version 0x02
        XCTAssertEqual(compressed[0], 0x02)
        // Scan data is present after header
        XCTAssertGreaterThan(compressed.count, 5)
    }

    // MARK: - B) decompress() tests

    func testDecompressTooShortThrows() {
        let data = Data([0x02, 0x00, 0x08, 0x00]) // only 4 bytes
        XCTAssertThrowsError(try jpeg.decompress(data)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("too short"), "Message was: \(msg)")
        }
    }

    func testDecompressVersion02ReconstructsJPEG() throws {
        let input = buildMinimalJPEG(width: 16, height: 32)
        let compressed = try jpeg.compress(input)
        XCTAssertEqual(compressed[0], 0x02)

        let output = try jpeg.decompress(compressed)
        XCTAssertEqual(output[0], 0xFF)
        XCTAssertEqual(output[1], 0xD8)
        XCTAssertTrue(output.range(of: "JFIF".data(using: .utf8)!) != nil)
    }

    func testDecompressVersion03ManualPayload() throws {
        let width: UInt16 = 40
        let height: UInt16 = 30
        let scanData = Data([0xAA, 0xBB, 0xFF, 0xD9])

        // Build tables data by compressing a custom JPEG and extracting tables
        let customJPEG = buildCustomQuantJPEG(width: width, height: height)
        guard let tablesData = try jpeg.getTablesData(customJPEG) else {
            return XCTFail("Expected non-nil tables data for custom JPEG")
        }

        var v03 = Data()
        v03.append(0x03)
        v03.append(UInt8(width >> 8))
        v03.append(UInt8(width & 0xFF))
        v03.append(UInt8(height >> 8))
        v03.append(UInt8(height & 0xFF))
        // tables length (2 bytes big-endian)
        v03.append(UInt8(tablesData.count >> 8))
        v03.append(UInt8(tablesData.count & 0xFF))
        v03.append(tablesData)
        v03.append(scanData)

        let output = try jpeg.decompress(v03)
        XCTAssertEqual(output[0], 0xFF)
        XCTAssertEqual(output[1], 0xD8)
        XCTAssertTrue(output.range(of: "JFIF".data(using: .utf8)!) != nil)
    }

    func testDecompressVersion04WithObjectStore() throws {
        let store = makeObjectStore(at: tempDir)
        jpeg.setObjectStore(store)

        let customJPEG = buildCustomQuantJPEG(width: 50, height: 60)
        let compressed = try jpeg.compress(customJPEG)
        XCTAssertEqual(compressed[0], 0x04)

        // Store tables in object store at the tablesHash that compress() embedded
        guard let tablesData = try jpeg.getTablesData(customJPEG) else {
            return XCTFail("Expected non-nil tables data")
        }
        let tablesHash = Hash.compute(tablesData)
        var headerObj = Data()
        headerObj.append("header\n".data(using: .utf8)!)
        headerObj.append("jpeg-tables\n".data(using: .utf8)!)
        headerObj.append(tablesData)
        // Write header object at the tablesHash path (matching what compress embeds)
        try storeObjectAtHash(store: store, hash: tablesHash, data: headerObj)

        let output = try jpeg.decompress(compressed)
        XCTAssertEqual(output[0], 0xFF)
        XCTAssertEqual(output[1], 0xD8)
    }

    func testDecompressUnknownVersion05Throws() {
        let data = Data([0x05, 0x00, 0x08, 0x00, 0x08])
        XCTAssertThrowsError(try jpeg.decompress(data)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Unknown"), "Message was: \(msg)")
        }
    }

    func testDecompressVersion00Throws() {
        let data = Data([0x00, 0x00, 0x08, 0x00, 0x08])
        XCTAssertThrowsError(try jpeg.decompress(data)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Unknown"), "Message was: \(msg)")
        }
    }

    func testDecompressVersion01Throws() {
        let data = Data([0x01, 0x00, 0x08, 0x00, 0x08])
        XCTAssertThrowsError(try jpeg.decompress(data)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Unknown"), "Message was: \(msg)")
        }
    }

    func testDecompressV03TruncatedLengthThrows() {
        // Version 0x03, dims, but no tables length bytes
        let data = Data([0x03, 0x00, 0x08, 0x00, 0x08])
        XCTAssertThrowsError(try jpeg.decompress(data)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Missing tables length"), "Message was: \(msg)")
        }
    }

    func testDecompressV03TruncatedDataThrows() {
        // Version 0x03, dims, length says 100 but only 2 bytes of data
        var data = Data([0x03, 0x00, 0x08, 0x00, 0x08])
        data.append(contentsOf: [0x00, 0x64]) // length = 100
        data.append(contentsOf: [0xAA, 0xBB]) // only 2 bytes
        XCTAssertThrowsError(try jpeg.decompress(data)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Truncated tables"), "Message was: \(msg)")
        }
    }

    func testDecompressV04NoObjectStoreThrows() throws {
        // Don't set objectStore, try to decompress v04
        let customJPEG = buildCustomQuantJPEG()
        let compressed = try jpeg.compress(customJPEG)
        XCTAssertEqual(compressed[0], 0x04)

        // Create a fresh instance without objectStore
        let fresh = JPEGHeaderCompression()
        XCTAssertThrowsError(try fresh.decompress(compressed)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Object store not available"), "Message was: \(msg)")
        }
    }

    func testDecompressV04MissingHashThrows() {
        // Version 0x04, dims, but no 32-byte hash
        let data = Data([0x04, 0x00, 0x08, 0x00, 0x08, 0xAA])
        XCTAssertThrowsError(try jpeg.decompress(data)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Missing tables hash"), "Message was: \(msg)")
        }
    }

    func testDecompressEOIPresentNoDuplicate() throws {
        // Scan data ends with FFD9 -- output should not have double EOI
        let scanWithEOI = Data([0xAA, 0xBB, 0xFF, 0xD9])
        let input = buildMinimalJPEG(scanData: scanWithEOI)
        let compressed = try jpeg.compress(input)
        let output = try jpeg.decompress(compressed)

        // Count occurrences of FFD9
        var count = 0
        for i in 0..<(output.count - 1) {
            if output[i] == 0xFF && output[i + 1] == 0xD9 {
                count += 1
            }
        }
        XCTAssertEqual(count, 1, "Expected exactly one EOI marker")
    }

    func testDecompressEOIAbsentAppended() throws {
        // Scan data does NOT end with FFD9 -- output should have FFD9 appended
        let scanNoEOI = Data([0xAA, 0xBB, 0xCC])
        let input = buildMinimalJPEG(scanData: scanNoEOI)
        let compressed = try jpeg.compress(input)
        let output = try jpeg.decompress(compressed)

        XCTAssertEqual(output[output.count - 2], 0xFF)
        XCTAssertEqual(output[output.count - 1], 0xD9)
    }

    // MARK: - C) tablesAreStandard() via compress version byte

    func testStandardTablesVersion02() throws {
        let data = buildMinimalJPEG()
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x02)
    }

    func testModifiedLumaQuantVersion04() throws {
        var modifiedLuma = standardQ20LumaTable
        modifiedLuma[0] = 99
        let data = buildCustomQuantJPEG(lumaTable: modifiedLuma, chromaTable: standardQ20ChromaTable)
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x04)
    }

    func testModifiedChromaQuantVersion04() throws {
        var modifiedChroma = standardQ20ChromaTable
        modifiedChroma[0] = 1
        let data = buildCustomQuantJPEG(lumaTable: standardQ20LumaTable, chromaTable: modifiedChroma)
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x04)
    }

    func testSingleQuantTableVersion04() throws {
        // Build a JPEG with only one quant table (non-standard count)
        var data = Data()
        data.append(contentsOf: [0xFF, 0xD8]) // SOI

        // Only one DQT
        data.append(contentsOf: [0xFF, 0xDB])
        data.append(contentsOf: [0x00, 0x43]) // length = 67
        data.append(0x00)
        data.append(contentsOf: standardQ20LumaTable)

        // SOF
        data.append(contentsOf: [0xFF, 0xC0])
        data.append(contentsOf: [0x00, 0x11])
        data.append(0x08)
        data.append(contentsOf: [0x00, 0x08, 0x00, 0x08])
        data.append(0x03)
        data.append(contentsOf: [0x01, 0x22, 0x00])
        data.append(contentsOf: [0x02, 0x11, 0x01])
        data.append(contentsOf: [0x03, 0x11, 0x01])

        // Standard Huffman tables
        appendStandardHuffmanTablesToData(&data)

        // SOS
        appendSOSToData(&data, scanData: Data([0x00, 0xFF, 0xD9]))

        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x04, "Single quant table should be non-standard")
    }

    func testModifiedDCLumaBitsVersion04() throws {
        var modifiedBits = standardDCLumaBits
        modifiedBits[1] = 99
        let data = buildJPEGWithCustomHuffman(
            dcLumaBits: modifiedBits, dcLumaVals: standardDCLumaVals,
            acLumaBits: standardACLumaBits, acLumaVals: standardACLumaVals,
            dcChromaBits: standardDCChromaBits, dcChromaVals: standardDCChromaVals,
            acChromaBits: standardACChromaBits, acChromaVals: standardACChromaVals
        )
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x04)
    }

    func testModifiedACLumaValsVersion04() throws {
        var modifiedVals = standardACLumaVals
        modifiedVals[0] = 0xFF
        let data = buildJPEGWithCustomHuffman(
            dcLumaBits: standardDCLumaBits, dcLumaVals: standardDCLumaVals,
            acLumaBits: standardACLumaBits, acLumaVals: modifiedVals,
            dcChromaBits: standardDCChromaBits, dcChromaVals: standardDCChromaVals,
            acChromaBits: standardACChromaBits, acChromaVals: standardACChromaVals
        )
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x04)
    }

    func testThreeQuantTablesVersion04() throws {
        var data = Data()
        data.append(contentsOf: [0xFF, 0xD8])

        // Three DQT tables
        for id: UInt8 in 0...2 {
            data.append(contentsOf: [0xFF, 0xDB])
            data.append(contentsOf: [0x00, 0x43])
            data.append(id)
            data.append(contentsOf: Array(repeating: UInt8(42), count: 64))
        }

        // SOF
        data.append(contentsOf: [0xFF, 0xC0])
        data.append(contentsOf: [0x00, 0x11])
        data.append(0x08)
        data.append(contentsOf: [0x00, 0x08, 0x00, 0x08])
        data.append(0x03)
        data.append(contentsOf: [0x01, 0x22, 0x00])
        data.append(contentsOf: [0x02, 0x11, 0x01])
        data.append(contentsOf: [0x03, 0x11, 0x01])

        appendStandardHuffmanTablesToData(&data)
        appendSOSToData(&data, scanData: Data([0x00, 0xFF, 0xD9]))

        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x04, "Three quant tables should be non-standard")
    }

    func testModifiedDCChromaVersion04() throws {
        var modifiedBits = standardDCChromaBits
        modifiedBits[0] = 5
        let data = buildJPEGWithCustomHuffman(
            dcLumaBits: standardDCLumaBits, dcLumaVals: standardDCLumaVals,
            acLumaBits: standardACLumaBits, acLumaVals: standardACLumaVals,
            dcChromaBits: modifiedBits, dcChromaVals: standardDCChromaVals,
            acChromaBits: standardACChromaBits, acChromaVals: standardACChromaVals
        )
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x04)
    }

    func testModifiedACChromaVersion04() throws {
        var modifiedVals = standardACChromaVals
        modifiedVals[0] = 0xFE
        let data = buildJPEGWithCustomHuffman(
            dcLumaBits: standardDCLumaBits, dcLumaVals: standardDCLumaVals,
            acLumaBits: standardACLumaBits, acLumaVals: standardACLumaVals,
            dcChromaBits: standardDCChromaBits, dcChromaVals: standardDCChromaVals,
            acChromaBits: standardACChromaBits, acChromaVals: modifiedVals
        )
        let compressed = try jpeg.compress(data)
        XCTAssertEqual(compressed[0], 0x04)
    }

    // MARK: - D) getTablesData() tests

    func testGetTablesDataNotJPEGReturnsNil() throws {
        let data = Data([0x00, 0x00, 0x00])
        let result = try jpeg.getTablesData(data)
        XCTAssertNil(result)
    }

    func testGetTablesDataStandardReturnsNil() throws {
        let data = buildMinimalJPEG()
        let result = try jpeg.getTablesData(data)
        XCTAssertNil(result)
    }

    func testGetTablesDataCustomReturnsNonNil() throws {
        let data = buildCustomQuantJPEG()
        let result = try jpeg.getTablesData(data)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.count, 0)
    }

    func testGetTablesDataTruncatedReturnsNil() throws {
        // A JPEG that's truncated mid-marker (no length after marker)
        let data = Data([0xFF, 0xD8, 0xFF, 0xDB])
        let result = try jpeg.getTablesData(data)
        XCTAssertNil(result)
    }

    // MARK: - E) setObjectStore() tests

    func testSetObjectStoreEnablesV04Decompress() throws {
        let store = makeObjectStore(at: tempDir)
        jpeg.setObjectStore(store)

        let customJPEG = buildCustomQuantJPEG()
        let compressed = try jpeg.compress(customJPEG)
        XCTAssertEqual(compressed[0], 0x04)

        // Store tables at the correct hash
        guard let tablesData = try jpeg.getTablesData(customJPEG) else {
            return XCTFail("Expected tables data")
        }
        let tablesHash = Hash.compute(tablesData)
        var headerObj = Data()
        headerObj.append("header\n".data(using: .utf8)!)
        headerObj.append("jpeg-tables\n".data(using: .utf8)!)
        headerObj.append(tablesData)
        try storeObjectAtHash(store: store, hash: tablesHash, data: headerObj)

        let output = try jpeg.decompress(compressed)
        XCTAssertEqual(output[0], 0xFF)
        XCTAssertEqual(output[1], 0xD8)
    }

    func testSetObjectStoreWeakReference() throws {
        let customJPEG = buildCustomQuantJPEG()
        let compressed = try jpeg.compress(customJPEG)

        autoreleasepool {
            let store = makeObjectStore(at: tempDir)
            jpeg.setObjectStore(store)
        }

        // After store is deallocated, decompress v04 should fail with "Object store not available"
        XCTAssertThrowsError(try jpeg.decompress(compressed)) { error in
            guard case CompressionError.decompressionFailed(let msg) = error else {
                return XCTFail("Expected decompressionFailed, got \(error)")
            }
            XCTAssertTrue(msg.contains("Object store not available"), "Message was: \(msg)")
        }
    }

    // MARK: - F) Full round-trip tests

    func testRoundTripStandardJPEG() throws {
        let input = buildMinimalJPEG(width: 64, height: 48)
        let compressed = try jpeg.compress(input)
        let output = try jpeg.decompress(compressed)

        XCTAssertEqual(output[0], 0xFF)
        XCTAssertEqual(output[1], 0xD8)
        XCTAssertTrue(output.range(of: "JFIF".data(using: .utf8)!) != nil)
        // Output ends with EOI
        XCTAssertEqual(output[output.count - 2], 0xFF)
        XCTAssertEqual(output[output.count - 1], 0xD9)
    }

    func testRoundTripCustomJPEG() throws {
        let store = makeObjectStore(at: tempDir)
        jpeg.setObjectStore(store)

        let input = buildCustomQuantJPEG(width: 100, height: 80)
        let compressed = try jpeg.compress(input)
        XCTAssertEqual(compressed[0], 0x04)

        // Store tables at the correct hash so decompress can find them
        guard let tablesData = try jpeg.getTablesData(input) else {
            return XCTFail("Expected tables data")
        }
        let tablesHash = Hash.compute(tablesData)
        var headerObj = Data()
        headerObj.append("header\n".data(using: .utf8)!)
        headerObj.append("jpeg-tables\n".data(using: .utf8)!)
        headerObj.append(tablesData)
        try storeObjectAtHash(store: store, hash: tablesHash, data: headerObj)

        let output = try jpeg.decompress(compressed)
        XCTAssertEqual(output[0], 0xFF)
        XCTAssertEqual(output[1], 0xD8)
        XCTAssertTrue(output.range(of: "JFIF".data(using: .utf8)!) != nil)
        XCTAssertEqual(output[output.count - 2], 0xFF)
        XCTAssertEqual(output[output.count - 1], 0xD9)
    }

    // MARK: - Additional compress edge cases

    func testCompressVersion02HeaderSize() throws {
        let scanData = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xFF, 0xD9])
        let input = buildMinimalJPEG(scanData: scanData)
        let compressed = try jpeg.compress(input)
        // Version 0x02: 1 byte version + 4 bytes dims + scan data
        XCTAssertEqual(compressed[0], 0x02)
        XCTAssertEqual(compressed.count, 5 + scanData.count)
    }

    func testCompressVersion04HeaderSize() throws {
        let input = buildCustomQuantJPEG()
        let compressed = try jpeg.compress(input)
        // Version 0x04: 1 byte version + 4 bytes dims + 32 bytes hash + scan data
        XCTAssertEqual(compressed[0], 0x04)
        XCTAssertGreaterThanOrEqual(compressed.count, 37)
    }

    func testCompressScanDataPreserved() throws {
        let scanData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0xFF, 0xD9])
        let input = buildMinimalJPEG(scanData: scanData)
        let compressed = try jpeg.compress(input)
        // Scan data should be at the end, starting after the 5-byte header
        let extractedScan = compressed[5...]
        XCTAssertEqual(Data(extractedScan), scanData)
    }

    func testCompressWithAPPMarkerInExtra() throws {
        // APP0 marker (0xE0) with some data in extraMarkers
        let appData = Data(repeating: 0x42, count: 10)
        let extraMarkers: [(UInt8, Data)] = [(0xE0, appData)]
        let data = buildMinimalJPEG(extraMarkers: extraMarkers)
        let compressed = try jpeg.compress(data)
        // Should still succeed and use standard tables
        XCTAssertEqual(compressed[0], 0x02)
    }

    func testCompressDeterministicHash() throws {
        // Compressing the same custom JPEG twice should produce the same hash
        let input = buildCustomQuantJPEG(width: 10, height: 20)
        let compressed1 = try jpeg.compress(input)
        let compressed2 = try jpeg.compress(input)

        XCTAssertEqual(compressed1[0], 0x04)
        // Hash bytes 5..<37 should be identical
        XCTAssertEqual(compressed1[5..<37], compressed2[5..<37])
    }

    func testCompressDifferentCustomTablesDifferentHash() throws {
        let input1 = buildCustomQuantJPEG(lumaTable: Array(repeating: 10, count: 64))
        let input2 = buildCustomQuantJPEG(lumaTable: Array(repeating: 20, count: 64))
        let compressed1 = try jpeg.compress(input1)
        let compressed2 = try jpeg.compress(input2)

        XCTAssertEqual(compressed1[0], 0x04)
        XCTAssertEqual(compressed2[0], 0x04)
        XCTAssertNotEqual(compressed1[5..<37], compressed2[5..<37])
    }

    // MARK: - Additional decompress edge cases

    func testDecompressV02PreservesWidthHeight() throws {
        let width: UInt16 = 1920
        let height: UInt16 = 1080
        let input = buildMinimalJPEG(width: width, height: height)
        let compressed = try jpeg.compress(input)
        let output = try jpeg.decompress(compressed)

        // Find the SOF marker in the output to verify dimensions
        var found = false
        for i in 0..<(output.count - 8) {
            if output[i] == 0xFF && output[i + 1] == 0xC0 {
                let h = UInt16(output[i + 5]) << 8 | UInt16(output[i + 6])
                let w = UInt16(output[i + 7]) << 8 | UInt16(output[i + 8])
                XCTAssertEqual(w, width)
                XCTAssertEqual(h, height)
                found = true
                break
            }
        }
        XCTAssertTrue(found, "SOF marker not found in decompressed output")
    }

    func testDecompressV02ContainsQuantTables() throws {
        let input = buildMinimalJPEG()
        let compressed = try jpeg.compress(input)
        let output = try jpeg.decompress(compressed)

        // Count DQT markers (0xFF 0xDB) in output
        var dqtCount = 0
        for i in 0..<(output.count - 1) {
            if output[i] == 0xFF && output[i + 1] == 0xDB {
                dqtCount += 1
            }
        }
        XCTAssertEqual(dqtCount, 2, "Expected 2 DQT markers in reconstructed JPEG")
    }

    func testDecompressV02ContainsHuffmanTables() throws {
        let input = buildMinimalJPEG()
        let compressed = try jpeg.compress(input)
        let output = try jpeg.decompress(compressed)

        // Count DHT markers (0xFF 0xC4) in output
        var dhtCount = 0
        for i in 0..<(output.count - 1) {
            if output[i] == 0xFF && output[i + 1] == 0xC4 {
                dhtCount += 1
            }
        }
        XCTAssertEqual(dhtCount, 4, "Expected 4 DHT markers in reconstructed JPEG")
    }

    func testDecompressV03WithEmptyScanData() throws {
        let width: UInt16 = 8
        let height: UInt16 = 8

        let customJPEG = buildCustomQuantJPEG(width: width, height: height)
        guard let tablesData = try jpeg.getTablesData(customJPEG) else {
            return XCTFail("Expected non-nil tables")
        }

        var v03 = Data()
        v03.append(0x03)
        v03.append(UInt8(width >> 8))
        v03.append(UInt8(width & 0xFF))
        v03.append(UInt8(height >> 8))
        v03.append(UInt8(height & 0xFF))
        v03.append(UInt8(tablesData.count >> 8))
        v03.append(UInt8(tablesData.count & 0xFF))
        v03.append(tablesData)
        // No scan data at all

        let output = try jpeg.decompress(v03)
        // Should still produce a valid JPEG start
        XCTAssertEqual(output[0], 0xFF)
        XCTAssertEqual(output[1], 0xD8)
        // EOI should be appended since there's no scan data ending with FFD9
        XCTAssertEqual(output[output.count - 2], 0xFF)
        XCTAssertEqual(output[output.count - 1], 0xD9)
    }

    // MARK: - Helpers for building JPEGs with custom Huffman tables

    private func buildJPEGWithCustomHuffman(
        dcLumaBits: [UInt8], dcLumaVals: [UInt8],
        acLumaBits: [UInt8], acLumaVals: [UInt8],
        dcChromaBits: [UInt8], dcChromaVals: [UInt8],
        acChromaBits: [UInt8], acChromaVals: [UInt8],
        width: UInt16 = 8, height: UInt16 = 8
    ) -> Data {
        var data = Data()
        data.append(contentsOf: [0xFF, 0xD8]) // SOI

        // Standard quant tables
        data.append(contentsOf: [0xFF, 0xDB])
        data.append(contentsOf: [0x00, 0x43])
        data.append(0x00)
        data.append(contentsOf: standardQ20LumaTable)

        data.append(contentsOf: [0xFF, 0xDB])
        data.append(contentsOf: [0x00, 0x43])
        data.append(0x01)
        data.append(contentsOf: standardQ20ChromaTable)

        // SOF
        data.append(contentsOf: [0xFF, 0xC0])
        data.append(contentsOf: [0x00, 0x11])
        data.append(0x08)
        data.append(UInt8(height >> 8))
        data.append(UInt8(height & 0xFF))
        data.append(UInt8(width >> 8))
        data.append(UInt8(width & 0xFF))
        data.append(0x03)
        data.append(contentsOf: [0x01, 0x22, 0x00])
        data.append(contentsOf: [0x02, 0x11, 0x01])
        data.append(contentsOf: [0x03, 0x11, 0x01])

        // Custom Huffman tables
        appendHuffmanTableToData(&data, classId: 0x00, bits: dcLumaBits, vals: dcLumaVals)
        appendHuffmanTableToData(&data, classId: 0x10, bits: acLumaBits, vals: acLumaVals)
        appendHuffmanTableToData(&data, classId: 0x01, bits: dcChromaBits, vals: dcChromaVals)
        appendHuffmanTableToData(&data, classId: 0x11, bits: acChromaBits, vals: acChromaVals)

        // SOS
        appendSOSToData(&data, scanData: Data([0x00, 0xFF, 0xD9]))

        return data
    }

    private func appendHuffmanTableToData(_ data: inout Data, classId: UInt8, bits: [UInt8], vals: [UInt8]) {
        data.append(contentsOf: [0xFF, 0xC4])
        let length = UInt16(2 + 1 + 16 + vals.count)
        data.append(UInt8(length >> 8))
        data.append(UInt8(length & 0xFF))
        data.append(classId)
        data.append(contentsOf: bits)
        data.append(contentsOf: vals)
    }

    private func appendStandardHuffmanTablesToData(_ data: inout Data) {
        appendHuffmanTableToData(&data, classId: 0x00, bits: standardDCLumaBits, vals: standardDCLumaVals)
        appendHuffmanTableToData(&data, classId: 0x10, bits: standardACLumaBits, vals: standardACLumaVals)
        appendHuffmanTableToData(&data, classId: 0x01, bits: standardDCChromaBits, vals: standardDCChromaVals)
        appendHuffmanTableToData(&data, classId: 0x11, bits: standardACChromaBits, vals: standardACChromaVals)
    }

    private func appendSOSToData(_ data: inout Data, scanData: Data) {
        data.append(contentsOf: [0xFF, 0xDA])
        data.append(contentsOf: [0x00, 0x0C])
        data.append(0x03)
        data.append(contentsOf: [0x01, 0x00])
        data.append(contentsOf: [0x02, 0x11])
        data.append(contentsOf: [0x03, 0x11])
        data.append(contentsOf: [0x00, 0x3F, 0x00])
        data.append(scanData)
    }

    /// Stores data at a specific hash path in the ObjectStore
    /// (bypasses content-addressed storage to place data at an arbitrary hash)
    private func storeObjectAtHash(store: ObjectStore, hash: Hash, data: Data) throws {
        let hex = hash.hex
        let prefix = String(hex.prefix(2))
        let suffix = String(hex.dropFirst(2))

        let objectsPath = tempDir.appendingPathComponent(".vcs/objects")
        let dirPath = objectsPath.appendingPathComponent(prefix)
        try FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: true)
        try data.write(to: dirPath.appendingPathComponent(suffix))
    }
}
