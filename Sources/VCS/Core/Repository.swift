import Foundation

public enum RepositoryError: Error, LocalizedError {
    case noCommits
    case invalidCombineCount(Int)
    case insufficientCommits(requested: Int, available: Int)

    public var errorDescription: String? {
        switch self {
        case .noCommits:
            return "No commits in repository"
        case .invalidCombineCount(let count):
            return "Combine count must be at least 2 (got \(count))"
        case .insufficientCommits(let requested, let available):
            return "Not enough commits to combine (requested \(requested), found \(available))"
        }
    }
}

public class Repository {
    private let rootPath: URL
    private let vcsPath: URL
    private let objectStore: ObjectStore
    private let compressionRegistry: CompressionRegistry
    private var ignorePatterns: [String] = []

    public init(path: URL) throws {
        self.rootPath = path
        self.vcsPath = path.appendingPathComponent(".vcs")
        self.compressionRegistry = CompressionRegistry()
        self.objectStore = ObjectStore(repositoryPath: path, compressionRegistry: compressionRegistry)

        loadIgnorePatterns()
    }

    public static func initialize(at path: URL) throws -> Repository {
        let vcsPath = path.appendingPathComponent(".vcs")
        try FileManager.default.createDirectory(at: vcsPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: vcsPath.appendingPathComponent("objects"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: vcsPath.appendingPathComponent("refs/heads"), withIntermediateDirectories: true)

        let headPath = vcsPath.appendingPathComponent("HEAD")
        try "ref: refs/heads/main\n".write(to: headPath, atomically: true, encoding: .utf8)

        return try Repository(path: path)
    }

    private func loadIgnorePatterns() {
        let ignorePath = rootPath.appendingPathComponent(".vcsignore")
        guard let content = try? String(contentsOf: ignorePath, encoding: .utf8) else {
            ignorePatterns = [".vcs"]
            return
        }

        ignorePatterns = content
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        if !ignorePatterns.contains(".vcs") {
            ignorePatterns.append(".vcs")
        }
    }

    private func shouldIgnore(_ path: String) -> Bool {
        for pattern in ignorePatterns {
            if path.contains(pattern) {
                return true
            }
        }
        return false
    }

    private func buildTree(at path: URL, relativePath: String = "") throws -> Hash {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isDirectoryKey])

        var entries: [TreeEntry] = []

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = item.lastPathComponent
            let itemRelativePath = relativePath.isEmpty ? name : "\(relativePath)/\(name)"

            if shouldIgnore(itemRelativePath) {
                continue
            }

            let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = resourceValues.isDirectory ?? false

            let hash: Hash
            if isDirectory {
                hash = try buildTree(at: item, relativePath: itemRelativePath)
            } else {
                let content = try Data(contentsOf: item)
                hash = try objectStore.writeBlob(content: content, path: itemRelativePath)
            }

            entries.append(TreeEntry(name: name, hash: hash.hex, isDirectory: isDirectory))
        }

        let tree = Tree(entries: entries)
        return try objectStore.writeTree(tree)
    }

    public func commit(message: String, author: String) throws -> Hash {
        let treeHash = try buildTree(at: rootPath)

        let parentHash = try? getCurrentCommit()

        let commit = Commit(
            tree: treeHash.hex,
            parent: parentHash?.hex,
            author: author,
            timestamp: Date(),
            message: message
        )

        let commitHash = try objectStore.writeCommit(commit)
        try updateHead(to: commitHash)

        return commitHash
    }

    public func combineCommits(count: Int = 2, message: String? = nil, author: String? = nil) throws -> Hash {
        guard count >= 2 else {
            throw RepositoryError.invalidCombineCount(count)
        }

        guard let headHash = try getCurrentCommit() else {
            throw RepositoryError.noCommits
        }

        // Walk back and collect `count` commits (newest → oldest)
        var commits: [(hash: Hash, commit: Commit)] = []
        var currentHash = headHash

        for _ in 0..<count {
            let commit = try objectStore.readCommit(currentHash)
            commits.append((hash: currentHash, commit: commit))

            if let parentHex = commit.parent, let parentHash = Hash(hex: parentHex) {
                currentHash = parentHash
            } else if commits.count < count {
                throw RepositoryError.insufficientCommits(requested: count, available: commits.count)
            }
        }

        let newestCommit = commits.first!.commit
        let oldestCommit = commits.last!.commit

        let combinedMessage: String
        if let message = message {
            combinedMessage = message
        } else {
            combinedMessage = commits.map { $0.commit.message }.joined(separator: "\n\n")
        }

        let combinedAuthor = author ?? newestCommit.author

        let combined = Commit(
            tree: newestCommit.tree,
            parent: oldestCommit.parent,
            author: combinedAuthor,
            timestamp: Date(),
            message: combinedMessage
        )

        let combinedHash = try objectStore.writeCommit(combined)
        try updateHead(to: combinedHash)

        return combinedHash
    }

    private func getCurrentCommit() throws -> Hash? {
        let headPath = vcsPath.appendingPathComponent("HEAD")
        let headContent = try String(contentsOf: headPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

        if headContent.hasPrefix("ref: ") {
            let refPath = String(headContent.dropFirst(5))
            let refFile = vcsPath.appendingPathComponent(refPath)

            guard FileManager.default.fileExists(atPath: refFile.path) else {
                return nil
            }

            let hashString = try String(contentsOf: refFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            return Hash(hex: hashString)
        } else {
            return Hash(hex: headContent)
        }
    }

    private func updateHead(to hash: Hash) throws {
        let headPath = vcsPath.appendingPathComponent("HEAD")
        let headContent = try String(contentsOf: headPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

        if headContent.hasPrefix("ref: ") {
            let refPath = String(headContent.dropFirst(5))
            let refFile = vcsPath.appendingPathComponent(refPath)
            try FileManager.default.createDirectory(at: refFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try hash.hex.write(to: refFile, atomically: true, encoding: .utf8)
        } else {
            try hash.hex.write(to: headPath, atomically: true, encoding: .utf8)
        }
    }

    public func checkout(_ commitHash: Hash) throws {
        let commit = try objectStore.readCommit(commitHash)
        let treeHash = Hash(hex: commit.tree)!

        try reconstructTree(treeHash, at: rootPath)
        try updateHead(to: commitHash)
    }

    private func reconstructTree(_ treeHash: Hash, at path: URL) throws {
        let tree = try objectStore.readTree(treeHash)

        for entry in tree.entries {
            let itemPath = path.appendingPathComponent(entry.name)
            guard let hash = Hash(hex: entry.hash) else { continue }

            if entry.isDirectory {
                try FileManager.default.createDirectory(at: itemPath, withIntermediateDirectories: true)
                try reconstructTree(hash, at: itemPath)
            } else {
                let blob = try objectStore.readBlob(hash)
                try blob.content.write(to: itemPath)
            }
        }
    }

    private func resolveBlob(at path: String, in treeHash: Hash) throws -> Data? {
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return nil }

        let tree = try objectStore.readTree(treeHash)

        if components.count == 1 {
            guard let entry = tree.entries.first(where: { $0.name == components[0] && !$0.isDirectory }),
                  let entryHash = Hash(hex: entry.hash) else {
                return nil
            }
            let blob = try objectStore.readBlob(entryHash)
            return blob.content
        } else {
            let dirName = components[0]
            guard let entry = tree.entries.first(where: { $0.name == dirName && $0.isDirectory }),
                  let entryHash = Hash(hex: entry.hash) else {
                return nil
            }
            let remainingPath = components.dropFirst().joined(separator: "/")
            return try resolveBlob(at: remainingPath, in: entryHash)
        }
    }

    public func show(commitHash: Hash, files: [String]) throws -> [String: Data] {
        let commit = try objectStore.readCommit(commitHash)
        guard let treeHash = Hash(hex: commit.tree) else {
            return [:]
        }

        var results: [String: Data] = [:]
        for file in files {
            if let data = try resolveBlob(at: file, in: treeHash) {
                results[file] = data
            }
        }
        return results
    }

    public func log(limit: Int = 10) throws -> [Commit] {
        guard var currentHash = try getCurrentCommit() else {
            return []
        }

        var commits: [Commit] = []

        for _ in 0..<limit {
            let commit = try objectStore.readCommit(currentHash)
            commits.append(commit)

            guard let parentHex = commit.parent,
                  let parentHash = Hash(hex: parentHex) else {
                break
            }

            currentHash = parentHash
        }

        return commits
    }

    public var registry: CompressionRegistry {
        return compressionRegistry
    }
}
