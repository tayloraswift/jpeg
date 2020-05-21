# jpeg

[![platforms](https://img.shields.io/badge/platforms-linux%20%7C%20macos-lightgrey.svg)](https://swift.org)
[![build](https://api.travis-ci.com/kelvin13/jpeg.svg?branch=master)](https://travis-ci.com/github/kelvin13/jpeg)
[![language](https://img.shields.io/badge/version-swift_5-ffa020.svg)](https://swift.org)
[![license](https://img.shields.io/badge/license-GPL3-ff3079.svg)](https://github.com/kelvin13/png/blob/master/COPYING)

Swift *JPEG* is a cross-platform pure Swift framework which provides a full-featured JPEG encoding and decoding API. The core framework has no external dependencies, including *Foundation*, and should compile and provide consistent behavior on *all* Swift platforms. The framework supports additional features, such as file system support, on Linux and MacOS. Swift *JPEG* is available under the [GPL3 open source license](https://choosealicense.com/licenses/gpl-3.0/).

[**tutorials and example programs**](examples/)

## getting started 

decode an image:

```swift 
import JPEG
func decode(jpeg path:String) throws
{
    guard let image:JPEG.Data.Rectangular<JPEG.Common> = try .decompress(path: path)
    else 
    {
        // failed to access file from file system
    }

    let rgb:[JPEG.RGB] = image.unpack(as: JPEG.RGB.self)
    // ...
}
```

encode an image: 

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
            Y:  (factor: (2, 2), qi: 0), 
            Cb: (factor: (1, 1), qi: 1), 
            Cr: (factor: (1, 1), qi: 1),
        ], 
        scans: 
        [
            .sequential((Y,  \.0, \.0), (Cb, \.1, \.1), (Cr, \.1, \.1)),
        ])
    let jfif:JPEG.JFIF = .init(version: .v1_2, density: (1, 1, .centimeters))
    let image:JPEG.Data.Rectangular<JPEG.Common> = 
        .pack(size: size, layout: layout, metadata: [.jfif(jfif)], pixels: rgb)

    try image.compress(path: path, quanta: 
    [
        0: JPEG.CompressionLevel.luminance(  compression).quanta,
        1: JPEG.CompressionLevel.chrominance(compression).quanta
    ])
}
```
