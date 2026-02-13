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
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-F", "Frameworks"]),
                .define("DEBUG", .when(configuration: .debug))
            ],
            linkerSettings: [
                .unsafeFlags(["-F", "Frameworks", "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "AIInputMethodTests",
            dependencies: [],
            path: "Tests"
        )
    ]
)
