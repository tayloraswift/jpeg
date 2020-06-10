/// protocol JPEG.Error
/// :   Swift.Error 
///     Functionality common to all library error types.
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
        /// case JPEG.LexingError.invalidMarkerSegmentPrefix(_:)
        ///     The lexer encountered a marker segment with a reserved type indicator 
        ///     code.
        /// - _ :Swift.UInt8 
        ///     The invalid type indicator code encountered by the lexer.
        case invalidMarkerSegmentType(UInt8)
        /// static var JPEG.LexingError.namespace : Swift.String { get }
        /// :   JPEG.Error 
        ///     Returns the string `"lexing error"`.
        public static 
        var namespace:String 
        {
            "lexing error" 
        }
        /// var JPEG.LexingError.message          : Swift.String { get }
        /// :   JPEG.Error 
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
        /// :   JPEG.Error 
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
        
        case invalidJFIFSignature([UInt8])
        case invalidJFIFVersionCode((major:UInt8, minor:UInt8))
        case invalidJFIFDensityUnitCode(UInt8)
        
        case invalidEXIFSignature([UInt8])
        case invalidEXIFEndiannessCode((UInt8, UInt8, UInt8, UInt8))
        
        case invalidFrameWidth(Int)
        case invalidFramePrecision(Int, Process)
        case invalidFrameComponentCount(Int, Process)
        case invalidFrameQuantizationSelectorCode(UInt8)
        case invalidFrameQuantizationSelector(JPEG.Table.Quantization.Selector, Process)
        case invalidFrameComponentSamplingFactor((x:Int, y:Int), Component.Key)
        case duplicateFrameComponentIndex(Component.Key)
        
        case invalidScanHuffmanSelectorCode(UInt8)
        case invalidScanHuffmanDCSelector(JPEG.Table.HuffmanDC.Selector, Process)
        case invalidScanHuffmanACSelector(JPEG.Table.HuffmanAC.Selector, Process)
        case invalidScanComponentCount(Int, Process)
        case invalidScanProgressiveSubset(band:(Int, Int), bits:(Int, Int), Process)
        
        case invalidHuffmanTargetCode(UInt8)
        case invalidHuffmanTypeCode(UInt8)
        case invalidHuffmanTable
        
        case invalidQuantizationTargetCode(UInt8)
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
        
        public static 
        var namespace:String 
        {
            "parsing error" 
        }
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
    public 
    enum DecodingError:JPEG.Error 
    {
        case truncatedEntropyCodedSegment
        
        case invalidRestartPhase(Int, expected:Int)
        case missingRestartIntervalSegment
        
        case invalidSpectralSelectionProgression(Range<Int>, Component.Key)
        case invalidSuccessiveApproximationProgression(Range<Int>, Int, z:Int, Component.Key)
        
        case invalidCompositeValue(Int16, expected:ClosedRange<Int>)
        case invalidCompositeBlockRun(Int, expected:ClosedRange<Int>)
        
        case undefinedScanComponentReference(Component.Key, Set<Component.Key>)
        case invalidScanSamplingVolume(Int)
        case undefinedScanHuffmanDCReference(Table.HuffmanDC.Selector)
        case undefinedScanHuffmanACReference(Table.HuffmanAC.Selector)
        case undefinedScanQuantizationReference(Table.Quantization.Selector)
        case invalidScanQuantizationPrecision(Table.Quantization.Precision)
        
        case missingStartOfImage(Marker)
        case duplicateStartOfImage
        case duplicateFrameHeaderSegment
        case prematureScanHeaderSegment
        case missingHeightRedefinitionSegment
        case prematureHeightRedefinitionSegment
        case unexpectedHeightRedefinitionSegment
        case prematureEntropyCodedSegment
        case unexpectedRestart
        case prematureEndOfImage
        
        case unsupportedFrameCodingProcess(Process)
        case unrecognizedColorFormat(Set<Component.Key>, Int, Any.Type)
        
        public static 
        var namespace:String 
        {
            "decoding error" 
        }
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
            case .prematureEntropyCodedSegment:
                return "premature entropy coded segment"
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
            case .prematureEntropyCodedSegment:
                return "entropy coded segment must occur immediately after scan header"
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
