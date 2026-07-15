// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PocketInputKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PocketInputKit", targets: ["PocketInputKit"]),
    ],
    targets: [
        .target(name: "PocketInputKit"),
    ]
)
