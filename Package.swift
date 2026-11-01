// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RIM",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "RIM", targets: ["RIM"])
    ],
    targets: [
        .executableTarget(name: "RIM", path: "Sources/RIM")
    ]
)
