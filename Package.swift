// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "JPEG",
    products: 
    [
        .library(   name: "jpeg",               targets: ["JPEG"]), 
        .executable(name: "fuzzer",             targets: ["JPEGFuzzer"]),
        .executable(name: "comparator",         targets: ["JPEGComparator"]),
        .executable(name: "unit-test",          targets: ["JPEGUnitTests"]),
        .executable(name: "integration-test",   targets: ["JPEGIntegrationTests"]),
    ],
    targets: 
    [
        .target(name: "JPEG",                                           path: "sources/jpeg"),
        .target(name: "JPEGFuzzer",             dependencies: ["JPEG"], path: "tests/fuzz"),
        .target(name: "JPEGComparator",         dependencies: ["JPEG"], path: "tests/compare"),
        .target(name: "JPEGUnitTests",          dependencies: ["JPEG"], path: "tests/unit"),
        .target(name: "JPEGIntegrationTests",   dependencies: ["JPEG"], path: "tests/integration"),
    ], 
    swiftLanguageVersions: [.v4_2, .v5]
)
