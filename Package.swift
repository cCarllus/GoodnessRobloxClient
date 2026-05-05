// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GoodnessRobloxClient",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GoodnessRobloxClient", targets: ["GoodnessRobloxClient"]),
        .executable(name: "ParserSmokeTest", targets: ["ParserSmokeTest"])
    ],
    targets: [
        .target(
            name: "GoodnessRobloxClientCore",
            path: "Sources/GoodnessRobloxClientCore"
        ),
        .executableTarget(
            name: "GoodnessRobloxClient",
            dependencies: ["GoodnessRobloxClientCore"],
            path: "Sources/GoodnessRobloxClient"
        ),
        .executableTarget(
            name: "ParserSmokeTest",
            dependencies: ["GoodnessRobloxClientCore"],
            path: "SmokeTests"
        )
    ]
)
