// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "strip-parent-name-nested-objects-default",
    platforms: [.iOS(.v13), .macCatalyst(.v13), .macOS(.v10_15), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(name: "strip-parent-name-nested-objects-default", targets: ["strip-parent-name-nested-objects-default"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jfd02/swift-typed-api", from: "0.3.0")
    ],
    targets: [
        .target(name: "strip-parent-name-nested-objects-default", dependencies: [
            .product(name: "TypedAPI", package: "swift-typed-api")
        ], path: "Sources")
    ]
)