// swift-tools-version: 5.9
import PackageDescription

let package = Package(
            name: "devping",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
    name: "devping",
            path: "Sources"
        )
    ]
)
