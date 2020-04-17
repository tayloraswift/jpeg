# Swift *JPEG*

Swift *JPEG* is a cross-platform pure Swift framework which provides a full-featured JPEG encoding and decoding API. The core framework has no external dependencies, including *Foundation*, and should compile and provide consistent behavior on *all* Swift platforms. The framework supports additional features, such as file system support, on Linux and MacOS. Swift *JPEG* is available under the [GPL3 open source license](https://choosealicense.com/licenses/gpl-3.0/).

## i. project motivation

> **Summary:** Unlike *UIImage*, Swift *JPEG* is cross-platform and open-source. It provides a rich, idiomatic set of APIs for the Swift language, beyond what wrappers around C frameworks such as *libjpeg* can emulate, and unlike *libjpeg*, guarantees safe and consistent behavior across different platforms and hardware. As a standalone SPM package, it is also significantly easier to install and use in a Swift project.

## ii. project goals

> **Summary:** Swift *JPEG* supports all three popular JPEG coding processes (baseline, extended, and progressive), and comes with built-in support for the JFIF/EXIF subset of the JPEG standard. The framework supports decompressing images to RGB and YCbCr targets. Lower-level APIs allow users to perform lossless operations on the frequency-domain representation of an image, transcode images between different coding processes, edit header fields and tables, and insert or strip metadata. The framework also provides the flexibility for users to extend the JPEG standard to support custom color formats and additional coding processes.

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
