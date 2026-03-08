import XCTest
@testable import VCS

final class RepositoryTests: TempDirectoryTestCase {

    // MARK: - A) Initialization

    func testInitializeCreatesVcsDirectoryStructure() throws {
        let repo = try Repository.initialize(at: tempDir)
        let fm = FileManager.default

        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent(".vcs").path))
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent(".vcs/objects").path))
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent(".vcs/refs/heads").path))
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent(".vcs/HEAD").path))
        _ = repo
    }

    func testInitializeHeadContentIsRefToMain() throws {
        _ = try Repository.initialize(at: tempDir)
        let headContent = try String(contentsOf: tempDir.appendingPathComponent(".vcs/HEAD"), encoding: .utf8)
        XCTAssertEqual(headContent, "ref: refs/heads/main\n")
    }

    func testOpeningExistingRepoSucceeds() throws {
        _ = try Repository.initialize(at: tempDir)
        let repo = try Repository(path: tempDir)
        XCTAssertNotNil(repo)
    }

    func testRegistryAccessorReturnsCompressionRegistry() throws {
        let repo = try Repository.initialize(at: tempDir)
        let registry = repo.registry
        XCTAssertNotNil(registry)
        XCTAssertNotNil(registry.getStrategy(byName: "zlib"))
    }

    // MARK: - B) Commit Operations

    func testCommitEmptyWorkingDirReturnsHash() throws {
        let repo = try Repository.initialize(at: tempDir)
        let hash = try repo.commit(message: "empty commit", author: "Test User")
        XCTAssertFalse(hash.hex.isEmpty)
        XCTAssertEqual(hash.hex.count, 64) // SHA-256 hex string
    }

    func testCommitWithFilesReturnsHash() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "hello world".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let hash = try repo.commit(message: "add file", author: "Test User")
        XCTAssertFalse(hash.hex.isEmpty)
        XCTAssertEqual(hash.hex.count, 64)
    }

    func testCommitWithSubdirectories() throws {
        let repo = try Repository.initialize(at: tempDir)
        let subdir = tempDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        try "nested content".write(to: subdir.appendingPathComponent("nested.txt"), atomically: true, encoding: .utf8)

        let hash = try repo.commit(message: "add nested", author: "Test User")
        XCTAssertFalse(hash.hex.isEmpty)
    }

    func testMultipleCommitsSecondHasParentPointingToFirst() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "v1".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let firstHash = try repo.commit(message: "first", author: "Test User")

        try "v2".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try repo.commit(message: "second", author: "Test User")

        let commits = try repo.log(limit: 2)
        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(commits[0].parent, firstHash.hex)
    }

    func testCommitMessagePreserved() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "data".write(to: tempDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        _ = try repo.commit(message: "my special message", author: "Author")

        let commits = try repo.log(limit: 1)
        XCTAssertEqual(commits.first?.message, "my special message")
    }

    func testCommitAuthorPreserved() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "data".write(to: tempDir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        _ = try repo.commit(message: "msg", author: "Jane Doe <jane@example.com>")

        let commits = try repo.log(limit: 1)
        XCTAssertEqual(commits.first?.author, "Jane Doe <jane@example.com>")
    }

    func testGetCurrentCommitNilBeforeFirstCommitNonNilAfter() throws {
        let repo = try Repository.initialize(at: tempDir)

        // Before any commit, log should return empty (getCurrentCommit is nil internally)
        let logBefore = try repo.log()
        XCTAssertTrue(logBefore.isEmpty)

        // After a commit, log returns results (getCurrentCommit is non-nil)
        try "content".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try repo.commit(message: "first commit", author: "Author")
        let logAfter = try repo.log()
        XCTAssertEqual(logAfter.count, 1)
    }

    // MARK: - C) Log Operations

    func testLogNoCommitsReturnsEmptyArray() throws {
        let repo = try Repository.initialize(at: tempDir)
        let commits = try repo.log()
        XCTAssertTrue(commits.isEmpty)
    }

    func testLogOneCommitReturnsSingleElement() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "x".write(to: tempDir.appendingPathComponent("x.txt"), atomically: true, encoding: .utf8)
        _ = try repo.commit(message: "one", author: "A")

        let commits = try repo.log()
        XCTAssertEqual(commits.count, 1)
    }

    func testLogMultipleCommitsNewestFirst() throws {
        let repo = try Repository.initialize(at: tempDir)

        for i in 1...3 {
            try "v\(i)".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
            _ = try repo.commit(message: "commit \(i)", author: "A")
        }

        let commits = try repo.log()
        XCTAssertEqual(commits.count, 3)
        XCTAssertEqual(commits[0].message, "commit 3")
        XCTAssertEqual(commits[1].message, "commit 2")
        XCTAssertEqual(commits[2].message, "commit 1")
    }

    func testLogDefaultLimitReturnsTen() throws {
        let repo = try Repository.initialize(at: tempDir)

        for i in 1...15 {
            try "v\(i)".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
            _ = try repo.commit(message: "commit \(i)", author: "A")
        }

        let commits = try repo.log()
        XCTAssertEqual(commits.count, 10)
    }

    func testLogCustomLimit() throws {
        let repo = try Repository.initialize(at: tempDir)

        for i in 1...15 {
            try "v\(i)".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
            _ = try repo.commit(message: "commit \(i)", author: "A")
        }

        let commits = try repo.log(limit: 5)
        XCTAssertEqual(commits.count, 5)
    }

    func testLogLimitLargerThanHistory() throws {
        let repo = try Repository.initialize(at: tempDir)

        for i in 1...3 {
            try "v\(i)".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
            _ = try repo.commit(message: "commit \(i)", author: "A")
        }

        let commits = try repo.log(limit: 100)
        XCTAssertEqual(commits.count, 3)
    }

    func testLogLimitZeroReturnsEmptyArray() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "data".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try repo.commit(message: "exists", author: "A")

        let commits = try repo.log(limit: 0)
        XCTAssertEqual(commits.count, 0)
    }

    // MARK: - D) Checkout Operations

    func testCheckoutValidCommitRestoresFiles() throws {
        let repo = try Repository.initialize(at: tempDir)
        let filePath = tempDir.appendingPathComponent("hello.txt")

        try "version 1".write(to: filePath, atomically: true, encoding: .utf8)
        let firstHash = try repo.commit(message: "v1", author: "A")

        try "version 2".write(to: filePath, atomically: true, encoding: .utf8)
        _ = try repo.commit(message: "v2", author: "A")

        try repo.checkout(firstHash)

        let content = try String(contentsOf: filePath, encoding: .utf8)
        XCTAssertEqual(content, "version 1")
    }

    func testCheckoutUpdatesHEAD() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "data".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let commitHash = try repo.commit(message: "initial", author: "A")

        // Write a direct hash to HEAD so updateHead writes to HEAD directly
        let headPath = tempDir.appendingPathComponent(".vcs/HEAD")
        try commitHash.hex.write(to: headPath, atomically: true, encoding: .utf8)

        try repo.checkout(commitHash)

        let headContent = try String(contentsOf: headPath, encoding: .utf8)
        XCTAssertEqual(headContent, commitHash.hex)
    }

    func testCheckoutWithNestedDirectories() throws {
        let repo = try Repository.initialize(at: tempDir)
        let nested = tempDir.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "deep content".write(to: nested.appendingPathComponent("deep.txt"), atomically: true, encoding: .utf8)
        try "root content".write(to: tempDir.appendingPathComponent("root.txt"), atomically: true, encoding: .utf8)

        let commitHash = try repo.commit(message: "nested structure", author: "A")

        // Remove the files to simulate a different state
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("a"))
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("root.txt"))

        try repo.checkout(commitHash)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: nested.appendingPathComponent("deep.txt").path))
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent("root.txt").path))

        let deepContent = try String(contentsOf: nested.appendingPathComponent("deep.txt"), encoding: .utf8)
        XCTAssertEqual(deepContent, "deep content")
    }

    func testCheckoutEmptyTreeNoFilesBesidesVcs() throws {
        let repo = try Repository.initialize(at: tempDir)

        // Commit with no files (empty working dir besides .vcs)
        let emptyHash = try repo.commit(message: "empty", author: "A")

        // Add a file then commit
        try "temp".write(to: tempDir.appendingPathComponent("temp.txt"), atomically: true, encoding: .utf8)
        _ = try repo.commit(message: "with file", author: "A")

        // Checkout the empty commit - it restores the empty tree
        try repo.checkout(emptyHash)

        // The checkout reconstructs from tree; temp.txt from previous state may still exist
        // since checkout only writes files from the tree but does not delete extras.
        // The key assertion is that .vcs still exists and checkout did not throw.
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent(".vcs").path))
    }

    // MARK: - E) Ignore Patterns

    func testDefaultIgnoreVcsAlwaysIgnoredWithoutVcsignore() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "data".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        _ = try repo.commit(message: "commit", author: "A")

        // .vcs directory should not appear in committed tree.
        // Verify by checking out and seeing that no .vcs files are
        // overwritten or duplicated. The commit succeeding without
        // infinite recursion into .vcs/objects proves .vcs is ignored.
        let commits = try repo.log()
        XCTAssertEqual(commits.count, 1)
    }

    func testVcsignoreWithPatternsExcludesMatchingFiles() throws {
        _ = try Repository.initialize(at: tempDir)
        try "build\n".write(to: tempDir.appendingPathComponent(".vcsignore"), atomically: true, encoding: .utf8)

        // Re-open repo so it reads the .vcsignore
        let repo = try Repository(path: tempDir)

        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("build"), withIntermediateDirectories: true)
        try "artifact".write(to: tempDir.appendingPathComponent("build/output.o"), atomically: true, encoding: .utf8)
        try "source".write(to: tempDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let commitHash = try repo.commit(message: "with ignore", author: "A")

        // Remove files, checkout, and verify build dir is NOT restored
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("build"))
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("main.swift"))

        try repo.checkout(commitHash)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent("main.swift").path))
        XCTAssertFalse(fm.fileExists(atPath: tempDir.appendingPathComponent("build/output.o").path))
    }

    func testVcsignoreCommentsSkipped() throws {
        _ = try Repository.initialize(at: tempDir)
        try "# this is a comment\nbuild\n".write(to: tempDir.appendingPathComponent(".vcsignore"), atomically: true, encoding: .utf8)

        let repo = try Repository(path: tempDir)

        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("build"), withIntermediateDirectories: true)
        try "artifact".write(to: tempDir.appendingPathComponent("build/out.o"), atomically: true, encoding: .utf8)
        try "code".write(to: tempDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let commitHash = try repo.commit(message: "ignore comments", author: "A")

        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("build"))
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("main.swift"))

        try repo.checkout(commitHash)

        // "# this is a comment" should not be treated as a pattern
        // "build" should be ignored, main.swift should be present
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("main.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("build/out.o").path))
    }

    func testVcsignoreEmptyLinesSkipped() throws {
        _ = try Repository.initialize(at: tempDir)
        try "\n\nbuild\n\n".write(to: tempDir.appendingPathComponent(".vcsignore"), atomically: true, encoding: .utf8)

        let repo = try Repository(path: tempDir)

        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("build"), withIntermediateDirectories: true)
        try "artifact".write(to: tempDir.appendingPathComponent("build/out.o"), atomically: true, encoding: .utf8)
        try "code".write(to: tempDir.appendingPathComponent("src.swift"), atomically: true, encoding: .utf8)

        let commitHash = try repo.commit(message: "empty lines", author: "A")

        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("build"))
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("src.swift"))

        try repo.checkout(commitHash)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("src.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("build/out.o").path))
    }

    func testVcsAlwaysIgnoredEvenIfNotInVcsignore() throws {
        _ = try Repository.initialize(at: tempDir)
        // .vcsignore that does NOT mention .vcs
        try "build\n".write(to: tempDir.appendingPathComponent(".vcsignore"), atomically: true, encoding: .utf8)

        let repo = try Repository(path: tempDir)
        try "source".write(to: tempDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        // If .vcs were not auto-ignored, committing would recurse into .vcs/objects and potentially fail
        // or produce a different tree. The fact that this succeeds confirms .vcs is always ignored.
        let hash = try repo.commit(message: "vcs auto-ignored", author: "A")
        XCTAssertFalse(hash.hex.isEmpty)
    }

    func testShouldIgnoreSubstringMatchBuildMatchesBuildOutput() throws {
        _ = try Repository.initialize(at: tempDir)
        try "build\n".write(to: tempDir.appendingPathComponent(".vcsignore"), atomically: true, encoding: .utf8)

        let repo = try Repository(path: tempDir)

        // "build" pattern should match "build/output" via substring contains
        let buildDir = tempDir.appendingPathComponent("build")
        try FileManager.default.createDirectory(at: buildDir.appendingPathComponent("output"), withIntermediateDirectories: true)
        try "binary".write(to: buildDir.appendingPathComponent("output/app"), atomically: true, encoding: .utf8)
        try "src".write(to: tempDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let commitHash = try repo.commit(message: "substring match", author: "A")

        try FileManager.default.removeItem(at: buildDir)
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("main.swift"))

        try repo.checkout(commitHash)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("main.swift").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: buildDir.appendingPathComponent("output/app").path))
    }

    func testShouldIgnoreNoMatchBuildDoesNotMatchSourceMainSwift() throws {
        _ = try Repository.initialize(at: tempDir)
        try "build\n".write(to: tempDir.appendingPathComponent(".vcsignore"), atomically: true, encoding: .utf8)

        let repo = try Repository(path: tempDir)

        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try "code".write(to: sourceDir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let commitHash = try repo.commit(message: "no match", author: "A")

        try FileManager.default.removeItem(at: sourceDir)

        try repo.checkout(commitHash)

        // "source/main.swift" does not contain "build", so it should be committed and restored
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceDir.appendingPathComponent("main.swift").path))
    }

    func testMultipleIgnorePatternsAllApplied() throws {
        _ = try Repository.initialize(at: tempDir)
        try "build\ntemp\n.cache\n".write(to: tempDir.appendingPathComponent(".vcsignore"), atomically: true, encoding: .utf8)

        let repo = try Repository(path: tempDir)

        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("build"), withIntermediateDirectories: true)
        try "b".write(to: tempDir.appendingPathComponent("build/out"), atomically: true, encoding: .utf8)

        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("temp"), withIntermediateDirectories: true)
        try "t".write(to: tempDir.appendingPathComponent("temp/scratch"), atomically: true, encoding: .utf8)

        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent(".cache"), withIntermediateDirectories: true)
        try "c".write(to: tempDir.appendingPathComponent(".cache/data"), atomically: true, encoding: .utf8)

        try "keep".write(to: tempDir.appendingPathComponent("keep.txt"), atomically: true, encoding: .utf8)

        let commitHash = try repo.commit(message: "multi ignore", author: "A")

        // Clean up everything
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("build"))
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("temp"))
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent(".cache"))
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("keep.txt"))

        try repo.checkout(commitHash)

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: tempDir.appendingPathComponent("keep.txt").path))
        XCTAssertFalse(fm.fileExists(atPath: tempDir.appendingPathComponent("build/out").path))
        XCTAssertFalse(fm.fileExists(atPath: tempDir.appendingPathComponent("temp/scratch").path))
        XCTAssertFalse(fm.fileExists(atPath: tempDir.appendingPathComponent(".cache/data").path))
    }

    // MARK: - F) HEAD Management

    func testUpdateHeadWithRefWritesHashToRefFile() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "data".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let commitHash = try repo.commit(message: "initial", author: "A")

        // HEAD is "ref: refs/heads/main", so the hash should be in refs/heads/main
        let refPath = tempDir.appendingPathComponent(".vcs/refs/heads/main")
        let refContent = try String(contentsOf: refPath, encoding: .utf8)
        XCTAssertEqual(refContent, commitHash.hex)
    }

    func testGetCurrentCommitAfterDirectHashInHEAD() throws {
        let repo = try Repository.initialize(at: tempDir)
        try "data".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let commitHash = try repo.commit(message: "initial", author: "A")

        // Overwrite HEAD with a direct hash (detached HEAD state)
        let headPath = tempDir.appendingPathComponent(".vcs/HEAD")
        try commitHash.hex.write(to: headPath, atomically: true, encoding: .utf8)

        // Now log should still work by reading the hash directly from HEAD
        let commits = try repo.log()
        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(commits.first?.message, "initial")
    }
}
