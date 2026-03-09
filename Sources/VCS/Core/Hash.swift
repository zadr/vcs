import Foundation
import CryptoKit

public struct Hash: Hashable, CustomStringConvertible {
    public let data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public init?(hex: String) {
        guard hex.count % 2 == 0 else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex

        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        self.data = data
    }

    public var hex: String {
        return data.map { String(format: "%02x", $0) }.joined()
    }

    public var description: String {
        return hex
    }

    public static func compute(_ data: Data) -> Hash {
        let digest = SHA256.hash(data: data)
        return Hash(Data(digest))
    }

    public static func compute(_ string: String) -> Hash {
        return compute(Data(string.utf8))
    }
}
