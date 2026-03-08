import Foundation

public class JPEGHeaderCompression: CompressionStrategy {
    public let name = "jpeg-header-strip"
    private weak var objectStore: ObjectStore?

    public init() {}

    public func setObjectStore(_ store: ObjectStore) {
        self.objectStore = store
    }

    private static let standardQ20LumaTable: [UInt8] = [
        16, 11, 12, 14, 12, 10, 16, 14,
        13, 14, 18, 17, 16, 19, 24, 40,
        26, 24, 22, 22, 24, 49, 35, 37,
        29, 40, 58, 51, 61, 60, 57, 51,
        56, 55, 64, 72, 92, 78, 64, 68,
        87, 69, 55, 56, 80, 109, 81, 87,
        95, 98, 103, 104, 103, 62, 77, 113,
        121, 112, 100, 120, 92, 101, 103, 99
    ]

    private static let standardQ20ChromaTable: [UInt8] = [
        17, 18, 18, 24, 21, 24, 47, 26,
        26, 47, 99, 66, 56, 66, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99,
        99, 99, 99, 99, 99, 99, 99, 99
    ]

    private static let standardDCLumaBits: [UInt8] = [0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0]
    private static let standardDCLumaVals: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

    private static let standardACLumaBits: [UInt8] = [0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 125]
    private static let standardACLumaVals: [UInt8] = [
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

    private static let standardDCChromaBits: [UInt8] = [0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]
    private static let standardDCChromaVals: [UInt8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

    private static let standardACChromaBits: [UInt8] = [0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 119]
    private static let standardACChromaVals: [UInt8] = [
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

    struct JPEGTables {
        var quantTables: [(id: UInt8, data: [UInt8])] = []
        var huffmanTables: [(class_id: UInt8, data: Data)] = []
        var sofData: Data?
    }

    public func compress(_ data: Data) throws -> Data {
        guard data.count > 2,
              data[0] == 0xFF,
              data[1] == 0xD8 else {
            throw CompressionError.compressionFailed("Not a valid JPEG (missing SOI marker)")
        }

        var position = 2
        var dimensions: (width: UInt16, height: UInt16)?
        var scanDataStart: Int?
        var tables = JPEGTables()

        while position < data.count - 1 {
            guard data[position] == 0xFF else {
                break
            }

            let marker = data[position + 1]
            position += 2

            if marker == 0xD8 || marker == 0xD9 {
                continue
            }

            if marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7) {
                continue
            }

            guard position + 2 <= data.count else {
                throw CompressionError.compressionFailed("Truncated JPEG segment")
            }

            let length = Int(data[position]) << 8 | Int(data[position + 1])

            if marker == 0xDB {
                let tableId = data[position + 2]
                let tableData = Array(data[(position + 3)..<(position + length)])
                tables.quantTables.append((id: tableId, data: tableData))
            }

            if marker == 0xC4 {
                let classId = data[position + 2]
                let tableData = data[(position + 2)..<(position + length)]
                tables.huffmanTables.append((class_id: classId, data: tableData))
            }

            if marker == 0xC0 || marker == 0xC2 {
                guard position + 7 <= data.count else {
                    throw CompressionError.compressionFailed("Truncated SOF segment")
                }

                let height = UInt16(data[position + 3]) << 8 | UInt16(data[position + 4])
                let width = UInt16(data[position + 5]) << 8 | UInt16(data[position + 6])
                dimensions = (width, height)

                tables.sofData = data[position..<(position + length)]
            }

            if marker == 0xDA {
                scanDataStart = position + length
                break
            }

            position += length
        }

        guard let dims = dimensions,
              let scanStart = scanDataStart else {
            throw CompressionError.compressionFailed("Could not find JPEG dimensions or scan data")
        }

        let scanData = data[scanStart...]

        let usesStandardTables = tablesAreStandard(tables)

        var compressed = Data()

        if usesStandardTables {
            compressed.append(0x02)
            compressed.append(UInt8(dims.width >> 8))
            compressed.append(UInt8(dims.width & 0xFF))
            compressed.append(UInt8(dims.height >> 8))
            compressed.append(UInt8(dims.height & 0xFF))
        } else {
            let tablesData = try encodeTables(tables)
            let tablesHash = Hash.compute(tablesData)

            compressed.append(0x04)
            compressed.append(UInt8(dims.width >> 8))
            compressed.append(UInt8(dims.width & 0xFF))
            compressed.append(UInt8(dims.height >> 8))
            compressed.append(UInt8(dims.height & 0xFF))
            compressed.append(contentsOf: tablesHash.data)
        }

        compressed.append(contentsOf: scanData)

        return compressed
    }

    private func tablesAreStandard(_ tables: JPEGTables) -> Bool {
        guard tables.quantTables.count == 2 else { return false }

        for qt in tables.quantTables {
            if qt.id == 0 && qt.data != Self.standardQ20LumaTable {
                return false
            }
            if qt.id == 1 && qt.data != Self.standardQ20ChromaTable {
                return false
            }
        }

        guard tables.huffmanTables.count == 4 else { return false }

        for ht in tables.huffmanTables {
            let classId = ht.class_id
            let tableData = Array(ht.data.dropFirst())

            if classId == 0x00 {
                let bits = Array(tableData.prefix(16))
                let vals = Array(tableData.dropFirst(16))
                if bits != Self.standardDCLumaBits || vals != Self.standardDCLumaVals {
                    return false
                }
            } else if classId == 0x10 {
                let bits = Array(tableData.prefix(16))
                let vals = Array(tableData.dropFirst(16))
                if bits != Self.standardACLumaBits || vals != Self.standardACLumaVals {
                    return false
                }
            } else if classId == 0x01 {
                let bits = Array(tableData.prefix(16))
                let vals = Array(tableData.dropFirst(16))
                if bits != Self.standardDCChromaBits || vals != Self.standardDCChromaVals {
                    return false
                }
            } else if classId == 0x11 {
                let bits = Array(tableData.prefix(16))
                let vals = Array(tableData.dropFirst(16))
                if bits != Self.standardACChromaBits || vals != Self.standardACChromaVals {
                    return false
                }
            }
        }

        return true
    }

    private func encodeTables(_ tables: JPEGTables) throws -> Data {
        var result = Data()

        result.append(UInt8(tables.quantTables.count))
        for qt in tables.quantTables {
            result.append(qt.id)
            result.append(UInt8(qt.data.count))
            result.append(contentsOf: qt.data)
        }

        result.append(UInt8(tables.huffmanTables.count))
        for ht in tables.huffmanTables {
            result.append(ht.class_id)
            let length = UInt16(ht.data.count)
            result.append(UInt8(length >> 8))
            result.append(UInt8(length & 0xFF))
            result.append(ht.data)
        }

        if let sofData = tables.sofData {
            result.append(UInt8(sofData.count >> 8))
            result.append(UInt8(sofData.count & 0xFF))
            result.append(sofData)
        } else {
            result.append(0x00)
            result.append(0x00)
        }

        return result
    }

    public func decompress(_ data: Data) throws -> Data {
        guard data.count >= 5 else {
            throw CompressionError.decompressionFailed("Compressed JPEG data too short")
        }

        let version = data[0]

        guard version == 0x02 || version == 0x03 || version == 0x04 else {
            throw CompressionError.decompressionFailed("Unknown JPEG compression version")
        }

        let width = UInt16(data[1]) << 8 | UInt16(data[2])
        let height = UInt16(data[3]) << 8 | UInt16(data[4])

        var position = 5
        var tables: JPEGTables?

        if version == 0x03 {
            guard position + 2 <= data.count else {
                throw CompressionError.decompressionFailed("Missing tables length")
            }

            let tablesLength = Int(data[position]) << 8 | Int(data[position + 1])
            position += 2

            guard position + tablesLength <= data.count else {
                throw CompressionError.decompressionFailed("Truncated tables data")
            }

            let tablesData = data[position..<(position + tablesLength)]
            tables = try decodeTables(Data(tablesData))
            position += tablesLength
        } else if version == 0x04 {
            guard position + 32 <= data.count else {
                throw CompressionError.decompressionFailed("Missing tables hash")
            }

            let hashData = data[position..<(position + 32)]
            position += 32

            tables = try loadTablesFromHash(Hash(hashData))
        }

        let scanData = data[position...]

        var jpeg = Data()
        jpeg.append(contentsOf: [0xFF, 0xD8])

        jpeg.append(contentsOf: [0xFF, 0xE0])
        jpeg.append(contentsOf: [0x00, 0x10])
        jpeg.append(contentsOf: "JFIF".utf8)
        jpeg.append(0x00)
        jpeg.append(contentsOf: [0x01, 0x01])
        jpeg.append(0x00)
        jpeg.append(contentsOf: [0x00, 0x01, 0x00, 0x01])
        jpeg.append(contentsOf: [0x00, 0x00])

        if let customTables = tables {
            for qt in customTables.quantTables {
                jpeg.append(contentsOf: [0xFF, 0xDB])
                let length = UInt16(qt.data.count + 3)
                jpeg.append(UInt8(length >> 8))
                jpeg.append(UInt8(length & 0xFF))
                jpeg.append(qt.id)
                jpeg.append(contentsOf: qt.data)
            }

            if let sofData = customTables.sofData {
                jpeg.append(contentsOf: [0xFF, 0xC0])
                jpeg.append(sofData)
            } else {
                appendStandardSOF(to: &jpeg, width: width, height: height)
            }

            for ht in customTables.huffmanTables {
                jpeg.append(contentsOf: [0xFF, 0xC4])
                let length = UInt16(ht.data.count + 2)
                jpeg.append(UInt8(length >> 8))
                jpeg.append(UInt8(length & 0xFF))
                jpeg.append(ht.data)
            }
        } else {
            appendStandardQuantTables(to: &jpeg)
            appendStandardSOF(to: &jpeg, width: width, height: height)
            appendStandardHuffmanTables(to: &jpeg)
        }

        jpeg.append(contentsOf: scanData)

        if jpeg.count < 2 || jpeg[jpeg.count - 2] != 0xFF || jpeg[jpeg.count - 1] != 0xD9 {
            jpeg.append(contentsOf: [0xFF, 0xD9])
        }

        return jpeg
    }

    private func loadTablesFromHash(_ hash: Hash) throws -> JPEGTables {
        guard let store = objectStore else {
            throw CompressionError.decompressionFailed("Object store not available for header lookup")
        }

        let headerData = try store.read(hash)
        let lines = headerData.split(separator: 0x0A, maxSplits: 2, omittingEmptySubsequences: false)

        guard lines.count >= 3,
              String(data: Data(lines[0]), encoding: .utf8) == "header",
              String(data: Data(lines[1]), encoding: .utf8) == "jpeg-tables" else {
            throw CompressionError.decompressionFailed("Invalid header object format")
        }

        let tablesData = Data(lines[2])
        return try decodeTables(tablesData)
    }

    private func decodeTables(_ data: Data) throws -> JPEGTables {
        var tables = JPEGTables()
        var position = 0

        guard position < data.count else {
            throw CompressionError.decompressionFailed("Empty tables data")
        }

        let quantCount = Int(data[position])
        position += 1

        for _ in 0..<quantCount {
            guard position + 2 <= data.count else {
                throw CompressionError.decompressionFailed("Truncated quant table")
            }

            let id = data[position]
            let length = Int(data[position + 1])
            position += 2

            guard position + length <= data.count else {
                throw CompressionError.decompressionFailed("Truncated quant table data")
            }

            let tableData = Array(data[position..<(position + length)])
            tables.quantTables.append((id: id, data: tableData))
            position += length
        }

        guard position < data.count else {
            throw CompressionError.decompressionFailed("Missing huffman count")
        }

        let huffmanCount = Int(data[position])
        position += 1

        for _ in 0..<huffmanCount {
            guard position + 3 <= data.count else {
                throw CompressionError.decompressionFailed("Truncated huffman table")
            }

            let classId = data[position]
            let length = Int(data[position + 1]) << 8 | Int(data[position + 2])
            position += 3

            guard position + length <= data.count else {
                throw CompressionError.decompressionFailed("Truncated huffman table data")
            }

            let tableData = data[position..<(position + length)]
            tables.huffmanTables.append((class_id: classId, data: tableData))
            position += length
        }

        guard position + 2 <= data.count else {
            throw CompressionError.decompressionFailed("Missing SOF length")
        }

        let sofLength = Int(data[position]) << 8 | Int(data[position + 1])
        position += 2

        if sofLength > 0 {
            guard position + sofLength <= data.count else {
                throw CompressionError.decompressionFailed("Truncated SOF data")
            }

            tables.sofData = data[position..<(position + sofLength)]
        }

        return tables
    }

    private func appendStandardQuantTables(to jpeg: inout Data) {
        jpeg.append(contentsOf: [0xFF, 0xDB])
        jpeg.append(contentsOf: [0x00, 0x43])
        jpeg.append(0x00)
        jpeg.append(contentsOf: Self.standardQ20LumaTable)

        jpeg.append(contentsOf: [0xFF, 0xDB])
        jpeg.append(contentsOf: [0x00, 0x43])
        jpeg.append(0x01)
        jpeg.append(contentsOf: Self.standardQ20ChromaTable)
    }

    private func appendStandardSOF(to jpeg: inout Data, width: UInt16, height: UInt16) {
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
    }

    private func appendStandardHuffmanTables(to jpeg: inout Data) {
        jpeg.append(contentsOf: [0xFF, 0xC4])
        jpeg.append(contentsOf: [0x00, 0x1F])
        jpeg.append(0x00)
        jpeg.append(contentsOf: Self.standardDCLumaBits)
        jpeg.append(contentsOf: Self.standardDCLumaVals)

        jpeg.append(contentsOf: [0xFF, 0xC4])
        jpeg.append(contentsOf: [0x00, 0xB5])
        jpeg.append(0x10)
        jpeg.append(contentsOf: Self.standardACLumaBits)
        jpeg.append(contentsOf: Self.standardACLumaVals)

        jpeg.append(contentsOf: [0xFF, 0xC4])
        jpeg.append(contentsOf: [0x00, 0x1F])
        jpeg.append(0x01)
        jpeg.append(contentsOf: Self.standardDCChromaBits)
        jpeg.append(contentsOf: Self.standardDCChromaVals)

        jpeg.append(contentsOf: [0xFF, 0xC4])
        jpeg.append(contentsOf: [0x00, 0xB5])
        jpeg.append(0x11)
        jpeg.append(contentsOf: Self.standardACChromaBits)
        jpeg.append(contentsOf: Self.standardACChromaVals)
    }

    public func getTablesData(_ data: Data) throws -> Data? {
        guard data.count > 2,
              data[0] == 0xFF,
              data[1] == 0xD8 else {
            return nil
        }

        var position = 2
        var tables = JPEGTables()

        while position < data.count - 1 {
            guard data[position] == 0xFF else {
                break
            }

            let marker = data[position + 1]
            position += 2

            if marker == 0xD8 || marker == 0xD9 {
                continue
            }

            if marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7) {
                continue
            }

            guard position + 2 <= data.count else {
                return nil
            }

            let length = Int(data[position]) << 8 | Int(data[position + 1])

            if marker == 0xDB {
                let tableId = data[position + 2]
                let tableData = Array(data[(position + 3)..<(position + length)])
                tables.quantTables.append((id: tableId, data: tableData))
            }

            if marker == 0xC4 {
                let classId = data[position + 2]
                let tableData = data[(position + 2)..<(position + length)]
                tables.huffmanTables.append((class_id: classId, data: tableData))
            }

            if marker == 0xC0 || marker == 0xC2 {
                tables.sofData = data[position..<(position + length)]
            }

            if marker == 0xDA {
                break
            }

            position += length
        }

        if tablesAreStandard(tables) {
            return nil
        }

        return try encodeTables(tables)
    }
}
