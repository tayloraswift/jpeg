/* This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// module JPEG 
///     Decode, inspect, edit, and encode JPEG images.
/// 
///     See example programs and library tutorials [here](https://github.com/kelvin13/jpeg/tree/master/examples).
/// #  [Top level namespaces](top-level-namespaces)

/// protocol JPEG.Format
///     A color format, determined by the bit depth and set of component keys in 
///     a frame header. 
/// 
///     The coding [`(JPEG).Process`] of an image may place restrictions on which 
///     combinations of component sets and bit precisions are valid.
/// # [See also](color-protocols)
/// ## (color-protocols)
/// ## (0:color-space-apis)
public 
protocol _JPEGFormat
{
    /// static func JPEG.Format.recognize(_:precision:)
    /// required 
    ///     Detects this color format, given a set of component keys and a bit depth.
    /// 
    /// - components    : Swift.Set<JPEG.Component.Key>
    ///     The set of given component keys.
    /// - precision     : Swift.Int
    ///     The given bit depth.
    /// - ->            : Self?
    ///     A color format instance.
    static 
    func recognize(_ components:Set<JPEG.Component.Key>, precision:Int) -> Self?
    
    /// var JPEG.Format.components  : [JPEG.Component.Key] {get}
    /// required 
    ///     The set of component keys for this color format. 
    /// 
    ///     The ordering is used to determine plane index assignments when initializing 
    ///     an image layout. This property should never be empty. It is allowed 
    ///     for this array to contain fewer components than were detected by the 
    ///     [`(Format).recognize(_:precision:)`] constructor.
    var components:[JPEG.Component.Key]
    {
        get 
    }
    
    /// var JPEG.Format.precision   : Swift.Int {get}
    /// required 
    ///     The bit depth of each component in this color format.
    var precision:Int 
    {
        get 
    }
}
/// protocol JPEG.Color 
///     A color target.
/// # [See also](color-protocols)
/// ## (color-protocols)
/// ## (0:color-space-apis)
public 
protocol _JPEGColor
{
    /// associatedtype JPEG.Color.Format    : JPEG.Format
    ///     The color format associated with this color target. An image using 
    ///     any color format of this type will support rendering to this color target.
    associatedtype Format:JPEG.Format 
    
    /// static func JPEG.Color.unpack(_:of:)
    /// required
    ///     Converts the given interleaved samples into an array of structured pixels.
    /// 
    /// - interleaved   : [Swift.UInt16]
    ///     A flat array of interleaved component samples.
    /// - format        : Format
    ///     The color format of the interleaved input.
    /// - ->            : [Self]
    ///     An array of pixels of this color target type.
    static 
    func unpack(_ interleaved:[UInt16], of format:Format) -> [Self]
    
    /// static func JPEG.Color.pack(_:as:)
    /// required
    ///     Converts the given array of structured pixels into an array of interleaved samples.
    /// 
    /// - pixels        : [Self]
    ///     An array of pixels of this color target type.
    /// - format        : Format
    ///     The color format of the interleaved output.
    /// - ->            : [Swift.UInt16]
    ///     A flat array of interleaved component samples.
    static 
    func pack(_ pixels:[Self], as format:Format) -> [UInt16]
}

/// enum JPEG 
///     A namespace for JPEG-related functionality. 
/// #  [Color spaces](color-space-apis)
/// #  [Image metadata](metadata-types)
/// #  [Image headers](header-types-and-namespace)
/// #  [Image tables](table-types-and-protocols)
/// #  [Entropy coding](entropy-coding)
/// #  [Image representations](image-data-types-and-namespace)
/// #  [Data IO and file structure](lexing-and-formatting)
/// #  [Image layout and decomposition](image-structure-and-decomposition)
/// #  [Image quality](image-quality)
/// #  [Manual decoding](manual-decoding)
/// #  [Error handling](error-handling)
/// #  [See also](top-level-namespaces)
/// ## (0:top-level-namespaces)
public 
enum JPEG 
{
    public 
    typealias Format = _JPEGFormat
    public 
    typealias Color  = _JPEGColor
    
    /// enum JPEG.Metadata
    ///     A metadata record.
    /// #  [Metadata types](metadata-types)
    /// ## (metadata-types)
    public 
    enum Metadata 
    {
        /// case JPEG.Metadata.jfif(_:)
        ///     A JFIF metadata record.
        /// - _     : JPEG.JFIF
        case jfif(JFIF)
        /// case JPEG.Metadata.exif(_:)
        ///     An EXIF metadata record.
        /// - _     : JPEG.EXIF
        case exif(EXIF)
        /// case JPEG.Metadata.application(_:data:)
        ///     An unparsed application data segment.
        /// - _     : Swift.Int
        ///     The type code of this application segment.
        /// - data  : Swift.Array<Swift.UInt8>
        ///     The raw data of this application segment.
        case application(Int, data:[UInt8])
        /// case JPEG.Metadata.comment(data:)
        ///     A comment segment.
        /// - data  : Swift.Array<Swift.UInt8>
        ///     The raw contents of this comment segment. Often, but not always, 
        ///     this data is UTF-8-encoded text.
        case comment(data:[UInt8])
    }
    
    /// struct JPEG.YCbCr 
    /// :   Swift.Hashable
    /// :   JPEG.Color
    /// @   frozen
    ///     An 8-bit YCbCr color. 
    /// 
    ///     This type is a color target for the built-in [`JPEG.Common`] color format.
    /// # [Color channels](JPEG-YCbCr-color-channels)
    /// # [See also](builtin-color-targets)
    /// ## (builtin-color-targets)
    /// ## (2:color-space-apis)
    @frozen 
    public 
    struct YCbCr:Hashable 
    {
        /// var JPEG.YCbCr.y    : Swift.UInt8
        ///     The luminance component of this color. 
        /// ## (0:JPEG-YCbCr-color-channels)
        public 
        var y:UInt8 
        /// var JPEG.YCbCr.cb   : Swift.UInt8
        ///     The blue component of this color. 
        /// ## (1:JPEG-YCbCr-color-channels)
        public 
        var cb:UInt8 
        /// var JPEG.YCbCr.cr   : Swift.UInt8
        ///     The red component of this color. 
        /// ## (2:JPEG-YCbCr-color-channels)
        public 
        var cr:UInt8 
        
        /// init JPEG.YCbCr.init(y:)
        ///     Initializes this color to the given luminance level.
        /// 
        ///     The Cb and Cr channels will be initialized to 128.
        /// - y : Swift.UInt8
        ///     The given luminance level.
        public 
        init(y:UInt8) 
        {
            self.init(y: y, cb: 128, cr: 128)
        }
        
        /// init JPEG.YCbCr.init(y:cb:cr:)
        ///     Initializes this color to the given YCbCr triplet.
        /// 
        /// - y : Swift.UInt8
        ///     The given luminance component.
        /// - cb: Swift.UInt8
        ///     The given blue component.
        /// - cr: Swift.UInt8
        ///     The given red component.
        public 
        init(y:UInt8, cb:UInt8, cr:UInt8) 
        {
            self.y  = y 
            self.cb = cb 
            self.cr = cr 
        }
    }
    /// struct JPEG.RGB 
    /// :   Swift.Hashable
    /// :   JPEG.Color
    /// @   frozen
    ///     An 8-bit RGB color. 
    /// 
    ///     This type is a color target for the built-in [`JPEG.Common`] color format.
    /// # [Color channels](JPEG-RGB-color-channels)
    /// # [See also](builtin-color-targets)
    /// ## (builtin-color-targets)
    /// ## (2:color-space-apis)
    @frozen
    public 
    struct RGB:Hashable 
    {
        /// var JPEG.RGB.r      : Swift.UInt8
        ///     The red component of this color. 
        /// ## (JPEG-RGB-color-channels)
        public
        var r:UInt8
        /// var JPEG.RGB.g      : Swift.UInt8
        ///     The green component of this color. 
        /// ## (JPEG-RGB-color-channels)
        public
        var g:UInt8
        /// var JPEG.RGB.b      : Swift.UInt8
        ///     The blue component of this color. 
        /// ## (JPEG-RGB-color-channels)
        public
        var b:UInt8
        
        /// init JPEG.RGB.init(_:)
        ///     Creates an opaque grayscale color with all color components set 
        ///     to the given value sample.
        /// 
        /// - value : Swift.UInt8
        ///     The value to initialize all color components to.
        public
        init(_ value:UInt8)
        {
            self.init(value, value, value)
        }
        
        /// init JPEG.RGB.init(_:_:_:)
        ///     Creates an opaque color with the given color samples.
        /// 
        /// - red   : Swift.UInt8
        ///     The value to initialize the red component to.
        /// - green : Swift.UInt8
        ///     The value to initialize the green component to.
        /// - blue  : Swift.UInt8
        ///     The value to initialize the blue component to.
        public
        init(_ red:UInt8, _ green:UInt8, _ blue:UInt8)
        {
            self.r = red 
            self.g = green 
            self.b = blue
        }
    }     
}

// pixel accessors 
extension JPEG  
{
    /// enum JPEG.Common 
    /// :   JPEG.Format 
    ///     A built-in color format which covers the JFIF/EXIF subset of the 
    ///     [JPEG standard](https://www.w3.org/Graphics/JPEG/itu-t81.pdf).
    /// 
    ///     This color format is able to recognize conforming JFIF and EXIF images,
    ///     which use the component key assignments *Y*\ =\ **1**, *Cb*\ =\ **2**, *Cr*\ =\ **3**.
    ///     To provide compatibility with older, faulty JPEG codecs, it is also  
    ///     able to recognize non-standard component schemes as long as 
    ///     they have the correct arity and form a contiguously increasing sequence.
    /// # [Standardized formats](common-standard-formats)
    /// # [Compatibility formats](common-nonstandard-formats)
    /// # [See also](color-protocols)
    /// ## (color-protocols)
    /// ## (1:color-space-apis)
    public 
    enum Common 
    {
        /// case JPEG.Common.y8 
        ///     The standard JFIF 8-bit grayscale format.
        /// 
        ///     This color format uses the component key assignment *Y*\ =\ **1**. 
        ///     Note that images using this format are compliant JFIF images, but 
        ///     are *not* compliant EXIF images.
        /// # [See also](common-standard-formats)
        /// ## (common-standard-formats)
        case y8
        /// case JPEG.Common.ycc8 
        ///     The standard JFIF/EXIF 8-bit YCbCr format.
        /// 
        ///     This color format uses the component key assignments *Y*\ =\ **1**, 
        ///     *Cb*\ =\ **2**, *Cr*\ =\ **3**.
        /// # [See also](common-standard-formats)
        /// ## (common-standard-formats)
        case ycc8
        /// case JPEG.Common.nonconforming1x8(_:)
        ///     A non-standard 8-bit grayscale format.
        /// 
        ///     This color format can use any component key assignment of arity 1. 
        ///     Note that images using this format are valid JPEG images, but are 
        ///     not compliant JFIF or EXIF images, and some viewers may not support them.
        /// - _     : JPEG.Component.Key 
        ///     The component key interpreted as the luminance component.
        /// # [See also](common-nonstandard-formats)
        /// ## (common-nonstandard-formats)
        case nonconforming1x8(JPEG.Component.Key)
        /// case JPEG.Common.nonconforming3x8(_:_:_:)
        ///     A non-standard 8-bit YCbCr format.
        /// 
        ///     This color format can use any contiguously increasing sequence of 
        ///     component key assignments of arity 3. For example, it can use the 
        ///     assignments *Y*\ =\ **0**, *Cb*\ =\ **1**, *Cr*\ =\ **2**, or the assignments 
        ///     *Y*\ =\ **2**, *Cb*\ =\ **3**, *Cr*\ =\ **4**.
        ///     Note that images using this format are valid JPEG images, but are 
        ///     not compliant JFIF or EXIF images, and some viewers may not support them.
        /// - _     : JPEG.Component.Key 
        ///     The component key interpreted as the luminance component.
        /// - _     : JPEG.Component.Key 
        ///     The component key interpreted as the blue component.
        /// - _     : JPEG.Component.Key 
        ///     The component key interpreted as the red component.
        /// # [See also](common-nonstandard-formats)
        /// ## (common-nonstandard-formats)
        case nonconforming3x8(JPEG.Component.Key, JPEG.Component.Key, JPEG.Component.Key)
    }
}
extension JPEG.Common:JPEG.Format
{
    fileprivate static 
    func clamp<T>(_ x:Float, to _:T.Type) -> T where T:FixedWidthInteger
    {
        .init(max(.init(T.min), min(x, .init(T.max))))
    }
    fileprivate static 
    func clamp<T>(_ x:SIMD3<Float>, to _:T.Type) -> SIMD3<T> where T:FixedWidthInteger
    {
        .init(x.clamped(
            lowerBound: .init(repeating: .init(T.min)), 
            upperBound: .init(repeating: .init(T.max))))
    }
    
    /// static func JPEG.Common.recognize(_:precision:)
    /// ?:  JPEG.Format 
    ///     Detects this color format, given a set of component keys and a bit depth.
    ///     
    ///     If this constructor detects a [`(Common).nonconforming3x8(_:_:_:)`] 
    ///     color format, it will populate the associated values with the keys in 
    ///     ascending order.
    /// - components    : Swift.Set<JPEG.Component.Key>
    ///     Must be a numerically-contiguous set with one or three elements, or 
    ///     this constructor will return `nil`.
    /// - precision     : Swift.Int 
    ///     Must be 8, or this constructor will return `nil`.
    /// - ->            : Self?
    public static 
    func recognize(_ components:Set<JPEG.Component.Key>, precision:Int) -> Self? 
    {
        let sorted:[JPEG.Component.Key] = components.sorted()
        switch (sorted, precision) 
        {
        case ([1],          8): 
            return .y8
        case ([1, 2, 3],    8): 
            return .ycc8
        default:
            break 
        }
        
        if sorted.count == 1 
        {
            return .nonconforming1x8(sorted[0])
        }
        else if let base:Int = sorted.first?.value, 
            sorted.count == 3, 
            sorted.map(\.value) == .init(base ..< base + 3)
        {
            return .nonconforming3x8(sorted[0], sorted[1], sorted[2])
        }
        else 
        {
            return nil
        }
    }
    /// var JPEG.Common.components  : [JPEG.Component.Key] {get}
    /// ?:  JPEG.Format 
    ///     The set of component keys for this color format. 
    /// 
    ///     If this instance is a [`(Common).nonconforming3x8(_:_:_:)`] color format,
    ///     the array contains the component keys in the order they appear 
    ///     in the instance’s associated values.
    public 
    var components:[JPEG.Component.Key] 
    {
        switch self 
        {
        case .y8:
            return [1]
        case .ycc8:
            return [1, 2, 3]
        case .nonconforming1x8(let c0):
            return [c0]
        case .nonconforming3x8(let c0, let c1, let c2):
            return [c0, c1, c2]
        }
    }
    /// var JPEG.Common.precision   : Swift.Int {get}
    /// ?:  JPEG.Format 
    ///     The bit depth of each component in this color format. 
    /// 
    ///     This value is always 8.
    public 
    var precision:Int 
    {
        8
    }
}
extension JPEG.YCbCr
{
    /// var JPEG.YCbCr.rgb  : JPEG.RGB 
    ///     This color represented in the RGB color space. 
    ///
    ///     This property applies the YCbCr-to-RGB conversion formula defined in 
    ///     the [JFIF standard](https://www.w3.org/Graphics/JPEG/jfif3.pdf). Some 
    ///     YCbCr colors are not representable in the RGB color space; such colors 
    ///     will be clipped to the acceptable range.
    public 
    var rgb:JPEG.RGB
    {
        let matrix:(cb:SIMD3<Float>, cr:SIMD3<Float>) = 
        (
            .init( 0.00000, -0.34414,  1.77200),
            .init( 1.40200, -0.71414,  0.00000)
        )
        let x:SIMD3<Float> = (.init(self.y)         as       Float ) + 
            (matrix.cb *     (.init(self.cb) - 128) as SIMD3<Float>) + 
            (matrix.cr *     (.init(self.cr) - 128) as SIMD3<Float>)
        let c:SIMD3<UInt8> = JPEG.Common.clamp(x, to: UInt8.self)
        return .init(c.x, c.y, c.z)
    }
}
extension JPEG.RGB
{
    /// var JPEG.RGB.ycc    : JPEG.YCbCr 
    ///     This color represented in the YCbCr color space. 
    ///
    ///     This property applies the RGB-to-YCbCr conversion formula defined in 
    ///     the [JFIF standard](https://www.w3.org/Graphics/JPEG/jfif3.pdf).
    public 
    var ycc:JPEG.YCbCr
    {
        let matrix:(SIMD3<Float>, r:SIMD3<Float>, g:SIMD3<Float>, b:SIMD3<Float>) = 
        (
            .init( 0,     128,     128     ),
            .init( 0.2990, -0.1687,  0.5000),
            .init( 0.5870, -0.3313, -0.4187),
            .init( 0.1140,  0.5000, -0.0813)
        )
        let x:SIMD3<Float> = matrix.0                  + 
            (matrix.r * .init(self.r) as SIMD3<Float>) + 
            (matrix.g * .init(self.g) as SIMD3<Float>) + 
            (matrix.b * .init(self.b) as SIMD3<Float>)
        let c:SIMD3<UInt8> = JPEG.Common.clamp(x, to: UInt8.self)
        return .init(y: c.x, cb: c.y, cr: c.z)
    }
}

extension JPEG.YCbCr:JPEG.Color 
{
    /// static func JPEG.YCbCr.unpack(_:of:)
    /// ?:  JPEG.Color
    ///     Converts the given interleaved samples into an array of YCbCr pixels.
    /// - interleaved   : [Swift.UInt16]
    ///     A flat array of interleaved component samples.
    /// - format        : JPEG.Common
    ///     The color format of the interleaved input.
    /// - ->            : [Self]
    ///     An array of YCbCr pixels.
    public static 
    func unpack(_ interleaved:[UInt16], of format:JPEG.Common) -> [Self]
    {
        // no need to clamp uint16 to uint8,, the idct should have already done 
        // this alongside the level shift 
        switch format 
        {
        case .y8, .nonconforming1x8:
            return interleaved.map 
            {
                Self.init(y: .init($0))
            }
        
        case .ycc8, .nonconforming3x8:
            return stride(from: 0, to: interleaved.count, by: 3).map 
            {
                Self.init(
                    y:  .init(interleaved[$0    ]), 
                    cb: .init(interleaved[$0 + 1]), 
                    cr: .init(interleaved[$0 + 2]))
            }
        }
    }
    /// static func JPEG.YCbCr.pack(_:as:)
    /// ?:  JPEG.Color 
    ///     Converts the given array of YCbCr pixels into an array of interleaved samples.
    /// 
    /// - pixels        : [Self]
    ///     An array of YCbCr pixels.
    /// - format        : JPEG.Common
    ///     The color format of the interleaved output.
    /// - ->            : [Swift.UInt16]
    ///     A flat array of interleaved component samples.
    public static 
    func pack(_ pixels:[Self], as format:JPEG.Common) -> [UInt16]
    {
        switch format 
        {
        case .y8, .nonconforming1x8:
            return pixels.map{ .init($0.y) }
        
        case .ycc8, .nonconforming3x8:
            return pixels.flatMap{ [ .init($0.y), .init($0.cb), .init($0.cr) ] }
        }
    }
}

extension JPEG.RGB:JPEG.Color 
{
    /// static func JPEG.RGB.unpack(_:of:)
    /// ?:  JPEG.Color
    ///     Converts the given interleaved samples into an array of RGB pixels.
    /// - interleaved   : [Swift.UInt16]
    ///     A flat array of interleaved component samples.
    /// - format        : JPEG.Common
    ///     The color format of the interleaved input.
    /// - ->            : [Self]
    ///     An array of RGB pixels.
    public static 
    func unpack(_ interleaved:[UInt16], of format:JPEG.Common) -> [Self]
    {
        switch format 
        {
        case .y8, .nonconforming1x8:
            return interleaved.map 
            {
                let ycc:JPEG.YCbCr = .init(y: .init($0))
                return ycc.rgb 
            }
        
        case .ycc8, .nonconforming3x8:
            return stride(from: 0, to: interleaved.count, by: 3).map 
            {
                let ycc:JPEG.YCbCr = .init(
                    y:  .init(interleaved[$0    ]), 
                    cb: .init(interleaved[$0 + 1]), 
                    cr: .init(interleaved[$0 + 2]))
                return ycc.rgb 
            }
        }
    }
    /// static func JPEG.RGB.pack(_:as:)
    /// ?:  JPEG.Color 
    ///     Converts the given array of RGB pixels into an array of interleaved samples.
    /// 
    /// - pixels        : [Self]
    ///     An array of RGB pixels.
    /// - format        : JPEG.Common
    ///     The color format of the interleaved output.
    /// - ->            : [Swift.UInt16]
    ///     A flat array of interleaved component samples.
    public static 
    func pack(_ pixels:[Self], as format:JPEG.Common) -> [UInt16]
    {
        switch format 
        {
        case .y8, .nonconforming1x8:
            return pixels.map{ .init($0.ycc.y) }
        
        case .ycc8, .nonconforming3x8:
            return pixels.flatMap
            {
                (rgb:JPEG.RGB) -> [UInt16] in 
                let ycc:JPEG.YCbCr = rgb.ycc  
                return [ .init(ycc.y), .init(ycc.cb), .init(ycc.cr) ] 
            } as [UInt16]
        }
    }
}

// compound types 
extension JPEG 
{
    /// enum JPEG.Process 
    ///     A coding process.
    /// 
    ///     The [JPEG standard](https://www.w3.org/Graphics/JPEG/itu-t81.pdf)
    ///     specifies several subformats of the JPEG format known as *coding processes*.
    ///     The library can recognize images using any coding process, but 
    ///     only supports encoding and decoding images using the [`(Process).baseline`], 
    ///     [`(Process).extended(coding:differential:)`], or 
    ///     [`(Process).progressive(coding:differential:)`] processes with 
    ///     [`(Process.Coding).huffman`] entropy coding and the `differential` flag 
    ///     set to `false`.
    /// # [Coding processes](coding-processes)
    /// ## (4:lexing-and-formatting)
    public 
    enum Process 
    {
        /// enum JPEG.Process.Coding 
        ///     An entropy coding method.
        public 
        enum Coding 
        {
            /// case JPEG.Process.Coding.huffman
            ///     Huffman entropy coding.
            case huffman 
            /// case JPEG.Process.Coding.arithmetic
            ///     Arithmetic entropy coding.
            case arithmetic 
        }
        
        /// case JPEG.Process.baseline
        ///     The baseline coding process. 
        /// 
        ///     This is a sequential coding process. It allows up to two simultaneously 
        ///     referenced tables of each type. It can only be used with color formats 
        ///     with a bit [`(JPEG.Format).precision`] of 8.
        /// ## (coding-processes)
        case baseline 
        /// case JPEG.Process.extended(coding:differential:)
        ///     The extended coding process. 
        /// 
        ///     This is a sequential coding process. It allows up to four simultaneously 
        ///     referenced tables of each type. It can only be used with color formats 
        ///     with a bit [`(JPEG.Format).precision`] of 8 or 12.
        /// - coding        : Coding 
        ///     The entropy coding used by this coding process.
        /// - differential  : Swift.Bool 
        ///     Indicates whether the image frame using this coding process is a 
        ///     differential frame under the hierarchical mode of operations.
        /// ## (coding-processes)
        case extended(coding:Coding, differential:Bool)
        /// case JPEG.Process.progressive(coding:differential:)
        ///     The progressive coding process. 
        /// 
        ///     This is a progressive coding process. It allows up to four simultaneously 
        ///     referenced tables of each type. It can only be used with color formats 
        ///     with a bit [`(JPEG.Format).precision`] of 8 or 12, and no more than 
        ///     four components.
        /// - coding        : Coding 
        ///     The entropy coding used by this coding process.
        /// - differential  : Swift.Bool 
        ///     Indicates whether the image frame using this coding process is a 
        ///     differential frame under the hierarchical mode of operations.
        /// ## (coding-processes)
        case progressive(coding:Coding, differential:Bool)
        /// case JPEG.Process.lossless(coding:differential:)
        ///     The lossless coding process.
        /// - coding        : Coding 
        ///     The entropy coding used by this coding process.
        /// - differential  : Swift.Bool 
        ///     Indicates whether the image frame using this coding process is a 
        ///     differential frame under the hierarchical mode of operations.
        /// ## (coding-processes)
        case lossless(coding:Coding, differential:Bool)
    }
    
    /// enum JPEG.Marker 
    ///     A marker type indicator.
    /// ## (3:lexing-and-formatting)
    public 
    enum Marker
    {
        /// case JPEG.Marker.start 
        ///     A start-of-image (SOI) marker.
        case start
        /// case JPEG.Marker.end 
        ///     An end-of-image (EOI) marker.
        case end
        /// case JPEG.Marker.quantization 
        ///     A quantization table definition (DQT) segment.
        case quantization 
        /// case JPEG.Marker.huffman
        ///     A huffman table definition (DHT) segment.
        case huffman 
        
        /// case JPEG.Marker.application(_:)
        ///     An application data (APP~*n*~) segment.
        /// - _     : Swift.Int 
        ///     The application segment type code. This value can be from 0 to 15.
        case application(Int)
        /// case JPEG.Marker.restart(_:)
        ///     A restart (RST~*m*~) marker.
        /// - _     : Swift.Int 
        ///     The restart phase. It cycles through the values 0 through 7.
        case restart(Int)
        /// case JPEG.Marker.height
        ///     A height redefinition (DNL) segment.
        case height 
        /// case JPEG.Marker.interval
        ///     A restart interval definition (DRI) segment. 
        case interval  
        /// case JPEG.Marker.comment
        ///     A comment (COM) segment. 
        case comment 
        
        /// case JPEG.Marker.frame(_:)
        ///     A frame header (SOF\*) segment. 
        /// - _     : JPEG.Process
        ///     The coding process used by the image frame.
        case frame(Process)
        /// case JPEG.Marker.scan
        ///     A scan header (SOS) segment. 
        case scan 
        
        /// case JPEG.Marker.arithmeticCodingCondition
        case arithmeticCodingCondition
        /// case JPEG.Marker.hierarchical
        case hierarchical 
        /// case JPEG.Marker.expandReferenceComponents
        case expandReferenceComponents
        
        init?(code:UInt8) 
        {
            switch code 
            {
            case 0xc0:
                self = .frame(.baseline)
            case 0xc1:
                self = .frame(.extended   (coding: .huffman, differential: false))
            case 0xc2:
                self = .frame(.progressive(coding: .huffman, differential: false))
            
            case 0xc3:
                self = .frame(.lossless   (coding: .huffman, differential: false))
            
            case 0xc4:
                self = .huffman
            
            case 0xc5:
                self = .frame(.extended   (coding: .huffman, differential: true))
            case 0xc6:
                self = .frame(.progressive(coding: .huffman, differential: true))
            case 0xc7:
                self = .frame(.lossless   (coding: .huffman, differential: true))
            
            case 0xc8: // reserved
                return nil 
            
            case 0xc9:
                self = .frame(.extended   (coding: .arithmetic, differential: false))
            case 0xca:
                self = .frame(.progressive(coding: .arithmetic, differential: false))
            case 0xcb:
                self = .frame(.lossless   (coding: .arithmetic, differential: false))
            
            case 0xcc:
                self = .arithmeticCodingCondition 
            
            case 0xcd:
                self = .frame(.extended   (coding: .arithmetic, differential: true))
            case 0xce:
                self = .frame(.progressive(coding: .arithmetic, differential: true))
            case 0xcf:
                self = .frame(.lossless   (coding: .arithmetic, differential: true))
            
            case 0xd0 ... 0xd7:
                self = .restart(.init(code & 0x0f))
                    
            case 0xd8:
                self = .start 
            case 0xd9:
                self = .end 
            case 0xda:
                self = .scan 
            case 0xdb:
                self = .quantization
            case 0xdc:
                self = .height 
            case 0xdd:
                self = .interval 
            case 0xde:
                self = .hierarchical
            case 0xdf:
                self = .expandReferenceComponents 
            
            case 0xe0 ... 0xef:
                self = .application(.init(code & 0x0f))
            case 0xf0 ... 0xfd:
                return nil 
            case 0xfe:
                self = .comment 
            
            default:
                return nil 
            }
        }
    }
}

/// protocol JPEG.AnyTable
///     Functionality common to all table types.
/// #  [See also](table-types-and-protocols)
/// ## (table-types-and-protocols)
public 
protocol _JPEGAnyTable 
{
    /// associatedtype JPEG.AnyTable.Delegate 
    /// required
    ///     A type representing a table instance while it is bound to a table slot.
    associatedtype Delegate 
    /// typealias JPEG.AnyTable.Slots = (Delegate?, Delegate?, Delegate?, Delegate?)
    ///     Four table slots. 
    /// 
    ///     JPEG images are always limited to four table slots for each table type. 
    ///     Some coding processes may limit further the number of available table slots.
    typealias Slots     = (Delegate?, Delegate?, Delegate?, Delegate?)
    /// typealias JPEG.AnyTable.Selector = Swift.WritableKeyPath<Slots, Delegate?>
    ///     A table selector.
    typealias Selector  = WritableKeyPath<Slots, Delegate?>
}
extension JPEG 
{
    /// enum JPEG.Header 
    ///     A namespace for header types.
    /// 
    ///     In general, the fields in these types can be assumed to be valid with 
    ///     respect to the other fields in the structure, but not necessarily with 
    ///     respect to the JPEG file as a whole.
    /// #  [Header types](header-types-and-namespace)
    /// ## (0:header-types-and-namespace)
    public 
    enum Header 
    {
        /// struct JPEG.Header.HeightRedefinition 
        ///     A height redefinition header. 
        /// 
        ///     This structure is the parsed form of a [`(JPEG.Marker).height`] 
        ///     marker segment. 
        /// ## (header-types-and-namespace)
        public 
        struct HeightRedefinition 
        {
            /// let JPEG.Header.HeightRedefinition.height   : Swift.Int 
            ///     The visible image height, in pixels. 
            /// 
            ///     This value is always positive.
            public 
            let height:Int 
            /// init JPEG.Header.HeightRedefinition.init(height:)
            ///     Creates a height redefinition header.
            /// - height    : Swift.Int 
            ///     The visible image height, in pixels. Passing a negative value 
            ///     will result in a precondition failure.
            public 
            init(height:Int)
            {
                precondition(height > 0, "height must be positive")
                self.height = height
            }
        }
        /// struct JPEG.Header.RestartInterval 
        ///     A restart interval definition header. 
        /// 
        ///     This structure is the parsed form of an [`(JPEG.Marker).interval`] 
        ///     marker segment. It can modify or clear the restart interval of an 
        ///     image.
        /// ## (header-types-and-namespace)
        public 
        struct RestartInterval 
        {
            /// let JPEG.Header.RestartInterval.interval    : Swift.Int?
            ///     The restart interval, in minimum-coded units, or `nil` if the 
            ///     header is meant to disable restart markers.
            /// 
            ///     This value is always positive or `nil`.
            public 
            let interval:Int? 
            /// init JPEG.Header.RestartInterval.init(interval:)
            ///     Creates a restart interval definition header. 
            /// - interval    : Swift.Int? 
            ///     The restart interval, in minimum-coded units, or `nil` to 
            ///     disable restart markers. Passing a negative or zero value 
            ///     will result in a precondition failure.
            public 
            init(interval:Int?)
            {
                precondition(interval.map{ $0 > 0 } ?? true, "interval must be positive or `nil`")
                self.interval = interval
            }
        }
        /// struct JPEG.Header.Frame 
        ///     A frame header.
        /// 
        ///     This structure is the parsed form of a [`(JPEG.Marker).frame(_:)`] 
        ///     marker segment. In non-hierarchical mode images, it defines global 
        ///     image parameters. It contains some of the information needed to 
        ///     fully-define an image [`(JPEG).Layout`].
        /// ## (1:header-types-and-namespace)
        public 
        struct Frame 
        {
            /// let JPEG.Header.Frame.process   : JPEG.Process 
            ///     The coding process used by the image. 
            public 
            let process:Process,
            /// let JPEG.Header.Frame.precision : Swift.Int 
            ///     The bit precision of this image.
                precision:Int, 
            /// let JPEG.Header.Frame.size      : (x:Swift.Int, y:Swift.Int)
            ///     The visible size of this image, in pixels. 
            ///     
            ///     The width is always positive. The height can be either positive 
            ///     or zero, if the height is to be defined later by a 
            ///     [`(JPEG.Header).HeightRedefinition`] header.
                size:(x:Int, y:Int)
            /// let JPEG.Header.Frame.components: [JPEG.Component.Key: JPEG.Component]
            ///     The components in this image.
            /// 
            ///     This dictionary will always have at least one element.
            public 
            let components:[Component.Key: Component]
        }
        /// struct JPEG.Header.Scan 
        ///     A scan header. 
        ///     
        ///     This structure is the parsed form of a [`(JPEG.Marker).scan`] 
        ///     marker segment. It defines scan-level image parameters. The library 
        ///     validates these structures against the global image parameters to 
        ///     create the [`JPEG.Scan`] structures elsewhere in the library API.
        /// # [Creating sequential scans](scan-header-creation-sequential)
        /// # [Creating progressive scans](scan-header-creation-progressive)
        /// ## (1:header-types-and-namespace)
        public 
        struct Scan
        {
            /// let JPEG.Header.Scan.band       : Swift.Range<Swift.Int>
            ///     The frequency band encoded by this scan. 
            /// 
            ///     This property specifies a range of zigzag-indexed frequency coefficients.
            ///     It is always within the interval of 0 to 64. 
            public 
            let band:Range<Int>, 
            /// let JPEG.Header.Scan.bits       : Swift.Range<Swift.Int> 
            ///     The bit range encoded by this scan. 
            /// 
            ///     This range is always non-negative.
                bits:Range<Int>, 
            /// let JPEG.Header.Scan.components : [JPEG.Scan.Component] 
            ///     The color components in this scan, in the order in which their 
            ///     data units are interleaved. 
            /// 
            ///     This array always contains at least one element.
                components:[JPEG.Scan.Component] 
        }
    }
    
    public 
    typealias AnyTable = _JPEGAnyTable 
    /// enum JPEG.Table 
    ///     A namespace for table types.
    /// #  [Table types](table-types-and-protocols)
    /// ## (0:table-types-and-protocols)
    public 
    enum Table 
    {
        /// typealias JPEG.Table.HuffmanDC = Huffman<JPEG.Bitstream.Symbol.DC>
        ///     A DC huffman table.
        /// #  [See also](huffman-table-types)
        /// ## (huffman-table-types)
        public 
        typealias HuffmanDC = Huffman<Bitstream.Symbol.DC>
        /// typealias JPEG.Table.HuffmanAC = Huffman<JPEG.Bitstream.Symbol.AC>
        ///     An AC huffman table.
        /// #  [See also](huffman-table-types)
        /// ## (huffman-table-types)
        public 
        typealias HuffmanAC = Huffman<Bitstream.Symbol.AC>
        /// struct JPEG.Table.Huffman<Symbol> 
        /// :   JPEG.AnyTable 
        /// where Symbol:JPEG.Bitstream.AnySymbol
        ///     A huffman table. 
        /// #  [See also](huffman-table-types)
        /// ## (1:table-types-and-protocols)
        public 
        struct Huffman<Symbol>:AnyTable where Symbol:Bitstream.AnySymbol
        {
            /// typealias JPEG.Table.Huffman.Delegate = Self 
            /// ?:  JPEG.AnyTable
            public 
            typealias Delegate = Self 
            
            let symbols:[[Symbol]]
            var target:Selector
            
            // these are size parameters generated by the structural validator. 
            // we store them here as proof of tree validity, so that the 
            // constructor for the huffman Decoder type can just read it from here 
            let size:(n:Int, z:Int)
        }
        /// struct JPEG.Table.Quantization 
        /// :   JPEG.AnyTable 
        ///     A quantization table.
        /// 
        ///     Quantization tables store 64 coefficient quanta. The quantum values 
        ///     can be accessed using either a zigzag index with the [`(Quantization).[z:]`] 
        ///     subscript, or grid indices with the [`(Quantization).[k:h:]`] subscript.
        /// ## (1:table-types-and-protocols)
        public 
        struct Quantization:AnyTable
        {
            /// struct JPEG.Table.Quantization.Key 
            /// :   Swift.Hashable 
            /// :   Swift.Comparable 
            /// :   Swift.ExpressibleByIntegerLiteral
            ///     A unique identifier assigned to each quantization table in an image.
            /// 
            ///     Quanta keys are numeric values ranging from [`Swift.Int`min`] 
            ///     to [`Swift.Int`max`]. In these reference pages, quanta keys 
            ///     in their numerical representation are written in **boldface**.
            /// #  [See also](key-types)
            /// ## (key-types)
            /// ## (0:image-quality)
            public 
            struct Key:Hashable, Comparable  
            {
                let value:Int 
                
                init<I>(_ value:I) where I:BinaryInteger 
                {
                    self.value = .init(value)
                }
                
                public static 
                func < (lhs:Self, rhs:Self) -> Bool 
                {
                    lhs.value < rhs.value
                }
            }
            
            /// typealias JPEG.Table.Quantization.Delegate = (q:Swift.Int, qi:JPEG.Table.Quantization.Key) 
            /// ?:  JPEG.AnyTable
            public 
            typealias Delegate = (q:Int, qi:Table.Quantization.Key)
            /// enum JPEG.Table.Quantization.Precision 
            ///     The integer width of the quantum values in this quantization table.
            public 
            enum Precision  
            {
                /// case JPEG.Table.Quantization.Precision.uint8 
                ///     The quantum values are encoded as 8-bit unsigned integers.
                case uint8
                /// case JPEG.Table.Quantization.Precision.uint16 
                ///     The quantum values are encoded as big endian 16-bit unsigned integers.
                case uint16
            }
            
            var storage:[UInt16], 
                target:Selector
            let precision:Precision
        }
    }
}

// layout 
extension JPEG 
{
    /// struct JPEG.Component 
    ///     A color channel in an image.
    /// ## (1:image-structure-and-decomposition)
    public 
    struct Component
    {
        /// let JPEG.Component.factor   : (x:Swift.Int, y:Swift.Int)
        ///     The horizontal and vertical sampling factors for this component.
        public 
        let factor:(x:Int, y:Int)
        /// let JPEG.Component.selector : JPEG.Table.Quantization.Selector 
        ///     The table selector of the quantization table associated with this component.
        public 
        let selector:Table.Quantization.Selector 
        /// struct JPEG.Component.Key 
        /// :   Swift.Hashable 
        /// :   Swift.Comparable 
        /// :   Swift.ExpressibleByIntegerLiteral
        ///     A unique identifier assigned to each color component in an image.
        /// 
        ///     Component keys are numeric values ranging from 0 to 255. In 
        ///     these reference pages, component keys in their numerical 
        ///     representation are written in **boldface**.
        /// #  [See also](key-types)
        /// ## (key-types)
        /// ## (2:image-structure-and-decomposition)
        public 
        struct Key:Hashable, Comparable 
        {
            let value:Int 
            
            init<I>(_ value:I) where I:BinaryInteger 
            {
                self.value = .init(value)
            }
            
            public static 
            func < (lhs:Self, rhs:Self) -> Bool 
            {
                lhs.value < rhs.value
            }
        }
    }
    
    /// struct JPEG.Scan 
    ///     An image scan. 
    /// 
    ///     Depending on the coding process used by the image, a scan may encode 
    ///     a select frequency band, range of bits, and subset of color components.
    /// 
    ///     This type contains essentially the same information as [`(JPEG).Header.Scan`], 
    ///     but has been validated against the global image parameters and has its 
    ///     component keys pre-resolved to integer indices.
    /// ## (4:image-structure-and-decomposition)
    public 
    struct Scan
    {
        /// struct JPEG.Scan.Component 
        ///     A descriptor for a component encoded within a scan. 
        /// ## (5:image-structure-and-decomposition)
        public 
        struct Component 
        {
            /// let JPEG.Scan.Component.ci          : JPEG.Component.Key 
            ///     The key specifying the image component referenced by this descriptor.
            public 
            let ci:JPEG.Component.Key
            /// let JPEG.Scan.Component.selector    : (dc:JPEG.Table.HuffmanDC.Selector, ac:JPEG.Table.HuffmanAC.Selector)
            ///     The table selectors for the huffman tables associated with this 
            ///     component in the context of this scan.
            ///
            ///     An image component may use different huffman 
            ///     tables in different scans. (In contrast, quantization 
            ///     table assignments are global to the file.) The DC table is 
            ///     used to encode or decode coefficient zero; the AC table is used 
            ///     for all other frequency coefficients. Depending on the band 
            ///     and bit range encoded by the image scan, one or both of the 
            ///     huffman table selectors may be unused, and therefore may not 
            ///     need to reference valid tables.
            public 
            let selector:(dc:Table.HuffmanDC.Selector, ac:Table.HuffmanAC.Selector)
        }
        
        /// let JPEG.Scan.band  : Swift.Range<Swift.Int> 
        ///     The frequency band encoded by this scan. 
        /// 
        ///     This property specifies a range of zigzag-indexed frequency coefficients.
        ///     It is always within the interval of 0 to 64. If the image coding 
        ///     process is not [`(Process).progressive(coding:differential:)`], 
        ///     this value will be `0 ..< 64`.
        public 
        let band:Range<Int>, 
        /// let JPEG.Scan.bits  : Swift.Range<Swift.Int> 
        ///     The bit range encoded by this scan. 
        /// 
        ///     This property specifies a range of bit indices, where bit zero is 
        ///     the least significant bit. The upper range bound is always either 
        ///     infinity ([`Swift.Int`max`]) or one greater than the lower bound.
        ///     If the image coding process is not [`(Process).progressive(coding:differential:)`], 
        ///     this value will be `0 ..< .max`.
            bits:Range<Int>, 
        /// let JPEG.Scan.components    : [(c:Swift.Int, component:Component)] 
        ///     The color components in this scan, in the order in which their 
        ///     data units are interleaved. 
        /// 
        ///     The component descriptors are paired with resolved component indices 
        ///     which are equivalent to the index of the image plane storing that 
        ///     color channel. This array will always have at least one element.
            components:[(c:Int, component:Component)] 
        // restrict access for synthesized init
        fileprivate 
        init(band:Range<Int>, bits:Range<Int>, components:[(c:Int, component:Component)]) 
        {
            self.band = band 
            self.bits = bits 
            self.components = components 
        }
    }
    
    /// struct JPEG.Layout<Format> 
    /// where Format:JPEG.Format 
    ///     A specification of the components, coding process, table assignments, 
    ///     and scan progression of an image.
    ///
    ///     This structure records both the *recognized components* and 
    ///     the *resident components* in an image. We draw this distinction because 
    ///     the [`(Layout).planes`] property is allowed to include definitions for components 
    ///     that are not part of [`(Layout).format``(Format).components`].
    ///     Such components will not recieve a plane in the [`(JPEG).Data`] types, 
    ///     but will be ignored by the scan decoder without errors. 
    ///
    ///     Non-recognized components can only occur in images decoded from JPEG files, 
    ///     and only when using a custom [`(JPEG).Format`] type, as the built-in 
    ///     [`JPEG.Common`] color format will never accept any component declaration 
    ///     in a frame header that it does not also recognize. When encoding images to JPEG 
    ///     files, all declared resident components must also be recognized components.
    /// # [Creating a layout](layout-creation)
    /// # [Image modes](layout-image-format)
    /// # [Component membership](layout-component-membership)
    /// # [Image structure](layout-image-structure)
    /// ## (0:image-structure-and-decomposition)
    public 
    struct Layout<Format> where Format:JPEG.Format 
    {
        /// let JPEG.Layout.format      : Format 
        ///     The color format of the image.
        /// ## (layout-image-format)
        public 
        let format:Format  
        /// let JPEG.Layout.process     : JPEG.Process 
        ///     The coding process used by the image.
        /// ## (layout-image-format)
        public 
        let process:Process
        
        /// let JPEG.Layout.residents   : [JPEG.Component.Key: Swift.Int]
        ///     The set of color components declared (or to-be-declared) in the 
        ///     image frame header.
        /// 
        ///     The dictionary values are indices to be used with the [`planes`] property 
        ///     on this type.
        /// # [See also](layout-component-membership)
        /// ## (layout-component-membership)
        public 
        let residents:[Component.Key: Int]
        /// var JPEG.Layout.recognized   : [JPEG.Component.Key] { get }
        ///     The set of color components in the color format of this image. 
        ///     This set is always a subset of the resident components in the image.
        /// # [See also](layout-component-membership)
        /// ## (layout-component-membership)
        public 
        var recognized:[Component.Key] 
        {
            self.format.components 
        }
        /// var JPEG.Layout.planes      : [(component:JPEG.Component, qi:JPEG.Table.Quantization.Key)] { get }
        ///     The descriptor array for the planes in the image. 
        ///
        ///     Each descriptor consists of a [`JPEG.Component`] instance and a 
        ///     quantization table key. On layout initialization, the library will 
        ///     automatically assign table keys to table selectors.
        ///
        ///     The ordering of the first *k* array elements follows the order that 
        ///     the component keys appear in the [`recognized`] property, where 
        ///     *k* is the number of components in the image. Any 
        ///     non-recognized resident components will occur at the end of this 
        ///     array, can can be indexed using the values of the [`residents`] 
        ///     dictionary.
        /// ## (layout-image-structure)
        public internal(set)
        var planes:[(component:Component, qi:Table.Quantization.Key)]
        /// var JPEG.Layout.definitions : [(quanta:[JPEG.Table.Quantization.Key], scans:[JPEG.Scan])] { get }
        ///     The sequence of scan and table definitions in the image file.
        ///
        ///     The definitions in this property are given as alternating runs 
        ///     of quantization tables and image scans. (Image layouts do not specify 
        ///     huffman table definitions, as the library encodes them on a per-scan 
        ///     basis.)
        /// ## (layout-image-structure)
        public private(set)
        var definitions:[(quanta:[Table.Quantization.Key], scans:[Scan])]
    }
}
extension JPEG.Layout 
{ 
    private 
    init(format:Format, 
        process:JPEG.Process, 
        components combined:
        [
            JPEG.Component.Key: (component:JPEG.Component, qi:JPEG.Table.Quantization.Key)
        ])
    {
        self.format     = format 
        self.process    = process 
        
        var planes:[(component:JPEG.Component, qi:JPEG.Table.Quantization.Key)] = 
            format.components.map 
        {
            guard let value:(component:JPEG.Component, qi:JPEG.Table.Quantization.Key) = 
                combined[$0]
            else 
            {
                preconditionFailure("missing definition for component \($0) in format '\(format)'")
            }
            
            return value 
        }
        
        var residents:[JPEG.Component.Key: Int] = 
            .init(uniqueKeysWithValues: zip(format.components, planes.indices))
        for (ci, value):
        (
            JPEG.Component.Key, (component:JPEG.Component, qi:JPEG.Table.Quantization.Key)
        ) in combined 
        {
            guard residents[ci] == nil 
            else 
            {
                continue 
            }
            
            residents[ci] = planes.endIndex
            planes.append(value)
        }
        
        self.residents   = residents
        self.planes      = planes
        self.definitions = []
    }
    
    init(format:Format, 
        process:JPEG.Process, 
        components:[JPEG.Component.Key: JPEG.Component])
    {
        self.init(format: format, process: process, components: components.mapValues 
        {
            ($0, -1)
        })
    }
    /// init JPEG.Layout.init(format:process:components:scans:)
    ///     Creates an image layout given image parameters and a scan decomposition.
    /// 
    ///     If the image coding process is a sequential process, the given scan headers 
    ///     should be constructed using the [`(JPEG.Header.Scan).sequential(...:)`] 
    ///     constructor. If the coding process is progressive, the scan headers 
    ///     should be constructed with the [`(JPEG.Header.Scan).progressive(...:bits:)`], 
    ///     [`(JPEG.Header.Scan).progressive(...:bit:)`], 
    ///     [`(JPEG.Header.Scan).progressive(_:band:bits:)`], or
    ///     [`(JPEG.Header.Scan).progressive(_:band:bit:)`] constructors.
    /// 
    ///     This initializer will validate the scan progression and attempt to 
    ///     generate a sequence of table definitions to implement the 
    ///     quantization table relationships specified by the `components` parameter. 
    ///     It will suffer a precondition failure if the scan progression is invalid, or 
    ///     if it is impossible to implement the specified table relationships with 
    ///     the number of table selectors available for the given coding process.
    /// 
    ///     This initializer will normalize all scan headers passed to the `scans`
    ///     argument. It will strip non-recognized components from the headers, 
    ///     and rearrange their component descriptors in ascending numeric order.
    ///     It will also validate the scan headers against the `process` argument 
    ///     with [`(Header.Scan).validate(process:band:bits:components:)`].
    ///     Passing invalid scan headers will result in a precondition failure.
    ///     See the [advanced encoding](https://github.com/kelvin13/jpeg/tree/master/examples#advanced-encoding)
    ///     library tutorial to learn more about the validation rules.
    /// - format    : Format
    ///     The color format of the image.
    /// - process   : JPEG.Process 
    ///     The coding process used by the image.
    /// - components: [JPEG.Component.Key: (factor:(x:Swift.Int, y:Swift.Int), qi:JPEG.Table.Quantization.Key)]
    ///     The sampling factors and quantization table key for each component in the image.
    ///     This dictionary must contain an entry for every component in the 
    ///     given color `format`.
    /// - scans     : [JPEG.Header.Scan]
    ///     The scan progression of the image. 
    /// ## (layout-creation)
    public 
    init(format:Format, 
        process:JPEG.Process, 
        components:[JPEG.Component.Key: 
            (factor:(x:Int, y:Int), qi:JPEG.Table.Quantization.Key)], 
        scans:[JPEG.Header.Scan])
    {
        // to assign quantization table selectors, we first need to determine 
        // the first and last scans for each component, which then tells us 
        // how long each quantization table needs to be activated
        // q -> lifetime
        var lifetimes:[JPEG.Table.Quantization.Key: (start:Int, end:Int)] = [:]
        for (i, descriptor):(Int, JPEG.Header.Scan) in zip(scans.indices, scans) 
        {
            for component:JPEG.Scan.Component in descriptor.components 
            {
                guard let qi:JPEG.Table.Quantization.Key = components[component.ci]?.qi 
                else 
                {
                    // this scan is referencing a component that’s not in the 
                    // `components` dictionary. we strip out unrecognized 
                    // scan components later on anyway, so we ignore it here 
                    continue 
                }
                
                lifetimes[qi, default: (i, i)].end = i + 1
            }
        }
        
        var slots:[(selector:JPEG.Table.Quantization.Selector, time:Int)] 
        switch process 
        {
        case .baseline:
            slots = [(\.0, 0), (\.1, 0)]
        default:
            slots = [(\.0, 0), (\.1, 0), (\.2, 0), (\.3, 0)]
        }
        
        // q -> selector 
        let mappings:[JPEG.Table.Quantization.Key: JPEG.Table.Quantization.Selector] = 
            lifetimes.mapValues 
        {
            (lifetime:(start:Int, end:Int)) in 
            
            guard let free:Int = 
                slots.firstIndex(where: { lifetime.start >= $0.time })
            else 
            {
                fatalError("not enough free quantization table slots")
            }
            
            slots[free].time = lifetime.end 
            return slots[free].selector
        }
        
        self.init(format: format, process: process, components: components.mapValues 
        {
            // if `q` is not in the mappings dictionary, that means that there 
            // were no scans, even ones with unrecognized components, that 
            // referenced it. (this is a problem, because all `q` values are associated 
            // with at least one component, and every component needs to be covered 
            // by the scan progression). for now, since it has a lifetime of 0, it does 
            // not matter which selector we assign to it
            (.init(factor: $0.factor, selector: mappings[$0.qi] ?? \.0), $0.qi)
        })
        
        // store scan information 
        let intrusions:[(start:Int, quanta:[JPEG.Table.Quantization.Key])] = 
            Dictionary.init(grouping: lifetimes.map{ (start: $0.value.start, quanta: $0.key) }) 
        {
            $0.start 
        }
        .map
        {
            (start: $0.key, quanta: $0.value.map(\.quanta))
        }
        .sorted 
        {
            $0.start < $1.start
        }
        
        var progression:Progression             = .init(format.components)
        let recognized:Set<JPEG.Component.Key>  = .init(format.components)
        
        self.definitions = zip(intrusions.indices, intrusions).map 
        {
            let (g, (start, quanta)):(Int, (Int, [JPEG.Table.Quantization.Key])) = $0
            
            let end:Int = intrusions.dropFirst(g + 1).first?.start ?? scans.endIndex
            let group:[JPEG.Scan] = scans[start ..< end].map 
            {
                do 
                {
                    try progression.update($0)
                    
                    // strip non-recognized components from the scan header. we 
                    // also have to sort them so that their ordering matches the 
                    // order in the generated frame header later on. this will 
                    // also validate process-dependent constraints.
                    return try self.push(scan: try .validate(process: process, 
                        band:       $0.band, 
                        bits:       $0.bits, 
                        components: $0.components.filter
                        { 
                            recognized.contains($0.ci) 
                        }
                        .sorted 
                        {
                            $0.ci < $1.ci
                        }))
                }
                catch let error as JPEG.ParsingError // validation error 
                {
                    preconditionFailure(error.message)
                }
                catch let error as JPEG.DecodingError // invalid progression 
                {
                    preconditionFailure(error.message)
                }
                catch 
                {
                    fatalError("unreachable")
                }
            }
            return (quanta, group)
        }
    }
    
    mutating 
    func push(scan header:JPEG.Header.Scan) throws -> JPEG.Scan
    {
        var volume:Int = 0 
        let components:[(c:Int, component:JPEG.Scan.Component)] = 
            try header.components.map 
        {
            // validate sampling factor sum, and component residency
            guard let c:Int = self.residents[$0.ci]
            else 
            {
                throw JPEG.DecodingError.undefinedScanComponentReference(
                    $0.ci, .init(residents.keys))
            }
            
            let (x, y):(Int, Int) = self.planes[c].component.factor
            volume += x * y
            
            return (c, $0)
        }
        
        guard 0 ... 10 ~= volume || components.count == 1
        else 
        {
            throw JPEG.DecodingError.invalidScanSamplingVolume(volume)
        }
        
        let passed:JPEG.Scan = 
            .init(band: header.band, bits: header.bits, components: components)
        
        // the ordering in the stored scan may be different since it has to match 
        // the ordering in the frame header
        let stored:JPEG.Scan = 
            .init(band: header.band, bits: header.bits, components: components.sorted 
        {
            $0.component.ci < $1.component.ci
        })
        
        if self.definitions.endIndex - 1 >= self.definitions.startIndex 
        {
            self.definitions[self.definitions.endIndex - 1].scans.append(stored)
        }
        else 
        {
            // this shouldn’t happen, and will trigger an error later on when 
            // the dequantize function runs 
            self.definitions.append(([], [stored]))
        }
        return passed
    }
    mutating 
    func push(qi:JPEG.Table.Quantization.Key) 
    {
        if self.definitions.last?.scans.isEmpty ?? false 
        {
            self.definitions[self.definitions.endIndex - 1].quanta.append(qi)
        }
        else 
        {
            self.definitions.append(([qi], []))
        }
    }
    
    func index(ci:JPEG.Component.Key) -> Int? 
    {
        guard let c:Int = self.residents[ci], self.recognized.indices ~= c
        else 
        {
            return nil 
        }
        return c
    }
}
// high-level state handling
extension JPEG.Layout 
{
    struct Progression 
    {
        private 
        var approximations:[JPEG.Component.Key: [Int]]
    }
}
extension JPEG.Layout.Progression
{
    init<S>(_ components:S) where S:Sequence, S.Element == JPEG.Component.Key 
    {
        self.approximations = .init(uniqueKeysWithValues: components.map
        { 
            ($0, .init(repeating: .max, count: 64)) 
        })
    }
    
    mutating 
    func update(_ scan:JPEG.Header.Scan) throws 
    {
        for component:JPEG.Scan.Component in scan.components 
        {
            guard var approximation:[Int] = self.approximations[component.ci]
            else 
            {
                continue 
            }
            
            // preempt an array copy 
            self.approximations[component.ci] = nil 
            
            // first scan must be a dc scan 
            guard approximation[0] < .max || scan.band.lowerBound == 0 
            else 
            {
                throw JPEG.DecodingError.invalidSpectralSelectionProgression(
                    scan.band, component.ci)
            }
            // we need to check this because even though the scan header 
            // parser enforces bit-range constraints, it doesn’t enforce ordering 
            for (z, a):(Int, Int) in zip(scan.band, approximation[scan.band])
            {
                guard scan.bits.upperBound == a, scan.bits.lowerBound < a 
                else 
                {
                    throw JPEG.DecodingError.invalidSuccessiveApproximationProgression(
                        scan.bits, a, z: z, component.ci)
                }
                
                approximation[z] = scan.bits.lowerBound
            }
            
            self.approximations[component.ci] = approximation
        }
    }
}
// this is an extremely boilerplatey api but i consider it necessary to avoid 
// having to provide huge amounts of (visually noisy) extraneous information 
// in the constructor (ie. huffman table selectors for refining dc scans)
extension JPEG.Header.Scan 
{
    // these constructors bypass the validator. this is fine because the validator 
    // runs when the scan headers get compiled into the layout struct.
    // it is possible for users to construct a process-inconsistent scan header 
    // using these apis, but this is also possible with the validating constructor, 
    // by simply passing a fake value for `process`
    
    /// static func JPEG.Header.Scan.sequential(_:)
    ///     Creates a sequential scan descriptor.
    /// 
    ///     This constructor bypasses normal scan header validation checks. It is 
    ///     otherwise equivalent to calling [`(Header.Scan).validate(process:band:bits:components:)`]
    ///     with the `band` argument set to `0 ..< 64` and the `bits` argument set 
    ///     to `0 ..< .max`.
    /// - components:[(ci:JPEG.Component.Key, dc:JPEG.Table.HuffmanDC.Selector, ac:JPEG.Table.HuffmanAC.Selector)]
    ///     The components encoded by this scan, and associated DC and AC huffman 
    ///     table selectors. For each type of huffman table, components with the 
    ///     same table selector will share the same huffman table. Huffman tables 
    ///     will not persist in between different scans. Passing an empty array 
    ///     will result in a precondition failure.
    /// - ->        :Self 
    ///     An unvalidated sequential scan header.
    /// # [See also](scan-header-creation-sequential)
    /// ## (scan-header-creation-sequential)
    public static 
    func sequential(_ components:
        [(
            ci:JPEG.Component.Key, 
            dc:JPEG.Table.HuffmanDC.Selector, 
            ac:JPEG.Table.HuffmanAC.Selector
        )]) -> Self 
    {
        precondition(!components.isEmpty, "components array cannot be empty")
        return .init(band: 0 ..< 64, bits: 0 ..< .max, 
            components: components.map{ .init(ci: $0.ci, selector: ($0.dc, $0.ac))})
    }
    /// static func JPEG.Header.Scan.sequential(...:)
    ///     Creates a sequential scan descriptor. 
    ///     
    ///     This function is variadic sugar for [`(Scan).sequential(_:)`].
    /// - components:(ci:JPEG.Component.Key, dc:JPEG.Table.HuffmanDC.Selector, ac:JPEG.Table.HuffmanAC.Selector)
    /// - ->        :Self 
    /// # [See also](scan-header-creation-sequential)
    /// ## (scan-header-creation-sequential)
    public static 
    func sequential(_ components:
        (
            ci:JPEG.Component.Key, 
            dc:JPEG.Table.HuffmanDC.Selector, 
            ac:JPEG.Table.HuffmanAC.Selector
        )...) -> Self 
    {
        .sequential(components)
    }
    /// static func JPEG.Header.Scan.progressive(_:bits:)
    ///     Creates a progressive initial DC scan descriptor.
    /// 
    ///     This constructor bypasses normal scan header validation checks. It is 
    ///     otherwise equivalent to calling [`(Header.Scan).validate(process:band:bits:components:)`]
    ///     with the `band` argument set to `0 ..< 1`.
    ///
    ///     Initial DC scans only use DC huffman tables, so no AC table selectors 
    ///     need to be specified.
    /// - components:[(ci:JPEG.Component.Key, dc:JPEG.Table.HuffmanDC.Selector)]
    ///     The components encoded by this scan, and associated DC huffman 
    ///     table selectors. Components with the same table selector will share
    ///     the same huffman table. Huffman tables will not persist in between 
    ///     different scans. Passing an empty array will result in a precondition failure.
    /// - bits      :Swift.PartialRangeFrom<Swift.Int>
    ///     The range of DC bits encoded by this scan. Setting this argument to 
    ///     `0...` disables spectral selection. Passing a range with a negative 
    ///     lower bound will result in a precondition failure.
    /// - ->        :Self 
    ///     An unvalidated initial DC scan header.
    /// # [See also](scan-header-creation-progressive)
    /// ## (scan-header-creation-progressive)
    public static 
    func progressive(_ 
        components:[(ci:JPEG.Component.Key, dc:JPEG.Table.HuffmanDC.Selector)], 
        bits:PartialRangeFrom<Int>) -> Self 
    {
        precondition(!components.isEmpty,  "components array cannot be empty")
        precondition(bits.lowerBound >= 0, "lower bound of bit range cannot be negative")
        return .init(band: 0 ..< 1, bits: bits.lowerBound ..< .max, 
            components: components.map{ .init(ci: $0.ci, selector: ($0.dc, \.0))})
    }
    /// static func JPEG.Header.Scan.progressive(...:bits:)
    ///     Creates a progressive initial DC scan descriptor.
    ///     
    ///     This function is variadic sugar for [`(Scan).progressive(_:bits:)`].
    /// - components:(ci:JPEG.Component.Key, dc:JPEG.Table.HuffmanDC.Selector)
    /// - bits      :Swift.PartialRangeFrom<Swift.Int>
    /// - ->        :Self 
    /// # [See also](scan-header-creation-progressive)
    /// ## (scan-header-creation-progressive)
    public static 
    func progressive(_ 
        components:(ci:JPEG.Component.Key, dc:JPEG.Table.HuffmanDC.Selector)..., 
        bits:PartialRangeFrom<Int>) -> Self 
    {
        .progressive(components, bits: bits)
    }
    /// static func JPEG.Header.Scan.progressive(_:bit:)
    ///     Creates a progressive refining DC scan descriptor.
    /// 
    ///     This constructor bypasses normal scan header validation checks. It is 
    ///     otherwise equivalent to calling [`(Header.Scan).validate(process:band:bits:components:)`]
    ///     with the `band` argument set to `0 ..< 1` and the `bits` argument set 
    ///     to `bit ..< bit + 1`.
    /// 
    ///     Refining DC scans do not use entropy-coding, so no huffman table selectors 
    ///     need to be specified.
    /// - components:[JPEG.Component.Key]
    ///     The components encoded by this scan. Passing an empty array will 
    ///     result in a precondition failure.
    /// - bit       :Swift.Int
    ///     The index of the bit refined by this scan. Passing a negative index
    ///     will result in a precondition failure.
    /// - ->        :Self 
    ///     An unvalidated refining DC scan header.
    /// # [See also](scan-header-creation-progressive)
    /// ## (scan-header-creation-progressive)
    public static 
    func progressive(_ 
        components:[JPEG.Component.Key], 
        bit:Int) -> Self 
    {
        precondition(!components.isEmpty, "components array cannot be empty")
        precondition(bit >= 0,            "bit index cannot be negative")
        return .init(band: 0 ..< 1, bits: bit ..< bit + 1, 
            components: components.map{ .init(ci: $0, selector: (\.0, \.0))})
    }
    /// static func JPEG.Header.Scan.progressive(...:bit:)
    ///     Creates a progressive refining DC scan descriptor.
    ///     
    ///     This function is variadic sugar for [`(Scan).progressive(_:bit:)`].
    /// - components:JPEG.Component.Key
    /// - bit       :Swift.Int
    /// - ->        :Self 
    /// # [See also](scan-header-creation-progressive)
    /// ## (scan-header-creation-progressive)
    public static 
    func progressive(_ 
        components:JPEG.Component.Key..., 
        bit:Int) -> Self 
    {
        .progressive(components, bit: bit)
    }
    /// static func JPEG.Header.Scan.progressive(_:band:bits:)
    ///     Creates a progressive initial AC scan descriptor.
    /// 
    ///     This constructor bypasses normal scan header validation checks. It is 
    ///     otherwise equivalent to calling [`(Header.Scan).validate(process:band:bits:components:)`].
    ///
    ///     AC scans only use AC huffman tables, so no DC table selectors 
    ///     need to be specified.
    /// - component :(ci:JPEG.Component.Key, ac:JPEG.Table.HuffmanAC.Selector)
    ///     The component encoded by this scan, and its associated AC huffman 
    ///     table selector. Huffman tables will not persist in between 
    ///     different scans.
    /// - band      :Swift.Range<Swift.Int>
    ///     The frequency band encoded by this scan, in zigzag indices. This range 
    ///     will be clamped to the interval `1 ..< 64`.
    /// - bits      :Swift.PartialRangeFrom<Swift.Int>
    ///     The range of AC bits encoded by this scan. Setting this argument to 
    ///     `0...` disables spectral selection. Passing a range with a negative 
    ///     lower bound will result in a precondition failure.
    /// - ->        :Self 
    ///     An unvalidated initial AC scan header.
    /// # [See also](scan-header-creation-progressive)
    /// ## (scan-header-creation-progressive)
    public static 
    func progressive(_ 
        component:(ci:JPEG.Component.Key, ac:JPEG.Table.HuffmanAC.Selector), 
        band:Range<Int>, bits:PartialRangeFrom<Int>) -> Self 
    {
        precondition(bits.lowerBound >= 0, "lower bound of bit range cannot be negative")
        return .init(band: band.clamped(to: 1 ..< 64), bits: bits.lowerBound ..< .max, 
            components: [.init(ci: component.ci, selector: (\.0, component.ac))])
    }
    /// static func JPEG.Header.Scan.progressive(_:band:bit:)
    ///     Creates a progressive refining AC scan descriptor.
    /// 
    ///     This constructor bypasses normal scan header validation checks. It is 
    ///     otherwise equivalent to calling [`(Header.Scan).validate(process:band:bits:components:)`] 
    ///     with the `bits` argument set to `bit ..< bit + 1`.
    ///
    ///     AC scans only use AC huffman tables, so no DC table selectors 
    ///     need to be specified.
    /// - component :(ci:JPEG.Component.Key, ac:JPEG.Table.HuffmanAC.Selector)
    ///     The component encoded by this scan, and its associated AC huffman 
    ///     table selector. Huffman tables will not persist in between 
    ///     different scans.
    /// - band      :Swift.Range<Swift.Int>
    ///     The frequency band encoded by this scan, in zigzag indices. This range 
    ///     will be clamped to the interval `1 ..< 64`.
    /// - bit       :Swift.Int
    ///     The index of the bit refined by this scan. Passing a negative index
    ///     will result in a precondition failure.
    /// - ->        :Self 
    ///     An unvalidated refining AC scan header.
    /// # [See also](scan-header-creation-progressive)
    /// ## (scan-header-creation-progressive)
    public static 
    func progressive(_ 
        component:(ci:JPEG.Component.Key, ac:JPEG.Table.HuffmanAC.Selector), 
        band:Range<Int>, bit:Int) -> Self 
    {
        precondition(bit >= 0, "bit index cannot be negative")
        return .init(band: band.clamped(to: 1 ..< 64), bits: bit ..< bit + 1, 
            components: [.init(ci: component.ci, selector: (\.0, component.ac))])
    }
}

// bitstream 
extension JPEG 
{
    /// struct JPEG.Bitstream 
    /// :   Swift.ExpressibleByArrayLiteral
    ///     A padded bitstream.
    /// #  [Symbol types](entropy-coding-symbols)
    /// ## (0:entropy-coding)
    public 
    struct Bitstream 
    {
        private 
        var atoms:[UInt16]
        private(set)
        var count:Int
    }
}
extension JPEG.Bitstream 
{
    init(_ data:[UInt8])
    {
        // convert byte array to big-endian UInt16 array 
        var atoms:[UInt16] = stride(from: 0, to: data.count - 1, by: 2).map
        {
            UInt16.init(data[$0]) << 8 | .init(data[$0 | 1])
        }
        // if odd number of bytes, pad out last atom
        if data.count & 1 != 0
        {
            atoms.append(.init(data[data.count - 1]) << 8 | 0x00ff)
        }
        
        // insert a `0xffff` atom to serve as a barrier
        atoms.append(0xffff)
        
        self.atoms = atoms
        self.count = 8 * data.count
    }
    
    // single bit (0 or 1)
    subscript<I>(i:Int, as _:I.Type) -> I where I:BinaryInteger
    {
        let a:Int           = i >> 4, 
            b:Int           = i & 0x0f
        let shift:Int       = UInt16.bitWidth &- 1 &- b
        let single:UInt16   = (self.atoms[a] &>> shift) & 1
        return .init(single)
    }
    
    subscript(i:Int, count c:Int) -> UInt16
    {
        let a:Int = i >> 4, 
            b:Int = i & 0x0f
        // w.0             w.1
        //        |<-- c = 16 -->|
        //  [ : : :x:x:x:x:x|x:x:x: : : : : ]
        //        ^
        //      b = 6
        //  [x:x:x:x:x|x:x:x]
        // must use >> and not &>> to correctly handle shift of 16
        let front:UInt16 = self.atoms[a] &<< b | self.atoms[a &+ 1] >> (UInt16.bitWidth &- b)
        return front &>> (UInt16.bitWidth - c)
    }
    
    // integer is 1 or 0 (ignoring higher bits), we avoid using `Bool` here 
    // since this is not semantically a logic parameter
    mutating 
    func append<I>(bit:I) where I:BinaryInteger 
    {
        let a:Int           = self.count >> 4, 
            b:Int           = self.count & 0x0f
        
        guard a < self.atoms.count
        else 
        {
            self.atoms.append(0xffff)
            self.append(bit: bit)
            return 
        }
        
        let shift:Int       = UInt16.bitWidth &- 1 &- b
        let inverted:UInt16 = ~(.init(~bit & 1) &<< shift)
        // all bits at and beyond bit index `self.count` should be `1`-bits 
        self.atoms[a]      &= inverted 
        self.count         += 1
    }
    // relevant bits in the least significant positions 
    mutating 
    func append(_ bits:UInt16, count:Int) 
    {
        let a:Int           = self.count >> 4, 
            b:Int           = self.count & 0x0f
        
        guard a + 1 < self.atoms.count
        else 
        {
            self.atoms.append(0xffff)
            self.append(bits, count: count)
            return 
        }
        
        // w.0             w.1
        //  [x:x:x:x:x|x:x:x]
        //      b = 6
        //        v
        //  [ : : :x:x:x:x:x|x:x:x: : : : : ]
        //        |<-- c = 16 -->|

        // invert bits because we use `1`-bits as the “background”, and shift 
        // operator will only extend with `0`-bits
        // must use >> and << and not &>> and &<< to correctly handle shift of 16
        let trimmed:UInt16 = bits &<< (UInt16.bitWidth &- count) | .max >> count
        let inverted:(UInt16, UInt16) = 
        (
            ~trimmed &>>                     b, 
            ~trimmed  << (UInt16.bitWidth &- b)
        )
        
        self.atoms[a    ] &= ~inverted.0
        self.atoms[a + 1] &= ~inverted.1
        self.count        += count 
    }
    
    func bytes(escaping escaped:UInt8, with sequence:(UInt8, UInt8)) -> [UInt8]
    {
        let unescaped:[UInt8] = .init(unsafeUninitializedCapacity: 2 * self.atoms.count)
        {
            for (i, atom):(Int, UInt16) in self.atoms.enumerated() 
            {
                $0[i << 1    ] = .init(atom >> 8)
                $0[i << 1 | 1] = .init(atom & 0xff)
            }
            
            $1 = 2 * self.atoms.count
        }
        // figure out which of the bytes are actually part of the bitstream 
        let count:Int = self.count >> 3 + (self.count & 0x07 != 0 ? 1 : 0)
        var bytes:[UInt8] = []
            bytes.reserveCapacity(count)
        for byte:UInt8 in unescaped.prefix(count) 
        {
            if byte == escaped 
            {
                bytes.append(sequence.0)
                bytes.append(sequence.1)
            }
            else 
            {
                bytes.append(byte)
            }
        }
        
        return bytes
    }
}
extension JPEG.Bitstream:ExpressibleByArrayLiteral 
{
    /// init JPEG.Bitstream.init(arrayLiteral...:)
    /// ?:  Swift.ExpressibleByArrayLiteral 
    ///     Creates a bitstream from the given array literal.
    ///
    ///     This type stores the bitstream in 16-bit atoms. If the array literal 
    ///     does not contain an even number of bytes, the last atom is padded 
    ///     with 1-bits.
    /// - arrayLiteral  : Swift.UInt8
    ///     The raw bytes making up the bitstream. The more significant bits in 
    ///     each byte come first in the bitstream. If the bitstream does not 
    ///     correspond to a whole number of bytes, the least significant bits 
    ///     in the last byte should be padded with 1-bits.
    public 
    init(arrayLiteral:UInt8...) 
    {
        self.init(arrayLiteral)
    }
}
