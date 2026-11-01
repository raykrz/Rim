// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Notchpad",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Notchpad", targets: ["Notchpad"])
    ],
    targets: [
        .executableTarget(name: "Notchpad", path: "Sources/Notchpad")
    ]
)
