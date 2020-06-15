/* This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// protocol JPEG.Error
/// :   Swift.Error 
///     Functionality common to all library error types.
/// #  [See also](error-types)
/// ## (error-handling)
public 
protocol _JPEGError:Swift.Error 
{
    /// static var JPEG.Error.namespace : Swift.String { get }
    /// required 
    ///     The human-readable namespace for errors of this type.
    static 
    var namespace:String 
    {
        get 
    }
    /// var JPEG.Error.message          : Swift.String { get }
    /// required 
    ///     A basic description of this error instance.
    var message:String 
    {
        get 
    }
    /// var JPEG.Error.details          : Swift.String? { get }
    /// required 
    ///     A detailed description of this error instance, if available.
    var details:String? 
    {
        get 
    }
}
extension JPEG 
{
    public 
    typealias Error = _JPEGError
    /// enum JPEG.LexingError
    /// :   JPEG.Error 
    ///     A lexing error.
    /// #  [See also](error-types)
    /// ## (error-types)
    /// ## (error-handling)
    public 
    enum LexingError:JPEG.Error
    {
        /// case JPEG.LexingError.truncatedMarkerSegmentType 
        ///     The lexer encountered end-of-stream while lexing a marker 
        ///     segment type indicator.
        case truncatedMarkerSegmentType
        /// case JPEG.LexingError.truncatedMarkerSegmentHeader
        ///     The lexer encountered end-of-stream while lexing a marker 
        ///     segment length field.
        case truncatedMarkerSegmentHeader
        /// case JPEG.LexingError.truncatedMarkerSegmentBody(expected:)
        ///     The lexer encountered end-of-stream while lexing a marker 
        ///     segment body.
        /// - expected:Swift.Int 
        ///     The number of bytes the lexer was expecting to read.
        case truncatedMarkerSegmentBody(expected:Int)
        /// case JPEG.LexingError.truncatedEntropyCodedSegment
        ///     The lexer encountered end-of-stream while lexing an entropy-coded 
        ///     segment, usually because it was expecting a subsequent marker segment.
        case truncatedEntropyCodedSegment
        /// case JPEG.LexingError.invalidMarkerSegmentLength(_:)
        ///     The lexer read a marker segment length field, but the value did 
        ///     not make sense.
        /// - _ :Swift.Int 
        ///     The value that the lexer read from the marker segment length field.
        case invalidMarkerSegmentLength(Int)
        /// case JPEG.LexingError.invalidMarkerSegmentPrefix(_:)
        ///     The lexer encountered a prefixed entropy-coded segment where it 
        ///     was expecting none.
        /// - _ :Swift.UInt8 
        ///     The first invalid byte encountered by the lexer.
        case invalidMarkerSegmentPrefix(UInt8)
        /// case JPEG.LexingError.invalidMarkerSegmentType(_:)
        ///     The lexer encountered a marker segment with a reserved type indicator 
        ///     code.
        /// - _ :Swift.UInt8 
        ///     The invalid type indicator code encountered by the lexer.
        case invalidMarkerSegmentType(UInt8)
        /// static var JPEG.LexingError.namespace : Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns the string `"lexing error"`.
        public static 
        var namespace:String 
        {
            "lexing error" 
        }
        /// var JPEG.LexingError.message          : Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns a basic description of this lexing error.
        public 
        var message:String 
        {
            switch self 
            {
            case .truncatedMarkerSegmentType:
                return "truncated marker segment type"
            case .truncatedMarkerSegmentHeader:
                return "truncated marker segment header"
            case .truncatedMarkerSegmentBody:
                return "truncated marker segment body"
            case .truncatedEntropyCodedSegment:
                return "truncated entropy coded segment"
            
            case .invalidMarkerSegmentLength:
                return "invalid value in marker segment length field"
            case .invalidMarkerSegmentPrefix:
                return "invalid marker segment prefix"
            case .invalidMarkerSegmentType:
                return "invalid marker segment type code"
            } 
        }
        /// var JPEG.LexingError.details          : Swift.String? { get }
        /// ?:  JPEG.Error 
        ///     Returns a detailed description of this lexing error, if available.
        public 
        var details:String? 
        {
            switch self 
            {
            case .truncatedMarkerSegmentType:
                return "unexpected end-of-stream while lexing marker segment type field"
            case .truncatedMarkerSegmentHeader:
                return "unexpected end-of-stream while lexing marker segment length field"
            case .truncatedMarkerSegmentBody(expected: let expected):
                return "unexpected end-of-stream while lexing marker segment body (expected \(expected) bytes)"
            case .truncatedEntropyCodedSegment:
                return "unexpected end-of-stream while lexing entropy coded segment"
            
            case .invalidMarkerSegmentLength(let length):
                return "value of marker segment length field (\(length)) cannot be less than 2"
            case .invalidMarkerSegmentPrefix(let byte):
                return "padding byte (0x\(String.init(byte, radix: 16))) preceeding marker segment must be 0xff"
            case .invalidMarkerSegmentType(let code):
                return "marker segment type code (0x\(String.init(code, radix: 16))) is a reserved marker code"
            } 
        }
    }
    /// enum JPEG.ParsingError
    /// :   JPEG.Error 
    ///     A parsing error.
    /// #  [See also](error-types)
    /// ## (error-types)
    /// ## (error-handling)
    public 
    enum ParsingError:JPEG.Error 
    {
        /// case JPEG.ParsingError.truncatedMarkerSegmentBody(_:_:expected:) 
        ///     A marker segment contained less than the expected amount of data.
        /// - _         : JPEG.Marker 
        ///     The marker segment type.
        /// - _         : Swift.Int 
        ///     The size of the marker segment, in bytes.
        /// - expected  : Swift.ClosedRange<Swift.Int> 
        ///     The range of marker segment sizes that was expected, in bytes.
        case truncatedMarkerSegmentBody(Marker, Int, expected:ClosedRange<Int>)
        /// case JPEG.ParsingError.extraneousMarkerSegmentData(_:_:expected:) 
        ///     A marker segment contained more than the expected amount of data.
        /// - _         : JPEG.Marker 
        ///     The marker segment type.
        /// - _         : Swift.Int 
        ///     The size of the marker segment, in bytes.
        /// - expected  : Swift.Int
        ///     The amount of data that was expected, in bytes.
        case extraneousMarkerSegmentData(Marker, Int, expected:Int)
        /// case JPEG.ParsingError.invalidJFIFSignature(_:)
        ///     A JFIF segment had an invalid signature.
        /// - _ : [Swift.UInt8] 
        ///     The signature read from the segment.
        case invalidJFIFSignature([UInt8])
        /// case JPEG.ParsingError.invalidJFIFVersionCode(_:)
        ///     A JFIF segment had an invalid version code. 
        /// - _ : (major:Swift.UInt8, minor:Swift.UInt8) 
        ///     The version code read from the segment.
        case invalidJFIFVersionCode((major:UInt8, minor:UInt8))
        /// case JPEG.ParsingError.invalidJFIFDensityUnitCode(_:)
        ///     A JFIF segment had an invalid density unit code. 
        /// - _ : Swift.UInt8 
        ///     The density unit code read from the segment.
        case invalidJFIFDensityUnitCode(UInt8)
        /// case JPEG.ParsingError.invalidEXIFSignature(_:)
        ///     An EXIF segment had an invalid signature.
        /// - _ : [Swift.UInt8] 
        ///     The signature read from the segment.
        case invalidEXIFSignature([UInt8])
        /// case JPEG.ParsingError.invalidEXIFEndiannessCode(_:)
        ///     An EXIF segment had an invalid endianness specifier.
        /// - _ : (Swift.UInt8, Swift.UInt8, Swift.UInt8, Swift.UInt8)
        ///     The endianness specifier read from the segment.
        case invalidEXIFEndiannessCode((UInt8, UInt8, UInt8, UInt8))
        
        /// case JPEG.ParsingError.invalidFrameWidth(_:)
        ///     A frame header segment had a negative or zero width field. 
        /// - _ : Swift.Int 
        ///     The value of the width field read from the segment.
        case invalidFrameWidth(Int)
        /// case JPEG.ParsingError.invalidFramePrecision(_:_:)
        ///     A frame header segment had an invalid precision field. 
        /// - _ : Swift.Int 
        ///     The value of the precision field read from the segment.
        /// - _ : JPEG.Process 
        ///     The coding process specified by the frame header.
        case invalidFramePrecision(Int, Process)
        /// case JPEG.ParsingError.invalidFrameComponentCount(_:_:)
        ///     A frame header segment had an invalid number of components. 
        /// - _ : Swift.Int 
        ///     The number of components in the segment.
        /// - _ : JPEG.Process 
        ///     The coding process specified by the frame header.
        case invalidFrameComponentCount(Int, Process)
        /// case JPEG.ParsingError.invalidFrameQuantizationSelectorCode(_:)
        ///     A component in a frame header segment had an invalid quantization 
        ///     table selector code. 
        /// - _ : Swift.UInt8  
        ///     The selector code read from the segment.
        case invalidFrameQuantizationSelectorCode(UInt8)
        /// case JPEG.ParsingError.invalidFrameQuantizationSelector(_:_:)
        ///     A component in a frame header segment used a quantization table 
        ///     selector which is well-formed but unavailable given the frame header coding process.
        /// - _ : JPEG.Table.Quantization.Selector 
        ///     The quantization table selector. 
        /// - _ : JPEG.Process 
        ///     The coding process specified by the frame header.
        case invalidFrameQuantizationSelector(JPEG.Table.Quantization.Selector, Process)
        /// case JPEG.ParsingError.invalidFrameComponentSamplingFactor(_:_:)
        ///     A component in a frame header had an invalid sampling factor. 
        /// 
        ///     Sampling factors must be within the range `1 ... 4`.
        /// - _ : (x:Swift.Int, y:Swift.Int)
        ///     The sampling factor of the component.
        /// - _ : JPEG.Component.Key 
        ///     The component key.
        case invalidFrameComponentSamplingFactor((x:Int, y:Int), Component.Key)
        /// case JPEG.ParsingError.duplicateFrameComponentIndex(_:)
        ///     The same component key occurred more than once in the same frame header. 
        /// - _ : JPEG.Component.Key 
        ///     The duplicated component key.
        case duplicateFrameComponentIndex(Component.Key)
        
        /// case JPEG.ParsingError.invalidScanHuffmanSelectorCode(_:)
        ///     A component in a frame header segment had an invalid quantization 
        ///     table selector code. 
        /// - _ : Swift.UInt8  
        ///     The selector code read from the segment.
        case invalidScanHuffmanSelectorCode(UInt8)
        /// case JPEG.ParsingError.invalidScanHuffmanDCSelector(_:_:)
        ///     A component in a frame header segment used a DC huffman table 
        ///     selector which is well-formed but unavailable given the frame header coding process.
        /// - _ : JPEG.Table.HuffmanDC.Selector 
        ///     The huffman table selector. 
        /// - _ : JPEG.Process 
        ///     The coding process specified by the frame header.
        case invalidScanHuffmanDCSelector(JPEG.Table.HuffmanDC.Selector, Process)
        /// case JPEG.ParsingError.invalidScanHuffmanACSelector(_:_:)
        ///     A component in a frame header segment used an AC huffman table 
        ///     selector which is well-formed but unavailable given the frame header coding process.
        /// - _ : JPEG.Table.HuffmanAC.Selector 
        ///     The huffman table selector. 
        /// - _ : JPEG.Process 
        ///     The coding process specified by the frame header.
        case invalidScanHuffmanACSelector(JPEG.Table.HuffmanAC.Selector, Process)
        /// case JPEG.ParsingError.invalidScanComponentCount(_:_:)
        ///     A scan header had more that the maximum allowed number of components 
        ///     given the image coding process. 
        /// - _ : Swift.Int 
        ///     The number of components in the scan header. 
        /// - _ : JPEG.Process 
        ///     The coding process used by the image.
        case invalidScanComponentCount(Int, Process)
        /// case JPEG.ParsingError.invalidScanProgressiveSubset(band:bits:_:)
        ///     A scan header specified an invalid progressive frequency band 
        ///     or bit range given the image coding process. 
        /// - band  : (Swift.Int, Swift.Int)
        ///     The lower and upper bounds of the frequency band read from the scan header.
        /// - bits  : (Swift.Int, Swift.Int)
        ///     The lower and upper bounds of the bit range read from the scan header.
        /// - _     : JPEG.Process 
        ///     The coding process used by the image.
        case invalidScanProgressiveSubset(band:(Int, Int), bits:(Int, Int), Process)
        
        /// case JPEG.ParsingError.invalidHuffmanTargetCode(_:)
        ///     A huffman table definition had an invalid huffman table 
        ///     selector code. 
        /// - _ : Swift.UInt8  
        ///     The selector code read from the segment.
        case invalidHuffmanTargetCode(UInt8)
        /// case JPEG.ParsingError.invalidHuffmanTypeCode(_:)
        ///     A huffman table definition had an invalid type indicator code. 
        /// - _ : Swift.UInt8  
        ///     The type indicator code read from the segment.
        case invalidHuffmanTypeCode(UInt8)
        /// case JPEG.ParsingError.invalidHuffmanTable
        ///     A huffman table definition did not define a valid binary tree.
        case invalidHuffmanTable
        
        /// case JPEG.ParsingError.invalidQuantizationTargetCode(_:)
        ///     A quantization table definition had an invalid quantization table 
        ///     selector code. 
        /// - _ : Swift.UInt8  
        ///     The selector code read from the segment.
        case invalidQuantizationTargetCode(UInt8)
        /// case JPEG.ParsingError.invalidQuantizationPrecisionCode(_:)
        ///     A quantization table definition had an invalid precision indicator code. 
        /// - _ : Swift.UInt8  
        ///     The precision indicator code read from the segment.
        case invalidQuantizationPrecisionCode(UInt8)
        
        static 
        func mismatched(marker:Marker, count:Int, minimum:Int) -> Self 
        {
            .truncatedMarkerSegmentBody(marker, count, expected: minimum ... .max)
        }
        static 
        func mismatched(marker:Marker, count:Int, expected:Int) -> Self 
        {
            if count < expected 
            {
                return .truncatedMarkerSegmentBody(marker, count, expected: expected ... expected)
            }
            else 
            {
                return .extraneousMarkerSegmentData(marker, count, expected: expected)
            }
        }
        /// static var JPEG.ParsingError.namespace: Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns the string `"parsing error"`.
        public static 
        var namespace:String 
        {
            "parsing error" 
        }
        /// var JPEG.ParsingError.message         : Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns a basic description of this parsing error.
        public 
        var message:String 
        {
            switch self 
            {
            case .truncatedMarkerSegmentBody:
                return "truncated marker segment body"
            case .extraneousMarkerSegmentData:
                return "extraneous data in marker segment body"
            
            case .invalidJFIFSignature:
                return "invalid JFIF signature"
            case .invalidJFIFVersionCode:
                return "invalid JFIF version"
            case .invalidJFIFDensityUnitCode:
                return "invalid JFIF density unit"
            
            case .invalidEXIFSignature:
                return "invalid EXIF signature"
            case .invalidEXIFEndiannessCode:
                return "invalid EXIF endianness code"
            
            case .invalidFrameWidth:
                return "invalid frame width"
            case .invalidFramePrecision:
                return "invalid precision specifier"
            case .invalidFrameComponentCount:
                return "invalid total component count"
            case .invalidFrameQuantizationSelectorCode:
                return "invalid quantization table selector code"
            case .invalidFrameQuantizationSelector:
                return "invalid quantization table selector"
            case .invalidFrameComponentSamplingFactor:
                return "invalid component sampling factors"
            case .duplicateFrameComponentIndex:
                return "duplicate component indices"
            
            case .invalidScanHuffmanSelectorCode:
                return "invalid huffman table selector pair code"
            case .invalidScanHuffmanDCSelector:
                return "invalid dc huffman table selector"
            case .invalidScanHuffmanACSelector:
                return "invalid ac huffman table selector"
            case .invalidScanComponentCount:
                return "invalid scan component count"
            case .invalidScanProgressiveSubset:
                return "invalid spectral selection or successive approximation"
            
            case .invalidHuffmanTargetCode:
                return "invalid huffman table destination"
            case .invalidHuffmanTypeCode:
                return "invalid huffman table type specifier"
            case .invalidHuffmanTable:
                return "malformed huffman table"
            
            case .invalidQuantizationTargetCode:
                return "invalid quantization table destination"
            case .invalidQuantizationPrecisionCode:
                return "invalid quantization table precision specifier"
            }
        }
        /// var JPEG.ParsingError.details         : Swift.String? { get }
        /// ?:  JPEG.Error 
        ///     Returns a detailed description of this parsing error, if available.
        public 
        var details:String? 
        {
            switch self 
            {
            case .truncatedMarkerSegmentBody(let marker, let count, expected: let expected):
                if expected.count == 1
                {
                    return "\(marker) segment (\(count) bytes) must be exactly \(expected.lowerBound) bytes long"
                }
                else 
                {
                    return "\(marker) segment (\(count) bytes) must be at least \(expected.lowerBound) bytes long"
                }
            case .extraneousMarkerSegmentData(let marker, let count, expected: let expected):
                return "\(marker) segment (\(count) bytes) must be exactly \(expected) bytes long"
            
            case .invalidJFIFSignature(let string):
                return "string (\(string.map{ "0x\(String.init($0, radix: 16))" }.joined(separator: ", "))) is not a valid JFIF signature"
            case .invalidJFIFVersionCode(let (major, minor)):
                return "version (\(major).\(minor)) must be within 1.0 ... 1.2"
            case .invalidJFIFDensityUnitCode(let code):
                return "density code (\(code)) does not correspond to a valid density unit"
            
            case .invalidEXIFSignature(let string):
                return "string (\(string.map{ "0x\(String.init($0, radix: 16))" }.joined(separator: ", "))) is not a valid EXIF signature"
            case .invalidEXIFEndiannessCode(let code):
                return "endianness code (\(code.0), \(code.1), \(code.2), \(code.3)) does not correspond to a valid EXIF endianness"
                
            case .invalidFrameWidth(let width):
                return "frame cannot have width \(width)"
            case .invalidFramePrecision(let precision, let process):
                return "precision (\(precision)) is not allowed for frame coding process '\(process)'"
            case .invalidFrameComponentCount(let count, let process):
                if count == 0 
                {
                    return "frame must have at least one component"
                }
                else 
                {
                    return "frame (\(count) components) with coding process '\(process)' has disallowed component count"
                }  
            case .invalidFrameQuantizationSelectorCode(let code):
                return "quantization table selector code (\(code)) must be within 0 ... 3"
            case .invalidFrameQuantizationSelector(let selector, let process):
                return "quantization table selector (\(String.init(selector: selector))) is not allowed for coding process '\(process)'"
            case .invalidFrameComponentSamplingFactor(let factor, let ci):
                return "both sampling factors (\(factor.x), \(factor.y)) for component index \(ci) must be within 1 ... 4"
            case .duplicateFrameComponentIndex(let ci):
                return "component index (\(ci)) conflicts with previously defined component"
            
            case .invalidScanHuffmanSelectorCode(let code):
                return "huffman table selector pair code (\(code)) must be within 0 ... 3 or 16 ... 19"
            case .invalidScanHuffmanDCSelector(let selector, let process):
                return "dc huffman table selector (\(String.init(selector: selector))) is not allowed for coding process '\(process)'"
            case .invalidScanHuffmanACSelector(let selector, let process):
                return "ac huffman table selector (\(String.init(selector: selector))) is not allowed for coding process '\(process)'"
            case .invalidScanComponentCount(let count, let process):
                if count == 0 
                {
                    return "scan must contain at least one component"
                }
                else 
                {
                    return "scan component count (\(count)) is not allowed for coding process '\(process)'"
                } 
            case .invalidScanProgressiveSubset(band: let band, bits: let bits, let process):
                return "scan cannot define spectral selection (\(band.0) ..< \(band.1)) with successive approximation (\(bits.0) ..< \(bits.1)) for coding process '\(process)'"
            
            case .invalidHuffmanTargetCode(let code):
                return "selector code (0x\(String.init(code, radix: 16))) does not correspond to a valid huffman table destination"
            case .invalidHuffmanTypeCode(let code):
                return "code (\(code)) does not correspond to a valid huffman table type"
            case .invalidHuffmanTable:
                return nil
            
            case .invalidQuantizationTargetCode(let code):
                return "selector code (0x\(String.init(code, radix: 16))) does not correspond to a valid quantization table destination"
            case .invalidQuantizationPrecisionCode(let code):
                return "code (\(code)) does not correspond to a valid quantization table precision"
            }
        }
    }
    /// enum JPEG.DecodingError
    /// :   JPEG.Error 
    ///     A decoding error.
    /// #  [See also](error-types)
    /// ## (error-types)
    /// ## (error-handling)
    public 
    enum DecodingError:JPEG.Error 
    {
        /// case JPEG.DecodingError.truncatedEntropyCodedSegment
        ///     An entropy-coded segment contained less than the expected amount of data.
        case truncatedEntropyCodedSegment
        
        /// case JPEG.DecodingError.invalidRestartPhase(_:expected:)
        ///     A restart marker appeared out-of-phase. 
        /// 
        ///     Restart markers should cycle from 0 to 7, in that order.
        /// - _         : Swift.Int 
        ///     The phase read from the restart marker. 
        /// - expected  : Swift.Int 
        ///     The expected phase, which is one greater than the phase of the 
        ///     last-encountered restart marker (modulo 8), or 0 if this is the 
        ///     first restart marker in the entropy-coded segment.
        case invalidRestartPhase(Int, expected:Int)
        /// case JPEG.DecodingError.missingRestartIntervalSegment
        ///     A restart marker appeared, but no restart interval was ever defined, 
        ///     or restart markers were disabled.
        case missingRestartIntervalSegment
        
        /// case JPEG.DecodingError.invalidSpectralSelectionProgression(_:_:)
        ///     The first scan for a component encoded a frequency band that 
        ///     did not include the DC coefficient.
        /// - _ : Swift.Range<Swift.Int> 
        ///     The frequency band encoded by the scan.
        /// - _ : JPEG.Component.Key 
        ///     The component key of the invalidated color channel.
        case invalidSpectralSelectionProgression(Range<Int>, Component.Key)
        /// case JPEG.DecodingError.invalidSuccessiveApproximationProgression(_:_:z:_:)
        ///     A scan did not follow the correct successive approximation sequence 
        ///     for at least one frequency coefficient.
        /// 
        ///     Successive approximation must refine bits starting from the most-significant 
        ///     and going towards the least-significant, only the initial scan 
        ///     for each coefficient can encode more than one bit at a time. 
        /// - _ : Swift.Range<Swift.Int>
        ///     The bit range encoded by the scan. 
        /// - _ : Swift.Int 
        ///     The index of the least-significant bit encoded so far for the coefficient `z`. 
        /// - z : Swift.Int 
        ///     The zigzag index of the coefficient. 
        /// - _ : JPEG.Component.Key 
        ///     The component key of the invalidated color channel.
        case invalidSuccessiveApproximationProgression(Range<Int>, Int, z:Int, Component.Key)
        
        /// case JPEG.DecodingError.invalidCompositeValue(_:expected:)
        ///     The decoder decoded an out-of-range composite value. 
        /// 
        ///     This error occurs when a refining AC scan encodes any composite 
        ///     value that is not –1, 0, or +1, because refining scans can only 
        ///     refine one bit at a time.
        /// - _         : Swift.Int16 
        ///     The decoded composite value.
        /// - expected  : Swift.ClosedRange<Swift.Int> 
        ///     The expected range for the composite value.
        case invalidCompositeValue(Int16, expected:ClosedRange<Int>)
        /// case JPEG.DecodingError.invalidCompositeBlockRun(_:expected:)
        ///     The decoder decoded an out-of-range end-of-band/end-of-block run count. 
        /// 
        ///     This error occurs when a sequential scan tries to encode an end-of-band
        ///     run, which is a progressive coding process concept only. Sequential 
        ///     scans can only end-of-block runs of length 1.
        /// - _         : Swift.Int16 
        ///     The decoded end-of-band/end-of-block run count.
        /// - expected  : Swift.ClosedRange<Swift.Int> 
        ///     The expected range for the end-of-band/end-of-block run count.
        case invalidCompositeBlockRun(Int, expected:ClosedRange<Int>)
        
        /// case JPEG.DecodingError.undefinedScanComponentReference(_:_:)
        ///     A scan encoded a component with a key that was not one of the 
        ///     resident components declared in the frame header.
        /// - _ : JPEG.Component.Key 
        ///     The undefined component key. 
        /// - _ : Swift.Set<JPEG.Component.Key>
        ///     The set of defined resident component keys.
        case undefinedScanComponentReference(Component.Key, Set<Component.Key>)
        /// case JPEG.DecodingError.invalidScanSamplingVolume(_:)
        ///     An interleaved scan had a total component sampling volume greater 
        ///     than 10.
        /// 
        ///     The total sampling volume is the sum of the products of the sampling 
        ///     factors of each component encoded by the scan.
        /// - _ : Swift.Int 
        ///     The total sampling volume of the scan components.
        case invalidScanSamplingVolume(Int)
        /// case JPEG.DecodingError.undefinedScanHuffmanDCReference(_:)
        ///     A DC huffman table selector in a scan referenced a table 
        ///     slot with no bound table.
        /// - _ : JPEG.Table.HuffmanDC.Selector 
        ///     The table selector.
        case undefinedScanHuffmanDCReference(Table.HuffmanDC.Selector)
        /// case JPEG.DecodingError.undefinedScanHuffmanACReference(_:)
        ///     An AC huffman table selector in a scan referenced a table 
        ///     slot with no bound table.
        /// - _ : JPEG.Table.HuffmanAC.Selector 
        ///     The table selector.
        case undefinedScanHuffmanACReference(Table.HuffmanAC.Selector)
        /// case JPEG.DecodingError.undefinedScanQuantizationReference(_:)
        ///     A quantization table selector in the first scan for a particular 
        ///     component referenced a table slot with no bound table.
        /// - _ : JPEG.Table.Quantization.Selector 
        ///     The table selector.
        case undefinedScanQuantizationReference(Table.Quantization.Selector)
        /// case JPEG.DecodingError.invalidScanQuantizationPrecision(_:)
        ///     A quantization table had the wrong precision mode for the image 
        ///     color format. 
        /// 
        ///     Only images with a bit depth greater than 8 should use a 16-bit 
        ///     quantization table.
        /// - _ : JPEG.Table.Quantization.Precision 
        ///     The precision mode of the quantization table.
        case invalidScanQuantizationPrecision(Table.Quantization.Precision)
        
        /// case JPEG.DecodingError.missingStartOfImage(_:)
        ///     The first marker segment in the image was not a start-of-image marker. 
        /// - _ : JPEG.Marker 
        ///     The type indicator of the first encountered marker segment. 
        case missingStartOfImage(Marker)
        /// case JPEG.DecodingError.duplicateStartOfImage 
        ///     The decoder encountered more than one start-of-image marker.
        case duplicateStartOfImage
        /// case JPEG.DecodingError.duplicateFrameHeaderSegment 
        ///     The decoder encountered more than one frame header segment. 
        ///     
        ///     JPEG files using the hierarchical coding process can encode more 
        ///     than one frame header. However, this coding process is not currently 
        ///     supported.
        case duplicateFrameHeaderSegment
        /// case JPEG.DecodingError.prematureScanHeaderSegment 
        ///     The decoder encountered a scan header segment before a frame header 
        ///     segment.
        case prematureScanHeaderSegment
        /// case JPEG.DecodingError.missingHeightRedefinitionSegment 
        ///     The decoder did not encounter the height redefinition segment that 
        ///     must follow the first scan of an image with a declared height of 0.
        case missingHeightRedefinitionSegment
        /// case JPEG.DecodingError.prematureHeightRedefinitionSegment 
        ///     The decoder encountered a height redefinition segment before the 
        ///     first image scan.
        case prematureHeightRedefinitionSegment
        /// case JPEG.DecodingError.unexpectedHeightRedefinitionSegment 
        ///     The decoder encountered a height redefinition segment after, but 
        ///     not immediately after the first image scan.
        case unexpectedHeightRedefinitionSegment
        /// case JPEG.DecodingError.unexpectedRestart 
        ///     The decoder encountered a restart marker outside of an entropy-coded 
        ///     segment.
        case unexpectedRestart
        /// case JPEG.DecodingError.prematureEndOfImage 
        ///     The decoder encountered an end-of-image marker before encountering 
        ///     a frame header segment.
        case prematureEndOfImage
        
        /// case JPEG.DecodingError.unsupportedFrameCodingProcess(_:)
        ///     The image coding process was anything other than 
        ///     [`(Process).baseline`], or [`(Process).extended(coding:differential:)`] 
        ///     and [`(Process).progressive(coding:differential:)`] with [`(Process.Coding).huffman`]
        ///     coding and `differential` set to `false`.
        /// - _ : JPEG.Process 
        ///     The coding process used by the image.
        case unsupportedFrameCodingProcess(Process)
        /// case JPEG.DecodingError.unrecognizedColorFormat(_:_:_:) 
        ///     A [`(Format).recognize(_:precision:)`] implementation failed to 
        ///     recognize the component set and bit precision in a frame header.
        /// - _ : Swift.Set<JPEG.Component.Key>
        ///     The set of resident component keys read from the frame header.
        /// - _ : Swift.Int 
        ///     The bit precision read from the frame header.
        /// - _ : Swift.Any.Type 
        ///     The [`Format`] type that tried to detect the color format.
        case unrecognizedColorFormat(Set<Component.Key>, Int, Any.Type)
        
        /// static var JPEG.DecodingError.namespace: Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns the string `"decoding error"`.
        public static 
        var namespace:String 
        {
            "decoding error" 
        }
        /// var JPEG.DecodingError.message        : Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns a basic description of this decoding error.
        public 
        var message:String 
        {
            switch self 
            {
            case .truncatedEntropyCodedSegment:
                return "truncated entropy coded segment bitstream"
                
            case .invalidSpectralSelectionProgression:
                return "invalid spectral selection progression"
            case .invalidSuccessiveApproximationProgression:
                return "invalid successive approximation progression"
                
            case .invalidRestartPhase:
                return "invalid restart phase"
            case .missingRestartIntervalSegment:
                return "missing restart interval segment"
                
            case .invalidCompositeValue:
                return "invalid composite value"
            case .invalidCompositeBlockRun:
                return "invalid composite end-of-band run length"
                
            case .undefinedScanComponentReference:
                return "undefined component reference"
            case .invalidScanSamplingVolume:
                return "invalid scan component sampling volume"
            case .undefinedScanHuffmanDCReference:
                return "undefined dc huffman table reference"
            case .undefinedScanHuffmanACReference:
                return "undefined ac huffman table reference"
            case .undefinedScanQuantizationReference:
                return "undefined quantization table reference"
            case .invalidScanQuantizationPrecision:
                return "quantization table precision mismatch"
            
            case .missingStartOfImage:
                return "missing start-of-image marker"
            case .duplicateStartOfImage:
                return "duplicate start-of-image marker"
            case .duplicateFrameHeaderSegment:
                return "duplicate frame header segment"
            case .prematureScanHeaderSegment:
                return "premature scan header segment"
            case .missingHeightRedefinitionSegment:
                return "missing height redefinition segment"
            case .prematureHeightRedefinitionSegment:
                return "premature height redefinition segment"
            case .unexpectedHeightRedefinitionSegment:
                return "unexpected height redefinition segment"
            case .unexpectedRestart:
                return "unexpected restart marker"
            case .prematureEndOfImage:
                return "premature end-of-image marker"
                
            case .unsupportedFrameCodingProcess:
                return "unsupported encoding process"
            case .unrecognizedColorFormat:
                return "unrecognized color format"
            }
        }
        /// var JPEG.DecodingError.details        : Swift.String? { get }
        /// ?:  JPEG.Error 
        ///     Returns a detailed description of this decoding error, if available.
        public 
        var details:String? 
        {
            switch self 
            {
            case .truncatedEntropyCodedSegment:
                return "not enough data in entropy coded segment bitstream"
            
            case .invalidRestartPhase(let phase, expected: let expected):
                return "decoded restart phase (\(phase)) is not the expected phase (\(expected))"
            case .missingRestartIntervalSegment:
                return "encountered restart segments, but no restart interval has been defined"
            
            case .invalidSpectralSelectionProgression(let band, let ci):
                return "frequency band \(band.lowerBound) ..< \(band.upperBound) for component \(ci) is not allowed"
            case .invalidSuccessiveApproximationProgression(let bits, let a, z: let z, let ci):
                return "bits \(bits.lowerBound)\(bits.upperBound == .max ? "..." : " \(bits.upperBound)") for component \(ci) cannot refine bit \(a) of coefficient \(z)"
            
            case .invalidCompositeValue(let value, expected: let expected):
                return "magnitude-tail encoded value (\(value)) must be within \(expected.lowerBound) ... \(expected.upperBound)"
            case .invalidCompositeBlockRun(let value, expected: let expected):
                return "magnitude-tail encoded end-of-band run length (\(value)) must be within \(expected.lowerBound) ... \(expected.upperBound)"
                
            case .undefinedScanComponentReference(let ci, let defined):
                return "component with index (\(ci)) is not one of the components \(defined.sorted()) defined in frame header"
            case .invalidScanSamplingVolume(let volume):
                return "scan mcu sample volume (\(volume)) can be at most 10"
            case .undefinedScanHuffmanDCReference(let selector):
                return "no dc huffman table has been installed at the location <\(String.init(selector: selector))>"
            case .undefinedScanHuffmanACReference(let selector):
                return "no ac huffman table has been installed at the location <\(String.init(selector: selector))>"
            case .undefinedScanQuantizationReference(let selector):
                return "no quantization table has been installed at the location <\(String.init(selector: selector))>"
            case .invalidScanQuantizationPrecision(let precision):
                return "quantization table has invalid integer type (\(precision))"
            
            case .missingStartOfImage:
                return "start-of-image marker must be the first marker in image"
            case .duplicateStartOfImage:
                return "start-of-image marker cannot occur more than once"
            case .duplicateFrameHeaderSegment:
                return "multiple frame headers only allowed for the hierarchical coding process"
            case .prematureScanHeaderSegment:
                return "scan header must occur after frame header"
            case .missingHeightRedefinitionSegment:
                return "define height segment must occur immediately after first scan"
            case .prematureHeightRedefinitionSegment, .unexpectedHeightRedefinitionSegment:
                return "define height segment can only occur immediately after first scan"
            case .unexpectedRestart:
                return "restart marker can only follow an entropy-coded segment"
            case .prematureEndOfImage:
                return "premature end-of-image marker"
            
            case .unsupportedFrameCodingProcess(let process):
                return "frame coding process (\(process)) is not supported"
            case .unrecognizedColorFormat(let components, let precision, let type):
                return "color format type (\(type)) could not match component identifier set \(components.sorted()) with precision \(precision) to a known value"
            }
        }
    }
}

extension JPEG 
{
    /// enum JPEG.FormattingError
    /// :   JPEG.Error 
    ///     A formatting error.
    /// #  [See also](error-types)
    /// ## (error-types)
    /// ## (error-handling)
    public 
    enum FormattingError:JPEG.Error 
    {
        /// case JPEG.FormattingError.invalidDestination 
        ///     The formatter could not write data to its destination stream.
        case invalidDestination
        /// static var JPEG.FormattingError.namespace: Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns the string `"formatting error"`.
        public static 
        var namespace:String 
        {
            "formatting error"
        }
        /// var JPEG.FormattingError.message        : Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns a basic description of this formatting error.
        public 
        var message:String 
        {
            switch self 
            {
            case .invalidDestination:
                return "failed to write to destination"
            } 
        }
        /// var JPEG.FormattingError.details        : Swift.String? { get }
        /// ?:  JPEG.Error 
        ///     Returns a detailed description of this formatting error, if available.
        public 
        var details:String? 
        {
            switch self 
            {
            case .invalidDestination:
                return nil
            } 
        }
    }
    /// enum JPEG.SerializingError
    /// :   JPEG.Error 
    ///     A serializing error.
    /// 
    ///     This enumeration currently has no cases.
    /// #  [See also](error-types)
    /// ## (error-types)
    /// ## (error-handling)
    public 
    enum SerializingError:JPEG.Error 
    {
        /// static var JPEG.SerializingError.namespace: Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns the string `"serializing error"`.
        public static 
        var namespace:String 
        {
            "serializing error"
        }
        /// var JPEG.SerializingError.message       : Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns a basic description of this serializing error.
        public 
        var message:String 
        {
            switch self 
            {
            } 
        }
        /// var JPEG.SerializingError.details       : Swift.String? { get }
        /// ?:  JPEG.Error 
        ///     Returns a detailed description of this serializing error, if available.
        public 
        var details:String? 
        {
            switch self 
            {
            } 
        }
    }
    /// enum JPEG.EncodingError
    /// :   JPEG.Error 
    ///     An encoding error.
    /// 
    ///     This enumeration currently has no cases.
    /// #  [See also](error-types)
    /// ## (error-types)
    /// ## (error-handling)
    public 
    enum EncodingError:JPEG.Error 
    {
        /// static var JPEG.EncodingError.namespace : Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns the string `"encoding error"`.
        public static 
        var namespace:String 
        {
            "encoding error"
        }
        /// var JPEG.EncodingError.message          : Swift.String { get }
        /// ?:  JPEG.Error 
        ///     Returns a basic description of this encoding error.
        public 
        var message:String 
        {
            switch self 
            {
            } 
        }
        /// var JPEG.EncodingError.details          : Swift.String? { get }
        /// ?:  JPEG.Error 
        ///     Returns a detailed description of this encoding error, if available.
        public 
        var details:String? 
        {
            switch self 
            {
            } 
        }
    }
}
