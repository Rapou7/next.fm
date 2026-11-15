// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NextFMCore",
    platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [.library(name: "NextFMCore", targets: ["NextFMCore"])],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3", providers: [.apt(["libsqlite3-dev"])]),
        .target(name: "NextFMCore", dependencies: ["CSQLite"]),
        .testTarget(name: "NextFMCoreTests", dependencies: ["NextFMCore"])
    ]
)
