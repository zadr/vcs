import Foundation
import Compression // https://developer.apple.com/library/mac/documentation/Performance/Reference/Compression/

public enum LibCompression {
    public enum Algorithm {
        case LZFSE
        case LZ4
        case LZMA
        case ZLIB

        var algorithm: compression_algorithm {
            switch self {
            case .LZFSE: return COMPRESSION_LZFSE
            case .LZ4: return COMPRESSION_LZ4
            case .LZMA: return COMPRESSION_LZMA
            case .ZLIB: return COMPRESSION_ZLIB
            }
        }
    }
    public enum Operation {
        case compress
        case decompress

        var operation: compression_stream_operation {
            switch self {
            case .compress: return COMPRESSION_STREAM_ENCODE
            case .decompress: return COMPRESSION_STREAM_DECODE
            }
        }

        var flags: Int32 {
            switch self {
            case .compress: return Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
            case .decompress: return 0
            }
        }
    }
    public struct Options {
        let bufferSize: Int
        let destination: NSMutableData?
        init(bufferSize: Int = 4096, destination: NSMutableData? = nil) {
            self.bufferSize = bufferSize
            self.destination = destination
        }
    }
}

extension NSData {
    func compression(with algorithm: LibCompression.Algorithm = .LZFSE, for operation: LibCompression.Operation, options: LibCompression.Options = LibCompression.Options()) throws -> NSData {
        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPtr.deallocate() }
        streamPtr.initialize(to: compression_stream(dst_ptr: UnsafeMutablePointer<UInt8>(bitPattern: 1)!, dst_size: 0, src_ptr: UnsafeMutablePointer<UInt8>(bitPattern: 1)!, src_size: 0, state: nil))
        defer { streamPtr.deinitialize(count: 1) }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: options.bufferSize)
        defer { buffer.deallocate() }

        guard compression_stream_init(streamPtr, operation.operation, algorithm.algorithm) != COMPRESSION_STATUS_ERROR else {
            throw NSError(domain: "LibCompression", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to initialize compression stream with algorithm \(algorithm) for operation \(operation)"])
        }
        defer { compression_stream_destroy(streamPtr) }

        streamPtr.pointee.src_ptr = bytes.assumingMemoryBound(to: UInt8.self)
        streamPtr.pointee.src_size = length
        streamPtr.pointee.dst_ptr = buffer
        streamPtr.pointee.dst_size = options.bufferSize

        let destination = options.destination ?? NSMutableData()
        while true {
            let status = compression_stream_process(streamPtr, operation.flags)
            switch status {
            case COMPRESSION_STATUS_OK:
                destination.append(buffer, length: options.bufferSize - streamPtr.pointee.dst_size)
                streamPtr.pointee.dst_ptr = buffer
                streamPtr.pointee.dst_size = options.bufferSize
            case COMPRESSION_STATUS_END:
                destination.append(buffer, length: options.bufferSize - streamPtr.pointee.dst_size)
                return destination.copy() as! NSData
            case COMPRESSION_STATUS_ERROR:
                throw NSError(domain: "LibCompression", code: -2, userInfo: [NSLocalizedDescriptionKey: "Error with compression stream with algorithm \(algorithm) for operation \(operation)"])
            default:
                throw NSError(domain: "LibCompression", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unknown status from compression stream"])
            }
        }
    }
}
