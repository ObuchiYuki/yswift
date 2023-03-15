// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yswift",
    products: [
        .library(name: "yswift", targets: ["yswift"]),
    ],
    dependencies: [
        
    ],
    targets: [
        .target(name: "yswift", dependencies: []),
        .testTarget(name: "yswiftTests", dependencies: ["yswift"]),
    ]
)
