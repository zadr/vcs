import Foundation

public protocol CompressionStrategy: AnyObject {
    var name: String { get }
    func compress(_ data: Data) throws -> Data
    func decompress(_ data: Data) throws -> Data
    func setObjectStore(_ store: ObjectStore)
}

public enum CompressionError: Error {
    case compressionFailed(String)
    case decompressionFailed(String)
    case unsupportedFormat
}
