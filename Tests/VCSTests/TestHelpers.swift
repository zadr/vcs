import XCTest
@testable import VCS

// MARK: - TempDirectoryTestCase

class TempDirectoryTestCase: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }
}

// MARK: - ObjectStore Factory

func makeObjectStore(at path: URL) -> ObjectStore {
    let registry = CompressionRegistry()
    return ObjectStore(repositoryPath: path, compressionRegistry: registry)
}

// MARK: - Minimal JPEG Builder

/// Builds a synthetic JPEG byte sequence with configurable tables, dimensions, and markers.
/// This is critical for JPEGHeaderCompression tests.
func buildMinimalJPEG(
    width: UInt16 = 8,
    height: UInt16 = 8,
    useStandardQuantTables: Bool = true,
    useStandardHuffmanTables: Bool = true,
    includeSOF: Bool = true,
    sofMarker: UInt8 = 0xC0,
    includeSOS: Bool = true,
    scanData: Data? = nil,
    extraMarkers: [(UInt8, Data)] = []
) -> Data {
    var jpeg = Data()

    // SOI
    jpeg.append(contentsOf: [0xFF, 0xD8])

    // Extra markers (APP, RST, TEM, etc.)
    for (marker, markerData) in extraMarkers {
        jpeg.append(0xFF)
        jpeg.append(marker)
        if marker != 0x01 && !(marker >= 0xD0 && marker <= 0xD7) {
            // Markers with length fields
            let length = UInt16(markerData.count + 2)
            jpeg.append(UInt8(length >> 8))
            jpeg.append(UInt8(length & 0xFF))
            jpeg.append(markerData)
        }
        // TEM (0x01) and RST (0xD0-0xD7) have no length field or data
    }

    // DQT markers
    if useStandardQuantTables {
        // Luma table (id=0)
        jpeg.append(contentsOf: [0xFF, 0xDB])
        jpeg.append(contentsOf: [0x00, 0x43]) // length = 67
        jpeg.append(0x00) // table id
        jpeg.append(contentsOf: standardQ20LumaTable)

        // Chroma table (id=1)
        jpeg.append(contentsOf: [0xFF, 0xDB])
        jpeg.append(contentsOf: [0x00, 0x43]) // length = 67
        jpeg.append(0x01) // table id
        jpeg.append(contentsOf: standardQ20ChromaTable)
    }

    // SOF marker
    if includeSOF {
        jpeg.append(0xFF)
        jpeg.append(sofMarker)
        jpeg.append(contentsOf: [0x00, 0x11]) // length = 17
        jpeg.append(0x08) // precision
        jpeg.append(UInt8(height >> 8))
        jpeg.append(UInt8(height & 0xFF))
        jpeg.append(UInt8(width >> 8))
        jpeg.append(UInt8(width & 0xFF))
        jpeg.append(0x03) // 3 components
        jpeg.append(contentsOf: [0x01, 0x22, 0x00]) // Y
        jpeg.append(contentsOf: [0x02, 0x11, 0x01]) // Cb
        jpeg.append(contentsOf: [0x03, 0x11, 0x01]) // Cr
    }

    // DHT markers
    if useStandardHuffmanTables {
        // DC Luma (classId=0x00)
        appendHuffmanTable(to: &jpeg, classId: 0x00, bits: standardDCLumaBits, vals: standardDCLumaVals)
        // AC Luma (classId=0x10)
        appendHuffmanTable(to: &jpeg, classId: 0x10, bits: standardACLumaBits, vals: standardACLumaVals)
        // DC Chroma (classId=0x01)
        appendHuffmanTable(to: &jpeg, classId: 0x01, bits: standardDCChromaBits, vals: standardDCChromaVals)
        // AC Chroma (classId=0x11)
        appendHuffmanTable(to: &jpeg, classId: 0x11, bits: standardACChromaBits, vals: standardACChromaVals)
    }

    // SOS marker
    if includeSOS {
        jpeg.append(contentsOf: [0xFF, 0xDA])
        jpeg.append(contentsOf: [0x00, 0x0C]) // length = 12
        jpeg.append(0x03) // 3 components
        jpeg.append(contentsOf: [0x01, 0x00]) // Y: DC=0, AC=0
        jpeg.append(contentsOf: [0x02, 0x11]) // Cb: DC=1, AC=1
        jpeg.append(contentsOf: [0x03, 0x11]) // Cr: DC=1, AC=1
        jpeg.append(contentsOf: [0x00, 0x3F, 0x00]) // spectral selection

        // Scan data
        let scan = scanData ?? Data([0x00, 0xFF, 0xD9])
        jpeg.append(scan)
    }

    return jpeg
}

private func appendHuffmanTable(to jpeg: inout Data, classId: UInt8, bits: [UInt8], vals: [UInt8]) {
    jpeg.append(contentsOf: [0xFF, 0xC4])
    let length = UInt16(2 + 1 + 16 + vals.count)
    jpeg.append(UInt8(length >> 8))
    jpeg.append(UInt8(length & 0xFF))
    jpeg.append(classId)
    jpeg.append(contentsOf: bits)
    jpeg.append(contentsOf: vals)
}

// MARK: - Standard JPEG Tables (must match JPEGHeaderCompression.swift exactly)

let standardQ20LumaTable: [UInt8] = [
    16, 11, 12, 14, 12, 10, 16, 14,
    13, 14, 18, 17, 16, 19, 24, 40,
    26, 24, 22, 22, 24, 49, 35, 37,
    29, 40, 58, 51, 61, 60, 57, 51,
    56, 55, 64, 72, 92, 78, 64, 68,
    87, 69, 55, 56, 80, 109, 81, 87,
    95, 98, 103, 104, 103, 62, 77, 113,
    121, 112, 100, 120, 92, 101, 103, 99
]

let standardQ20ChromaTable: [UInt8] = [
    17, 18, 18, 24, 21, 24, 47, 26,
    26, 47, 99, 66, 56, 66, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99
]

let standardDCLumaBits: [UInt8] = [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0]
let standardDCLumaVals: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

let standardACLumaBits: [UInt8] = [0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 125]
let standardACLumaVals: [UInt8] = [
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12,
    0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
    0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08,
    0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0,
    0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16,
    0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
    0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
    0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
    0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
    0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79,
    0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
    0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
    0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6,
    0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5,
    0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4,
    0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
    0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA,
    0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8,
    0xF9, 0xFA
]

let standardDCChromaBits: [UInt8] = [0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]
let standardDCChromaVals: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

let standardACChromaBits: [UInt8] = [0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 119]
let standardACChromaVals: [UInt8] = [
    0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21,
    0x31, 0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71,
    0x13, 0x22, 0x32, 0x81, 0x08, 0x14, 0x42, 0x91,
    0xA1, 0xB1, 0xC1, 0x09, 0x23, 0x33, 0x52, 0xF0,
    0x15, 0x62, 0x72, 0xD1, 0x0A, 0x16, 0x24, 0x34,
    0xE1, 0x25, 0xF1, 0x17, 0x18, 0x19, 0x1A, 0x26,
    0x27, 0x28, 0x29, 0x2A, 0x35, 0x36, 0x37, 0x38,
    0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48,
    0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58,
    0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68,
    0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,
    0x79, 0x7A, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
    0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96,
    0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5,
    0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4,
    0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3,
    0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2,
    0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA,
    0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9,
    0xEA, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8,
    0xF9, 0xFA
]

/// Build a JPEG with custom (non-standard) quantization tables
func buildCustomQuantJPEG(
    width: UInt16 = 8,
    height: UInt16 = 8,
    lumaTable: [UInt8]? = nil,
    chromaTable: [UInt8]? = nil
) -> Data {
    var jpeg = Data()

    // SOI
    jpeg.append(contentsOf: [0xFF, 0xD8])

    // Custom luma quant table
    let luma = lumaTable ?? Array(repeating: UInt8(50), count: 64)
    jpeg.append(contentsOf: [0xFF, 0xDB])
    jpeg.append(contentsOf: [0x00, 0x43])
    jpeg.append(0x00)
    jpeg.append(contentsOf: luma)

    // Custom chroma quant table
    let chroma = chromaTable ?? Array(repeating: UInt8(60), count: 64)
    jpeg.append(contentsOf: [0xFF, 0xDB])
    jpeg.append(contentsOf: [0x00, 0x43])
    jpeg.append(0x01)
    jpeg.append(contentsOf: chroma)

    // SOF
    jpeg.append(contentsOf: [0xFF, 0xC0])
    jpeg.append(contentsOf: [0x00, 0x11])
    jpeg.append(0x08)
    jpeg.append(UInt8(height >> 8))
    jpeg.append(UInt8(height & 0xFF))
    jpeg.append(UInt8(width >> 8))
    jpeg.append(UInt8(width & 0xFF))
    jpeg.append(0x03)
    jpeg.append(contentsOf: [0x01, 0x22, 0x00])
    jpeg.append(contentsOf: [0x02, 0x11, 0x01])
    jpeg.append(contentsOf: [0x03, 0x11, 0x01])

    // Standard Huffman tables
    appendHuffmanTable(to: &jpeg, classId: 0x00, bits: standardDCLumaBits, vals: standardDCLumaVals)
    appendHuffmanTable(to: &jpeg, classId: 0x10, bits: standardACLumaBits, vals: standardACLumaVals)
    appendHuffmanTable(to: &jpeg, classId: 0x01, bits: standardDCChromaBits, vals: standardDCChromaVals)
    appendHuffmanTable(to: &jpeg, classId: 0x11, bits: standardACChromaBits, vals: standardACChromaVals)

    // SOS
    jpeg.append(contentsOf: [0xFF, 0xDA])
    jpeg.append(contentsOf: [0x00, 0x0C])
    jpeg.append(0x03)
    jpeg.append(contentsOf: [0x01, 0x00])
    jpeg.append(contentsOf: [0x02, 0x11])
    jpeg.append(contentsOf: [0x03, 0x11])
    jpeg.append(contentsOf: [0x00, 0x3F, 0x00])

    // Scan data + EOI
    jpeg.append(contentsOf: [0x00, 0xFF, 0xD9])

    return jpeg
}
