// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KyozoClient",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "KyozoClient",
            targets: ["KyozoClient"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "KyozoClient",
            dependencies: []
        ),
        .testTarget(
            name: "KyozoClientTests",
            dependencies: ["KyozoClient"]
        ),
    ]
)