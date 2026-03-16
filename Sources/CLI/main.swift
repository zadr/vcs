import Foundation
import VCS

func printUsage() {
    print("""
    VCS - Version Control System

    Usage:
        vcs init                     Initialize a new repository
        vcs commit <message>         Create a new commit
        vcs commit combine [--count N] [--message "msg"]   Combine last N commits into one
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
                print("Error: commit message or subcommand required")
                exit(1)
            }

            if args[2] == "combine" {
                var count = 2
                var message: String? = nil
                var i = 3
                while i < args.count {
                    switch args[i] {
                    case "--count":
                        guard i + 1 < args.count, let n = Int(args[i + 1]) else {
                            print("Error: --count requires a number")
                            exit(1)
                        }
                        count = n
                        i += 2
                    case "--message":
                        guard i + 1 < args.count else {
                            print("Error: --message requires a value")
                            exit(1)
                        }
                        message = args[i + 1]
                        i += 2
                    default:
                        print("Error: unknown option '\(args[i])'")
                        exit(1)
                    }
                }

                let repo = try Repository(path: currentDir)
                let hash = try repo.combineCommits(count: count, message: message)
                print("Combined \(count) commits into: \(hash.hex)")
            } else {
                let message = args[2..<args.count].joined(separator: " ")
                let repo = try Repository(path: currentDir)
                let author = ProcessInfo.processInfo.environment["USER"] ?? "unknown"
                let hash = try repo.commit(message: message, author: author)
                print("Created commit: \(hash.hex)")
            }

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
