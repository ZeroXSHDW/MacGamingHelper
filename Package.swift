// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacGamingHelper",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacGamingHelper", targets: ["MacGamingHelper"])
    ],
    targets: [
        .executableTarget(
            name: "MacGamingHelper",
            path: "Sources"
        )
    ]
)
