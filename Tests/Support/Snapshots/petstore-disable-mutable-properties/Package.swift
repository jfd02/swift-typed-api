// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "petstore-disable-mutable-properties",
    platforms: [.iOS(.v13), .macCatalyst(.v13), .macOS(.v10_15), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(name: "petstore-disable-mutable-properties", targets: ["petstore-disable-mutable-properties"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jfd02/swift-typed-api", from: "0.3.0")
    ],
    targets: [
        .target(name: "petstore-disable-mutable-properties", dependencies: [
            .product(name: "TypedAPI", package: "swift-typed-api")
        ], path: "Sources")
    ]
)