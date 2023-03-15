// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yswift",
    products: [
        .library(name: "yswift", targets: ["yswift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ObuchiYuki/lib0-swift.git", branch: "main")
    ],
    targets: [
        .target(name: "yswift", dependencies: [
            .product(name: "lib0", package: "lib0-swift")
        ]),
        .testTarget(name: "yswiftTests", dependencies: ["yswift"]),
    ]
)
