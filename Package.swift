// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "JPEG",
    products: 
    [
        .library(name: "JPEG",      targets: ["JPEG"]), 
        .executable(name: "tests",  targets: ["JPEGTests"])
    ],
    targets: 
    [
        .target(name: "JPEG",                               path: "sources/jpeg"),
        .target(name: "JPEGTests", dependencies: ["JPEG"],  path: "tests"),
    ], 
    swiftLanguageVersions: [.v4_2, .v5]
)
