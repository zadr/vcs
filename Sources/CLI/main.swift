import Foundation
import VCS

func printUsage() {
    print("""
    VCS - Version Control System

    Usage:
        vcs init                     Initialize a new repository
        vcs commit <message>         Create a new commit
        vcs log [limit]              Show commit history
        vcs checkout <hash>          Checkout a specific commit
        vcs compression set <ext> <strategy>     Set compression for extension
        vcs compression override <path> <strategy>  Set compression for specific file

    Available compression strategies: lzfse (default), zlib, lz4, none, jpeg-header-strip
    """)
}

func main() {
    let args = CommandLine.arguments

    guard args.count >= 2 else {
        printUsage()
        exit(1)
    }

    let command = args[1]
    let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    do {
        switch command {
        case "init":
            let repo = try Repository.initialize(at: currentDir)
            print("Initialized VCS repository at \(currentDir.path)")

        case "commit":
            guard args.count >= 3 else {
                print("Error: commit message required")
                exit(1)
            }
            let message = args[2..<args.count].joined(separator: " ")
            let repo = try Repository(path: currentDir)
            let author = ProcessInfo.processInfo.environment["USER"] ?? "unknown"
            let hash = try repo.commit(message: message, author: author)
            print("Created commit: \(hash.hex)")

        case "log":
            let limit = args.count >= 3 ? Int(args[2]) ?? 10 : 10
            let repo = try Repository(path: currentDir)
            let commits = try repo.log(limit: limit)

            for commit in commits {
                print("\nCommit: \(commit.tree)")
                print("Author: \(commit.author)")
                print("Date: \(commit.timestamp)")
                print("\n    \(commit.message)")
            }

        case "checkout":
            guard args.count >= 3 else {
                print("Error: commit hash required")
                exit(1)
            }
            guard let hash = Hash(hex: args[2]) else {
                print("Error: invalid hash")
                exit(1)
            }
            let repo = try Repository(path: currentDir)
            try repo.checkout(hash)
            print("Checked out commit: \(hash.hex)")

        case "compression":
            guard args.count >= 4 else {
                print("Error: compression subcommand requires arguments")
                exit(1)
            }

            let repo = try Repository(path: currentDir)
            let subcommand = args[2]

            switch subcommand {
            case "set":
                guard args.count >= 5 else {
                    print("Error: extension and strategy required")
                    exit(1)
                }
                let ext = args[3]
                let strategy = args[4]
                repo.registry.setCompressionForExtension(ext, strategy: strategy)
                print("Set compression for .\(ext) files to \(strategy)")

            case "override":
                guard args.count >= 5 else {
                    print("Error: path and strategy required")
                    exit(1)
                }
                let path = args[3]
                let strategy = args[4]
                repo.registry.setCompressionForPath(path, strategy: strategy)
                print("Set compression for \(path) to \(strategy)")

            default:
                print("Error: unknown compression subcommand")
                exit(1)
            }

        default:
            printUsage()
            exit(1)
        }
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

main()
