// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "JPEG",
    products: 
    [
        .library(   name: "jpeg",       targets: ["JPEG"]), 
        .executable(name: "fuzzer",     targets: ["JPEGFuzzer"]),
        .executable(name: "comparator", targets: ["JPEGComparator"]),
        .executable(name: "tests",      targets: ["JPEGTests"]),
    ],
    targets: 
    [
        .target(name: "JPEG",                                   path: "sources/jpeg"),
        .target(name: "JPEGFuzzer",     dependencies: ["JPEG"], path: "tests/fuzz"),
        .target(name: "JPEGComparator", dependencies: ["JPEG"], path: "tests/compare"),
        .target(name: "JPEGTests",      dependencies: ["JPEG"], path: "tests/integration"),
    ], 
    swiftLanguageVersions: [.v4_2, .v5]
)
