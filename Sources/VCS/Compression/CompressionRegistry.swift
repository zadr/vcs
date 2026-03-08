import Foundation

public class CompressionRegistry {
    private var strategies: [String: CompressionStrategy] = [:]
    private var extensionMap: [String: String] = [:]
    private var pathOverrides: [String: String] = [:]
    public var defaultStrategy: String = "lzfse"

    public init() {
        register(ZlibCompression())
        register(LZ4Compression())
        register(NoCompression())
        register(JPEGHeaderCompression())
        register(LZFSECompression())

        configureDefaults()
    }

    private func configureDefaults() {
        extensionMap["jpg"] = "jpeg-header-strip"
        extensionMap["jpeg"] = "jpeg-header-strip"
        extensionMap["png"] = "none"
        extensionMap["gif"] = "none"
        extensionMap["zip"] = "none"
        extensionMap["gz"] = "none"
        extensionMap["bz2"] = "none"
        extensionMap["mp4"] = "none"
        extensionMap["mp3"] = "none"
        extensionMap["pdf"] = "none"

        extensionMap["txt"] = "lzfse"
        extensionMap["md"] = "lzfse"
        extensionMap["swift"] = "lzfse"
        extensionMap["rs"] = "lzfse"
        extensionMap["js"] = "lzfse"
        extensionMap["ts"] = "lzfse"
        extensionMap["json"] = "lzfse"
        extensionMap["xml"] = "lzfse"
        extensionMap["html"] = "lzfse"
        extensionMap["css"] = "lzfse"

        extensionMap["log"] = "lz4"
    }

    public func register(_ strategy: CompressionStrategy) {
        strategies[strategy.name] = strategy
    }

    public func setCompressionForExtension(_ ext: String, strategy: String) {
        extensionMap[ext.lowercased()] = strategy
    }

    public func setCompressionForPath(_ path: String, strategy: String) {
        pathOverrides[path] = strategy
    }

    public func getStrategy(forPath path: String) -> CompressionStrategy {
        if let override = pathOverrides[path],
           let strategy = strategies[override] {
            return strategy
        }

        let ext = (path as NSString).pathExtension.lowercased()
        if let strategyName = extensionMap[ext],
           let strategy = strategies[strategyName] {
            return strategy
        }

        return strategies[defaultStrategy] ?? ZlibCompression()
    }

    public func getStrategy(byName name: String) -> CompressionStrategy? {
        return strategies[name]
    }
}
