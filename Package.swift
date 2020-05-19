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
        .executable(name: "regression-test",    targets: ["JPEGRegressionTests"]),
        .executable(name: "integration-test",   targets: ["JPEGIntegrationTests"]),
        
        .executable(name: "decode-basic",       targets: ["JPEGDecodeBasic"]),
        .executable(name: "encode-basic",       targets: ["JPEGEncodeBasic"]),
        .executable(name: "rotate",             targets: ["JPEGRotate"]),
    ],
    targets: 
    [
        .target(name: "JPEG",                                           path: "sources/jpeg"),
        .target(name: "JPEGFuzzer",             dependencies: ["JPEG"], path: "tests/fuzz"),
        .target(name: "JPEGComparator",         dependencies: ["JPEG"], path: "tests/compare"),
        .target(name: "JPEGUnitTests",          dependencies: ["JPEG"], path: "tests/unit"),
        .target(name: "JPEGRegressionTests",    dependencies: ["JPEG"], path: "tests/regression"),
        .target(name: "JPEGIntegrationTests",   dependencies: ["JPEG"], path: "tests/integration"),
        
        .target(name: "JPEGDecodeBasic",        dependencies: ["JPEG"], path: "examples/decode-basic"),
        .target(name: "JPEGEncodeBasic",        dependencies: ["JPEG"], path: "examples/encode-basic"),
        .target(name: "JPEGRotate",             dependencies: ["JPEG"], path: "examples/rotate"),
    ], 
    swiftLanguageVersions: [.v4_2, .v5]
)
