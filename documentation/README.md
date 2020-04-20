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

The JPEG standard is color-format agnostic, meaning it supports any combination of user-defined color components (YCbCr, RGB, RGBA, and anything else). The standard defines no fewer than thirteen different *coding processes*, which are essentially distinct image formats grouped under the umbrella of “JPEG formats”. Coding processes can be classified by their *entropy coding*:

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

> *Note: processes this project aims to support are **bolded***.

Among these formats, only the baseline huffman non-hierarchical process is commonly used today, though the progressive huffman non-hierarchical process is sometimes also seen. This is in large part due to the other two technical standards relevant to the JPEG format, discussed shortly.

Until very recently, the arithmetic entropy coding method was patented, which resulted in its exclusion from software implementations of the standard. The lossless and hierarchical processes are seldom-used today, and are considered out of scope for this project. However, the extended (huffman, non-hierarchical) process is a relatively straightforward derivation from the baseline process, and sees some usage in applications such as medical imaging, so this project supports this process in addition to processes 1 and 6.

The framework is designed to still parse and recognize the unsupported coding processes, even if it is unable to encode or decode them. As such, it supports, for example, editing and resaving metadata for all conforming JPEG files regardless of the coding process used. 

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

## iii. concepts 

> **Summary:** JPEG is a frequency transform-based compressed image format. Decompressing the file format can be roughly divided into lexing, parsing, and decoding stages. Decoding involves assembling multiple image *scans* into a single image *frame*. A scan may contain one or more color *components* (channels). In a progressive JPEG, a single scan may contain only a specific range of bits for a specific frequency band. JPEG images also use *huffman* and *quantization* tables. Huffman tables are associated with image components at the scan level. Quantization tables are associated with image components at the frame level. Multiple components can reference the same huffman or quantization table. The “compression level” of a JPEG image is almost fully determined by the quantization tables used by the image.

## iv. user model

> **Summary:** The Swift *JPEG* encoder provides unique abstract *component key* and *quantization table key* identifiers. The component keys are equivalent in value to the component idenfiers (*c<sub>i</sub>*) in the JPEG standard, while the quantization table identifiers (*q<sub>i</sub>*) are a library concept, which obviate the need for users to assign and refer to quantization tables by their slot index, as slots may be overwritten and reused within the same JPEG file. Users also specify the *scan progression* by band range, bit range, and component key set. These relationships are combined into a *layout*, a library concept encapsulating relationships between table indices, component indices, scan component references, etc. When initializing a layout, the framework is responsible for mapping the abstract, user-specified relationships into a sequence of JPEG scan headers and table definitions.

> JPEG layout structures also contain a mapping from abstract component and quantization table keys to linear integer indices which point to the actual storage for the respective resources. (The framework notations for these indices are *c* and *q*, respectively.) The linear indices provide fast access to JPEG resources, as using them does not involve resolving hashtable lookups.

> Layout structures are combined with actual quantization table values to construct *image data* structures. All image data structures (except the `Rectangular` type) are planar, and are conceptually `Collection`s of planes corresponding to a single color component. The ordering of the planes is determined by the *image format*, which is generic and can be replaced with a user-defined implementation. The framework vends a default “common format” which corresponds to the 8-bit Y and YCbCr color modes defined by the JFIF standard. Plane indices range from 0 to *p*<sub>max</sub>, where *p*<sub>max</sub> is the number of planes in the image. The library assigns linear component indices such that *c*&nbsp;=&nbsp;*p*.

## v. library architecture

> **Summary:** The library is broadly divided into a decompressor and a compressor. The decompressor is further subdivided into a lexer, parser, and decoder, while the compressor is divided into an encoder, serializer, and formatter. Accordingly, the framework distinguishes between parseme types, returned by the parser and taken by the serializer, and model types, used by the decoder and encoder. For example, the parser returns a scan *header*, which is then “frozen” into a scan *structure*.

> The framework is architected for extensibility. For example, although the decoder and encoder do not support JPEG processes beyond the baseline, extended, and progressive processes, all JPEG processes, including hierarchical and arithmetic processes are recognized by the parser. Similarly, the lexer recognizes JPEG marker types that the parser does not necessarily know how to parse.

## vi. test architecture

> **Summary:** The Travis Continuous Integration set up for the project repository supports four sets of tests. *Unit tests* verify basic algorithmic components of the library, such as the huffman coders and zigzag index translators. *Integration tests* verify that a sample set of images with different supported coding processes and layouts can be decoded and encoded without errors. *Regression tests* run the integration tests and compare them with known outputs. Finally, *fuzz tests* generate randomized test images and compare the output to that output from third-party implementations such as the *libjpeg*-based `imagemagick convert` tool, ensuring inter-library compatibility.
