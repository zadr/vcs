// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VCS",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "VCS",
            targets: ["VCS"]),
        .executable(
            name: "vcs-cli",
            targets: ["VCSCLI"])
    ],
    targets: [
        .target(
            name: "VCS",
            dependencies: []),
        .executableTarget(
            name: "VCSCLI",
            dependencies: ["VCS"]),
        .testTarget(
            name: "VCSTests",
            dependencies: ["VCS"]),
    ]
)
