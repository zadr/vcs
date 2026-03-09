import XCTest
@testable import VCS

final class CompressionRegistryTests: XCTestCase {
    var registry: CompressionRegistry!

    override func setUp() {
        super.setUp()
        registry = CompressionRegistry()
    }

    // MARK: - Default Registration

    func testInitRegistersZlib() {
        XCTAssertNotNil(registry.getStrategy(byName: "zlib"))
    }

    func testInitRegistersLZ4() {
        XCTAssertNotNil(registry.getStrategy(byName: "lz4"))
    }

    func testInitRegistersNone() {
        XCTAssertNotNil(registry.getStrategy(byName: "none"))
    }

    func testInitRegistersJPEGHeaderStrip() {
        XCTAssertNotNil(registry.getStrategy(byName: "jpeg-header-strip"))
    }

    func testDefaultStrategyIsZlib() {
        XCTAssertEqual(registry.defaultStrategy, "zlib")
    }

    // MARK: - getStrategy(byName:)

    func testGetStrategyByNameZlib() {
        let strategy = registry.getStrategy(byName: "zlib")
        XCTAssertEqual(strategy?.name, "zlib")
    }

    func testGetStrategyByNameLZ4() {
        let strategy = registry.getStrategy(byName: "lz4")
        XCTAssertEqual(strategy?.name, "lz4")
    }

    func testGetStrategyByNameNone() {
        let strategy = registry.getStrategy(byName: "none")
        XCTAssertEqual(strategy?.name, "none")
    }

    func testGetStrategyByNameJPEG() {
        let strategy = registry.getStrategy(byName: "jpeg-header-strip")
        XCTAssertEqual(strategy?.name, "jpeg-header-strip")
    }

    func testGetStrategyByNameInvalid() {
        XCTAssertNil(registry.getStrategy(byName: "fake"))
    }

    func testGetStrategyByNameEmpty() {
        XCTAssertNil(registry.getStrategy(byName: ""))
    }

    // MARK: - getStrategy(forPath:) — Text extensions → zlib

    func testGetStrategyForPathTxt() {
        XCTAssertEqual(registry.getStrategy(forPath: "file.txt").name, "zlib")
    }

    func testGetStrategyForPathMd() {
        XCTAssertEqual(registry.getStrategy(forPath: "readme.md").name, "zlib")
    }

    func testGetStrategyForPathSwift() {
        XCTAssertEqual(registry.getStrategy(forPath: "main.swift").name, "zlib")
    }

    func testGetStrategyForPathRs() {
        XCTAssertEqual(registry.getStrategy(forPath: "main.rs").name, "zlib")
    }

    func testGetStrategyForPathJs() {
        XCTAssertEqual(registry.getStrategy(forPath: "app.js").name, "zlib")
    }

    func testGetStrategyForPathTs() {
        XCTAssertEqual(registry.getStrategy(forPath: "app.ts").name, "zlib")
    }

    func testGetStrategyForPathJson() {
        XCTAssertEqual(registry.getStrategy(forPath: "data.json").name, "zlib")
    }

    func testGetStrategyForPathXml() {
        XCTAssertEqual(registry.getStrategy(forPath: "data.xml").name, "zlib")
    }

    func testGetStrategyForPathHtml() {
        XCTAssertEqual(registry.getStrategy(forPath: "index.html").name, "zlib")
    }

    func testGetStrategyForPathCss() {
        XCTAssertEqual(registry.getStrategy(forPath: "style.css").name, "zlib")
    }

    // MARK: - getStrategy(forPath:) — Log → lz4

    func testGetStrategyForPathLog() {
        XCTAssertEqual(registry.getStrategy(forPath: "app.log").name, "lz4")
    }

    // MARK: - getStrategy(forPath:) — JPEG → jpeg-header-strip

    func testGetStrategyForPathJpg() {
        XCTAssertEqual(registry.getStrategy(forPath: "photo.jpg").name, "jpeg-header-strip")
    }

    func testGetStrategyForPathJpeg() {
        XCTAssertEqual(registry.getStrategy(forPath: "photo.jpeg").name, "jpeg-header-strip")
    }

    // MARK: - getStrategy(forPath:) — Already compressed → none

    func testGetStrategyForPathPng() {
        XCTAssertEqual(registry.getStrategy(forPath: "image.png").name, "none")
    }

    func testGetStrategyForPathGif() {
        XCTAssertEqual(registry.getStrategy(forPath: "anim.gif").name, "none")
    }

    func testGetStrategyForPathZip() {
        XCTAssertEqual(registry.getStrategy(forPath: "archive.zip").name, "none")
    }

    func testGetStrategyForPathGz() {
        XCTAssertEqual(registry.getStrategy(forPath: "file.gz").name, "none")
    }

    func testGetStrategyForPathBz2() {
        XCTAssertEqual(registry.getStrategy(forPath: "file.bz2").name, "none")
    }

    func testGetStrategyForPathMp4() {
        XCTAssertEqual(registry.getStrategy(forPath: "video.mp4").name, "none")
    }

    func testGetStrategyForPathMp3() {
        XCTAssertEqual(registry.getStrategy(forPath: "audio.mp3").name, "none")
    }

    func testGetStrategyForPathPdf() {
        XCTAssertEqual(registry.getStrategy(forPath: "doc.pdf").name, "none")
    }

    // MARK: - getStrategy(forPath:) — Unknown/no extension → default

    func testGetStrategyForPathUnknownExt() {
        XCTAssertEqual(registry.getStrategy(forPath: "file.xyz").name, "zlib")
    }

    func testGetStrategyForPathNoExtension() {
        XCTAssertEqual(registry.getStrategy(forPath: "Makefile").name, "zlib")
    }

    func testGetStrategyForPathEmpty() {
        XCTAssertEqual(registry.getStrategy(forPath: "").name, "zlib")
    }

    // MARK: - setCompressionForExtension

    func testSetCompressionForNewExtension() {
        registry.setCompressionForExtension("py", strategy: "lz4")
        XCTAssertEqual(registry.getStrategy(forPath: "script.py").name, "lz4")
    }

    func testSetCompressionOverrideExisting() {
        registry.setCompressionForExtension("txt", strategy: "lz4")
        XCTAssertEqual(registry.getStrategy(forPath: "file.txt").name, "lz4")
    }

    func testSetCompressionCaseInsensitive() {
        registry.setCompressionForExtension("PY", strategy: "lz4")
        XCTAssertEqual(registry.getStrategy(forPath: "script.py").name, "lz4")
    }

    // MARK: - setCompressionForPath

    func testSetCompressionForPath() {
        registry.setCompressionForPath("special/file.txt", strategy: "none")
        XCTAssertEqual(registry.getStrategy(forPath: "special/file.txt").name, "none")
    }

    func testPathOverridePrecedence() {
        // Extension says zlib, path override says none
        registry.setCompressionForPath("data.txt", strategy: "none")
        XCTAssertEqual(registry.getStrategy(forPath: "data.txt").name, "none")
    }

    // MARK: - register

    func testRegisterCustomStrategy() {
        let custom = NoCompression()
        // NoCompression has name "none" — but we can test retrieval
        registry.register(custom)
        let retrieved = registry.getStrategy(byName: "none")
        XCTAssertTrue(retrieved === custom)
    }

    func testRegisterOverwritesExisting() {
        let newZlib = ZlibCompression()
        registry.register(newZlib)
        let retrieved = registry.getStrategy(byName: "zlib")
        XCTAssertTrue(retrieved === newZlib)
    }

    // MARK: - Default strategy fallback (BUG #8)

    func testDefaultStrategyFallbackUnknown() {
        registry.defaultStrategy = "nonexistent"
        // Falls back to new ZlibCompression() instance
        let strategy = registry.getStrategy(forPath: "file.xyz")
        XCTAssertEqual(strategy.name, "zlib")
    }

    func testChangeDefaultStrategy() {
        registry.defaultStrategy = "lz4"
        XCTAssertEqual(registry.getStrategy(forPath: "file.xyz").name, "lz4")
    }
}
