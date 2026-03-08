import Foundation

public struct Commit: Codable {
    public let tree: String
    public let parent: String?
    public let author: String
    public let timestamp: Date
    public let message: String

    public init(tree: String, parent: String?, author: String, timestamp: Date, message: String) {
        self.tree = tree
        self.parent = parent
        self.author = author
        self.timestamp = timestamp
        self.message = message
    }

    public func encode() throws -> Data {
        var result = Data()
        result.append("commit\n".data(using: .utf8)!)

        let jsonData = try JSONEncoder().encode(self)
        result.append(jsonData)

        return result
    }

    public static func decode(_ data: Data) throws -> Commit {
        let lines = data.split(separator: 0x0A, maxSplits: 1, omittingEmptySubsequences: false)

        guard lines.count >= 2,
              String(data: Data(lines[0]), encoding: .utf8) == "commit" else {
            throw CompressionError.decompressionFailed("Invalid commit format")
        }

        let jsonData = Data(lines[1])
        return try JSONDecoder().decode(Commit.self, from: jsonData)
    }
}
