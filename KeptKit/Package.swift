// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KeptKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "KeptKit", targets: ["KeptKit"])
    ],
    targets: [
        .target(name: "KeptKit")
    ]
)
