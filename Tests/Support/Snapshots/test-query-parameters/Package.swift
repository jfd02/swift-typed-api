// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "test-query-parameters",
    platforms: [.iOS(.v13), .macCatalyst(.v13), .macOS(.v10_15), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(name: "test-query-parameters", targets: ["test-query-parameters"]),
    ],
    dependencies: [
        .package(url: "https://github.com/0xff8c00/swift-typed-api", from: "0.3.0"),
        .package(url: "https://github.com/CreateAPI/URLQueryEncoder", from: "0.2.0")
    ],
    targets: [
        .target(name: "test-query-parameters", dependencies: [
            .product(name: "TypedAPI", package: "swift-typed-api"),
            .product(name: "URLQueryEncoder", package: "URLQueryEncoder")
        ], path: "Sources")
    ]
)