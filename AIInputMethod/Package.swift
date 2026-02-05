// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIInputMethod",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AIInputMethod", targets: ["AIInputMethod"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AIInputMethod",
            dependencies: [],
            path: "Sources"
        )
    ]
)
