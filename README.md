# jpeg

[![platforms](https://img.shields.io/badge/platforms-linux%20%7C%20macos-lightgrey.svg)](https://swift.org)
[![releases](https://img.shields.io/github/v/release/kelvin13/jpeg)](https://github.com/kelvin13/jpeg/releases)
[![build](https://img.shields.io/github/workflow/status/kelvin13/jpeg/build/master)](https://github.com/kelvin13/jpeg/actions?query=workflow%3Abuild)
[![build documentation](https://img.shields.io/github/workflow/status/kelvin13/jpeg/documentation/master?label=build%20docs)](https://github.com/kelvin13/jpeg/actions?query=workflow%3Adocumentation)
[![issues](https://img.shields.io/github/issues/kelvin13/jpeg)](https://github.com/kelvin13/jpeg/issues?state=open)
[![language](https://img.shields.io/badge/version-swift_5.5-ffa020.svg)](https://swift.org)
[![license](https://img.shields.io/badge/license-MPL2-ff3079.svg)](https://github.com/kelvin13/jpeg/blob/master/LICENSE)

Swift *JPEG* is a cross-platform pure Swift framework for decoding, inspecting, editing, and encoding JPEG images. The core framework has no external dependencies, including *Foundation*, and should compile and provide consistent behavior on *all* Swift platforms. The framework supports additional features, such as file system support, on Linux and MacOS. 

Swift *JPEG* is available under the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/). The [example programs](examples/) are public domain and can be adapted freely.

## [tutorials and example programs](examples/)

* [basic decoding](examples#basic-decoding) ([sources](decode-basic/))
* [basic encoding](examples#basic-encoding) ([sources](encode-basic/))
* [advanced decoding](examples#advanced-decoding) ([sources](decode-advanced/))
* [advanced encoding](examples#advanced-encoding) ([sources](encode-advanced/))
* [using in-memory images](examples#using-in-memory-images) ([sources](in-memory/))
* [online decoding](examples#online-decoding) ([sources](decode-online/))
* [requantizing images](examples#requantizing-images) ([sources](recompress/))
* [lossless rotations](examples#lossless-rotations) ([sources](rotate/))
* [custom color formats](examples#custom-color-formats) ([sources](custom-color/))

## [api reference](https://kelvin13.github.io/jpeg/)

* [`JPEG.JPEG`](https://kelvin13.github.io/jpeg/JPEG/)
* [`JPEG.General`](https://kelvin13.github.io/jpeg/General/)
* [`JPEG.System`](https://kelvin13.github.io/jpeg/System/)

## getting started 

To Swift *JPEG* in a project, add this descriptor to the `dependencies` list in your `Package.swift`:

```swift 
.package(url: "https://github.com/kelvin13/jpeg", .exact("1.0.0")) 
```

## basic usage

Decode an image:

```swift 
import JPEG
func decode(jpeg path:String) throws
{
    guard let image:JPEG.Data.Rectangular<JPEG.Common> = try .decompress(path: path)
    else 
    {
        // failed to access file from file system
    }

    let rgb:[JPEG.RGB]      = image.unpack(as: JPEG.RGB.self), 
        size:(x:Int, y:Int) = image.size
    // ...
}
```

Encode an image: 

```swift 
import JPEG
func encode(jpeg path:String, size:(x:Int, y:Int), pixels:[JPEG.RGB], 
    compression:Double) // 0.0 = highest quality
    throws 
{
    let layout:JPEG.Layout<JPEG.Common> = .init(
        format:     .ycc8,
        process:    .baseline, 
        components: 
        [
            1: (factor: (2, 2), qi: 0), // Y
            2: (factor: (1, 1), qi: 1), // Cb
            3: (factor: (1, 1), qi: 1), // Cr 
        ], 
        scans: 
        [
            .sequential((1, \.0, \.0), (2, \.1, \.1), (3, \.1, \.1)),
        ])
    let jfif:JPEG.JFIF = .init(version: .v1_2, density: (72, 72, .inches))
    let image:JPEG.Data.Rectangular<JPEG.Common> = 
        .pack(size: size, layout: layout, metadata: [.jfif(jfif)], pixels: rgb)

    try image.compress(path: path, quanta: 
    [
        0: JPEG.CompressionLevel.luminance(  compression).quanta,
        1: JPEG.CompressionLevel.chrominance(compression).quanta
    ])
}
```
