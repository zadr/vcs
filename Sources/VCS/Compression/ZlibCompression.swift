import Foundation
import Compression

public class ZlibCompression: CompressionStrategy {
    public let name = "zlib"

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
                    COMPRESSION_ZLIB
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

            var destSize = data.count * 10      // Initial 10x estimate
            let maxSize = data.count * 1000     // Safety cap at 1000x

            while destSize <= maxSize {
                var destBuffer = Data(count: destSize)

                let decompressedSize = destBuffer.withUnsafeMutableBytes { destPtr -> Int in
                    compression_decode_buffer(
                        destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        destSize,
                        baseAddress.assumingMemoryBound(to: UInt8.self),
                        data.count,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }

                guard decompressedSize > 0 else {
                    throw CompressionError.decompressionFailed("Decompression returned zero bytes")
                }

                // If output is smaller than buffer, all data was decompressed
                if decompressedSize < destSize {
                    return destBuffer.prefix(decompressedSize)
                }

                // Buffer was fully used — likely truncated, grow 4x and retry
                let nextSize = destSize * 4
                if nextSize > maxSize && destSize < maxSize {
                    destSize = maxSize
                } else {
                    destSize = nextSize
                }
            }

            throw CompressionError.decompressionFailed(
                "Decompressed data exceeds maximum buffer size"
            )
        }
    }
}
