# swift jpeg tutorials

*jump to:*

* [basic decoding](#basic-decoding) ([sources](decode-basic/))
* [basic encoding](#basic-encoding) ([sources](encode-basic/))
* [lossless rotations](#lossless-rotations) ([sources](rotate/))
* [increasing a file’s compression level](#increasing-a-files-compression-level) ([sources](recompress/))

---

## basic decoding 
[`sources`](decode-basic/)

On platforms with built-in file system support (MacOS, Linux), decoding a JPEG file to a pixel array takes just two function calls.

```swift 
import JPEG 

let path:String = "examples/decode-basic/karlie-kwk-2019.jpg"
guard let image:JPEG.Data.Rectangular<JPEG.Common> = try .decompress(path: path)
else 
{
    fatalError("failed to open file '\(path)'")
}

let rgb:[JPEG.RGB] = image.unpack(as: JPEG.RGB.self)
```

<img src="decode-basic/karlie-kwk-2019.jpg" alt="output (as png)" width=512/>

> *Karlie Kloss at [Kode With Klossy](https://www.kodewithklossy.com/) 2019*
>
> *(photo by Shantell Martin)*


The pixel unpacking can also be done with the `JPEG.YCbCr` built-in target, to obtain an image in its native [YCbCr](https://en.wikipedia.org/wiki/YCbCr) color space.

```swift 
let ycc:[JPEG.YCbCr] = image.unpack(as: JPEG.YCbCr.self)
```

The `.unpack(as:)` method is [non-mutating](https://docs.swift.org/swift-book/LanguageGuide/Methods.html#ID239), so you can unpack the same image to multiple color targets without having to re-decode the file each time.

<img src="decode-basic/karlie-kwk-2019.jpg.rgb.png" alt="output (as png)" width=512/>

> decoded jpeg image, saved in png format

---

## basic encoding 
[`sources`](encode-basic/)

Encoding a JPEG file is somewhat more complex than decoding one due to the number of encoding options available. We’ll assume you have a pixel buffer containing the image you want to save as a JPEG, along with its dimensions, and the prefix of the file path you want to write it to. (As with the decoder, built-in file system support is only available on MacOS and Linux.)

```swift 
let rgb:[JPEG.RGB]      = [ ... ] , 
    size:(x:Int, y:Int) = (400, 665)
let path:String         = "examples/encode-basic/karlie-milan-sp12-2011", 
```

<img src="encode-basic/karlie-milan-sp12-2011.rgb.png" alt="input (as png)" width=256/>

> *Karlie Kloss at Milan Fashion Week Spring 2012, in 2011*
> 
> *(photo by John “hugo971”)*

To explore some of the possible encoding options, we will export images under varying subsampling schemes and quality levels. The outer loop will iterate through four different subsampling modes, which include human-readable suffixes that will go into the generated file names:

```swift 
for factor:(luminance:(x:Int, y:Int), chrominance:(x:Int, y:Int), name:String) in 
[
    ((1, 1), (1, 1), "4:4:4"),
    ((1, 2), (1, 1), "4:4:0"),
    ((2, 1), (1, 1), "4:2:2"),
    ((2, 2), (1, 1), "4:2:0"),
]
```

If you don’t know what subsampling is, or what the colon-separated notation means, it’s a way of encoding the grayscale and color channels of an image in different resolutions to save space. The first number in the colon-separated notation is always 4 and represents two rows of four luminance pixels; the second number represents the number of corresponding chrominance pixels in the first row, and the third number represents the number of corresponding chrominance pixels in the second row, or is 0 if there is no second row.

```
          Y                      Cb,Cr 
┏━━━━┱────┬────┬────┐    ┏━━━━┱────┬────┬────┐
┃    ┃    │    │    │    ┃    ┃    │    │    │
┡━━━━╃────┼────┼────┤ ←→ ┡━━━━╃────┼────┼────┤    4:4:4
│    │    │    │    │    │    │    │    │    │
└────┴────┴────┴────┘    └────┴────┴────┴────┘

┏━━━━┱────┬────┬────┐    ┏━━━━┱────┬────┬────┐
┃    ┃    │    │    │    ┃    ┃    │    │    │
┠────╂────┼────┼────┤ ←→ ┃    ┃    │    │    │    4:4:0
┃    ┃    │    │    │    ┃    ┃    │    │    │
┗━━━━┹────┴────┴────┘    ┗━━━━┹────┴────┴────┘

┏━━━━┯━━━━┱────┬────┐    ┏━━━━━━━━━┱─────────┐
┃    │    ┃    │    │    ┃         ┃         │
┡━━━━┿━━━━╃────┼────┤ ←→ ┡━━━━━━━━━╃─────────┤    4:2:2
│    │    │    │    │    │         │         │
└────┴────┴────┴────┘    └─────────┴─────────┘

┏━━━━┯━━━━┱────┬────┐    ┏━━━━━━━━━┱─────────┐
┃    │    ┃    │    │    ┃         ┃         │
┠────┼────╂────┼────┤ ←→ ┃         ┃         │    4:2:0
┃    │    ┃    │    │    ┃         ┃         │
┗━━━━┷━━━━┹────┴────┘    ┗━━━━━━━━━┹─────────┘
```

The sampling factors are alternative ways of expressing these configurations, indicating the number of samples in a minimum coded unit (bolded line).

We will use these settings to initialize a `Layout` structure specifying the shape and scan progression of the JPEG file you want to output.

```swift 
let layout:JPEG.Layout<JPEG.Common> = .init(
    format:     .ycc8,
    process:    .baseline, 
    components: 
    [
        1: (factor: factor.luminance,   qi: 0 as JPEG.Table.Quantization.Key), 
        2: (factor: factor.chrominance, qi: 1 as JPEG.Table.Quantization.Key), 
        3: (factor: factor.chrominance, qi: 1 as JPEG.Table.Quantization.Key),
    ], 
    scans: 
    [
        .sequential((1, \.0, \.0)),
        .sequential((2, \.1, \.1), (3, \.1, \.1))
    ])
```

The `JPEG.Common` generic parameter is the same as the one that appeared in the `JPEG.Data.Rectangular` type in the [basic decoding](#basic-decoding) example. It is the type of the `format:` argument which specifies the color format that you want to save the image in. The `JPEG.Common` enumeration has four cases:

* `y8`: (8-bit [grayscale](https://en.wikipedia.org/wiki/Grayscale), *Y*&nbsp;=&nbsp;1)
* `ycc8`: (8-bit [YCbCr](https://en.wikipedia.org/wiki/YCbCr), *Y*&nbsp;=&nbsp;1, *Cb*&nbsp;=&nbsp;2, *Cr*&nbsp;=&nbsp;3)
* `nonconforming1x8` `(c1)`: (8-bit [grayscale](https://en.wikipedia.org/wiki/Grayscale), non-conforming scalars)
* `nonconforming3x8` `(c1, c2, c3)`: (8-bit [YCbCr](https://en.wikipedia.org/wiki/YCbCr), non-conforming triplets)

The last two cases are not standard JPEG color formats, they are provided for compatibility with older, buggy JPEG encoders.

The `process:` argument specifies the JPEG coding process we are going to use to encode the image. Here, we have set it to the `baseline` process, which all browsers and image viewers should be able to display.

The `components:` argument takes a dictionary mapping `JPEG.Component.Key`s to their sampling factors and `JPEG.Table.Quantization.Key`s. Both key types are [`ExpressibleByIntegerLiteral`](https://developer.apple.com/documentation/swift/expressiblebyintegerliteral)s, so we’ve written them with their integer values. (We need the `as` coercion for the quantization keys in this example because the compiler is having issues inferring the type context here.)

Because we are using the standard `ycc8` color format, component 1 always represents the *Y* channel; component 2, the *Cb* channel; and component 3, the *Cr* channel. As long as we are using the `ycc8` color format, the dictionary must consist of these three component keys. (The quantization table keys can be anything you want.)

The `scans:` argument specifies the scan progression of the JPEG file, and takes an array of `JPEG.Header.Scan`s. Because we are using the `baseline` coding process, we can only use sequential scans, which we initialize using the `.sequential(_:...)` static constructor. Here, we have defined one single-component scan containing the luminance channel, and another two-component interleaved scan containing the two color channels.

The two [keypaths](https://developer.apple.com/documentation/swift/keypath) in each component tuple specify [huffman table](https://en.wikipedia.org/wiki/Huffman_coding) destinations (DC and AC, respectively); if the AC or DC selectors are the same for each component in a scan, then those components will share the same (AC or DC) huffman table. The interleaved color scan 

```
        .sequential((2, \.1, \.1), (3, \.1, \.1))
```

will use one shared DC table, and one shared AC tables (two tables total). If we specified it like this:

```
        .sequential((2, \.1, \.1), (3, \.0, \.0))
```

then the scan will use a separate DC and separate AC table for each component (four tables total). Using separate tables for each component may result in better compression.

There are four possible selectors for each table type (`\.0`, `\.1`, `\.2`, and `\.3`), but since we are using the `baseline` coding process, we are only allowed to use selectors `\.0` and `\.1`. (Other coding processes can use all four.)

Next, we initialize a `JPEG.JFIF` metadata record with some placeholder values.

```swift 
let jfif:JPEG.JFIF = .init(version: .v1_2, density: (1, 1, .dpcm))
```

This step is not really necessary, but some applications may expect [JFIF](https://en.wikipedia.org/wiki/JPEG_File_Interchange_Format) metadata to be present, so we fill out this record with some junk values anyway.

Finally, we combine the layout, metadata, and the image contents into a `JPEG.Data.Rectangular` structure.

```swift 
let image:JPEG.Data.Rectangular<JPEG.Common> = 
    .pack(size: size, layout: layout, metadata: [.jfif(jfif)], pixels: rgb)
```

The static `.pack(size:layout:metadata:pixels:)` method is generic and can also take an array of native `JPEG.YCbCr` pixels.

The next step is to specify the quantum values the encoder will use to compress each of the image components. JPEG has no concept of linear “quality”; the quantization table values are completely independent. Still, the framework provides the `JPEG.CompressionLevel` APIs to generate quantum values from a single “quality” parameter.

```swift 
enum JPEG.CompressionLevel 
{
    case luminance(Double)
    case chrominance(Double)
    
    var quanta:[UInt16] 
    {
        get 
    }
}
```

The only difference between the `luminance(_:)` and `chrominance(_:)` cases is that one produces quantum values optimized for the *Y* channel while the other produces values optimized for the *Cb* and *Cr* channels.

We then loop through different compression levels and use the `.compress(path:quanta:)` method to encode the files. The keys in the dictionary for the `quanta:` argument must match the quantization table keys in the image layout.

```swift 
for level:Double in [0.0, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0] 
{
    try image.compress(path: "\(path)-\(factor.name)-\(level).jpg", quanta: 
    [
        0: JPEG.CompressionLevel.luminance(  level).quanta,
        1: JPEG.CompressionLevel.chrominance(level).quanta
    ])
}
```

This example program will generate 32 output images. For comparison, the PNG-encoded image is about 548&nbsp;KB in size.

***4:4:4 subsampling***

| *l* = 0.0  | *l* = 0.125 | *l* = 0.25 | *l* = 0.5 |
| ---------- | ----------- | ---------- | --------- |
| 365.772 KB | 136.063 KB  | 98.233 KB  | 66.457 KB |
|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:4-0.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:4-0.125.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:4-0.25.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:4-0.5.jpg"/>

| *l* = 1.0 | *l* = 2.0 | *l* = 4.0 | *l* = 8.0 |
| --------- | --------- | --------- | --------- |
| 46.548 KB | 32.378 KB | 22.539 KB | 15.708 KB |  
|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:4-1.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:4-2.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:4-4.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:4-8.0.jpg"/>|

***4:4:0 subsampling***

| *l* = 0.0  | *l* = 0.125 | *l* = 0.25 | *l* = 0.5 |
| ---------- | ----------- | ---------- | --------- |
| 290.606 KB | 116.300 KB  | 84.666 KB  | 58.284 KB | 
|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:0-0.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:0-0.125.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:0-0.25.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:0-0.5.jpg"/>|

| *l* = 1.0 | *l* = 2.0 | *l* = 4.0 | *l* = 8.0 |
| --------- | --------- | --------- | --------- |
| 41.301 KB | 28.362 KB | 18.986 KB | 12.367 KB | 
|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:0-1.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:0-2.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:0-4.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:4:0-8.0.jpg"/>|

***4:2:2 subsampling***

| *l* = 0.0  | *l* = 0.125 | *l* = 0.25 | *l* = 0.5 |
| ---------- | ----------- | ---------- | --------- |
| 288.929 KB | 116.683 KB  | 85.089 KB  | 58.816 KB |
|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:2-0.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:2-0.125.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:2-0.25.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:2-0.5.jpg"/>|

| *l* = 1.0 | *l* = 2.0 | *l* = 4.0 | *l* = 8.0 |
| --------- | --------- | --------- | --------- |
| 41.759 KB | 28.694 KB | 19.173 KB | 12.463 KB | 
|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:2-1.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:2-2.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:2-4.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:2-8.0.jpg"/>|

***4:2:0 subsampling***

| *l* = 0.0  | *l* = 0.125 | *l* = 0.25 | *l* = 0.5 |
| ---------- | ----------- | ---------- | --------- |
| 247.604 KB | 106.800 KB  | 78.437 KB  | 54.693 KB |
|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:0-0.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:0-0.125.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:0-0.25.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:0-0.5.jpg"/>|

| *l* = 1.0 | *l* = 2.0 | *l* = 4.0 | *l* = 8.0 |
| --------- | --------- | --------- | --------- |
| 38.912 KB | 26.466 KB | 17.299 KB | 10.744 KB | 
|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:0-1.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:0-2.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:0-4.0.jpg"/>|<img width=256 src="encode-basic/karlie-milan-sp12-2011-4:2:0-8.0.jpg"/>|
