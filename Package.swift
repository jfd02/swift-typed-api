// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CreateAPI",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(name: "create-api", targets: ["create-api"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.3"),
        .package(url: "https://github.com/liamnichols/swift-configuration-parser", from: "0.0.4"),
        .package(url: "https://github.com/mattpolzin/OpenAPIKit", from: "3.9.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0"),
        .package(url: "https://github.com/Cosmo/GrammaticalNumber", from: "0.0.3"),
        .package(url: "https://github.com/eonist/FileWatcher", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "create-api",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ConfigurationParser", package: "swift-configuration-parser"),
                .product(name: "OpenAPIKit", package: "OpenAPIKit"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "GrammaticalNumber", package: "GrammaticalNumber"),
                .product(name: "FileWatcher", package: "FileWatcher", condition: .when(platforms: [.macOS])),
                .target(name: "CreateOptions")
            ],
            path: "Sources/CreateAPI"
        ),
        .target(
            name: "CreateOptions",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                .product(name: "ConfigurationParser", package: "swift-configuration-parser")
            ]
        ),
        .testTarget(
            name: "create-api-tests",
            dependencies: [
                "create-api",
                "CreateOptions",
                .product(name: "OpenAPIKit", package: "OpenAPIKit"),
                .product(name: "Yams", package: "Yams")
            ],
            path: "Tests/CreateAPITests"
        ),
        .testTarget(
            name: "CreateOptionsTests",
            dependencies: ["CreateOptions"]
        )
    ]
)
