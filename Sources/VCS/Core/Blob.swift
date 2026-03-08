import Foundation

public struct Blob: Codable {
    public let content: Data
    public let compressionStrategy: String

    public init(content: Data, compressionStrategy: String) {
        self.content = content
        self.compressionStrategy = compressionStrategy
    }

    public func encode(registry: CompressionRegistry) throws -> Data {
        guard let strategy = registry.getStrategy(byName: compressionStrategy) else {
            throw CompressionError.unsupportedFormat
        }

        let compressed = try strategy.compress(content)

        var result = Data()
        result.append("blob\n".data(using: .utf8)!)
        result.append("\(compressionStrategy)\n".data(using: .utf8)!)
        result.append(compressed)

        return result
    }

    public static func decode(_ data: Data, registry: CompressionRegistry, objectStore: ObjectStore) throws -> Blob {
        let lines = data.split(separator: 0x0A, maxSplits: 2, omittingEmptySubsequences: false)

        guard lines.count >= 3,
              String(data: Data(lines[0]), encoding: .utf8) == "blob",
              let strategyName = String(data: Data(lines[1]), encoding: .utf8),
              let strategy = registry.getStrategy(byName: strategyName) else {
            throw CompressionError.decompressionFailed("Invalid blob format")
        }

        let compressed = Data(lines[2])

        strategy.setObjectStore(objectStore)
        let decompressed = try strategy.decompress(compressed)

        return Blob(content: decompressed, compressionStrategy: strategyName)
    }
}
