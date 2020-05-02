# Swift *JPEG*

Swift *JPEG* is a cross-platform pure Swift framework which provides a full-featured JPEG encoding and decoding API. The core framework has no external dependencies, including *Foundation*, and should compile and provide consistent behavior on *all* Swift platforms. The framework supports additional features, such as file system support, on Linux and MacOS. Swift *JPEG* is available under the [GPL3 open source license](https://choosealicense.com/licenses/gpl-3.0/).

## i. project motivation

> **Summary:** Unlike *UIImage*, Swift *JPEG* is cross-platform and open-source. It provides a rich, idiomatic set of APIs for the Swift language, beyond what wrappers around C frameworks such as *libjpeg* can emulate, and unlike *libjpeg*, guarantees safe and consistent behavior across different platforms and hardware. As a standalone SPM package, it is also significantly easier to install and use in a Swift project.

### i.i. problem

Today, almost all Swift users rely on two popular system frameworks for encoding and decoding the JPEG file format. The first of these system frameworks is *UIKit*, which is available on Apple platforms and includes a multi-format image codec, [*UIImage*](https://developer.apple.com/documentation/uikit/uiimage). However, this codec is proprietary and unavailable on Linux platforms, making tools and applications that depend on *UIImage* non-portable.

The second popular system framework is the C library [*libjpeg*](http://ijg.org/) which comes pre-installed with most Linux distributions. The *libjpeg* codec, which has existed since [1991](https://en.wikipedia.org/wiki/Libjpeg), has the advantage of having a large user base, and unlike *UIImage*, is free and open source software. 

The *libjpeg* codec however, has a number of drawbacks which make it unsuitable for use in Swift projects. Despite Swift’s excellent C-interop, installing and importing *libjpeg* into Swift projects can be challenging for all but advanced Swift users. 

Owing to vast differences in programming paradigms and preferred design patterns between C and Swift, APIs designed for (and constrained by) the C language can also be extremely awkward, and needlessly verbose when called from Swift code. Swift wrappers around C APIs can mitigate some of these issues, but must still incur necessary overhead to bridge the gap between a framework designed for a language without dynamic arrays, automatic reference counting, or the concept of memory state, and a calling language which relies on modern data structures and guarantees for safe and efficient operation.

The *libjpeg* codec specifically also suffers from serious technical flaws which preclude its safe inclusion in Swift projects. Error handling in *libjpeg* relies heavily on the `setjmp` family of POSIX functions, which are [unsafe](https://forums.swift.org/t/on-the-road-to-swift-6/32862/149) to use in Swift (and many [other languages](https://internals.rust-lang.org/t/support-c-apis-designed-for-safe-unwinding/7212) as well). The output from *libjpeg* can also vary across different hardware due to differences in platform rounding and SIMD architecture. 

### i.ii. proposed solution

A major, and in our opinion, beneficial, trend in modern language design, has been to distribute language compilers with package managers that can pull code from the internet to be compiled locally by a developer’s compiler (or interpeter) toolchain. The most famous examples might be Node and Python’s `pip` tool. In Swift, the equivalent is the [Swift Package Manager](https://swift.org/package-manager/) (SPM). While the Swift Package Manager is capable of linking to system C libraries, this process is generally not automated and entails some complexity on the part of users. A native-Swift framework, on the other hand, can be automatically downloaded, versioned, installed, and imported by the package manager, greatly streamlining its use. 

This, and the previously discussed issues with existing system frameworks, motivates the creation of a pure Swift implementation of JPEG. A pure Swift JPEG library can vend a natural, idiomatic API. By default, pure Swift code compiles on *all* Swift platforms, and the lack of undefined/implementation-defined behavior in the language ensures consistent behavior across those platforms. First-class language support for concepts such as SIMD also make native-Swift codecs considerably more portable than their C counterparts, which are often compiled as a patchwork of macro-defined cores and extensions. 


### i.iii. prior art

Currently, no production-ready JPEG codec exists for the Swift language today. 

Many language communities have “experimental” implementations of JPEG and other image formats. Most experimental implementations begin as personal projects, and many are non-compliant, or even not fully functional. However, they sometimes mature into formidable local competitors to *libjpeg* and other system libraries. Experimental JPEG implementations rarely meet the threshold to qualify as a usable framework, but the few that do serve as a proof-of-concept for the idea of commodotizing image processing into something that can be handled by a native-language package, as opposed to relying on system dependencies. While this can imply additional code-size costs, the portability and usability gains inherent in “demoting” a system dependency into a regular package are significant. 

Language communities with strong “hacker” traditions, such as the Rust community, often sport [advanced native codec libraries](https://docs.rs/jpeg-decoder/0.1.16/jpeg_decoder/) in their package indices. In the Swift world, however, we could only locate a [single](https://github.com/sergeysmagleev/JPEGEncoder), unfinished Github project which implements JPEG in native Swift, by Github user [`sergeysmagleev`](https://github.com/sergeysmagleev).

Why does Swift have such poor support for JPEG (and other image formats) compared to languages such as Rust which has a comparatively tiny user base? There are in fact, no technical limitations — performance or otherwise — inherent to the Swift language that would preclude a native Swift implementation of JPEG, or make such an implementation inferior to existing C implementations. The only real constraint is the fact that all open source code (in fact, all code) has to be authored by someone, and in the FOSS ecosystem especially, the limiting factor in producing new libraries and frameworks has been the availability and willingness of someone “up to the task” to write that code.

Without funding, interest and technical difficulty are the main determinants of whether a library will arise in a particular language community. This is true for any language community, including the Swift community. For example, because game development is a popular developer hobby, many algorithms and toolkits relevant to the field have been implemented natively in most languages. 

In the field of image codecs, this has meant that “easier” formats such as GIF and, to a much lesser extent, PNG, often have high quality native-language implementations, while more technically challenging formats such as JPEG often remain unsupported. However, we forsee that as libraries and frameworks become increasingly decoupled from operating systems, the monopoly of `libjpeg` and proprietary system frameworks will too be broken, in favor of portable, native implementations. As such, developing such a resource contributes to the [language community-level goal](https://forums.swift.org/t/on-the-road-to-swift-6/32862) of expanding the Swift library ecosystem.

## ii. project goals

> **Summary:** Swift *JPEG* supports all three popular JPEG coding processes (baseline, extended, and progressive), and comes with built-in support for the JFIF/EXIF subset of the JPEG standard. The framework supports decompressing images to RGB and YCbCr targets. Lower-level APIs allow users to perform lossless operations on the frequency-domain representation of an image, transcode images between different coding processes, edit header fields and tables, and insert or strip metadata. The framework also provides the flexibility for users to extend the JPEG standard to support custom color formats and additional coding processes.

### ii.i. the jpeg standard

JPEG images as commonly encountered today are actually governed by three overlapping (and slightly contradictory) standards. The most important is the **ISO/IEC 10918-1** standard (also called the **ITU T.81** standard), which this document will refer to simply as the *JPEG standard*.

The JPEG standard is color format agnostic, meaning it supports any combination of user-defined color components (YCbCr, RGB, RGBA, and anything else). The standard defines no fewer than thirteen different *coding processes*, which are essentially distinct image formats grouped under the umbrella of “JPEG formats”. Coding processes can be classified by their *entropy coding*:

```swift
enum Coding 
{
    case huffman 
    case arithmetic 
}
```

Coding processes can also either be *hierarchical* or *non-hierarchical*. A summary of JPEG coding processes is given below:

|     | process type    | entropy coding | hierarchical |
| --- | --------------- | -------------- | ------------ |
|  1. | **baseline**    | **huffman**    | **false**    |
|  2. | **extended**    | **huffman**    | **false**    |
|  3. |   extended      |   arithmetic   |   false      |
|  4. |   extended      |   huffman      |   true       |
|  5. |   extended      |   arithmetic   |   true       |
|  6. | **progressive** | **huffman**    | **false**    |
|  7. |   progressive   |   arithmetic   |   false      |
|  8. |   progressive   |   huffman      |   true       |
|  9. |   progressive   |   arithmetic   |   true       |
| 10. |   lossless      |   huffman      |   false      |
| 11. |   lossless      |   arithmetic   |   false      |
| 12. |   lossless      |   huffman      |   true       |
| 13. |   lossless      |   arithmetic   |   true       |

> *Note: processes this project supports are **bolded***.

Among these formats, only the baseline huffman non-hierarchical process is commonly used today, though the progressive huffman non-hierarchical process is sometimes also seen. This is in large part due to the other two technical standards relevant to the JPEG format, discussed shortly.

Until very recently, the arithmetic entropy coding method was patented, which resulted in its exclusion from software implementations of the standard. The lossless and hierarchical processes are seldom-used today, and are considered out of scope for this project. However, the extended (huffman, non-hierarchical) process is a relatively straightforward derivation from the baseline process, and sees some usage in applications such as medical imaging, so this project supports this process in addition to processes 1 and 6.

The framework is designed to still parse and recognize the unsupported coding processes, even if it is unable to encode or decode them. As such, it supports, for example, editing and resaving metadata for all conforming JPEG files regardless of the coding process used. In theory, users can use the lexing and parsing components of the framework to implement codec extensions implementing the unsupported processes. 

### ii.ii. color formats

A *color format* for a JPEG image is a set of *component identifiers* and a defined meaning for each of those components. A component identifier is an integer from 1 to 255, denoted [*c<sub>i</sub>*] in this document, and the identifiers need not be contiguous or in increasing order (or any order at all). An example of a (non-standard) color format for RGBA might be:

```
{
    [5]: red, 
    [6]: green, 
    [8]: blue, 
    [1]: alpha
}
```

JPEG color formats are defined by the two other standards besides the ISO 10918-1, which we will refer to as the JFIF/EXIF standards. The JFIF/EXIF standards are subsets of the JPEG standard which define common color format meanings for JPEG images on the web (primarily JFIF) and from digital cameras (primarily EXIF). They “strongly recommend” use of the baseline coding process only, though they are compatible with the other coding processes as well. The JFIF and EXIF standards are mutually incompatible due to differences in file structure, but most codecs tolerate both.

Both the JFIF and EXIF standards use the [YCbCr color model](https://en.wikipedia.org/wiki/YCbCr). The JFIF standard allows both full YCbCr triplets, and a Y-only grayscale form. The EXIF standard only allows YCbCr triplets. Both standards share the same identifier–channel mapping, and in addition, the JFIF YCbCr format is compatible with the Y format.

```
{
    [1]: Y  (luminance), 
    [2]: Cb (blueness), 
    [3]: Cr (redness)
}
```

The framework includes built-in support for the JFIF/EXIF color formats, which we will refer to as the *common format*. However it also provides support through Swift generics for custom user-defined color formats, which may be useful for certain applications.

### ii.iii. color targets 

*Color targets* are related to but distinct from color formats. A color format specifies how colors are represented and stored within a JPEG image, while a color target specifies how those colors are presented to users. This framework includes built-in support for both YCbCr and [RGB](https://en.wikipedia.org/wiki/RGB_color_model) as color targets. The conversion formula from JPEG-native YCbCr colors to RGB is defined by the JFIF/EXIF standards, and given (in matrix form) below:

```
┌   ┐   ┌                             ┐   ┌          ┐
│ R │   │ 1.00000   0.00000   1.40200 │   │ Y        │
│ G │ = │ 1.00000  -0.34414  -0.71414 │ x │ Cb - 128 │
│ B │   │ 1.00000   1.77200   0.00000 │   │ Cr - 128 │
└   ┘   └                             ┘   └          ┘
```

The inverse formula is given below:
```
┌          ┐   ┌                           ┐   ┌   ┐
│ Y        │   │  0.2990   0.5870   0.1140 │   │ R │
│ Cb - 128 │ = │ -0.1687  -0.3313   0.5000 │ x │ G │
│ Cr - 128 │   │  0.5000  -0.4187  -0.0813 │   │ B │
└          ┘   └                           ┘   └   ┘
```

The framework supports rendering to multiple color targets from the same decoded image, without having to redecode the image for each target. As with custom color formats, the framework also supports user-defined color targets, which much also define an associated color format type since the JFIF/EXIF conversion formulas assume a specific YCbCr input format.

### ii.iv. levels of abstraction

Rendering to (or saving from) an RGB/YCbCr pixel array is the most common JPEG codec use-case, but it is not the only one. As is well-known, the full JPEG encoding–decoding pipeline is lossy, which results in both image degradation and increased file size each time a JPEG is reencoded. However, most of the steps in that pipeline are actually reversible, which means many common image operations (ranging from editing metadata to performing crops and rotations, and even color grading) can be done losslessly. Doing so requires a codec which exposes each abstracted stage of the coding pipeline in its API:

1. structural representation 
2. spectral representation 
3. dequantized representation 
4. spatial representation 
5. color representation

For example, metadata editing is best performed on the structural representation, while lossless crops, reflections, and rotations can only be performed on the spectral representation. Changing the compression level is performed on the dequantized representation, while changing the subsampling level is best performed on the spatial representation. As such, the framework allows users to interact with JPEG images at all five major levels of abstraction.

## iii. concepts 

> **Summary:** JPEG is a frequency transform-based compressed image format. Decompressing the file format can be roughly divided into lexing, parsing, and decoding stages. Decoding involves assembling multiple image *scans* into a single image *frame*. A scan may contain one or more color *components* (channels). In a progressive JPEG, a single scan may contain only a specific range of bits for a specific frequency band. JPEG images also use *huffman* and *quantization* tables. Huffman tables are associated with image components at the scan level. Quantization tables are associated with image components at the frame level. Multiple components can reference the same huffman or quantization table. The “compression level” of a JPEG image is almost fully determined by the quantization tables used by the image.

This section is meant to give a concise overview of the JPEG format itself. For the actual format details, consult the [ISO 10918-1 standard](https://www.w3.org/Graphics/JPEG/itu-t81.pdf).

### iii.i. jpeg segmented structure

Structurally, JPEG files are sequences of *marker segments* and *entropy-coded segments*. It is possible to segment JPEG files without having to parse the body of each segment. Marker segments have headers, while entropy-coded segments are “naked” byte sequences. Because entropy-coded segments can have zero length, a JPEG file can be conceptualized as a sequence of alternating marker and entropy-coded segments. The terminator for an entropy-coded segment is one or more `0xFF` bytes; an entropy-coded segment together with its terminator is a *prefix*.

```
JPEG                  ::= <Marker Segment> (<Prefix> <Marker Segment>) *
Prefix                ::= <Entropy-Coded Segment> (0xFF)+
```

Because the delimiter for an entropy-coded segment is an `0xFF` byte, this means that any `0xFF` bytes in its payload data must be escaped with the escape sequence `0xFF 0x00`.

```
Entropy-Coded Segment ::= <Escape> *
Escape                ::= [0x00-0xFE]
                        |  0xFF 0x00
```

Marker segments consist of a *type*, *length field*, and a *segment body*, in that order. The type is always one byte; the JPEG standard defines which values of this byte correspond to which marker segment types. The length field is a big-endian 16-bit integer. The length includes the length field itself, so the length of the segment body is always two less than the value of the length field. (Because the length of a marker segment is always known, no escaping takes place.)

```
Marker Segment        ::= <Type> <Length> <Body>
Type                  ::= [0x01-0xFE]
Length                ::= [0x00-0xFF] [0x00-0xFF]
Body                  ::= [0x00-0xFF]{ (Length[0] << 8 | Length[1]) - 2 }
```

There are many different types of marker segments, but the most important are *header segments* and *table segments*.

### iii.ii. header segments 

There are two types of JPEG header segments: *frame headers* and *scan headers*. 

#### iii.ii.i. frame headers

A frame header is a header segment which describes a rectangular image as a whole. Except when the JPEG file uses a hierarchical coding process, there is only one frame, and therefore, one frame header per image. A frame header contains the following fields:

* Bit depth (integer, usually 8 or 12)
* Image width (integer, greater than zero)
* Image height (integer)
* Resident components (array)

Note that, as a technical detail, the height can be initialized to 0 by the frame header segment, and set later by a separate segment called a *height redefinition segment*.

The resident components array defines the color components in the image, and includes image-global parameters for each component. A resident component definition contains the following fields:

* Component identifier (*c<sub>i</sub>*)
* Quantization table reference (*q<sub>i</sub>*)
* Horizontal sampling factor (integer, between 1 and 4)
* Vertical sampling factor (integer, between 1 and 4)

The sampling factors determine the chroma subsampling level of the image. All components having a sampling factor of (1,&nbsp;1) corresponds to a 4:4:4 subsampling scheme. A sampling factor of (2,&nbsp;2) for the Y channel, and (1,&nbsp;1) for the Cb and Cr channels corresponds to a 4:2:0 subsampling scheme.

#### iii.ii.ii. scan headers

A scan header is a header segment which describes data, a *scan*, which makes up a portion of a complete image. There can be one or more scans, and therefore, scan headers, for a single frame. The decomposition of image data into multiple scans is always done spectrally, by bit-index, and by component, never spatially, so each scan contains data for the entire spatial extent of the image. A scan header is always immediately followed by an entropy-coded segment containing the scan data the header describes.

A scan header contains the following fields:

* Band range (integer range, between 0 and 63)
* Bit range (integer range)
* Component reference array

The *band range* is given in terms of discrete frequencies. The lowest frequency, 0, is the DC frequency, all other frequencies, up to a maximum of 63, are AC frequencies. 

The *bit range* is given in terms of bit indices. The bit range refers to bits in the frequency-domain representation of the image, not its spatial-domain representation, so the bit range is not limited to the bit depth given in the frame header.

For non-progressive coding processes, the band range is always set to [0,&nbsp;64). Likewise, the bit range is always set to [0,&nbsp;∞).

For progressive coding processes, the band range can be anything within the interval [0,&nbsp;64), as long as the range doesn’t mix DC and AC frequencies. This means that [0,&nbsp;1) and [1,&nbsp;6) are both valid band ranges, but [0,&nbsp;6) is not. Furthermore, when there are multiple scans for each component, the [0,&nbsp;1) scan must come first. This decomposition is called *spectral selection*.

Progressively-coded images can also optionally use a decomposition called *successive approximation*, in which the first scan for each component (called an *initial scan*) has a bit range with an upper limit of infinity, and later scans (called *refining scans*) step down one bit at a time to zero. An example of a valid successive approximation sequence is {&nbsp;[3,&nbsp;∞),&nbsp;[2,&nbsp;3),&nbsp;[1,&nbsp;2),&nbsp;[0,&nbsp;1)&nbsp;}. The sequence {&nbsp;[3,&nbsp;∞),&nbsp;[1,&nbsp;3),&nbsp;[0,&nbsp;1)&nbsp;} is invalid because the second scan contains a bit range with two bits, while the sequence {&nbsp;[3,&nbsp;∞),&nbsp;[1,&nbsp;2),&nbsp;[2,&nbsp;3),&nbsp;[0,&nbsp;1)&nbsp;} is invalid because bit&nbsp;1 is refined before bit&nbsp;2.

The sequence of scan-specified band ranges and bit ranges for a particular component is called a *scan progression*. The following is a visual example of a possible scan progression for one component of a progressively-coded image:

```
    a   Scan 0 (band: 0 ..< 1, bits: 1 ...)
z       0  1  2  3  4  5  6  7  8 ··· 61 62 63
  
    ∞   X 
    ·   X
    ·   X
    ·   X
    2   X
    1   X
    0
                      +
                    
        Scan 1 (band: 6 ..< 64, bits: 1 ...)
        0  1  2  3  4  5  6  7  8 ··· 61 62 63
  
    ∞                     X  X  X ··· X  X  X
    ·                     X  X  X ··· X  X  X
    ·                     X  X  X ··· X  X  X
    ·                     X  X  X ··· X  X  X
    2                     X  X  X ··· X  X  X
    1                     X  X  X ··· X  X  X
    0
                      +
                    
        Scan 2 (band: 1 ..< 6, bits: 2 ...)
        0  1  2  3  4  5  6  7  8 ··· 61 62 63
  
    ∞      X  X  X  X  X
    ·      X  X  X  X  X
    ·      X  X  X  X  X
    ·      X  X  X  X  X
    2      X  X  X  X  X
    1      
    0
                      +
                    
        Scan 3 (band: 1 ..< 6, bits: 1 ..< 2)
        0  1  2  3  4  5  6  7  8 ··· 61 62 63
  
    ∞ 
    · 
    · 
    · 
    2 
    1      X  X  X  X  X
    0                     
                      +
                      
        Scan 4 (band: 1 ..< 64, bits: 0 ..< 1)
        0  1  2  3  4  5  6  7  8 ··· 61 62 63

    ∞ 
    · 
    · 
    · 
    2 
    1      
    0      X  X  X  X  X  X  X  X ··· X  X  X
                      +
                      
        Scan 5 (band: 0 ..< 1, bits: 0 ..< 1)
        0  1  2  3  4  5  6  7  8 ··· 61 62 63

    ∞ 
    · 
    · 
    · 
    2 
    1      
    0   X
                      =
                      
        Completed Frame 
        0  1  2  3  4  5  6  7  8 ··· 61 62 63

    ∞   X  X  X  X  X  X  X  X  X ··· X  X  X
    ·   X  X  X  X  X  X  X  X  X ··· X  X  X
    ·   X  X  X  X  X  X  X  X  X ··· X  X  X
    ·   X  X  X  X  X  X  X  X  X ··· X  X  X
    2   X  X  X  X  X  X  X  X  X ··· X  X  X
    1   X  X  X  X  X  X  X  X  X ··· X  X  X     
    0   X  X  X  X  X  X  X  X  X ··· X  X  X
```

The component reference array specifies which of the components defined in the frame header is present within the scan. If there is more than one component in a scan, then the scan is *interleaved*, otherwise it is *non-interleaved*. Interleaving is not allowed for progressive scans which define AC coefficients only, though it is allowed for non-progressive scans which define all 64 frequencies, including the AC frequencies.

The ordering of component references within the array (if there are more than one) is meaningful, both because it must follow the ordering of component definitions in the frame header, and also because the ordering specifies the ordering of the interleaved data units in the entropy-coded segment following the scan header. A component reference contains the following fields:

* Component reference (*c<sub>i</sub>*, matching one of the components in the frame header)
* DC huffman table reference 
* AC huffman table reference 

Note that quantization tables (described in the next section) are associated with components at the frame level, while huffman tables (also described in the next section) are associated with components at the scan level. It is allowed (and standard practice) for the same component to use a different huffman table in each scan.

### iii.iii. table segments 

Table segments define resources which are referenced by the header segments. There are two types of table segments — *quantization table definitions*, and *huffman table definitions* — which define three types of resources.

#### iii.iii.i. quantization tables 

A quantization table definition consists of 64 multiplier values, which correspond to the 64 discrete frequencies, and some basic information about the table:

* Quantization table identifier (*q<sub>i</sub>*)
* Table precision (8- or 16-bit)

The table precision is not necessarily the same as the image bit depth (though it is subject to some constraints based on the image bit depth). This field is solely used to specify the (big-endian) integer type the table values are stored as. 

Note that, as a technical detail, quantization tables do not actually identify themselves with a *q<sub>i</sub>* identifier, nor do component definitions in a frame header use those identifiers to reference them. However, table identifiers are a useful conceptual model for understanding resource relationships within a JPEG file. This issue will be discussed further in the [contextual state](#iii-v-contextual-state) section.

#### iii.iii.ii. huffman tables 

Huffman table definitions are somewhat more sophisticated than quantization tables. There are two types of huffman tables — AC and DC — but they are defined by the same type of marker segment, and share the same field format.

Like a quantization table definition, a huffman table definition includes some basic information about the table:

* Huffman table identifier 
* Resource type (DC table or AC table)

A huffman table definition does not contain the table values verbatim. (That would be far too space-inefficient.) Rather, it specifies the shape of huffman *tree* used to generate the table, and the symbol values of the (up to 256) leaves in the tree. The algorithm for generating the huffman table from the huffman tree is discussed in more detail in the [library architecture](#v-library-architecture) section.

Unlike quantization tables, huffman tables have no direct relation to frequency coefficient values themselves. They are only used to decompress entropy-coded data within a single entropy-coded segment. (It is allowed, but uncommon, for multiple entropy-coded segments to use the same huffman table.) It is for this reason that huffman tables are “locally” associated with scans while quantization tables are “globally” associated with components at the frame level.

### iii.iv. blocks, planes, and MCUs

JPEG is a *planar format*, meaning each color channel is represented independently as a monochromatic sub-image. However, *interleaving* is still possible down to the granularity determined by the *minimum-coded unit* (MCU) of the image. (Within a single minimum-coded unit, the format is fully planar.) Minimum-coded units in turn are composed of constant-size *blocks*, sometimes called *data units*, which are the smallest spatial unit of a JPEG.

#### iii.iv.i. blocks 

Each JPEG block contains 64 frequency coefficients which correspond to a block of pixels in the visual image. It is often stated that these are 8x8 pixel blocks, but the size actually depends on the component sampling factor. (Subsampled blocks are linearly interpolated to fill in intermediate pixels; the frequency transform is not evaluated per-pixel.)

All blocks for a particular component are the same size, even if the image pixel width and height would indicate fractional blocks along the right and bottom edges of the image. In these cases, the image data is padded (when encoding) to fill an integer number of blocks, and this padding is discarded when decoding. If different components use different sampling factors, the block grid for one component may cover areas that the block grid for another component does not. 

The following diagram shows the block decomposition of a 35x28 pixel image using sampling factors (2,&nbsp;2), (2,&nbsp;1), and (1,&nbsp;1). Note that all three block grids cover pixels that are outside the 35x28 pixel bounds (bolded rectangle), and furthermore, the last block grid covers pixels that the other two grids do not:

```
Image (3 components, 35x28 pixels)
╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌

    Component Y  (20 blocks)
    sampling factor: (2, 2)

   0    8    16   24   32   40   48
 0 ┏━━━━┯━━━━┯━━━━┯━━━━┯━┱──┐
   ┃    │    │    │    │ ┃  │
 8 ┠────┼────┼────┼────┼─╂──┤
   ┃    │    │    │    │ ┃  │
16 ┠────┼────┼────┼────┼─╂──┤
   ┃    │    │    │    │ ┃  │
24 ┠────┼────┼────┼────┼─╂──┤
   ┡━━━━┿━━━━┿━━━━┿━━━━┿━┛  │
32 └────┴────┴────┴────┴────┘

    Component Cb (10 blocks)
    sampling factor: (2, 1)

   0    8    16   24   32   40   48
 0 ┏━━━━┯━━━━┯━━━━┯━━━━┯━┱──┐
   ┃    │    │    │    │ ┃  │
 8 ┃    │    │    │    │ ┃  │
   ┃    │    │    │    │ ┃  │
16 ┠────┼────┼────┼────┼─╂──┤
   ┃    │    │    │    │ ┃  │
24 ┃    │    │    │    │ ┃  │
   ┡━━━━┿━━━━┿━━━━┿━━━━┿━┛  │
32 └────┴────┴────┴────┴────┘

    Component Cr (6 blocks)
    sampling factor: (1, 1)

   0    8    16   24   32   40   48
 0 ┏━━━━━━━━━┯━━━━━━━━━┯━┱───────┐
   ┃         │         │ ┃       │
 8 ┃         │         │ ┃       │
   ┃         │         │ ┃       │
16 ┠─────────┼─────────┼─╂───────┤
   ┃         │         │ ┃       │
24 ┃         │         │ ┃       │
   ┡━━━━━━━━━┿━━━━━━━━━┿━┛       │
32 └─────────┴─────────┴─────────┘
```

It is important to remember that, even though less densely-sampled blocks are spatially bigger, all blocks contain the same amount of information.

#### iii.iv.ii. minimum-coded units

If (and only if) a JPEG scan encodes more than one component, then the blocks are organized into minimum-coded units. (Single-component scans do not use the concept of a minimum-coded unit, and simply store their blocks as a row-major rectangular array.) 

The spatial size of the minimum coded unit is the size of a block with a component sampling factor of (1, 1), even if the scan contains no such component. The blocks are stored within the minimum-coded unit in the same order they were declared in the scan header. For example, the minimum-coded units from a scan containing the Y and Cb components from the previous example would look like this:

```
   Component Y        Component Cb
   (4 blocks)         (2 blocks)

   0    8    16       0    8    16  
 0 ┏━━━━┯━━━━┑      0 ┏━━━━┯━━━━┑   
   ┃ A0 │ B0 │        ┃    │    │   
 8 ┠────┼────┤  +   8 ┃ E0 │ F0 │  +
   ┃ C0 │ D0 │        ┃    │    │   
16 ┖────┴────┘     16 ┖────┴────┘   

   16   24   32       16   24   32  
 0 ┍━━━━┯━━━━┑      0 ┍━━━━┯━━━━┑   
   │ A1 │ B1 │        │    │    │   
 8 ├────┼────┤  +   8 │ E1 │ F1 │  +
   │ C1 │ D1 │        │    │    │   
16 └────┴────┘     16 └────┴────┘   

   32   40   48       32   40   48 
 0 ┍━┱──┬────┐      0 ┍━┱──┬────┐   
   │ A2 │ B2 │        │ ┃  │    │   
 8 ├─╂──┼────┤  +   8 │ E2 │ F2 │  +
   │ C2 │ D2 │        │ ┃  │    │   
16 └─┸──┴────┘     16 └─┸──┴────┘   

   0    8    16       0    8    16
16 ┎────┬────┐     16 ┎────┬────┐
   ┃ A3 │ B3 │        ┃    │    │
24 ┠────┼────┤  +  24 ┃ E3 │ F3 │  +
   ┡ C3 ┿ D3 ┥        ┡━━━━┿━━━━┥
32 └────┴────┘     32 └────┴────┘

   16   24   32       16   24   32
16 ┌────┬────┐     16 ┌────┬────┐
   │ A4 │ B4 │        │    │    │
24 ├────┼────┤  +  24 │ E4 │ F4 │  +
   ┝ C4 ┿ D4 ┥        ┝━━━━┿━━━━┥
32 └────┴────┘     32 └────┴────┘

   32   40   48       32   40   48
16 ┌─┰──┬────┐     16 ┌─┰──┬────┐
   │ A5 │ B5 │        │ ┃  │    │
24 ├─╂──┼────┤  +  24 │ E5 │ F5 │
   ┝ C5 │ D5 │        ┝━┛  │    │
32 └────┴────┘     32 └────┴────┘

   Sequential order:
[
    A0, B0, C0, D0,     E0, F0, 
    A1, B1, C1, D1,     E1, F1, 
    A2, B2, C2, D2,     E2, F2, 
    A3, B3, C3, D3,     E3, F3, 
    A4, B4, C4, D4,     E4, F4, 
    A5, B5, C5, D5,     E5, F5
]
```

Note that blocks B2, D2, F2, B5, D5, and F5 have been added to complete the minimum-coded units they appear in. They would not appear in a non-interleaved scan.

#### iii.iv.iii. planes 

Planes are a very simple concept — they are simply the collection of all the blocks for a particular component. Even though blocks may be stored in an interleaved arrangement, planes are conceptually independent. Even when interleaved, each plane uses its own huffman and quantization tables, which means that a single entropy-coded segment can actually contain codewords from multiple huffman coding schemes.

Converting planes into a rectangular array of color pixels entails expanding subsampled planes, and then clipping them to the pixel dimensions of the image so that each plane has the same spatial width and height. The planes are then pixel-wise interleaved to form color tuples.

### iii.v. contextual state 

All of the aforementioned concepts are related by the *contextual state* of a JPEG file. The state is determined by the ordering of marker and entropy-coded segments in the file.

#### iii.v.i. sections

All JPEG files must start with a *preamble section*, which begins with an *start-of-image* marker segment, followed by JFIF/EXIF metadata segments, and then any number of table segments. While huffman table definitions can live in the preamble, usually it is only quantization table definitions that appear here, since quantization tables are the only JPEG resources that have a whole-frame scope.

In a non-hierarchical JPEG file, the *body section* comes after the preamble. The body starts with a frame header segment, and then contains any number of scan header&nbsp;+&nbsp;entropy-coded segment pairs and table definitions. It is rare for quantization table definitions to appear in the middle of this section, so most of these table definitions are huffman table definitions. The body section, and the JPEG file as a whole, concludes with an *end-of-image* marker.

#### iii.v.ii. table slots 

The JPEG format establishes relationships between table resources and reference holders using the concept of *table slots*. Each type of table (there are three: quantization, DC huffman, and AC huffman) has a fixed number of binding points: 2 for the baseline coding process, and 4 for all other processes. In this document, we use the Swift keypath syntax `\.i` to denote a binding point *i*. 

Whenever a table definition appears, it specifies a *table destination*, which is the binding point to which the table is attached. Whenever a consumer (such as a component definition in a frame header, which references a quantization table, or a component reference in a scan header, which includes references to a DC and/or AC huffman table) references a resource, it does so by specifying a binding point, which resolves to whatever table is attached to it at the time. Table bindings are stateful, so the same slot can be overwritten multiple times within the same JPEG file.

The following is an example structure of a (sequential) JPEG from start to finish, with the state of the table slots given on the right:

```
                                              Quantization  DC Huffman  AC Huffman 
                                                  tables      tables      tables 
——————————————————————————————————————————       \.0 \.1     \.0 \.1     \.0 \.1
Start-of-Image 
——————————————————————————————————————————      [   |   ]   [   |   ]   [   |   ]
Application Segment (JFIF metadata)
    version     :   1.2
    units       :   centimeters
    ...
——————————————————————————————————————————      [   |   ]   [   |   ]   [   |   ]
Quantization Table Definition (Table A) 
    destination :   \.0
    precision   :   8-bit
    ...
— — — — — — — — — — — — — — — — — — — — —       [ A |   ]   [   |   ]   [   |   ]
Quantization Table Definition (Table B)
    destination :   \.1
    precision   :   8-bit
    ...
——————————————————————————————————————————      [ A | B ]   [   |   ]   [   |   ]
Frame Header 
    size        :   382x479
    precision   :   8-bit 
    components  : 
    {
        [1]: 
            sampling            : 2x2, 
            quantization table  : \.0 (Table A)
        [2]: 
            sampling            : 1x1, 
            quantization table  : \.1 (Table B)
        [3]: 
            sampling            : 1x1, 
            quantization table  : \.1 (Table B)
    }
    ...
——————————————————————————————————————————      [ A | B ]   [   |   ]   [   |   ]
DC Huffman Table Definition (Table C)
    destination :   \.0 
    ...
— — — — — — — — — — — — — — — — — — — — —       [ A | B ]   [ C |   ]   [   |   ]
AC Huffman Table Definition (Table D)
    destination :   \.0
    ...
——————————————————————————————————————————      [ A | B ]   [ C |   ]   [ D |   ]
Scan Header 
    band        :   [0, 64)
    bits        :   [0, ∞)
    components  :
    [
        {
            ci  : [1]
            DC huffman table: \.0 (Table C)
            AC huffman table: \.0 (Table D)
        }
    ]
——————————————————————————————————————————      [ A | B ]   [ C |   ]   [ D |   ]
Entropy-Coded Segment 
    ...
——————————————————————————————————————————      [ A | B ]   [ C |   ]   [ D |   ]
DC Huffman Table Definition (Table E)
    destination :   \.0 
    ...
— — — — — — — — — — — — — — — — — — — — —       [ A | B ]   [ E |   ]   [ D |   ]
AC Huffman Table Definition (Table F)
    destination :   \.0
    ...
— — — — — — — — — — — — — — — — — — — — —       [ A | B ]   [ E |   ]   [ F |   ]
DC Huffman Table Definition (Table G)
    destination :   \.1 
    ...
— — — — — — — — — — — — — — — — — — — — —       [ A | B ]   [ E | G ]   [ F |   ]
AC Huffman Table Definition (Table H)
    destination :   \.1
    ...
——————————————————————————————————————————      [ A | B ]   [ E | G ]   [ F | H ]
Scan Header 
    band        :   [0, 64)
    bits        :   [0, ∞)
    components  :
    [
        {
            ci  : [2]
            DC huffman table: \.0 (Table E)
            AC huffman table: \.0 (Table F)
        },
        {
            ci  : [3]
            DC huffman table: \.1 (Table G)
            AC huffman table: \.1 (Table H)
        }
    ]
——————————————————————————————————————————      [ A | B ]   [ E | G ]   [ F | H ]
Entropy-Coded Segment 
    ...
——————————————————————————————————————————      [ A | B ]   [ E | G ]   [ F | H ]
End-of-Image 
——————————————————————————————————————————
```

Note how tables C and D were overwritten partway through the JPEG file.

## iv. user model

> **Summary:** The Swift *JPEG* encoder provides unique abstract *component key* and *quantization table key* identifiers. The component keys are equivalent in value to the component idenfiers (*c<sub>i</sub>*) in the JPEG standard, while the quantization table identifiers (*q<sub>i</sub>*) are a library concept, which obviate the need for users to assign and refer to quantization tables by their slot index, as slots may be overwritten and reused within the same JPEG file. Users also specify the *scan progression* by band range, bit range, and component key set. These relationships are combined into a *layout*, a library concept encapsulating relationships between table indices, component indices, scan component references, etc. When initializing a layout, the framework is responsible for mapping the abstract, user-specified relationships into a sequence of JPEG scan headers and table definitions.

> JPEG layout structures also contain a mapping from abstract component and quantization table keys to linear integer indices which point to the actual storage for the respective resources. (The framework notations for these indices are *c* and *q*, respectively.) The linear indices provide fast access to JPEG resources, as using them does not involve resolving hashtable lookups.

> Layout structures are combined with actual quantization table values to construct *image data* structures. All image data structures (except the `Rectangular` type) are planar, and are conceptually `Collection`s of planes corresponding to a single color component. The ordering of the planes is determined by the *image format*, which is generic and can be replaced with a user-defined implementation. The framework vends a default “common format” which corresponds to the 8-bit Y and YCbCr color modes defined by the JFIF standard. Plane indices range from 0 to *p*<sub>max</sub>, where *p*<sub>max</sub> is the number of planes in the image. The library assigns linear component indices such that *c*&nbsp;=&nbsp;*p*.

The JPEG format, as previously discussed, contains a great deal of complexity meant to facilitate implementation. However, much of this complexity is unnecessary for users, which is why this framework attempts to abstract away most of the user-irrelevant aspects of the format.

This framework provides two sets of top-level APIs: a *segmentation API* and an *decoding/encoding API*. Both are top-level in that they are capable of interpreting or outputting a JPEG file from start to finish. The segmentation API is essentially a lexer/formatter in that it detects JPEG segment boundaries, and classifies them by type. It does not attempt to interpret the contents of the segments. The decoding/encoding API reads or writes a JPEG file as a whole; its output/input is a complete bitmap image. This API is essentially built atop of the segmentation API.

While the segmentation and decoding/encoding APIs roughly correspond to the lexing/formatting and decoding/encoding stages of JPEG interpretation, there is no such top-level API for the parsing/serializing stage. This is because each lexed or formatted JPEG segment requires a different parser or serializer implementation, and which implementation it requires depends on the type of the segment. As such, a “top-level” parsing/serializing API would not be a useful abstraction, and so this framework does not seek to provide one.

### iv.i. segmentation API

As mentioned already, the segmentation API takes a file input (or byte stream), and divides it into its constituent segments. Its inverse API takes raw segment buffers and concatenates them with appropriate segment headers into an output bytestream.

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                           raw bytestream (file or file blob)                            ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
                                            ↿⇂
┏━━━━━━┓┏━━━━━━┯━━━━━━━━━━┓┏━━━━━━┯━━━━━━━━━━┓┏━━━━━━━━━━━━━━━━┓┏━━━━━━┯━━━━━━━━━━┓┏━━━━━━┓
┃ Type ┃┃ Type │   Body   ┃┃ Type │   Body   ┃┃     Prefix     ┃┃ Type │   Body   ┃┃ Type ┃
┗━━━━━━┛┗━━━━━━┷━━━━━━━━━━┛┗━━━━━━┷━━━━━━━━━━┛┗━━━━━━━━━━━━━━━━┛┗━━━━━━┷━━━━━━━━━━┛┗━━━━━━┛
   ↑             ↑                  ↑                 ↑                  ↑            ↑
   Marker segments           Marker segment  Entropy-coded segment      Marker segments
```

Its operations can be best summarized by the pseudoswift below:
```swift 
var input:Source
while true 
{
    let (prefix, type, body):([UInt8], JPEG.Marker, [UInt8]) = input.segment()
    switch type 
    {
        ...
    }
}

var output:Destination 
let pairs:[([UInt8], JPEG.Marker, [UInt8])]
for (prefix, type, body):([UInt8], JPEG.Marker, [UInt8]) in pairs 
{
    output.format(prefix: prefix)
    output.format(marker: type, tail: body)
    ...
}
```

Note that this is *not* how the segmentation API is actually spelled, as the real API expects the user to know whether to expect an entropy-coded segment to be present, as well as to be aware of error handling.

### iv.ii. decoding/encoding API 

While the segmentation API only goes so far as to lex or format a JPEG file, the decoding/encoding API does the heavy lifting of actually converting a JPEG to and from its bitmap data. This this is the most common use-case for JPEG, this set of APIs is likely to be the one most commonly used by users.

Internally, this set of APIs handles JPEG state management, abstracting away the confusing system of table slots, plane indices, and binding points, and replacing it with resource identifiers (*c<sub>i</sub>*’s and *q<sub>i</sub>*’s) which are unique over the lifetime of the JPEG. The purpose of this abstraction is not only to present a simpler mental model for users, but also to make it harder for users to accidentally create an invalid JPEG file (for example, switching out a quantization table while its corresponding component is still being encoded.)

#### iv.ii.i. keys, indices, and binding points 

To users, this framework replaces the concept of resource binding points with *keys* and *indices*. (These terms are used in accordance to Swift convention.) The framework also uses the system of keys and indices to identify components, and by extension, image planes.

Keys are unique identifiers for either a color component or a quantization table. The identifiers [*q<sub>i</sub>*] and [*c<sub>i</sub>*] are keys in this context, and we use the same notation to refer to them. Keys are essentially integer identifiers, and in the case of component keys, they have the same wrapped value as the component identifiers assigned in the image frame header. (Quantization table keys are a framework concept, they do not appear in the JPEG standard itself.) However, the framework uses Swift’s strong type system to distinguish them from actual indices to prevent user mixups.

Indices, as the name suggests (according to Swift convention) are shortcuts used for efficient dereferencing of entities that would otherwise have to go through expensive hashtable lookups. Because the storage type is always some kind of `Array`, all indices have the type `Int`. The library API is written to discourage direct use of keys as accessors, rather, it nudges users towards looking up an index from a key once, and then using the index for all subsequent accesses.

The framework uses the notation *c* and *q* for indices, corresponding to the [*q<sub>i</sub>*] and [*c<sub>i</sub>*] notation for keys.

By library convention, the quanta key –1 is assigned to the “default” (all zeroes) quantization table when decoding a JPEG file. This key has index 0, so all file-defined quantization tables have indices counting up from 1. Quanta keys are assigned by the user when encoding a JPEG file. 

Component keys are completely data-defined. Component indices start from 0, and are determined by the order that the component identifiers appear in the [color format](#ii-ii-color-formats). For the JFIF/EXIF common format, the key-to-index mapping is: 

```
{
    [1]: 0, 
    [2]: 1, 
    [3]: 2
}
```

Component indices are the same as plane indices, which use the notation *p* in the framework. In the above common format, component [1] would be plane *p*&nbsp;=&nbsp;0, component [2] would be plane *p*&nbsp;=&nbsp;1, and component [3] would be plane *p*&nbsp;=&nbsp;2. 

While the builtin common format does not do this, custom color formats are allowed to support more *resident components* (components that a frame header can define without causing the library to emit a validation error) than *recognized components* (components that the decoder maintains pixel storage for and includes in its output). In this case, only the recognized components have corresponding planes. An example of a use-case for this kind of component subsetting is a custom RGB color format, which supports an optional alpha channel. In this case, custom RGBA JPEG images can be made compatible with another custom RGB color format using component subsetting.

When a color format defines optional resident components, the recognized components get assigned contiguous indices starting from 0, and the optional components come after them.

The encoder does not allow optional resident components, since it would not make sense to encode an image component for which no plane data has been provided.

#### iv.ii.ii. layouts and definitions

An image *layout* specifies all the parametric characteristics of the image save for the actual pixel values. It contains:

* The image color format 
* The image coding process 
* The set of resident components 
* The list of recognized components (which is always a subset of the residents)


* The parameters for image planes (an array)
* The sequence of definitions in the image (also an array)

Each plane in the image has its own layout parameters. (The framework, of course, follows the same component/plane indexing scheme for this array.) A plane layout contains:

* The component sampling factor 
* The component quanta key ([*q<sub>i</sub>*])
* The component quantization table binding point 

The quanta key and the table binding point are always related. When a user initializes a layout, the binding points are assigned by the library. (In some cases, it is impossible to assign a large number of overlapping quanta keys to a limited number of binding points, in which case the library throws an error.) When a layout gets read from a JPEG file, the quanta keys get assigned by the library, as discussed in the [last section](#iv-ii-i-keys-indices-and-binding-points).

The definition sequence is a list of alternating runs of quantization table definitions and scan definitions. The quantization table definitions say nothing about the actual contents of the tables, they only specify that the quantization table for a particular quanta key [*q<sub>i</sub>*] should appear in that position in the sequence.

The following is a block diagram of a layout for an image with a custom color format with four components:
```
            c           0                1                2                3
                        ┏━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━┱────────────────┐
format and components   ┃ ci       : [5] │ ci       : [6] │ ci       : [7] ┃ ci       : [4] │
                        ┗━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━┹────────────────┘
                        ┏━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━┱────────────────┐
                        ┃ factor   : 2x2 │ factor   : 1x2 │ factor   : 1x2 ┃ factor   : 1x1 │
        planes          ┃ quanta   : [2] │ quanta   : [3] │ quanta   : [3] ┃ quanta   : [0] │
                        ┃ selector : \.0 │ selector : \.1 │ selector : \.1 ┃ selector : \.1 │
                        ┗━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━┷━━━━━━━━━━━━━━━━┹────────────────┘
                        ╰────────────────────────┬─────────────────────────╯
                                    recognized components/planes

                      ╭ ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ ╮
  quantization table  │ ┃ qi        : [2]                        ┃ │
      definitions    ─┤ ┠────────────────────────────────────────┨ │
                      │ ┃ qi        : [0]                        ┃ │
                      ╰ ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┨ │
                      ╭ ┃             ┌────────────────────────┐ ┃ │
                      │ ┃             │ c             :  0     │ ┃ │
                      │ ┃ components: │ ci            : [5]    │ ┃ │
                      │ ┃             │ selector (DC) : \.0    │ ┃ │
                      │ ┃             │ selector (AC) : \.0    │ ┃ │
                      │ ┃             └────────────────────────┘ ┃ │
                      │ ┃ band      : [0, 64)                    ┃ │
        scan          │ ┃ bits      : [0,  ∞)                    ┃ │
     definitions     ─┤ ┠────────────────────────────────────────┨ │
                      │ ┃             ┌────────────────────────┐ ┃ │
                      │ ┃             │ c             :  3     │ ┃ │
                      │ ┃ components: │ ci            : [4]    │ ┃ │
                      │ ┃             │ selector (DC) : \.0    │ ┃ │
                      │ ┃             │ selector (AC) : \.0    │ ┃ │
                      │ ┃             └────────────────────────┘ ┃ │
                      │ ┃ band      : [0, 64)                    ┃ ├─  definition sequence
                      │ ┃ bits      : [0,  ∞)                    ┃ │
                      ╰ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ │
                        ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ │
                        ┃ qi        : [3]                        ┃ │
                        ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┨ │
                        ┃             ┌────────────────────────┐ ┃ │
                        ┃             │ c             :  1     │ ┃ │
                        ┃             │ ci            : [6]    │ ┃ │
                        ┃             │ selector (DC) : \.0    │ ┃ │
                        ┃             │ selector (AC) : \.0    │ ┃ │
                        ┃ components: ├────────────────────────┤ ┃ │
                        ┃             │ c             :  2     │ ┃ │
                        ┃             │ ci            : [7]    │ ┃ │
                        ┃             │ selector (DC) : \.1    │ ┃ │
                        ┃             │ selector (AC) : \.1    │ ┃ │
                        ┃             └────────────────────────┘ ┃ │
                        ┃ band      : [0, 64)                    ┃ │
                        ┃ bits      : [0,  ∞)                    ┃ │
                        ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ ╯
```

## v. library architecture

> **Summary:** The library is broadly divided into a decompressor and a compressor. The decompressor is further subdivided into a lexer, parser, and decoder, while the compressor is divided into an encoder, serializer, and formatter. Accordingly, the framework distinguishes between parseme types, returned by the parser and taken by the serializer, and model types, used by the decoder and encoder. For example, the parser returns a scan *header*, which is then “frozen” into a scan *structure*.

> The framework is architected for extensibility. For example, although the decoder and encoder do not support JPEG processes beyond the baseline, extended, and progressive processes, all JPEG processes, including hierarchical and arithmetic processes are recognized by the parser. Similarly, the lexer recognizes JPEG marker types that the parser does not necessarily know how to parse.

## vi. test architecture

> **Summary:** The Travis Continuous Integration set up for the project repository supports four sets of tests. *Unit tests* verify basic algorithmic components of the library, such as the huffman coders and zigzag index translators. *Integration tests* verify that a sample set of images with different supported coding processes and layouts can be decoded and encoded without errors. *Regression tests* run the integration tests and compare them with known outputs. Finally, *fuzz tests* generate randomized test images and compare the output to that output from third-party implementations such as the *libjpeg*-based `imagemagick convert` tool, ensuring inter-library compatibility.
