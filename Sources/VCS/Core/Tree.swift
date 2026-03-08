import Foundation

public struct TreeEntry: Codable {
    public let name: String
    public let hash: String
    public let isDirectory: Bool

    public init(name: String, hash: String, isDirectory: Bool) {
        self.name = name
        self.hash = hash
        self.isDirectory = isDirectory
    }
}

public struct Tree: Codable {
    public let entries: [TreeEntry]

    public init(entries: [TreeEntry]) {
        self.entries = entries
    }

    public func encode() throws -> Data {
        var result = Data()
        result.append("tree\n".data(using: .utf8)!)

        let jsonData = try JSONEncoder().encode(entries)
        result.append(jsonData)

        return result
    }

    public static func decode(_ data: Data) throws -> Tree {
        let lines = data.split(separator: 0x0A, maxSplits: 1, omittingEmptySubsequences: false)

        guard lines.count >= 2,
              String(data: Data(lines[0]), encoding: .utf8) == "tree" else {
            throw CompressionError.decompressionFailed("Invalid tree format")
        }

        let jsonData = Data(lines[1])
        let entries = try JSONDecoder().decode([TreeEntry].self, from: jsonData)

        return Tree(entries: entries)
    }
}
