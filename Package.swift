// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "JPEG",
    products: [
        .library(name: "JPEG", targets: ["JPEG"])
    ],
    targets: [
        .target(
            name: "JPEG",
            path: "sources/jpeg"),
        .testTarget(
            name: "JPEGTests",
            dependencies: ["JPEG"],
            path: "tests/jpeg"),
    ]
)
