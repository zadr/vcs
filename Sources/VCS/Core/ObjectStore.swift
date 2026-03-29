import Foundation

public class ObjectStore {
    private let objectsPath: URL
    private let compressionRegistry: CompressionRegistry

    public init(repositoryPath: URL, compressionRegistry: CompressionRegistry) {
        self.objectsPath = repositoryPath.appendingPathComponent(".vcs/objects")
        self.compressionRegistry = compressionRegistry
    }

    private func objectPath(for hash: Hash) -> URL {
        let hex = hash.hex
        let prefix = String(hex.prefix(2))
        let suffix = String(hex.dropFirst(2))

        return objectsPath
            .appendingPathComponent(prefix)
            .appendingPathComponent(suffix)
    }

    public func write(_ data: Data) throws -> Hash {
        let hash = Hash.compute(data)
        let path = objectPath(for: hash)

        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try data.write(to: path)
        return hash
    }

    public func write(_ data: Data, at hash: Hash) throws {
        let path = objectPath(for: hash)
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: path)
    }

    public func read(_ hash: Hash) throws -> Data {
        let path = objectPath(for: hash)
        return try Data(contentsOf: path)
    }

    public func exists(_ hash: Hash) -> Bool {
        let path = objectPath(for: hash)
        return FileManager.default.fileExists(atPath: path.path)
    }

    public func writeBlob(content: Data, path: String) throws -> Hash {
        let strategy = compressionRegistry.getStrategy(forPath: path)

        if strategy.name == "jpeg-header-strip",
           let jpegStrategy = strategy as? JPEGHeaderCompression,
           let tablesData = try jpegStrategy.getTablesData(content) {
            let tablesHash = Hash.compute(tablesData)

            if !exists(tablesHash) {
                var headerObj = Data()
                headerObj.append("header\n".data(using: .utf8)!)
                headerObj.append("jpeg-tables\n".data(using: .utf8)!)
                headerObj.append(tablesData)
                try write(headerObj, at: tablesHash)
            }
        }

        let blob = Blob(content: content, compressionStrategy: strategy.name)
        let encoded = try blob.encode(registry: compressionRegistry)
        return try write(encoded)
    }

    public func readBlob(_ hash: Hash) throws -> Blob {
        let data = try read(hash)
        return try Blob.decode(data, registry: compressionRegistry, objectStore: self)
    }

    public func writeTree(_ tree: Tree) throws -> Hash {
        let encoded = try tree.encode()
        return try write(encoded)
    }

    public func readTree(_ hash: Hash) throws -> Tree {
        let data = try read(hash)
        return try Tree.decode(data)
    }

    public func writeCommit(_ commit: Commit) throws -> Hash {
        let encoded = try commit.encode()
        return try write(encoded)
    }

    public func readCommit(_ hash: Hash) throws -> Commit {
        let data = try read(hash)
        return try Commit.decode(data)
    }
}
