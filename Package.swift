// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yswift",
    platforms: [.macOS(.v10_15), .iOS(.v15)],
    products: [
        .library(name: "yswift", targets: ["yswift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ObuchiYuki/Promise.git", branch: "main")
    ],
    targets: [
        .target(name: "yswift", dependencies: [.product(name: "Promise", package: "Promise")]),
        .testTarget(name: "yswiftTests", dependencies: ["yswift"])
    ]
)
