import Foundation
import Compression

public class LZFSECompression: CompressionStrategy {
    public let name = "lzfse"

    public init() {}

    public func setObjectStore(_ store: ObjectStore) {}

    public func compress(_ data: Data) throws -> Data {
        return try data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Data in
            guard let baseAddress = ptr.baseAddress else {
                throw CompressionError.compressionFailed("Invalid data pointer")
            }

            let destSize = data.count + (data.count / 10) + 32
            var destBuffer = Data(count: destSize)

            let compressedSize = destBuffer.withUnsafeMutableBytes { destPtr -> Int in
                compression_encode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destSize,
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_LZFSE
                )
            }

            guard compressedSize > 0 else {
                throw CompressionError.compressionFailed("Compression returned zero bytes")
            }

            return destBuffer.prefix(compressedSize)
        }
    }

    public func decompress(_ data: Data) throws -> Data {
        return try data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Data in
            guard let baseAddress = ptr.baseAddress else {
                throw CompressionError.decompressionFailed("Invalid data pointer")
            }

            // Start with a generous estimate; retry with larger buffers if needed,
            // since compression_decode_buffer returns 0 when the buffer is too small.
            var destSize = max(data.count * 10, 65_536)
            for _ in 0..<8 {
                var destBuffer = Data(count: destSize)

                let decompressedSize = destBuffer.withUnsafeMutableBytes { destPtr -> Int in
                    compression_decode_buffer(
                        destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        destSize,
                        baseAddress.assumingMemoryBound(to: UInt8.self),
                        data.count,
                        nil,
                        COMPRESSION_LZFSE
                    )
                }

                if decompressedSize > 0 && decompressedSize < destSize {
                    return destBuffer.prefix(decompressedSize)
                }

                if decompressedSize == destSize {
                    // Buffer may have been too small; double and retry
                    destSize *= 2
                    continue
                }

                // decompressedSize == 0 means genuine failure
                break
            }

            throw CompressionError.decompressionFailed("Decompression returned zero bytes")
        }
    }
}
