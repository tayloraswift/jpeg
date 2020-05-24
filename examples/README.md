# swift jpeg tutorials

*jump to:*

1. [basic decoding](#basic-decoding) ([sources](decode-basic/))
2. [basic encoding](#basic-encoding) ([sources](encode-basic/))
3. [advanced decoding](#advanced-decoding) ([sources](decode-advanced/))
4. [advanced encoding](#advanced-encoding) ([sources](encode-advanced/))
5. [using in-memory images](#using-in-memory-images) (sources)
6. [artistic degradation](#artistic-degradation) (sources)
7. [online decoding](#online-decoding) (sources)
8. [annotating images](#annotating-files) (sources)
9. [requantizing images](#requantizing-images) ([sources](recompress/))
10. [lossless rotations](#lossless-rotations) ([sources](rotate/))
11. [custom color formats](#custom-color-formats) (sources)

---

*while traditionally, the field of image processing uses [lena forsén](https://en.wikipedia.org/wiki/Lena_Fors%C3%A9n)’s [1972 playboy shoot](https://www.wired.com/story/finding-lena-the-patron-saint-of-jpegs/) as its standard test image, in these tutorials, we will be using pictures of modern supermodel [karlie kloss](https://twitter.com/karliekloss) as our example data. karlie is a longstanding advocate for women in science and technology, and founded the [kode with klossy](https://www.kodewithklossy.com/) summer camps in 2015 for girls interested in studying computer science. karlie is also [an advocate](https://www.engadget.com/2018-03-16-karlie-kloss-coding-camp-more-cities-and-languages.html) for [the swift language](https://swift.org/).*

*[view photo attributions](attribution.md)*

---

## basic decoding 
[`sources`](decode-basic/)

> ***by the end of this tutorial, you should be able to:***
> * *decompress a jpeg file to its rectangular image representation*
> * *unpack rectangular image data to the rgb and ycbcr built-in color targets*

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

> Decoded JPEG image, saved in PNG format.

---

## basic encoding 
[`sources`](encode-basic/)

> ***by the end of this tutorial, you should be able to:***
> * *encode a jpeg file using the baseline sequential coding process*
> * *understand and use chroma subsampling*
> * *define image layouts and sequential scan progressions*
> * *define basic huffman and quantization table relationships*
> * *use the parameterized quantization api to save images at different quality levels*

Encoding a JPEG file is somewhat more complex than decoding one due to the number of encoding options available. We’ll assume you have a pixel buffer containing the image you want to save as a JPEG, along with its dimensions, and the prefix of the file path you want to write it to. (As with the decoder, built-in file system support is only available on MacOS and Linux.)

```swift 
import JPEG 

let rgb:[JPEG.RGB]      = [ ... ] , 
    size:(x:Int, y:Int) = (400, 665)
let path:String         = "examples/encode-basic/karlie-milan-sp12-2011", 
```

<img src="encode-basic/karlie-milan-sp12-2011.rgb.png" alt="input (as png)" width=256/>

> *Karlie Kloss at Milan Fashion Week Spring 2012, in 2011*
> 
> *(photo by John “hugo971”)*

To explore some of the possible encoding options, we will export images under varying **subsampling** schemes and quality levels. The outer loop will iterate through four different subsampling modes, which include human-readable suffixes that will go into the generated file names:

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

We will use these settings to initialize a `JPEG.Layout` structure specifying the shape and scan progression of the JPEG file you want to output.

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

Because we are using the standard `ycc8` color format, component **1** always represents the *Y* channel; component **2**, the *Cb* channel; and component **3**, the *Cr* channel. As long as we are using the `ycc8` color format, the dictionary must consist of these three component keys. (The quantization table keys can be anything you want.)

The `scans:` argument specifies the **scan progression** of the JPEG file, and takes an array of `JPEG.Header.Scan`s. Because we are using the `baseline` coding process, we can only use sequential scans, which we initialize using the `.sequential(_:...)` static constructor. Here, we have defined one single-component scan containing the luminance channel, and another two-component interleaved scan containing the two color channels.

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
let jfif:JPEG.JFIF = .init(version: .v1_2, density: (1, 1, .centimeters))
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

---

## advanced decoding 

[`sources`](decode-advanced/)

> ***by the end of this tutorial, you should be able to:***
> * *use the multi-stage decompression api*
> * *read image sizes, metadata records, and layouts*
> * *understand the size metrics used by different data models*
> * *understand the difference between centered and cosited sampling*
> * *convert intra-data unit grid coordinates to zigzag indices*
> * *access values from a quantization table*

In the [basic decoding](#basic-decoding) tutorial, we used the single-stage `.decompress(path:)` function to inflate a JPEG file from disk directly to its `Data.Rectangular` representation. This time, we will decompress the file to an intermediate representation modeled by the `JPEG.Data.Spectral` type.

```swift 
import JPEG 

let path:String = "examples/decode-advanced/karlie-2019.jpg"
guard let spectral:JPEG.Data.Spectral<JPEG.Common> = try .decompress(path: path)
else 
{
    fatalError("failed to open file '\(path)'")
}
```

<img src="decode-advanced/karlie-2019.jpg" width=512/>

> *Karlie Kloss leaving a [Cavs vs. Hornets basketball game](https://www.cleveland.com/cavs/2019/04/cleveland-cavaliers-end-season-with-124-97-loss-finish-with-fourth-worst-record-in-franchise-history-chris-fedors-instant-analysis.html) at [Rocket Mortgage FieldHouse](https://en.wikipedia.org/wiki/Rocket_Mortgage_FieldHouse) in 2019*
> 
> *(photo by Erik Drost)*

The spectral representation is the native representation of a JPEG image. That means that the image can be re-encoded from a `JPEG.Data.Spectral` structure without any loss of information.

We can access the image’s pixel dimensions through the `.size` property, which returns a `(x:Int, y:Int)` tuple, and its layout through the `.layout` property, which returns a `JPEG.Layout` structure, the same type that we used in the [basic encoding](#basic-encoding) tutorial.

The `JPEG.Layout` structure has the following members:

```swift 
struct JPEG.Layout<Format> where Format:JPEG.Format 
{
    // the color format of the image 
    let format:Format  
    // the coding process of the image 
    let process:JPEG.Process
    
    // a dictionary mapping each of the color components in the image 
    // to the index of the image plane storing it
    let residents:[JPEG.Component.Key: Int]
    
    // descriptors for each plane in the image 
    internal(set)
    var planes:[(component:JPEG.Component, qi:JPEG.Table.Quantization.Key)]
    // the sequence of scan and table declarations in the image 
    private(set)
    var definitions:[(quanta:[JPEG.Table.Quantization.Key], scans:[JPEG.Scan])]
}
```

We can print some of this information out like this:

```swift 
"""
'\(path)' (\(spectral.layout.format))
{
    size        : (\(spectral.size.x), \(spectral.size.y))
    process     : \(spectral.layout.process)
    precision   : \(spectral.layout.format.precision)
    components  : 
    [
        \(spectral.layout.residents.sorted(by: { $0.key < $1.key }).map 
        {
            let (component, qi):(JPEG.Component, JPEG.Table.Quantization.Key) = 
                spectral.layout.planes[$0.value]
            return "\($0.key): (\(component.factor.x), \(component.factor.y), qi: \(qi))"
        }.joined(separator: "\n        "))
    ]
    scans       : 
    [
        \(spectral.layout.scans.map 
        {
            "[band: \($0.band), bits: \($0.bits)]: \($0.components.map(\.ci))"
        }.joined(separator: "\n        "))
    ]
}
"""
```

```
'examples/decode-advanced/karlie-2019.jpg' (ycc8)
{
    size        : (640, 426)
    process     : baseline sequential DCT
    precision   : 8
    components  : 
    [
        [1]: (2, 2, qi: [0])
        [2]: (1, 1, qi: [1])
        [3]: (1, 1, qi: [1])
    ]
    scans       : 
    [
        [band: 0..<64, bits: 0..<9223372036854775807]: [[1], [2], [3]]
    ]
}

```

Here we can see that this image:

* is 640 pixels wide, and 426 pixels high,
* uses the baseline sequential coding process ,
* uses the 8-bit YCbCr color format, with standard component key assignments *Y*&nbsp;=&nbsp;**1**, *Cb*&nbsp;=&nbsp;**2**, and *Cr*&nbsp;=&nbsp;**3**,
* uses one quantization table (key **0**) for the *Y* component, and one (key **1**) for the *Cb* and *Cr* components,
* uses 4:2:0 chroma subsampling, and 
* has one sequential, interleaved scan encoding all three color components.

We can also read (and modify) the image metadata through the `.metadata` property, which stores an array of metadata records in the order in which they were encountered in the file. The metadata records are enumerations which come in four cases:

```swift 
enum JPEG.Metadata 
{
    case jfif       (JPEG.JFIF)
    case exif       (JPEG.EXIF)
    case application(Int, data:[UInt8])
    case comment    (data:[UInt8])
}
```

It should be noted that both JFIF and EXIF metadata segments are special types of `application(_:data:)` segments, with JFIF being equivalent to `application(0, data: ... )`, and EXIF being equivalent to `application(1, data: ... )`. The framework will only parse them as `JPEG.JFIF` or `JPEG.EXIF` if it encounters them at the very beginning of the JPEG file, and it will only parse one instance of each per file. This means that if for some reason, a JPEG file contains multiple JFIF segments (for example, to store a thumbnail), the latter segments will get parsed as regular `application(_:data:)` segments.

We can print out the metadata records like this: 

```swift 
for metadata:JPEG.Metadata in spectral.metadata
{
    switch metadata 
    {
    case .jfif(let jfif):
        print(jfif)
    case .exif(let exif):
        print(exif)
    case .application(let a, data: let data):
        print("metadata (application \(a), \(data.count) bytes)")
    case .comment(data: let data):
        print("""
        comment 
        {
            '\(String.init(decoding: data, as: Unicode.UTF8.self))'
        }
        """)
    }
}
```

```
metadata (EXIF)
{
    endianness  : bigEndian
    storage     : 126 bytes 
}
metadata (application 2, 538 bytes)
```

We can see that this image contains an EXIF segment which uses big-endian byte order. (JPEG data is always big-endian, but EXIF data can be big-endian or little-endian.) It also contains a [Flashpix EXIF extension](https://en.wikipedia.org/wiki/Exif#FlashPix_extensions) segment, which shows up here as an unparsed 538-byte APP2 segment.

The `.size`, `.layout`, and `.metadata` properties are available on all image representations, including `JPEG.Data.Rectangular`, so you don’t need to go through this multistep decompression process to access them. However, the spectral representation is unique in that it also provides access to the quantization tables used by the image.

First we uniquify the quanta keys used by the all the planes in the image, since some planes may reference the same quantization table.

```swift 
let keys:Set<JPEG.Table.Quantization.Key> = .init(spectral.layout.planes.map(\.qi))
```

Then, for each of the quanta keys, we use the `.index(forKey:)` method on the `.quanta` member of the `JPEG.Data.Spectral` structure to obtain an integer index we can subscript the quanta storage with to get the table. (Accessing quantization tables with an index is a little more efficient than doing a new key lookup each time.)

```swift
let q:Int                           = spectral.quanta.index(forKey: qi) 
let table:JPEG.Table.Quantization   = spectral.quanta[q]

print("quantization table \(qi):")
```

The quantum values (and the spectral coefficients) are stored in a special **zigzag order**:

``` 
0    1    2    3    4    5    6    7    k
┏━━━━┱────┬────┬────┬────┬────┬────┬────┐  0
┃  0 →  1 │  5 →  6 │ 14 → 15 │ 27 → 28 │
┡━━━ ↙ ── ↗ ── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ───┤  1
│  2 │  4 │  7 │ 13 │ 16 │ 26 │ 29 │ 42 │
├─ ↓ ↗ ── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ── ↗ ↓ ─┤  2
│  3 │  8 │ 12 │ 17 │ 25 │ 30 │ 41 │ 43 │
├─── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ───┤  3
│  9 │ 11 │ 18 │ 24 │ 31 │ 40 │ 44 │ 53 │
├─ ↓ ↗ ── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ── ↗ ↓ ─┤  4
│ 10 │ 19 │ 23 │ 32 │ 39 │ 45 │ 52 │ 54 │
├─── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ───┤  5
│ 20 │ 22 │ 33 │ 38 │ 46 │ 51 │ 55 │ 60 │
├─ ↓ ↗ ── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ── ↗ ↓ ─┤  6
│ 21 │ 34 │ 37 │ 47 │ 50 │ 56 │ 59 │ 61 │
├─── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ── ↗ ── ↙ ───┤  7
│ 35 → 36 │ 48 → 49 │ 57 → 58 │ 62 → 63 │
└────┴────┴────┴────┴────┴────┴────┴────┘  h
```

To obtain the zigzag coordinate from a 2D grid coordinate, you use the static `JPEG.Table.Quantization.z(k:h:)` function, where `k` is the column index and `h` is the row index.

We can print out the quantum values as a matrix like this:

```swift 
extension String 
{
    static 
    func pad(_ string:String, left count:Int) -> Self 
    {
        .init(repeating: " ", count: count - string.count) + string
    }
}

"""
┌ \(String.init(repeating: " ", count: 4 * 8)) ┐
\((0 ..< 8).map 
{
    (h:Int) in 
    """
    │ \((0 ..< 8).map 
    {
        (k:Int) in 
        String.pad("\(table[z: JPEG.Table.Quantization.z(k: k, h: h)]) ", left: 4)
    }.joined()) │
    """
}.joined(separator: "\n"))
└ \(String.init(repeating: " ", count: 4 * 8)) ┘
"""
```

```
quantization table [0]:
┌                                  ┐
│   4   3   3   4   6  10  13  16  │
│   3   3   4   5   7  15  16  14  │
│   4   3   4   6  10  15  18  15  │
│   4   4   6   8  13  23  21  16  │
│   5   6  10  15  18  28  27  20  │
│   6   9  14  17  21  27  29  24  │
│  13  17  20  23  27  31  31  26  │
│  19  24  25  25  29  26  27  26  │
└                                  ┘
quantization table [1]:
┌                                  ┐
│   4   5   6  12  26  26  26  26  │
│   5   5   7  17  26  26  26  26  │
│   6   7  15  26  26  26  26  26  │
│  12  17  26  26  26  26  26  26  │
│  26  26  26  26  26  26  26  26  │
│  26  26  26  26  26  26  26  26  │
│  26  26  26  26  26  26  26  26  │
│  26  26  26  26  26  26  26  26  │
└                                  ┘
```

We can convert the spectral representation into a planar spatial representation, modeled by the `JPEG.Data.Planar` structure, using the `.idct()` method. This function performs an **inverse frequency transform** (or **i**nverse **d**iscrete **c**osine **t**ransform) on the spectral data.

```swift
let planar:JPEG.Data.Planar<JPEG.Common> = spectral.idct()
```

The size of the planes in a `JPEG.Data.Planar` structure (and a `JPEG.Data.Spectral` structure as well) always corresponds to a whole number of pixel blocks, which may not match the declared size of the image given by the `.size` property. In addition, if the image uses chroma subsampling, the planes will not all be the same size.

Both `JPEG.Data.Spectral` and `JPEG.Data.Planar` structures are `RandomAccessCollection`s of their `Plane` types. The `Plane` types provide 2D index iterators which traverse their index spaces in row-major order.

```swift 
for (p, plane):(Int, JPEG.Data.Planar<JPEG.Common>.Plane) in planar.enumerated()
{
    print("""
    plane \(p) 
    {
        size: (\(plane.size.x), \(plane.size.y))
    }
    """)
    
    let samples:[UInt8] = plane.indices.map 
    {
        (i:(x:Int, y:Int)) in 
        .init(clamping: plane[x: i.x, y: i.y])
    }
}
```

| *Y* component [**1**] |
| --------------------- | 
| 640x432 pixels        |
|<img width=512 src="decode-advanced/karlie-2019.jpg-0.640x432.gray.png"/>|

| *Cb* component [**2**] |
| --------------------- | 
| 320x216 pixels        |
|<img width=256 src="decode-advanced/karlie-2019.jpg-1.320x216.gray.png"/>|

| *Cr* component [**3**] |
| --------------------- | 
| 320x216 pixels        |
|<img width=256 src="decode-advanced/karlie-2019.jpg-2.320x216.gray.png"/>|

The last step is to convert the planar representation into rectangular representation using the `.interleaved(cosite:)` method. **Cositing** refers to the positioning of color samples relative to the pixel grid. If samples are not cosited, then they are **centered**. The default setting is centered, meaning `cosite:` is `false`.

```
        centered                             cosited 
     (cosite: false)                     (cosite: true)
┏━━━━━┱─────┬─────┬─────┐           ┏━━━━━┱─────┬─────┬─────┐
┃  ×  ┃  ×  │  ×  │  ×  │           ┃  ×  ┃  ×  │  ×  │  ×  │
┡━━━━━╃─────┼─────┼─────┤   4:4:4   ┡━━━━━╃─────┼─────┼─────┤
│  ×  │  ×  │  ×  │  ×  │           │  ×  │  ×  │  ×  │  ×  │
└─────┴─────┴─────┴─────┘           └─────┴─────┴─────┴─────┘

┏━━━━━┯━━━━━┱─────┬─────┐           ┏━━━━━┯━━━━━┱─────┬─────┐
┃  ·  ×  ·  ┃  ·  ×  ·  │           ┃  ×  │  ·  ┃  ×  │  ·  │
┡━━━━━┿━━━━━╃─────┼─────┤   4:2:2   ┡━━━━━┿━━━━━╃─────┼─────┤
│  ·  ×  ·  │  ·  ×  ·  │           │  ×  │  ·  │  ×  │  ·  │
└─────┴─────┴─────┴─────┘           └─────┴─────┴─────┴─────┘

┏━━━━━┯━━━━━┱─────┬─────┐           ┏━━━━━┯━━━━━┱─────┬─────┐
┃  ·  │  ·  ┃  ·  │  ·  │           ┃  ×  │  ·  ┃  ×  │  ·  │
┠──── × ────╂──── × ────┤   4:2:0   ┠─────┼─────╂─────┼─────┤
┃  ·  │  ·  ┃  ·  │  ·  │           ┃  ·  │  ·  ┃  ·  │  ·  │
┗━━━━━┷━━━━━┹─────┴─────┘           ┗━━━━━┷━━━━━┹─────┴─────┘

            luminance sample  ·
          chrominance sample  ×
```

In this example, we are using centered sampling to obtain the final pixel array.

```swift 
let rectangular:JPEG.Data.Rectangular<JPEG.Common> = planar.interleaved(cosite: false)
let rgb:[JPEG.RGB] = rectangular.unpack(as: JPEG.RGB.self)
```

<img width=512 src="decode-advanced/karlie-2019.jpg.rgb.png"/>

> decoded jpeg image, saved in png format

---

## advanced encoding  

[`sources`](encode-advanced/)

> ***by the end of this tutorial, you should be able to:***
> * *use custom quantization tables*
> * *use the multi-stage compression api*
> * *use the progressive coding process to encode images*
> * *define valid scan progressions for progressive images*
> * *view generated jpeg declarations and selector assignments*
> * *initialize various data models directly*

In this tutorial, we will use the same multi-stage API we used in the [advanced decoding](#advanced-decoding) tutorial, but in reverse. We will also use the progressive coding process to define a more sophisticated scan progression. As before, we will assume we have an input image, its pixel dimensions, and a file destination available.

```swift 
let rgb:[JPEG.RGB]       = [ ... ] 
let path:String          = "examples/encode-advanced/karlie-cfdas-2011.png.rgb",
    size:(x:Int, y:Int)  = (600, 900)
```

<img width=300 src="encode-advanced/karlie-cfdas-2011.png"/>

> *Karlie Kloss at the 2011 [CFDA Fashion Awards](https://en.wikipedia.org/wiki/Council_of_Fashion_Designers_of_America#CFDA_Fashion_Awards) in New York City*
> 
> *(photo by John “hugo971”)*

To make the code a little more readable, we will give names to the three YCbCr component keys in the `ycc8` format this image is going to use. The `.components` property of the color format returns an array containing the component keys in the format, in canonical order.

```swift 
let format:JPEG.Common              = .ycc8
let Y:JPEG.Component.Key            = format.components[0],
    Cb:JPEG.Component.Key           = format.components[1],
    Cr:JPEG.Component.Key           = format.components[2]
```

Note that if the format case was `y8`, then we would only be able to subscript up to index `0`. There is also no guarantee that `.components[0]` is the same in all cases, though for `y8` and `ycc8`, they are.

We begin to initialize a `JPEG.Layout` structure just as we did in the [basic encoding](#basic-encoding) tutorial, only this time we specify the `progressive(coding:differential:)` coding process. The only supported values for the `coding:` and `differential:` parameters are `huffman` and `false`, respectively, but they are defined because other library APIs can still recognize images using arithmetic (`arithmetic` coding) and hierarchical (differential) modes of operation.

```swift 
let layout:JPEG.Layout<JPEG.Common> = .init(
    format:     format,
    process:    .progressive(coding: .huffman, differential: false), 
    components: 
    [
        Y:  (factor: (2, 1), qi: 0), // 4:2:2 subsampling
        Cb: (factor: (1, 1), qi: 1), 
        Cr: (factor: (1, 1), qi: 1),
    ], 
```

The scan progression rules for progressive JPEGs are different than for sequential (`baseline` or `extended(coding:differential:)`) JPEGs. A sequential scan encodes all bits (0 to infinity) of all coefficients (0 to 63) for each channel, and are always allowed to contain multiple channels. A progressive scan subsets bits in a process called **successive approximation**, and coefficients in a process called **spectral selection**. (In an analogy to signal processing, a coefficient subset is also called a **band**.) Only progressive scans which encode the DC coefficient only (band indices `0 ..< 1`) are allowed to encode multiple channels.

Progressive scans using successive approximation can be either **initial scans** or **refining scans**. An initial scan encodes all the bits from some starting index to infinity. A refining scan encodes a single bit. One valid successive approximation sequence is `(3..., 2 ..< 3, 1 ..< 2, 0 ..< 1)`, which contains one initial scan, and three refining scans. It is possible for there to be no refining scans, in which case, the refining scan will simply encode bits `0...`.

The progressive coding process is not backwards compatible with the sequential processes — progressive images always have to encode AC bands and the DC coefficient in separate scans, so a sequential scan, which contains coefficients 0 through 63, is not a valid progressive scan. It would have to be broken up into a scan encoding coefficient 0, and at least one scan encoding coefficients 1 through 63.

There are several more rules that have to be followed, or else the `JPEG.Layout` initializer will suffer a [precondition failure](https://developer.apple.com/documentation/swift/1539374-preconditionfailure):

* The first scan for a particular component must be an initial DC scan, which can be interleaved with other components.
* Refining DC scans can be interleaved, but not refining AC scans.
* The initial scan encoding the high bits of any coefficient must come before any refining scans encoding bits in that coefficient.
* Refining scans must count downwards toward bit zero in increments of 1.
* No bit of any coefficient can be encoded twice.
* The total sampling volume (product of the sampling factors) of all the components in an interleaved scan cannot be greater than 10. This restriction does not apply to scans encoding a single component.

The following is an example of a valid scan progression, which we will be using in this tutorial:

```swift 
    scans: 
    [
        .progressive((Y,  \.0), (Cb, \.1), (Cr, \.1),  bits: 2...),
        .progressive( Y,         Cb,        Cr      ,  bit:  1   ),
        .progressive( Y,         Cb,        Cr      ,  bit:  0   ),
        
        .progressive((Y,  \.0),        band: 1 ..< 64, bits: 1...), 
        
        .progressive((Cb, \.0),        band: 1 ..<  6, bits: 1...), 
        .progressive((Cr, \.0),        band: 1 ..<  6, bits: 1...), 
        
        .progressive((Cb, \.0),        band: 6 ..< 64, bits: 1...), 
        .progressive((Cr, \.0),        band: 6 ..< 64, bits: 1...), 
        
        .progressive((Y,  \.0),        band: 1 ..< 64, bit:  0   ), 
        .progressive((Cb, \.0),        band: 1 ..< 64, bit:  0   ), 
        .progressive((Cr, \.0),        band: 1 ..< 64, bit:  0   ), 
    ])
```

The library provides four progressive scan header constructors:

1. `.progressive(_:... bits:)`

 Returns an initial DC scan header. The variadic argument takes tuples of component keys and huffman table selectors; components with the same huffman table selector will share the same huffman table.

2. `.progressive(_:... bit:)`

 Returns a refining DC scan header. The variadic argument takes scalar component keys with no huffman table selectors, because refining DC scans do not use entropy coding.

3. `.progressive(_:band:bits:)`

 Returns an initial AC scan header. For flexibility, you can specify the huffman table selector you want the scan in the encoded JPEG file to use, though this will have no discernable effect on image compression.

4. `.progressive(_:band:bit:)`

 Returns a refining AC scan header. The huffman table selector has the same significance that it does in the initial AC scan headers.

All the scan header constructors, including `.sequential(_:... )` return the same type, `JPEG.Header.Scan`, but using a sequential constructor to define a scan for a progressive image will always produce an error.

When you initialize a layout, it will automatically assign quantization tables to table selectors and generate the sequence of JPEG declarations needed to associate the right table resources with the right scans. This can sometimes fail (with a fatal error) if the scan progression you provided requires more tables to be referenced at once than there are selectors for them to be attached to. The lifetime of a table extends from the first scan that contains a component using it, to the last scan containing such a component. (It does not have to be the same component.) 

Just as with the limits on the number of simultaneously referenced huffman tables, the `baseline` coding process allows for up to two simultaneously referenced quantization tables, while all other coding processes allow for up to four. In practice, since each component can only use one quantization table, the total number of quantization tables in a JPEG image can never exceed the number of components in the image, so these limitations are rarely encountered.

We can view the generated declarations and selector assignments with the following code: 

```swift 
for (tables, scans):([JPEG.Table.Quantization.Key], [JPEG.Scan]) in layout.definitions 
{
    print("""
    define quantization tables: 
    [
        \(tables.map(String.init(describing:)).joined(separator: "\n    "))
    ]
    """)
    print("""
    scans: \(scans.count) scans 
    """)
}

for (c, (component, qi)):(Int, (component:JPEG.Component, qi:JPEG.Table.Quantization.Key)) in layout.planes.enumerated() 
{
    print("""
    plane \(c)
    {
        sampling factor         : (\(component.factor.x), \(component.factor.y))
        quantization table      : \(qi)
        quantization selector   : \\.\(String.init(selector: component.selector))
    }
    """)
}
```

```
define quantization tables: 
[
    [0]
    [1]
]
scans: 11 scans 
plane 0
{
    sampling factor         : (2, 1)
    quantization table      : [0]
    quantization selector   : \.0
}
plane 1
{
    sampling factor         : (1, 1)
    quantization table      : [1]
    quantization selector   : \.1
}
plane 2
{
    sampling factor         : (1, 1)
    quantization table      : [1]
    quantization selector   : \.1
}
```

Here we can see that the library has decided to define both quantization tables up front, with no need for additional declarations later on. Unsurprisingly, table **0** has been assigned to selector `\.0` and table **1** to selector `\.1`.

In the last encoding tutorial, we inserted a meaningless JFIF metadata segment into the encoded file; this time we will skip that and instead insert a JPEG comment segment.

```swift 
let comment:[UInt8] = .init("the way u say ‘important’ is important".utf8)
let rectangular:JPEG.Data.Rectangular<JPEG.Common> = 
    .pack(size: size, layout: layout, metadata: [.comment(data: comment)], pixels: rgb)
```

Here, we have stored a string encoded as [UTF-8](https://en.wikipedia.org/wiki/UTF-8) data into the comment body. The text encoding is irrelevant to JPEG, but many metadata viewers will display JPEG comments as UTF-8 text, so this is how we will store it.

When we created the rectangular data structure, we used the `.pack(size:layout:metadata:pixels:)` constructor, but we could also have used the regular `.init(size:layout:metadata:values:)` initializer, which takes a `[UInt16]` array of (row-major) interleaved color samples. This initializer assumes you already have the image data stored in the right order and format, so it’s a somewhat lower-level API.

The next step is to convert the rectangular data into planar data. The method which returns the planar representation is the `.decomposed()` method.

```swift 
let planar:JPEG.Data.Planar<JPEG.Common> = rectangular.decomposed()
```

If the image layout uses subsampling, this method will downsample the image data with a basic box filter for the appropriate image planes. There is no concept of cositing or centering when downsampling, so this method takes no arguments. The box filter the library applies is a pretty bad low-pass filter, so it may be beneficial for you to implement your own subsampling filter and construct the planar data structure “manually” if you are trying to squeeze some extra quality into a subsampled JPEG. The `.init(size:layout:metadata:initializingWith:)` initializer can be used for this. It has the following signature:

```swift 
init(size:(x:Int, y:Int), 
    layout:JPEG.Layout<Format>, 
    metadata:[JPEG.Metadata], 
    initializingWith initializer:
    (Int, (x:Int, y:Int), (x:Int, y:Int), UnsafeMutableBufferPointer<UInt16>) throws -> ())
```

The first closure argument is the component index (also the plane index), the second closure argument is the dimensions of the plane in 8x8 unit blocks, the third closure argument is the sampling factor of the plane, and the last closure argument is the uninitialized (row-major) plane buffer. It stores 64*XY* elements, where (*X*,&nbsp;*Y*) are the dimensions of the plane in unit blocks.

The `JPEG.Data.Planar` type also has a plain `.init(size:layout:metadata:)` initializer with no data argument which initializes all planes to a neutral color. You can read and modify sample values through the 2D subscript `[x:y:]` available on the plane type. 

To convert the planar data to spectral representation, we have to do a **forward frequency transform** (or **f**orward **d**iscrete **c**osine **t**ransform) using the `.fdct(quanta:)` method. It is at this point where you have to provide the actual quantum values for each quantization table used in the image. In the [basic encoding](#basic-encoding) tutorial, we used the parameterized quality API to generate quantum values for us, but you can also specify the quanta yourself. Usually, it’s a good idea to pick smaller values for the earlier coefficients, and larger values for the later coefficients.

```swift 
let spectral:JPEG.Data.Spectral<JPEG.Common> = planar.fdct(quanta:     
    [
        0: [1, 2, 2, 3, 3, 3] + .init(repeating:  4, count: 58),
        1: [1, 2, 2, 5, 5, 5] + .init(repeating: 30, count: 58),
    ])
```

Finally, we can use the file system-aware compression API to encode the image and write it to disk.

```swift 
guard let _:Void = try spectral.compress(path: "\(path).jpg")
else 
{
    fatalError("failed to open file '\(path).jpg'")
}
```

<img width=300 src="/home/klossy/dev/jpeg/examples/encode-advanced/karlie-cfdas-2011.png.rgb.jpg"/>

> Output JPEG, 189.8 KB. (Original RGB data was 1.6 MB, PNG image was 805.7 KB.)
