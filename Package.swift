// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "jpeg",
    products: 
    [
        .library(   name: "JPEG",               targets: ["JPEG"]), 
        .executable(name: "JPEG-fuzzer",             targets: ["JPEGFuzzer"]),
        .executable(name: "JPEG-comparator",         targets: ["JPEGComparator"]),
        .executable(name: "JPEG-unit-test",          targets: ["JPEGUnitTests"]),
        .executable(name: "JPEG-regression-test",    targets: ["JPEGRegressionTests"]),
        .executable(name: "JPEG-integration-test",   targets: ["JPEGIntegrationTests"]),
        
        .executable(name: "JPEG-decode-basic",       targets: ["JPEGDecodeBasic"]),
        .executable(name: "JPEG-encode-basic",       targets: ["JPEGEncodeBasic"]),
        .executable(name: "JPEG-decode-advanced",    targets: ["JPEGDecodeAdvanced"]),
        .executable(name: "JPEG-encode-advanced",    targets: ["JPEGEncodeAdvanced"]),
        .executable(name: "JPEG-in-memory",          targets: ["JPEGInMemory"]),
        .executable(name: "JPEG-decode-online",      targets: ["JPEGDecodeOnline"]),
        .executable(name: "JPEG-recompress",         targets: ["JPEGRecompress"]),
        .executable(name: "JPEG-rotate",             targets: ["JPEGRotate"]),
        .executable(name: "JPEG-custom-color",       targets: ["JPEGCustomColor"]),
    ],
    targets: 
    [
        .target(          name: "JPEG",                                           path: "sources/jpeg"),
        .executableTarget(name: "JPEGFuzzer",             dependencies: ["JPEG"], path: "tests/fuzz"),
        .executableTarget(name: "JPEGComparator",         dependencies: ["JPEG"], path: "tests/compare"),
        .executableTarget(name: "JPEGUnitTests",          dependencies: ["JPEG"], path: "tests/unit"),
        .executableTarget(name: "JPEGRegressionTests",    dependencies: ["JPEG"], path: "tests/regression"),
        .executableTarget(name: "JPEGIntegrationTests",   dependencies: ["JPEG"], path: "tests/integration"),
        
        .executableTarget(name: "JPEGDecodeBasic",        dependencies: ["JPEG"], path: "examples/decode-basic"),
        .executableTarget(name: "JPEGEncodeBasic",        dependencies: ["JPEG"], path: "examples/encode-basic"),
        .executableTarget(name: "JPEGDecodeAdvanced",     dependencies: ["JPEG"], path: "examples/decode-advanced"),
        .executableTarget(name: "JPEGEncodeAdvanced",     dependencies: ["JPEG"], path: "examples/encode-advanced"),
        .executableTarget(name: "JPEGInMemory",           dependencies: ["JPEG"], path: "examples/in-memory"),
        .executableTarget(name: "JPEGDecodeOnline",       dependencies: ["JPEG"], path: "examples/decode-online"),
        .executableTarget(name: "JPEGRecompress",         dependencies: ["JPEG"], path: "examples/recompress"),
        .executableTarget(name: "JPEGRotate",             dependencies: ["JPEG"], path: "examples/rotate"),
        .executableTarget(name: "JPEGCustomColor",        dependencies: ["JPEG"], path: "examples/custom-color"),
    ], 
    swiftLanguageVersions: [.v4_2, .v5]
)
