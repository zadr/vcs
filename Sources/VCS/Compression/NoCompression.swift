import Foundation

public class NoCompression: CompressionStrategy {
    public let name = "none"

    public init() {}

    public func setObjectStore(_ store: ObjectStore) {}

    public func compress(_ data: Data) throws -> Data {
        return data
    }

    public func decompress(_ data: Data) throws -> Data {
        return data
    }
}
