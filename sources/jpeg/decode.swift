public 
protocol _JPEGFormat
{
    static 
    func recognize(_ components:Set<JPEG.Component.Key>, precision:Int) -> Self?
    
    // the ordering here is used to determine planar indices 
    var components:[JPEG.Component.Key]
    {
        get 
    }
    var precision:Int 
    {
        get 
    }
}
public 
protocol _JPEGColor
{
    associatedtype Format:JPEG.Format 
    
    static 
    func pixels(_ interleaved:[UInt16], format:Format) -> [Self]
}

public 
enum JPEG 
{
    public 
    typealias Format = _JPEGFormat
    public 
    typealias Color  = _JPEGColor
    
    public 
    enum Metadata 
    {
        // case exif(EXIF)
        case jfif(JFIF)
        case unknown(application:Int, [UInt8])
    }
    
    // sample types 
    @frozen 
    public 
    struct YCbCr:Hashable 
    {
        /// The luminance component of this color. 
        public 
        var y:UInt8 
        /// The blue component of this color. 
        public 
        var cb:UInt8 
        /// The red component of this color. 
        public 
        var cr:UInt8 
        
        public 
        init(y:UInt8) 
        {
            self.init(y: y, cb: 128, cr: 128)
        }
        
        public 
        init(y:UInt8, cb:UInt8, cr:UInt8) 
        {
            self.y  = y 
            self.cb = cb 
            self.cr = cr 
        }
    }
    @frozen
    public 
    struct RGB:Hashable 
    {
        /// The red component of this color.
        public
        var r:UInt8
        /// The green component of this color.
        public
        var g:UInt8
        /// The blue component of this color.
        public
        var b:UInt8
        
        /// Creates an opaque grayscale color with all color components set to the given
        /// value sample.
        /// 
        /// - Parameters:
        ///     - value: The value to initialize all color components to.
        public
        init(_ value:UInt8)
        {
            self.init(value, value, value)
        }
        
        /// Creates an opaque color with the given color samples.
        /// 
        /// - Parameters:
        ///     - red: The value to initialize the red component to.
        ///     - green: The value to initialize the green component to.
        ///     - blue: The value to initialize the blue component to.
        public
        init(_ red:UInt8, _ green:UInt8, _ blue:UInt8)
        {
            self.r = red 
            self.g = green 
            self.b = blue
        }
    }     
}

// layout 
extension JPEG 
{
    public 
    struct Component
    {
        public 
        let factor:(x:Int, y:Int)
        public 
        let selector:Table.Quantization.Selector 
        
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
    
    public 
    struct Scan
    {
        public 
        struct Component 
        {
            public 
            let ci:JPEG.Component.Key
            public 
            let selector:(dc:Table.HuffmanDC.Selector, ac:Table.HuffmanAC.Selector)
        }
        
        public 
        let band:Range<Int>, 
            bits:Range<Int>, 
            components:[(c:Int, component:Component)] 
    }
    
    public 
    struct Layout<Format> where Format:JPEG.Format 
    {
        // note: we draw a distinction between *recognized* components and 
        // *resident* components. it is allowed for `self.components` to include 
        // definitions for components that are not part of `self.format.components`.
        // these components do not recieve a plane in the `Data` types, but will 
        // be ignored by the scan decoder without errors. 
        // note: `self.format.components` is a subset of `self.components.keys`
        // note: all components referenced by the scan headers in `self.scans`
        // must be recognized components.
        public 
        let format:Format  
        
        public 
        let process:Process
        
        public 
        let residents:[Component.Key: Int]
        public 
        var recognized:[Component.Key] 
        {
            self.format.components 
        }
        
        public internal(set)
        var planes:[(component:Component, qi:Table.Quantization.Key)]
        
        public private(set)
        var definitions:[(quanta:[Table.Quantization.Key], scans:[Scan])]
    }
}

// compound types 
extension JPEG 
{
    public 
    enum Process 
    {
        public 
        enum Coding 
        {
            case huffman 
            case arithmetic 
        }
        
        case baseline 
        case extended(coding:Coding, differential:Bool)
        case progressive(coding:Coding, differential:Bool)
        case lossless(coding:Coding, differential:Bool)
    }
    
    public 
    enum Marker
    {
        case start
        case end
        
        case quantization 
        case huffman 
        
        case application(Int)
        case restart(Int)
        case height 
        case interval  
        case comment 
        
        case frame(Process)
        case scan 
        
        case arithmeticCodingCondition
        case hierarchical 
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

// binary utilities 
public 
protocol _JPEGBytestreamSource 
{
    mutating 
    func read(count:Int) -> [UInt8]?
}
extension JPEG 
{
    public 
    enum Bytestream 
    {
        public 
        typealias Source = _JPEGBytestreamSource
    }
    
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
            .init(data[$0]) << 8 | .init(data[$0 | 1])
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
    public 
    init(arrayLiteral:UInt8...) 
    {
        self.init(arrayLiteral)
    }
}

public 
protocol _JPEGError:Swift.Error 
{
    static 
    var namespace:String 
    {
        get 
    }
    var message:String 
    {
        get 
    }
    var details:String? 
    {
        get 
    }
}
extension JPEG 
{
    public 
    typealias Error = _JPEGError
    public 
    enum LexingError:JPEG.Error
    {
        case truncatedMarkerSegmentType
        case truncatedMarkerSegmentHeader
        case truncatedMarkerSegmentBody(expected:Int)
        case truncatedEntropyCodedSegment
        
        case invalidMarkerSegmentLength(Int)
        case invalidMarkerSegmentPrefix(UInt8)
        case invalidMarkerSegmentType(UInt8)
        
        public static 
        var namespace:String 
        {
            "lexing error" 
        }
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
    public 
    enum ParsingError:JPEG.Error 
    {
        case truncatedMarkerSegmentBody(Marker, Int, expected:ClosedRange<Int>)
        case extraneousMarkerSegmentData(Marker, Int, expected:Int)
        
        case invalidJFIFSignature([UInt8])
        case invalidJFIFVersionCode((major:UInt8, minor:UInt8))
        case invalidJFIFDensityUnitCode(UInt8)
        
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
        case duplicateFrameHeader
        case prematureScanHeader
        case prematureDefineHeightSegment
        case prematureEntropyCodedSegment
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
            case .duplicateFrameHeader:
                return "duplicate frame header"
            case .prematureScanHeader:
                return "premature scan header"
            case .prematureDefineHeightSegment:
                return "premature define height segment"
            case .prematureEntropyCodedSegment:
                return "premature entropy coded segment"
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
            case .duplicateFrameHeader:
                return "multiple frame headers only allowed for the hierarchical coding process"
            case .prematureScanHeader:
                return "scan header must occur after frame header"
            case .prematureDefineHeightSegment:
                return "define height segment must occur immediately after first scan"
            case .prematureEntropyCodedSegment:
                return "entropy coded segment must occur immediately after scan header"
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

// lexing 
extension JPEG.Bytestream.Source 
{
    private mutating 
    func read() -> UInt8?
    {
        return self.read(count: 1)?[0]
    }
    
    // segment lexing 
    private mutating 
    func tail(type:JPEG.Marker) throws -> [UInt8]
    {
        switch type 
        {
        case .start, .end:
            return []
        default:
            guard let header:[UInt8] = self.read(count: 2)
            else 
            {
                throw JPEG.LexingError.truncatedMarkerSegmentHeader
            }
            let length:Int = header.load(bigEndian: UInt16.self, as: Int.self, at: 0)
            
            guard length >= 2
            else 
            {
                throw JPEG.LexingError.invalidMarkerSegmentLength(length)
            }
            guard let data:[UInt8] = self.read(count: length - 2)
            else 
            {
                throw JPEG.LexingError.truncatedMarkerSegmentBody(expected: length - 2)
            }
            
            return data
        }
    }
    
    public mutating 
    func segment() throws -> (JPEG.Marker, [UInt8])
    {
        try self.segment(prefix: false).1
    }
    public mutating 
    func segment(prefix:Bool) throws -> ([UInt8], (JPEG.Marker, [UInt8]))
    {
        // buffering would help immensely here 
        var ecs:[UInt8] = []
        let append:(_ byte:UInt8) throws -> ()
        
        if prefix 
        {
            append = 
            {
                ecs.append($0)
            }
        } 
        else 
        {
            append = 
            {
                throw JPEG.LexingError.invalidMarkerSegmentPrefix($0)
            }
        }
        
        outer:
        while var byte:UInt8 = self.read() 
        {
            guard byte == 0xff 
            else 
            {
                try append(byte)
                continue outer
            }
            
            repeat
            {
                guard let next:UInt8 = self.read() 
                else 
                {
                    throw JPEG.LexingError.truncatedMarkerSegmentType
                }
                
                byte = next
                
                guard byte != 0x00 
                else 
                {
                    try append(0xff)
                    continue outer 
                }
            } 
            while byte == 0xff 
            
            guard let marker:JPEG.Marker = JPEG.Marker.init(code: byte)
            else 
            {
                throw JPEG.LexingError.invalidMarkerSegmentType(byte)
            }
                
            let data:[UInt8] = try self.tail(type: marker)
            return (ecs, (marker, data))
        }
        
        throw JPEG.LexingError.truncatedEntropyCodedSegment
    }
}

// parsing 
public 
protocol _JPEGAnyTable 
{
    associatedtype Delegate  
    typealias Slots     = (Delegate?, Delegate?, Delegate?, Delegate?)
    typealias Selector  = WritableKeyPath<Slots, Delegate?>
}
public 
protocol _JPEGBitstreamAnySymbol:Hashable
{
    init(_:UInt8)
    
    var value:UInt8 
    {
        get 
    }
}
extension JPEG.Bitstream 
{
    public 
    typealias AnySymbol = _JPEGBitstreamAnySymbol
    public 
    enum Symbol 
    {
        public 
        struct DC:AnySymbol
        {
            public  
            let value:UInt8 
            
            public 
            init(_ value:UInt8) 
            {
                self.value = value 
            }
        }
        public 
        struct AC:AnySymbol
        {
            public  
            let value:UInt8
            
            public 
            init(_ value:UInt8) 
            {
                self.value = value 
            }
        }
    }
}

extension JPEG 
{
    // public 
    // struct EXIF 
    // {
    // }
    public 
    struct JFIF
    {
        public 
        enum Version 
        {
            case v1_0, v1_1, v1_2
        }
        
        public 
        enum Unit
        {
            case none
            case dpi 
            case dpcm 
        }
        
        public 
        let version:Version,
            density:(x:Int, y:Int, unit:Unit)
        
        // initializer has to live here due to compiler issue
        public  
        init(version:Version, density:(x:Int, y:Int, unit:Unit))
        {
            self.version = version 
            self.density = density
        }
    }
    
    public 
    typealias AnyTable = _JPEGAnyTable 
    public 
    enum Table 
    {
        public 
        typealias HuffmanDC = Huffman<Bitstream.Symbol.DC>
        public 
        typealias HuffmanAC = Huffman<Bitstream.Symbol.AC>
        public 
        struct Huffman<Symbol>:AnyTable where Symbol:Bitstream.AnySymbol
        {
            public 
            typealias Delegate = Self 
            
            let symbols:[[Symbol]]
            var target:Selector
            
            // these are size parameters generated by the structural validator. 
            // we store them here as proof of tree validity
            private 
            let size:(n:Int, z:Int)
        }
        
        public 
        struct Quantization:AnyTable
        {
            public 
            struct Key:Hashable 
            {
                let value:Int 
                
                init<I>(_ value:I) where I:BinaryInteger 
                {
                    self.value = .init(value)
                }
            }
            
            public 
            typealias Delegate = (q:Int, qi:Table.Quantization.Key)
            
            public 
            enum Precision  
            {
                case uint8
                case uint16
            }
            
            var storage:[UInt16], 
                target:Selector
            let precision:Precision
        }
    }
    
    public 
    enum Header 
    {
        public 
        struct HeightRedefinition 
        {
            public 
            let height:Int 
        }
        
        public 
        struct Frame 
        {
            public 
            let process:Process,
                precision:Int, 
                size:(x:Int, y:Int)
            public 
            let components:[Component.Key: Component]
        }
        
        public 
        struct Scan
        {
            public 
            let band:Range<Int>, 
                bits:Range<Int>, 
                components:[JPEG.Scan.Component] 
        }
    }
}
// jfif segment parsing 
extension JPEG.JFIF.Version  
{
    static 
    func parse(code:(UInt8, UInt8)) -> Self?
    {
        switch (major: code.0, minor: code.1)
        {
        case (major: 1, minor: 0):
            return .v1_0
        case (major: 1, minor: 1):
            return .v1_1
        case (major: 1, minor: 2):
            return .v1_2
        default:
            return nil 
        }
    }
}
extension JPEG.JFIF.Unit 
{
    static 
    func parse(code:UInt8) -> Self?
    {
        switch code 
        {
        case 0:
            return .some(.none) 
        case 1:
            return .dpi 
        case 2:
            return .dpcm 
        default:
            return nil 
        }
    }
}
extension JPEG.JFIF 
{
    static 
    let signature:[UInt8] = [0x4a, 0x46, 0x49, 0x46, 0x00]
    
    public static 
    func parse(_ data:[UInt8]) throws -> Self
    {
        guard data.count >= 14
        else
        {
            throw JPEG.ParsingError.mismatched(marker: .application(0), 
                count: data.count, minimum: 14)
        }
        
        // look for 'JFIF' signature
        guard data[0 ..< 5] == Self.signature[...]
        else 
        {
            throw JPEG.ParsingError.invalidJFIFSignature(.init(data[0 ..< 5]))
        }

        guard let version:Version   = .parse(code: (data[5], data[6]))
        else 
        {
            throw JPEG.ParsingError.invalidJFIFVersionCode((data[5], data[6]))
        }
        guard let unit:Unit         = .parse(code: data[7])
        else
        {
            // invalid JFIF density unit
            throw JPEG.ParsingError.invalidJFIFDensityUnitCode(data[7])
        }

        let density:(x:Int, y:Int)  = 
        (
            data.load(bigEndian: UInt16.self, as: Int.self, at:  8), 
            data.load(bigEndian: UInt16.self, as: Int.self, at: 10)
        )
        
        // we ignore the thumbnail data
        return .init(version: version, density: (density.x, density.y, unit))
    }
}
// table parsing 
extension JPEG.AnyTable  
{
    static 
    func parse(selector:UInt8) -> Self.Selector?
    {
        switch selector & 0x0f
        {
        case 0:
            return \.0 
        case 1:
            return \.1 
        case 2:
            return \.2 
        case 3:
            return \.3 
        default:
            return nil 
        }
    }
}
extension JPEG.Table.Huffman 
{
    // determine the value of n, explained in `Table.Huffman.decode()`,
    // as well as the useful size of the table (often, a large region of the high codeword 
    // space is unused so it can be excluded)
    // also validates leaf counts to make sure they define a valid 16-bit tree
    private static
    func size(_ levels:[Int]) -> (n:Int, z:Int)?
    {
        // count the interior nodes 
        var interior:Int = 1 // count the root 
        for leaves:Int in levels[0 ..< 8] 
        {
            guard interior > 0 
            else 
            {
                return nil
            }
            
            // every interior node on the level above generates two new nodes.
            // some of the new nodes are leaf nodes, the rest are interior nodes.
            interior = 2 * interior - leaves
        }
        
        // the number of interior nodes remaining is the number of child trees, with 
        // the possible exception of a fake all-ones branch 
        let n:Int      = 256 - interior 
        var z:Int      = n
        // finish validating the tree 
        for (i, leaves):(Int, Int) in levels[8 ..< 16].enumerated()
        {
            guard interior > 0 
            else 
            {
                return nil
            }
            
            z       += leaves << (7 - i)
            interior = 2 * interior - leaves 
        }
        
        guard interior > 0
        else 
        {
            return nil
        }
        
        return (n, z)
    }
    
    // internal unsafe init 
    init(validated symbols:[[Symbol]], target:Selector)
    {
        precondition(symbols.count == 16)
        guard let size:(n:Int, z:Int) = Self.size(symbols.map(\.count))
        else 
        {
            fatalError("unreachable")
        }
        
        self.symbols = symbols
        self.target  = target 
        self.size    = size
    }
    
    init?<RAC>(counts:[Int], values:RAC, target:Selector) 
        where RAC:RandomAccessCollection, RAC.Element == UInt8, RAC.Index == Int
    {
        var symbols:[[Symbol]] = []
        var begin:Int = values.startIndex 
        for leaves:Int in counts 
        {
            let end:Int = begin + leaves 
            symbols.append(values[begin ..< end].map(Symbol.init(_:)))
            begin       = end 
        }
        
        self.init(symbols, target: target)
    }
    
    public 
    init?(_ symbols:[[Symbol]], target:Selector)
    {
        precondition(symbols.count == 16)
        // validate leaf counts 
        guard let size:(n:Int, z:Int) = Self.size(symbols.map(\.count))
        else 
        {
            return nil
        }
        
        self.symbols = symbols
        self.target  = target 
        self.size    = size
    } 
}
extension JPEG.Table.Quantization 
{
    init<RAC>(precision:Precision, values:RAC, target:Selector) 
        where RAC:RandomAccessCollection, RAC.Element == UInt8, RAC.Index == Int
    {
        switch precision 
        {
        case .uint8:
            // doing the `UInt16` conversion here potentially saves a copy in 
            // the public initializer 
            let uint16:[UInt16] = values.map(UInt16.init(_:))
            self.init(precision: .uint8, values: uint16, target: target)
        case .uint16:
            let base:Int        = values.startIndex 
            let uint16:[UInt16] = (0 ..< 64).map 
            {
                let bytes:[UInt8] = .init(values[base + 2 * $0 ..< base + 2 * $0 + 2])
                return bytes.load(bigEndian: UInt16.self, as: UInt16.self, at: 0)
            }
            self.init(precision: .uint16, values: uint16, target: target)
        }
    }
    
    public 
    init(precision:Precision, values:[UInt16], target:Selector) 
    {
        precondition(values.count == 64)
        self.precision  = precision
        self.storage    = values 
        self.target     = target 
    }
}
extension JPEG.Table 
{
    public static 
    func parse(_ data:[UInt8], as:(HuffmanDC.Type, HuffmanAC.Type)) 
        throws -> (dc:[HuffmanDC], ac:[HuffmanAC]) 
    {
        var tables:(dc:[HuffmanDC], ac:[HuffmanAC]) = ([], [])
        
        var base:Int = 0
        while base < data.count
        {
            guard data.count >= base + 17
            else
            {
                // data buffer does not contain enough data
                throw JPEG.ParsingError.mismatched(marker: .huffman, 
                    count: data.count, minimum: base + 17)
            }
            
            // huffman tables have variable length that can only be determined
            // by examining the first 17 bytes of each table which means checks
            // have to be done midway through the parsing
            let leaf:(counts:[Int], values:ArraySlice<UInt8>)
            leaf.counts = data[base + 1 ..< base + 17].map(Int.init(_:))
            
            // count the number of expected leaves 
            let count:Int = leaf.counts.reduce(0, +)
            guard data.count >= base + 17 + count
            else 
            {
                throw JPEG.ParsingError.mismatched(marker: .huffman, 
                    count: data.count, minimum: base + 17 + count)
            }
            defer 
            {
                base += 17 + count
            }
            
            leaf.values = data[base + 17 ..< base + 17 + count]
            
            switch data[base] >> 4 
            {
            case 0:
                guard let target:HuffmanDC.Selector = HuffmanDC.parse(selector: data[base])
                else 
                {
                    break 
                }
                
                guard let table:HuffmanDC = 
                    HuffmanDC.init(counts: leaf.counts, values: leaf.values, target: target)
                else 
                {
                    throw JPEG.ParsingError.invalidHuffmanTable 
                }
                
                tables.dc.append(table)
                continue 
            
            case 1:
                guard let target:HuffmanAC.Selector = HuffmanAC.parse(selector: data[base])
                else 
                {
                    break 
                }
                
                guard let table:HuffmanAC = 
                    HuffmanAC.init(counts: leaf.counts, values: leaf.values, target: target)
                else 
                {
                    throw JPEG.ParsingError.invalidHuffmanTable 
                }
                
                tables.ac.append(table)
                continue 
            
            default:
                throw JPEG.ParsingError.invalidHuffmanTypeCode(data[base] >> 4)
            }
            
            // huffman table has invalid binding index
            throw JPEG.ParsingError.invalidHuffmanTargetCode(data[base] & 0x0f)
        }
        
        return tables
    }
    
    public static 
    func parse(_ data:[UInt8], as: Quantization.Type) 
        throws -> [Quantization] 
    {
        var tables:[Quantization] = []
        
        var base:Int = 0 
        while base < data.count 
        {
            guard let target:Quantization.Selector = Quantization.parse(selector: data[base])
            else 
            {
                throw JPEG.ParsingError.invalidQuantizationTargetCode(data[base] & 0x0f)
            }
            
            let table:Quantization
            switch data[base] >> 4
            {
            case 0:
                guard data.count >= base + 65 
                else 
                {
                    throw JPEG.ParsingError.mismatched(marker: .quantization, 
                        count: data.count, minimum: base + 65)
                }
                
                table = .init(precision: .uint8, values: data[base + 1 ..< base + 65], 
                    target: target)
                base += 65 
            case 1:
                guard data.count >= base + 129 
                else 
                {
                    throw JPEG.ParsingError.mismatched(marker: .quantization, 
                        count: data.count, minimum: base + 129)
                }
                
                table = .init(precision: .uint16, values: data[base + 1 ..< base + 129], 
                    target: target)
                base += 129 
            
            default:
                throw JPEG.ParsingError.invalidQuantizationPrecisionCode(data[base] >> 4)
            }
            
            tables.append(table)
        }
        
        return tables
    }
}
// frame/scan header parsing 
extension JPEG.Header.HeightRedefinition 
{
    public static
    func parse(_ data:[UInt8]) throws -> Self
    {
        guard data.count == 2
        else
        {
            throw JPEG.ParsingError.mismatched(marker: .height, count: data.count, expected: 2)
        }

        return .init(height: data.load(bigEndian: UInt16.self, as: Int.self, at: 0))
    } 
}
extension JPEG.Header.Frame 
{
    public static 
    func validate(process:JPEG.Process, precision:Int, size:(x:Int, y:Int), 
        components:[JPEG.Component.Key: JPEG.Component]) throws -> Self 
    {
        guard size.x > 0 
        else 
        {
            throw JPEG.ParsingError.invalidFrameWidth(size.x)
        }
        
        for (ci, component):(JPEG.Component.Key, JPEG.Component) in components 
        {
            // we don’t enforce the scan volume constraint in the parsing stage 
            // because it only applies to interleaved scans (so a 4x4 sampled 
            // component is legal as long as count == 1)
            guard   1 ... 4 ~= component.factor.x,
                    1 ... 4 ~= component.factor.y
            else
            {
                throw JPEG.ParsingError.invalidFrameComponentSamplingFactor(
                    component.factor, ci)
            }
            
            if case .baseline = process 
            {
                // make sure only selectors 0 and 1 are used 
                switch component.selector 
                {
                case \.0, \.1:
                    break 
                default:
                    throw JPEG.ParsingError.invalidFrameQuantizationSelector(component.selector, 
                        process)
                }
            }
        }
        
        switch (process, precision) 
        {
        case    (.baseline,     8), 
                (.extended,     8), (.extended,     12), 
                (.progressive,  8), (.progressive,  12), 
                (.lossless,     2 ... 16):
            break

        default:
            // invalid precision
            throw JPEG.ParsingError.invalidFramePrecision(precision, process)
        }
        
        switch (process, components.count) 
        {
        case    (.baseline,     1 ... 255), 
                (.extended,     1 ... 255), 
                (.progressive,  1 ...   4), 
                (.lossless,     1 ... 255):
            break

        default:
            // invalid count
            throw JPEG.ParsingError.invalidFrameComponentCount(components.count, process)
        }
        
        return .init(process: process, precision: precision, size: size, 
            components: components)
    }
    public static
    func parse(_ data:[UInt8], process:JPEG.Process) throws -> Self
    {
        guard data.count >= 6
        else
        {
            throw JPEG.ParsingError.mismatched(marker: .frame(process), 
                count: data.count, minimum: 6)
        }

        let precision:Int       = .init(data[0])
        let size:(x:Int, y:Int) = 
        (
            data.load(bigEndian: UInt16.self, as: Int.self, at: 3),
            data.load(bigEndian: UInt16.self, as: Int.self, at: 1)
        )
        let count:Int           = .init(data[5])
        
        guard data.count == 3 * count + 6
        else
        {
            // wrong segment size
            throw JPEG.ParsingError.mismatched(marker: .frame(process), 
                count: data.count, expected: 3 * count + 6)
        }

        var components:[JPEG.Component.Key: JPEG.Component] = [:]
        for i:Int in 0 ..< count
        {
            let base:Int = 3 * i + 6
            let byte:(UInt8, UInt8, UInt8) = (data[base], data[base + 1], data[base + 2])
            
            let factor:(x:Int, y:Int)  = (.init(byte.1 >> 4), .init(byte.1 & 0x0f))
            let ci:JPEG.Component.Key  =  .init(byte.0)
            
            guard let selector:JPEG.Table.Quantization.Selector = 
                JPEG.Table.Quantization.parse(selector: byte.2)
            else 
            {
                throw JPEG.ParsingError.invalidFrameQuantizationSelectorCode(byte.2)
            }
            
            let component:JPEG.Component = .init(factor: factor, selector: selector)
            // make sure no duplicate component indices are used 
            guard components.updateValue(component, forKey: ci) == nil 
            else 
            {
                throw JPEG.ParsingError.duplicateFrameComponentIndex(ci)
            }
        }

        return try .validate(process: process, precision: precision, size: size, 
            components: components)
    }
} 
extension JPEG.Header.Scan 
{
    public static 
    func validate(process:JPEG.Process, 
        band:Range<Int>, bits:Range<Int>, components:[JPEG.Scan.Component]) 
        throws -> Self 
    {
        for component:JPEG.Scan.Component in components 
        {
            if case .baseline = process 
            {
                // make sure only selectors 0 and 1 are used 
                switch component.selector.dc
                {
                case \.0, \.1:
                    break 
                default:
                    throw JPEG.ParsingError.invalidScanHuffmanDCSelector(
                        component.selector.dc, process)
                }
                switch component.selector.ac
                {
                case \.0, \.1:
                    break 
                default:
                    throw JPEG.ParsingError.invalidScanHuffmanACSelector(
                        component.selector.ac, process)
                }
            }
        }
        
        // validate subsetting 
        let a:Int = bits.lowerBound
        switch (process, (band.lowerBound, band.upperBound), (bits.lowerBound, bits.upperBound)) 
        {
        case    (.baseline,    (0,       64), (0,  .max)), 
                (.extended,    (0,       64), (0,  .max)), 
                (.progressive, (0,        1), (_,  .max)), // unlimited bits per initial scan
                (.progressive, (0,        1), (_, a + 1)): // 1 bit per refining scan 
            guard 1 ... 4 ~= components.count
            else 
            {
                throw JPEG.ParsingError.invalidScanComponentCount(components.count, 
                    process)
            }  
        case    (.progressive, (_, 2 ... 64), (_,  .max)), 
                (.progressive, (_, 2 ... 64), (_, a + 1)): 
            guard 1 ... 1 ~= components.count
            else 
            {
                // progressive scans that code for AC components cannot be interleaved
                throw JPEG.ParsingError.invalidScanComponentCount(components.count, 
                    process)
            }
        
        default:
            throw JPEG.ParsingError.invalidScanProgressiveSubset(
                band: (band.lowerBound, band.upperBound), 
                bits: (bits.lowerBound, bits.upperBound), 
                process)
        }
        
        return .init(band: band, bits: bits, components: components)
    }
    public static 
    func parse(_ data:[UInt8], process:JPEG.Process) throws -> Self
    {
        guard data.count >= 4 
        else 
        {
            throw JPEG.ParsingError.mismatched(marker: .scan, 
                count: data.count, minimum: 4)
        }
        
        let count:Int = .init(data[0])
        
        guard data.count == 2 * count + 4
        else 
        {
            // wrong segment size
            throw JPEG.ParsingError.mismatched(marker: .scan, 
                count: data.count, expected: 2 * count + 4)
        }
        
        let components:[JPEG.Scan.Component] = try (0 ..< count).map 
        {
            let base:Int            = 2 * $0 + 1
            let byte:(UInt8, UInt8) = (data[base], data[base + 1])
            
            let ci:JPEG.Component.Key = .init(byte.0)
            guard   let dc:JPEG.Table.HuffmanDC.Selector = 
                    JPEG.Table.HuffmanDC.parse(selector: byte.1 >> 4), 
                    let ac:JPEG.Table.HuffmanAC.Selector = 
                    JPEG.Table.HuffmanAC.parse(selector: byte.1 & 0xf)
            else 
            {
                throw JPEG.ParsingError.invalidScanHuffmanSelectorCode(byte.1)
            }
            
            return .init(ci: ci, selector: (dc, ac))
        }
        
        // parse spectral parameters 
        let base:Int                    = 2 * count + 1
        let byte:(UInt8, UInt8, UInt8)  = (data[base], data[base + 1], data[base + 2])
        
        let band:(Int, Int)             = (.init(byte.0), .init(byte.1) + 1)
        let bits:(Int, Int)             = 
        (
                                        .init(byte.2 & 0x0f), 
            byte.2 & 0xf0 == 0 ? .max : .init(byte.2 >> 4)
        )
        
        guard   band.0 < band.1, // is valid range 
                bits.0 < bits.1
        else 
        {
            throw JPEG.ParsingError.invalidScanProgressiveSubset(
                band: band, bits: bits, process)
        }
        
        return try .validate(process: process, 
            band: band.0 ..< band.1, bits: bits.0 ..< bits.1, components: components)
    }
}

// huffman decoder 
extension JPEG.Table.Huffman 
{
    struct Decoder 
    {
        struct Entry 
        {
            let symbol:Symbol
            @Common.Storage<UInt8> 
            var length:Int 
        }
        
        private 
        let storage:[Entry], 
            n:Int, // number of level 0 entries
            ζ:Int  // logical size of the table (where the n level 0 entries are each 256 units big)
        
        init(_ storage:[Entry], n:Int, ζ:Int) 
        {
            self.storage    = storage 
            self.n          = n
            self.ζ          = ζ
        }
    }
}
extension JPEG.Table.Huffman 
{
    // this is a (relatively) expensive function. however most jpegs define a 
    // fresh set of huffman tables for each scan, so it is very unlikely that 
    // this function will get called redundantly.
    func decoder() -> Decoder
    {
        /*
        idea:    jpeg huffman tables are encoded gzip style, as sequences of
                 leaf counts and leaf values. the leaf counts tell you the
                 number of leaf nodes at each level of the tree. combined with
                 a rule that says that leaf nodes always occur on the “leftmost”
                 side of the tree, this uniquely determines a huffman tree.
        
                 Given: leaves per level = [0, 3, 1, 1, ... ]
        
                         ___0___[root]___1___
                       /                      \
                __0__[ ]__1__            __0__[ ]__1__
              /              \         /               \
             [a]            [b]      [c]            _0_[ ]_1_
                                                  /           \
                                                [d]        _0_[ ]_1_
                                                         /           \
                                                       [e]        reserved
        
                 note that in a huffman tree, level 0 always contains 0 leaf
                 nodes (why?) so the huffman table omits level 0 in the leaf
                 counts list.
        
                 we *could* build a tree data structure, and traverse it as
                 we read in the coded bits, but that would be slow and require
                 a shift for every bit. instead we extend the huffman tree
                 into a perfect tree, and assign the new leaf nodes the
                 values of their parents.
        
                             ________[root]________
                           /                        \
                   _____[ ]_____                _____[ ]_____
                  /             \             /               \
                 [a]           [b]          [c]            ___[ ]___
               /     \       /     \       /   \         /           \
             (a)     (a)   (b)     (b)   (c)   (c)      [d]          ...
        
                 this lets us make a table of huffman codes where all the
                 codes are “padded” to the same length. note that codewords
                 that occur higher up the tree occur multiple times because
                 they have multiple children. of course, since the extra bits
                 aren’t actually part of the code, we have to store separately
                 the length of the original code so we know how many bits
                 we should advance the current bit position by once we match
                 a code.
        
                   code       value     length
                 —————————  —————————  ————————
                    000        'a'         2
                    001        'a'         2
                    010        'b'         2
                    011        'b'         2
                    100        'c'         2
                    101        'c'         2
                    110        'd'         3
                    111        ...        >3
        
                 decoding coded data then becomes a matter of matching a fixed
                 length bitstream against the table (the code works as an integer
                 index!) since all possible combinations of trailing “padding”
                 bits are represented in the table.
        
                 in jpeg, codewords can be a maximum of 16 bits long. this
                 means in theory we need a table with 2^16 entries. that’s a
                 huge table considering there are only 256 actual encoded
                 values, and since this is the kind of thing that really needs
                 to be optimized for speed, this needs to be as cache friendly
                 as possible.
        
                 we can reduce the table size by splitting the 16-bit table
                 into two 8-bit levels. this means we have one 8-bit “root”
                 tree, and k 8-bit child trees rooted on the internal nodes
                 at level 8 of the original tree.
        
                 so far, we’ve looked at the huffman tree as a tree. however 
                 it actually makes more sense to look at it as a table, just 
                 like its implementation. remember that the tree is right-heavy, 
                 so the first 8 levels will look something like 
        
                 +———————————————————+ 0
                 |                   |
                 |                   |
                 |                   |
                 |                   |
                 |                   |
                 |                   |
                 |                   |
                 +———————————————————+
                 |                   |
                 |                   |
                 |                   |
                 +———————————————————+
                 |                   |
                 |                   |
                 |                   |
                 +———————————————————+ -
                 |                   |
                 +———————————————————+
                 |                   |
                 +———————————————————+
                 |                   |
                 +———————————————————+
                 |                   |
                 +———————————————————+ -
                 |                   |
                 +———————————————————+
                 +———————————————————+
               n +———————————————————+ -    —    +———————————————————+ s = 0
                 +-------------------+      ↑    |                   |
                 +-------------------+      s    |                   |
                 +-------------------+      ↓    |                   |
           n + s +-------------------+ 256  —    +———————————————————+
                                                 |                   |
                                                 |                   |
                                                 |                   |
                                                 +———————————————————+
                                                 |                   |
                                                 |                   |
                                                 |                   |
                                                 +———————————————————+
                                                 |                   |
                                                 +———————————————————+
                                                 |                   |
                                                 /////////////////////
        
                 this is awesome because we don’t need to store anything in 
                 the table entries themselves to know if they are direct entries 
                 or indirect entries. if the index of the entry is greater than 
                 or equal to `n` (the number of direct entries), it is an 
                 indirect entry, and its indirect index is given by the first 
                 byte of the codeword with `n` subtracted from it. 
                 level-1 subtables are always 256 entries long since they are 
                 leaf tables. this means their positions can be computed in 
                 constant time, given `n`, which is also the position of the 
                 first level-1 table.
                 
                 (for computational ease, we store `s = 256 - n` instead. 
                 `s` can be interpreted as the number of level-1 subtables 
                 trail the level-0 table in the storage buffer)
        
                 how big can `s` be? well, remember that there are only 256
                 different encoded values which means the original tree can
                 only have 256 leaves. any full binary tree with height at
                 least 1 *must* contain at least 2 leaf nodes (why?). since
                 the child trees must have a height > 0 (otherwise they would
                 be 0-bit trees), every child tree except possibly the right-
                 most one must have at least 2 leaf nodes. the rightmost child
                 tree is an exception because in jpeg, the all-ones codeword
                 does not represent any value, so the right-most tree can
                 possibly only contain one “real” leaf node. we can pigeonhole
                 this to show that we can only have up to k ≤ 129 child trees.
                 in fact, we can reduce this even further to k ≤ 128 because
                 if the rightmost tree only contains 1 leaf, there has to be at
                 least one other tree with an odd number of leaves to make the  
                 total add up to 256, and that number has to be at least 3. 
                 in reality, k is rarely bigger than 7 or 8 yielding a significant 
                 size savings.
        
                 because we don’t need to store pointers, each table entry can 
                 be just 2 bytes long — 1 byte for the encoded value, and 1 byte 
                 to store the length of the codeword.
        
                 a buffer like this will never have size greater than
                 2 * 256 × (128 + 1) = 65_792 bytes, compared with
                 2 × (1 << 16)  = 131_072 bytes for the 16-bit table. in
                 reality the 2 layer table is usually on the order of 2–4 kB.
        
                 why not compact the child trees further, since not all of them
                 actually have height 8? we could do that, and get some serious
                 worst-case memory savings, but then we couldn’t access the
                 child tables at constant offsets from the buffer base. we’d
                 need to store whole ≥16-bit pointers to the specific byte offset 
                 where the variable-length child table lives, and perform a 
                 conditional bit shift to transform the input bits into an 
                 appropriate index into the table. not a good look.
        */
        
        // z is the physical size of the table in memory
        let (n, z):(Int, Int) = self.size 
        
        var storage:[Decoder.Entry] = []
            storage.reserveCapacity(z)
        
        for (l, symbols):(Int, [Symbol]) in self.symbols.enumerated()
        {
            guard storage.count < z 
            else 
            {
                break
            }            
            
            let clones:Int  = 0x8080 >> l & 0xff
            for symbol:Symbol in symbols 
            {
                let entry:Decoder.Entry = .init(symbol: symbol, length: l + 1)
                storage.append(contentsOf: repeatElement(entry, count: clones))
            }
        }
        
        assert(storage.count == z)
        return .init(storage, n: n, ζ: z + n * 255)
    }
}
// table accessors 
extension JPEG.Table.Huffman.Decoder 
{
    // codeword is big-endian
    subscript(codeword:UInt16) -> Entry 
    {
        // [ level 0 index  |    offset    ]
        let i:Int = .init(codeword >> 8)
        if i < self.n 
        {
            return self.storage[i]
        }
        else 
        {
            let j:Int = .init(codeword)
            guard j < self.ζ 
            else 
            {
                return .init(symbol: .init(0), length: 16)
            }
            
            return self.storage[j - self.n * 255]
        }
    }
}
extension JPEG.Table.Quantization 
{
    // convert a 2D coordinate to a zigzag parameter
    @inlinable
    public static 
    func z(k x:Int, h y:Int) -> Int 
    {
        let p:Int =  x + y < 8 ? 1 : 0, 
            q:Int = (x + y) & 1
        let a:Int = 72 * (p ^ 1), 
            b:Int = 2 * p - 1
        let n:Int = b * (x + y) - 14 * p + 15
        let t:Int = (n * (n + 1)) >> 1
        return a + b * t - q * x - (q ^ 1) * y - 1
    }
    
    // it is easier to convert (k, h) 2-d coordinates to z zig-zag coordinates
    // than the other way around, so we store the coefficients in zig-zag 
    // order, and provide a subscript that converts 2-d coordinates into 
    // zig-zag coordinates 
    @inlinable
    public 
    subscript(k k:Int, h h:Int) -> UInt16 
    {
        get 
        {
            self[z: Self.z(k: k, h: h)]
        }
        set(value)
        {
            self[z: Self.z(k: k, h: h)] = value 
        }
    }
    
    public 
    subscript(z z:Int) -> UInt16 
    {
        get 
        {
            self.storage[z]
        }
        set(value)
        {
            self.storage[z] = value
        }
    }
}

// intermediate forms
extension JPEG 
{
    public 
    enum Data 
    {
    }
}
extension JPEG.Data 
{
    private static  
    func units(_ size:Int, stride:Int) -> Int  
    {
        let complete:Int = size / stride, 
            partial:Int  = size % stride != 0 ? 1 : 0 
        return complete + partial 
    }
    
    public 
    struct Spectral<Format> where Format:JPEG.Format 
    {
        public 
        struct Quanta 
        {
            private 
            var quanta:[JPEG.Table.Quantization], 
                q:[JPEG.Table.Quantization.Key: Int]
        }
        
        public 
        struct Plane 
        {
            public 
            var units:(x:Int, y:Int)
            
            // have to be `Int16` to circumvent compiler size limits for `_read` and `_modify`
            @Common.Storage2<Int16>
            public 
            var factor:(x:Int, y:Int) 
            @Common.MutableStorage<Int32>
            var q:Int
            
            private 
            var buffer:[Int16]
            
            // subscript with a zigzag coordinate
            public 
            subscript(x x:Int, y y:Int, z z:Int) -> Int16 
            {
                get 
                {
                    guard   0 ..< self.units.x ~= x, 
                            0 ..< self.units.y ~= y 
                    else 
                    {
                        return 0 
                    }
                    
                    return self.buffer[64 * (self.units.x * y + x) + z]
                }
                set(value) 
                {
                    guard   0 ..< self.units.x ~= x, 
                            0 ..< self.units.y ~= y 
                    else 
                    {
                        return 
                    }
                    
                    self.buffer[64 * (self.units.x * y + x) + z] = value 
                }
            }
        }
        
        public private(set)
        var size:(x:Int, y:Int), 
            blocks:(x:Int, y:Int)
        
        public private(set)
        var layout:JPEG.Layout<Format>
        public 
        var metadata:[JPEG.Metadata]
        
        public private(set) 
        var quanta:Quanta
        private 
        var planes:[Plane]
    }
    
    public 
    struct Planar<Format> where Format:JPEG.Format
    {
        public 
        struct Plane 
        {
            public 
            let units:(x:Int, y:Int)
            public 
            var size:(x:Int, y:Int) 
            {
                (8 * self.units.x, 8 * self.units.y)
            }
            
            // have to be `Int32` to circumvent compiler size limits for `_read` and `_modify`
            @Common.Storage2<Int32>
            public 
            var factor:(x:Int, y:Int) 
            
            private 
            var buffer:[UInt16]
            
            public 
            subscript(x x:Int, y y:Int) -> UInt16
            {
                get 
                {
                    self.buffer[x + self.size.x * y]
                }
                set(value) 
                {
                    self.buffer[x + self.size.x * y] = value 
                }
            }
        }
        
        public 
        let size:(x:Int, y:Int)
        
        public 
        let layout:JPEG.Layout<Format>, 
            metadata:[JPEG.Metadata]
        
        private 
        var planes:[Plane] 
        
        init(size:(x:Int, y:Int), 
            layout:JPEG.Layout<Format>, 
            metadata:[JPEG.Metadata],
            planes:[JPEG.Data.Planar<Format>.Plane])
        {
            self.size       = size
            self.layout     = layout
            self.metadata   = metadata
            self.planes     = planes 
        } 
    }
    
    public 
    struct Rectangular<Format> where Format:JPEG.Format 
    {
        public 
        let size:(x:Int, y:Int), 
            layout:JPEG.Layout<Format>, 
            metadata:[JPEG.Metadata]
        
        private 
        var values:[UInt16]
        
        public 
        var stride:Int 
        {
            self.layout.recognized.count 
        }
        
        init(size:(x:Int, y:Int), 
            layout:JPEG.Layout<Format>, 
            metadata:[JPEG.Metadata], 
            values:[UInt16])
        {
            self.size       = size
            self.layout     = layout
            self.metadata   = metadata
            self.values     = values
        }
    }
}

// RAC conformance for planar types 
extension JPEG.Data.Spectral.Quanta
{
    init(default:JPEG.Table.Quantization)
    {
        // generate the ‘default’ quantization table at `qi = -1`, `q = 0`
        self.quanta = [`default`]
        self.q      = [-1: 0]
    } 
    
    mutating 
    func push(qi:JPEG.Table.Quantization.Key, quanta table:JPEG.Table.Quantization) 
        -> Int 
    {
        self.q.updateValue(self.quanta.endIndex, forKey: qi)
        self.quanta.append(table)
        return self.quanta.endIndex - 1
    }
    
    mutating 
    func removeAll()
    {
        self.quanta.removeAll()
        self.q.removeAll()
    }
    
    public 
    func mapValues(_ transform:([UInt16]) throws -> [UInt16]) 
        rethrows -> [JPEG.Table.Quantization.Key: [UInt16]]
    {
        try self.q.mapValues
        {
            try transform(self.quanta[$0].storage)
        }
    }
}
extension JPEG.Data.Spectral.Quanta:RandomAccessCollection 
{
    public 
    var startIndex:Int 
    {
        // don’t include the default quanta
        self.quanta.startIndex + 1
    }
    public 
    var endIndex:Int 
    {
        self.quanta.endIndex
    }
    
    public 
    subscript(q:Int) -> JPEG.Table.Quantization
    {
        _read 
        {
            yield  self.quanta[q]
        }
        _modify 
        {
            yield &self.quanta[q]
        }
    }
    
    public 
    func index(forKey qi:JPEG.Table.Quantization.Key) -> Int? 
    {
        self.q[qi]
    }
}
extension JPEG.Data.Spectral:RandomAccessCollection 
{
    public 
    var startIndex:Int 
    {
        self.planes.startIndex
    }
    public 
    var endIndex:Int 
    {
        self.planes.endIndex
    }
    
    public 
    subscript(p:Int) -> Plane 
    {
        _read  
        {
            yield  self.planes[p]
        }
        _modify
        {
            yield &self.planes[p]
        }
    }
    
    public 
    func index(forKey ci:JPEG.Component.Key) -> Int? 
    {
        self.layout.index(ci: ci)
    }
}
extension JPEG.Data.Planar:RandomAccessCollection 
{
    public 
    var startIndex:Int 
    {
        self.planes.startIndex
    }
    public 
    var endIndex:Int 
    {
        self.planes.endIndex
    }
    
    public 
    subscript(p:Int) -> Plane 
    {
        _read  
        {
            yield  self.planes[p]
        }
        _modify
        {
            yield &self.planes[p]
        }
    }
    
    public 
    func index(forKey ci:JPEG.Component.Key) -> Int? 
    {
        self.layout.index(ci: ci)
    }
}
extension JPEG.Data.Rectangular 
{
    public 
    subscript(x x:Int, y y:Int, p:Int) -> UInt16 
    {
        get 
        {
            self.values[p + self.stride * (x + self.size.x * y)]
        }
        set(value) 
        {
            self.values[p + self.stride * (x + self.size.x * y)] = value
        }
    }
    
    public 
    func offset(forKey ci:JPEG.Component.Key) -> Int? 
    {
        self.layout.index(ci: ci)
    }
}
// `indices` property for plane types 
extension JPEG.Data.Spectral.Plane 
{
    public 
    var indices:Common.Range2<Int> 
    {
        (0, 0) ..< self.units 
    }
}
extension JPEG.Data.Planar.Plane 
{
    public 
    var indices:Common.Range2<Int> 
    {
        (0, 0) ..< self.size 
    }
}

// “with” regulated accessors for plane mutation by component index 
extension JPEG.Data.Spectral 
{
    // cannot have both of them named `with(ci:_)` since this leads to ambiguity 
    // at the call site
    public 
    func read<R>(ci:JPEG.Component.Key, 
        body:(Plane, JPEG.Table.Quantization) throws -> R) 
        rethrows -> R
    {
        guard let p:Int = self.index(forKey: ci)
        else 
        {
            fatalError("component key out of range")
        }
        return try body(self[p], self.quanta[self[p].q])
    }
    public mutating 
    func with<R>(ci:JPEG.Component.Key, 
        body:(inout Plane, JPEG.Table.Quantization) throws -> R) 
        rethrows -> R
    {
        guard let p:Int = self.index(forKey: ci)
        else 
        {
            fatalError("component key out of range")
        }
        return try body(&self[p], self.quanta[self[p].q])
    }
}
extension JPEG.Data.Planar 
{
    // cannot have both of them named `with(ci:_)` since this leads to ambiguity 
    // at the call site
    public 
    func read<R>(ci:JPEG.Component.Key, 
        body:(Plane) throws -> R) 
        rethrows -> R
    {
        guard let p:Int = self.index(forKey: ci)
        else 
        {
            fatalError("component key out of range")
        }
        return try body(self[p])
    }
    public mutating 
    func with<R>(ci:JPEG.Component.Key, 
        body:(inout Plane) throws -> R) 
        rethrows -> R
    {
        guard let p:Int = self.index(forKey: ci)
        else 
        {
            fatalError("component key out of range")
        }
        return try body(&self[p])
    }
}

// shared properties needed for initializing planar, spectral, and other layout types 
extension JPEG.Layout 
{
    public 
    var scale:(x:Int, y:Int) 
    {
        self.planes.reduce((0, 0))
        {
            (
                Swift.max($0.x, $1.component.factor.x), 
                Swift.max($0.y, $1.component.factor.y)
            )
        }
    }
    
    public 
    var components:
    [
        JPEG.Component.Key: (factor:(x:Int, y:Int), qi:JPEG.Table.Quantization.Key)
    ] 
    {
        self.residents.mapValues 
        {
            (self.planes[$0].component.factor, self.planes[$0].qi)
        }
    }
}
// spectral type APIs
extension JPEG.Data.Spectral.Plane 
{
    init(factor:(x:Int, y:Int))
    {
        self.buffer     = []
        self.units      = (0, 0)
        self._q         = .init(wrappedValue: 0) // the default quanta (qi = -1)
        self._factor    = .init(wrappedValue: factor)
    }
    
    // used by the `fdct(_:quanta:precision:)` function defined in `encode.swift`
    mutating 
    func set(values:[Int16], units:(x:Int, y:Int))
    {
        precondition(values.count == 64 * units.x * units.y)
        self.buffer = values 
        self.units  = units
    }
    // width is in units, not pixels 
    mutating 
    func set(width x:Int) 
    {
        guard x != self.units.x 
        else 
        {
            return 
        }
        
        let count:Int   = 64 * x * self.units.y
        let new:[Int16] = .init(unsafeUninitializedCapacity: count) 
        {
            guard let base:UnsafeMutablePointer<Int16> = $0.baseAddress 
            else 
            {
                $1 = 0 
                return 
            }
            
            self.buffer.withUnsafeBufferPointer 
            {
                guard let source:UnsafePointer<Int16> = $0.baseAddress 
                else 
                {
                    base.initialize(repeating: 0, count: count)
                    return 
                }
                
                let stride:(old:Int, new:Int) = 
                (
                    64 * self.units.x, 
                    64 * x
                )
                if stride.old < stride.new 
                {
                    for y:Int in 0 ..< self.units.y
                    {
                        (base + y * stride.new             ).initialize(
                            from: source + y * stride.old, count: stride.old)
                        (base + y * stride.new + stride.old).initialize(
                            repeating: 0, count: stride.new - stride.old)
                    }
                }
                else 
                {
                    for y:Int in 0 ..< self.units.y
                    {
                        (base + y * stride.new             ).initialize(
                            from: source + y * stride.old, count: stride.new)
                    }
                }
            }
            
            $1 = count 
        }
        
        self.buffer  = new 
        self.units.x = x
    }
    mutating 
    func set(height y:Int) 
    {
        guard y != self.units.y 
        else 
        {
            return 
        }
        
        let count:Int   = 64 * self.units.x * y, 
            change:Int  = count - self.buffer.count
        if  change < 0
        {
            self.buffer.removeLast(-change)
        }
        else 
        {
            self.buffer.append(contentsOf: repeatElement(0, count: change))
        }
        
        self.units.y = y
    }
    
    @inlinable
    public 
    subscript(x x:Int, y y:Int, k k:Int, h h:Int) -> Int16 
    {
        get 
        {
            self[x: x, y: y, z: JPEG.Table.Quantization.z(k: k, h: h)]
        }
        set(value)
        {
            self[x: x, y: y, z: JPEG.Table.Quantization.z(k: k, h: h)] = value 
        }
    }
}
extension JPEG.Data.Spectral 
{
    // this function is supposed to match the public `encode()` function, 
    // but since it returns an incomplete Spectral struct, we don’t make it public 
    // (even if that makes the name of the `encode()` function not make any sense 
    // anymore)
    static 
    func decode(frame:JPEG.Header.Frame) throws -> Self 
    {
        // catch unsupported processes
        switch frame.process 
        {
        case    .baseline, 
                .extended   (coding: .huffman, differential: false),
                .progressive(coding: .huffman, differential: false):
            break 
        default:
            throw JPEG.DecodingError.unsupportedFrameCodingProcess(frame.process)
        }
        
        // recognize format 
        guard let format:Format = 
            .recognize(.init(frame.components.keys), precision: frame.precision)
        else 
        {
            throw JPEG.DecodingError.unrecognizedColorFormat(
                .init(frame.components.keys), frame.precision, Format.self)
        }
        
        let layout:JPEG.Layout<Format> = 
            .init(format: format, process: frame.process, components: frame.components)
        
        var spectral:Self = .init(layout: layout)
            spectral.set(width:  frame.size.x)
            spectral.set(height: frame.size.y)
        return spectral 
    }
    
    public 
    init(size:(x:Int, y:Int), layout:JPEG.Layout<Format>, 
        quanta:[JPEG.Table.Quantization.Key: [UInt16]], 
        metadata:[JPEG.Metadata])
    {
        self.init(layout: layout)
        self.set(width:   size.x)
        self.set(height:  size.y)
        self.set(quanta:  quanta)
        
        self.metadata.append(contentsOf: metadata)
    }
    
    init(layout:JPEG.Layout<Format>)  
    {
        self.layout     = layout
        
        self.metadata   = [] 
        self.planes     = layout.recognized.indices.map 
        {
            .init(factor: layout.planes[$0].component.factor)
        }
        self.quanta     = .init(default: .init(
            precision:  layout.format.precision > 8 ? .uint16 : .uint8, 
            values:     .init(repeating: 0, count: 64), 
            target:     \.0))
        
        self.size       = (0, 0)
        self.blocks     = (0, 0)
    }
    
    // width in pixels 
    public mutating 
    func set(width x:Int) 
    {
        let scale:Int = self.layout.scale.x
        self.blocks.x   = JPEG.Data.units(x, stride: 8 * scale)
        self.size.x     = x
        for p:Int in self.indices
        {
            //        x * factor 
            // ceil( ------------ )
            //        8 * scale 
            let u:Int = JPEG.Data.units(x * self[p].factor.x, stride: 8 * scale)
            self[p].set(width: u)
        }
    }
    public mutating 
    func set(height y:Int) 
    {
        let scale:Int = self.layout.scale.y
        self.blocks.y   = JPEG.Data.units(y, stride: 8 * scale)
        self.size.y     = y
        for p:Int in self.indices
        {
            let u:Int = JPEG.Data.units(y * self[p].factor.y, stride: 8 * scale)
            self[p].set(height: u)
        }
    }
    
    public mutating 
    func set(quanta:[JPEG.Table.Quantization.Key: [UInt16]])
    {
        self.quanta.removeAll()
        for (ci, c):(JPEG.Component.Key, Int) in self.layout.residents
        {
            let qi:JPEG.Table.Quantization.Key = self.layout.planes[c].qi
            let q:Int 
            if let index:Int = self.quanta.index(forKey: qi)
            {
                q = index 
            }
            else 
            {
                guard let values:[UInt16] = quanta[qi]
                else 
                {
                    fatalError("missing quantization table for component \(ci)")
                }
                
                let table:JPEG.Table.Quantization = .init(
                    precision: self.layout.format.precision > 8 ? .uint16 : .uint8, 
                    values:    values, 
                    target:    self.layout.planes[c].component.selector)
                
                q = self.quanta.push(qi: qi, quanta: table)
            }
            
            if let p:Int = self.index(forKey: ci)
            {
                self[p].q = q 
            }
        }
    }
    
    mutating 
    func push(qi:JPEG.Table.Quantization.Key, quanta:JPEG.Table.Quantization) 
        throws -> Int 
    {
        switch (self.layout.format.precision, quanta.precision) 
        {
        // the only thing the jpeg standard says about this is “an 8-bit dct-based 
        // process shall not use a 16-bit quantization table”
        case    (1 ... 16, .uint8), 
                (9 ... 16, .uint16):
            break 
        default:
            throw JPEG.DecodingError.invalidScanQuantizationPrecision(quanta.precision)
        } 
        
        self.layout.push(qi: qi)
        return self.quanta.push(qi: qi, quanta: quanta)
    }
}
extension JPEG.Data.Planar 
{
    public 
    init(size:(x:Int, y:Int), layout:JPEG.Layout<Format>, 
        metadata:[JPEG.Metadata])
    {
        self.layout     = layout

        self.size       = size
        self.metadata   = metadata
        
        let scale:(x:Int, y:Int)    = layout.scale
        let midpoint:UInt16         = 1 << (layout.format.precision - 1 as Int)
        self.planes                 = layout.recognized.indices.map 
        {
            let factor:(x:Int, y:Int) = layout.planes[$0].component.factor
            let units:(x:Int, y:Int)  = 
            (
                JPEG.Data.units(size.x * factor.x, stride: 8 * scale.x),
                JPEG.Data.units(size.y * factor.y, stride: 8 * scale.y)
            )
            
            let blank:[UInt16] = .init(repeating: midpoint, 
                count: 64 * units.x * units.y)
            return .init(blank, units: units, factor: factor)
        }
    }
}

// huffman symbol and composite value semantics 

// entropy-coded bitstreams look like this (not all intervals may be present)
//
//     |<----------- composite value --------->|
//     |<------- symbol -------->|
// ... [ zeroes:binade or binade ][    tail    ][ refining bits ] ...
//
// the refining bits are *not* part of the composite values (even though 
// the composite values themselves have trailing “extra bits”). the difference 
// between the “extra bits” (tail) and the refining bits is that the length 
// of the tail is completely determined by the value of the preceeding symbol, 
// whereas the number of refining bits can depend on previously decoded information
// 
// note: in a DC refining scan, the composite values do not exist, and each 
// coefficient gets exactly one refining bit. in an AC refining scan, the 
// number of refining bits is the same as the number of non-zero previously-
// decoded coefficients within the run described by the symbol `zeroes` field
extension JPEG.Bitstream.Symbol.DC
{
    // SSSS
    var binade:Int 
    {
        .init(self.value)
    }
}
extension JPEG.Bitstream.Symbol.AC 
{
    // RRRR
    var zeroes:Int
    {
        .init(self.value >> 4)
    }
    // SSSS
    var binade:Int 
    {
        .init(self.value & 0x0f)
    }
}
extension JPEG.Bitstream
{
    public 
    enum Composite 
    {
        public 
        struct DC 
        {
            public 
            let difference:Int16 
            
            public 
            init(difference:Int16) 
            {
                self.difference = difference
            }
        }
        public 
        enum AC 
        {
            case run(Int, value:Int16)
            case eob(Int)
        }
    }
    
    static 
    func extend<I>(binade:Int, _ tail:UInt16, as _:I.Type) -> I
        where I:FixedWidthInteger & SignedInteger
    {
        assert(binade > 0)
        // 0 for lower half of range, 1 for upper half 
        let sign:UInt16     = tail &>> (binade &- 1)
        // [0000 0000 0000 0000]
        // [1111 1111 1100 0000]
        let high:UInt16     = (0xffff &+ sign) &<< binade  
        let low:UInt16      = tail &+ (sign ^ 1)
        let combined:Int16  = .init(bitPattern: high | low)
        return .init(combined)
    }
    
    static 
    func compact<I>(_ x:I) -> (binade:Int, tail:UInt16)
        where I:FixedWidthInteger & SignedInteger
    {
        let x:Int16         = .init(x)
        // one of the advantages of swift is that we can query this through a CPU 
        // intrinsic as opposed to loop-based queries found in much example c code 
        let position:Int    = abs(x).leadingZeroBitCount
        let binade:Int      = Int16.bitWidth &- position
        
        let sign:UInt16     = .init(bitPattern: x) &>> (Int16.bitWidth - 1)
        // can use &<< because binade is always less than 16 (because of abs(_:) when 
        // computing `position`)
        let tail:UInt16     = (.init(bitPattern: x) &- sign) & ~(.max &<< binade)
        return (binade: binade, tail: tail)
    }
    
    func refinement(_ i:inout Int) throws -> Int16
    {
        guard i < self.count 
        else 
        {
            throw JPEG.DecodingError.truncatedEntropyCodedSegment
        }
        
        defer 
        {
            i += 1
        }
        return self[i, as: Int16.self]
    }
    
    func composite(_ i:inout Int, table:JPEG.Table.HuffmanDC.Decoder) throws -> Composite.DC  
    {
        // read SSSS:[extra] (huffman coded)
        guard i < self.count 
        else 
        {
            throw JPEG.DecodingError.truncatedEntropyCodedSegment
        }
        
        let entry:JPEG.Table.HuffmanDC.Decoder.Entry    = table[self[i, count: 16]]
        let binade:Int                                  = entry.symbol.binade 
        i += entry.length
        
        guard binade > 0
        else  
        {
            return .init(difference: 0) 
        }
        
        // read `binade` additional bits (raw)
        guard i + binade <= self.count 
        else 
        {
            throw JPEG.DecodingError.truncatedEntropyCodedSegment
        }
        defer 
        {
            i += binade
        }
        
        let value:Int16 = Self.extend(binade: binade, self[i, count: binade], as: Int16.self)
        return .init(difference: value)
    }
    
    func composite(_ i:inout Int, table:JPEG.Table.HuffmanAC.Decoder) throws -> Composite.AC  
    {
        // read RRRR:SSSS:[extra] (huffman coded)
        guard i < self.count 
        else 
        {
            throw JPEG.DecodingError.truncatedEntropyCodedSegment
        }
        
        let entry:JPEG.Table.HuffmanAC.Decoder.Entry    = table[self[i, count: 16]]
        let zeroes:Int                                  = entry.symbol.zeroes, 
            binade:Int                                  = entry.symbol.binade 
        i += entry.length
        
        switch (zeroes, binade) 
        {
        case (0,        0):
            return .eob(1)
        case (1 ... 14, 0):
            // read `zeroes` additional bits (raw)
            guard i + zeroes <= self.count 
            else 
            {
                throw JPEG.DecodingError.truncatedEntropyCodedSegment
            } 
            defer 
            {
                i += zeroes
            }
            
            let run:Int = 1 &<< zeroes | .init(self[i, count: zeroes])
            return .eob(run)
        
        case (_,        0):
            return .run(15, value: 0) // `zeroes` is always in the range `0 ... 15`
        
        default:
            guard i + binade <= self.count 
            else 
            {
                throw JPEG.DecodingError.truncatedEntropyCodedSegment
            }
            defer 
            {
                i += binade
            }
            
            let value:Int16 = Self.extend(binade: binade, self[i, count: binade], as: Int16.self)
            return .run(zeroes, value: value)
        }
    }
}

// decoding processes
extension JPEG.Data.Spectral.Plane 
{
    // sequential mode 
    mutating 
    func decode(_ data:[UInt8], component:JPEG.Scan.Component, 
        tables slots:(dc:JPEG.Table.HuffmanDC.Slots, ac:JPEG.Table.HuffmanAC.Slots)) throws 
    {
        guard let dc:JPEG.Table.HuffmanDC.Decoder = 
            slots.dc[keyPath: component.selector.dc]?.decoder()
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanDCReference(component.selector.dc)
        }
        guard let ac:JPEG.Table.HuffmanAC.Decoder = 
            slots.ac[keyPath: component.selector.ac]?.decoder()
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanACReference(component.selector.ac)
        }
        
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        var predecessor:Int16   = 0
        row: 
        for y:Int in 0... 
        {
            guard b < bits.count, bits[b, count: 16] != 0xffff 
            else 
            {
                break row 
            }
            
            if y >= self.units.y
            {
                self.set(height: y + 1)
            }
            
            column:
            for x:Int in 0 ..< self.units.x 
            {
                // dc
                let composite:JPEG.Bitstream.Composite.DC = try bits.composite(&b, table: dc)
                predecessor           &+= composite.difference
                self[x: x, y: y, z: 0]  = predecessor 
                
                // ac
                var z:Int = 1
                frequency: 
                while z < 64
                {
                    switch try bits.composite(&b, table: ac)
                    {
                    case .run(let run, value: let v):
                        z += run 
                        
                        guard z < 64
                        else 
                        {
                            break frequency
                        }
                        
                        self[x: x, y: y, z: z] = v 
                        z += 1
                    
                    case .eob(1):
                        break frequency
                    
                    case .eob(let v):
                        throw JPEG.DecodingError.invalidCompositeBlockRun(v, expected: 1 ... 1)
                    }
                } 
            }
        }
    }
    
    // progressive mode 
    mutating 
    func decode(_ data:[UInt8], bits a:PartialRangeFrom<Int>, component:JPEG.Scan.Component, 
        tables slots:JPEG.Table.HuffmanDC.Slots) throws 
    {
        guard let table:JPEG.Table.HuffmanDC.Decoder = 
            slots[keyPath: component.selector.dc]?.decoder()
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanDCReference(component.selector.dc)
        }
        
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        var predecessor:Int16   = 0
        row: 
        for y:Int in 0... 
        {
            guard b < bits.count, bits[b, count: 16] != 0xffff 
            else 
            {
                break row 
            }
            
            if y >= self.units.y
            {
                self.set(height: y + 1)
            }
            
            column:
            for x:Int in 0 ..< self.units.x 
            {
                let composite:JPEG.Bitstream.Composite.DC = try bits.composite(&b, table: table)
                // it’s not well-defined what should happen if the dc coefficients 
                // overflow, so we just use Int16 wraparound to avoid crashing 
                predecessor           &+= composite.difference
                self[x: x, y: y, z: 0]  = predecessor << a.lowerBound
            }
        }
    } 
    
    mutating 
    func decode(_ data:[UInt8], bit a:Int) throws 
    {
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        for (x, y):(Int, Int) in (0, 0) ..< self.units 
        {
            let refinement:Int16    = try bits.refinement(&b)
            self[x: x, y: y, z: 0] |= refinement << a
        }
    }
    
    mutating 
    func decode(_ data:[UInt8], band:Range<Int>, bits a:PartialRangeFrom<Int>, 
        component:JPEG.Scan.Component, tables slots:JPEG.Table.HuffmanAC.Slots) throws
    {
        guard let table:JPEG.Table.HuffmanAC.Decoder = 
            slots[keyPath: component.selector.ac]?.decoder()
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanACReference(component.selector.ac)
        }
        
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0, 
            skip:Int            = 0
        for (x, y):(Int, Int) in (0, 0) ..< self.units
        {
            var z:Int = band.lowerBound
            frequency: 
            while z < band.upperBound  
            {
                guard skip == 0
                else  
                {
                    skip -= 1
                    break frequency 
                } 
                
                switch try bits.composite(&b, table: table)
                {
                case .run(let run, value: let v):
                    z += run 
                    
                    guard z < band.upperBound 
                    else 
                    {
                        break frequency
                    }
                    
                    self[x: x, y: y, z: z] = v << a.lowerBound
                    z += 1
                
                case .eob(let blocks):
                    skip   = blocks - 1
                    break frequency 
                }
            } 
        }
    }
    
    mutating 
    func decode(_ data:[UInt8], band:Range<Int>, bit a:Int, 
        component:JPEG.Scan.Component, tables slots:JPEG.Table.HuffmanAC.Slots) throws
    {
        guard let table:JPEG.Table.HuffmanAC.Decoder = 
            slots[keyPath: component.selector.ac]?.decoder()
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanACReference(component.selector.ac)
        }
        
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0, 
            skip:Int            = 0
        for (x, y):(Int, Int) in (0, 0) ..< self.units
        {
            var z:Int = band.lowerBound
            frequency:
            while z < band.upperBound  
            {
                let zeroes:Int, 
                    delta:Int16
                if skip > 0 
                {
                    zeroes = 64 
                    delta  = 0
                    skip  -= 1
                } 
                else 
                {
                    switch try bits.composite(&b, table: table)
                    {
                    case .run(let run, value: let v):
                        guard -1 ... 1 ~= v 
                        else 
                        {
                            throw JPEG.DecodingError.invalidCompositeValue(v, expected: -1 ... 1)
                        }
                        
                        zeroes = run 
                        delta  = v 
                    
                    case .eob(let blocks):
                        zeroes = 64 
                        delta  = 0 
                        skip   = blocks - 1
                    }
                }
                
                var skipped:Int = 0
                repeat  
                {
                    defer 
                    {
                        z += 1
                    }
                    
                    let unrefined:Int16 = self[x: x, y: y, z: z]
                    if unrefined == 0 
                    {
                        guard skipped < zeroes 
                        else 
                        {
                            self[x: x, y: y, z: z] = delta << a
                            continue frequency  
                        }
                        
                        skipped += 1
                    }
                    else 
                    {
                        let delta:Int16 = (unrefined < 0 ? -1 : 1) * (try bits.refinement(&b))
                        self[x: x, y: y, z: z] &+= delta << a
                    }
                } while z < band.upperBound
                
                break frequency
            }
        } 
    }
}
extension JPEG.Data.Spectral  
{
    // sequential mode 
    private mutating 
    func decode(_ data:[UInt8], components:[(c:Int, component:JPEG.Scan.Component)], 
        tables slots:(dc:JPEG.Table.HuffmanDC.Slots, ac:JPEG.Table.HuffmanAC.Slots)) throws 
    {
        guard components.count > 1 
        else 
        {
            // noninterleaved
            precondition(components.count == 1, "components array cannot be empty")
            let (p, component):(Int, JPEG.Scan.Component) = components[0]
            guard self.indices ~= p
            else 
            {
                return 
            }
            
            try self[p].decode(data, component: component, tables: slots)
            return 
        }
        
        typealias Descriptor = 
        (
            p:Int?, 
            factor:(x:Int, y:Int), 
            table:(dc:JPEG.Table.HuffmanDC.Decoder, ac:JPEG.Table.HuffmanAC.Decoder)
        )
        let descriptors:[Descriptor] = try components.map 
        {
            guard let dc:JPEG.Table.HuffmanDC.Decoder = 
                slots.dc[keyPath: $0.component.selector.dc]?.decoder()
            else 
            {
                throw JPEG.DecodingError.undefinedScanHuffmanDCReference($0.component.selector.dc)
            }
            guard let ac:JPEG.Table.HuffmanAC.Decoder = 
                slots.ac[keyPath: $0.component.selector.ac]?.decoder()
            else 
            {
                throw JPEG.DecodingError.undefinedScanHuffmanACReference($0.component.selector.ac)
            }
            
            let factor:(x:Int, y:Int) = self.layout.planes[$0.c].component.factor
            return (self.indices ~= $0.c ? $0.c : nil, factor, (dc, ac))
        }
        
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        var predecessor:[Int16] = .init(repeating: 0, count: descriptors.count)
        row:
        for my:Int in 0... 
        {
            guard b < bits.count, bits[b, count: 16] != 0xffff 
            else 
            {
                break row 
            }
            
            for (p, factor, _):Descriptor in descriptors 
            {
                guard let p:Int = p 
                else 
                {
                    continue 
                }
                
                let height:Int = (my + 1) * factor.y
                if height > self[p].units.y
                {
                    self[p].set(height: height)
                }
            }
            
            column:
            for mx:Int in 0 ..< self.blocks.x 
            {
                for (c, (p, factor, table)):(Int, Descriptor) in zip(predecessor.indices, descriptors)
                {
                    let start:(x:Int, y:Int) = (     mx * factor.x,      my * factor.y), 
                        end:(x:Int, y:Int)   = (start.x + factor.x, start.y + factor.y) 
                    for (x, y):(Int, Int) in start ..< end 
                    {
                        // dc 
                        let composite:JPEG.Bitstream.Composite.DC = 
                            try bits.composite(&b, table: table.dc)
                        
                        if let p:Int = p 
                        {
                            predecessor[c]            &+= composite.difference 
                            self[p][x: x, y: y, z: 0]   = predecessor[c]  
                        }
                        
                        // ac
                        var z:Int = 1
                        frequency: 
                        while z < 64
                        {
                            switch try bits.composite(&b, table: table.ac)
                            {
                            case .run(let run, value: let v):
                                z += run 
                                
                                guard z < 64
                                else 
                                {
                                    break frequency 
                                } 
                                
                                if let p:Int = p 
                                {
                                    self[p][x: x, y: y, z: z] = v  
                                }
                                
                                z += 1
                            
                            case .eob(1):
                                break frequency
                            
                            case .eob(let v):
                                throw JPEG.DecodingError.invalidCompositeBlockRun(v, expected: 1 ... 1)
                            }
                        } 
                    }
                }
            }
        }
    }
    
    // progressive mode 
    private mutating 
    func decode(_ data:[UInt8], bits a:PartialRangeFrom<Int>, 
        components:[(c:Int, component:JPEG.Scan.Component)], 
        tables slots:JPEG.Table.HuffmanDC.Slots) throws
    {
        // it is allowed (in the case of a custom implementation of `Format`) for 
        // jpegs to encode components that aren’t represented by a plane in this 
        // data structure. hence, the `p:Int?` being an optional. 
        // the scan header parser should enforce the membership of the `ci` index 
        // in the frame header, we don’t care about that here 
        guard components.count > 1 
        else 
        {
            // noninterleaved
            precondition(components.count == 1, "components array cannot be empty")
            let (p, component):(Int, JPEG.Scan.Component) = components[0]
            guard self.indices ~= p
            else 
            {
                return 
            }
            
            try self[p].decode(data, bits: a, component: component, tables: slots)
            return 
        }
        
        typealias Descriptor = (p:Int?, factor:(x:Int, y:Int), table:JPEG.Table.HuffmanDC.Decoder)
        let descriptors:[Descriptor] = try components.map 
        {
            guard let huffman:JPEG.Table.HuffmanDC.Decoder = 
                slots[keyPath: $0.component.selector.dc]?.decoder()
            else 
            {
                throw JPEG.DecodingError.undefinedScanHuffmanDCReference($0.component.selector.dc)
            }
            let factor:(x:Int, y:Int) = self.layout.planes[$0.c].component.factor
            return (self.indices ~= $0.c ? $0.c : nil, factor, huffman)
        }
        
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        var predecessor:[Int16] = .init(repeating: 0, count: descriptors.count)
        row:
        for my:Int in 0... 
        {
            guard b < bits.count, bits[b, count: 16] != 0xffff 
            else 
            {
                break row 
            }
            
            for (p, factor, _):Descriptor in descriptors 
            {
                guard let p:Int = p 
                else 
                {
                    continue 
                }
                
                let height:Int = (my + 1) * factor.y
                if height > self[p].units.y
                {
                    self[p].set(height: height)
                }
            }
            
            column:
            for mx:Int in 0 ..< self.blocks.x 
            {
                for (c, (p, factor, table)):(Int, Descriptor) in zip(predecessor.indices, descriptors)
                {
                    let start:(x:Int, y:Int) = (     mx * factor.x,      my * factor.y), 
                        end:(x:Int, y:Int)   = (start.x + factor.x, start.y + factor.y) 
                    for (x, y):(Int, Int) in start ..< end 
                    {
                        let composite:JPEG.Bitstream.Composite.DC = 
                            try bits.composite(&b, table: table)
                        
                        guard let p:Int = p 
                        else 
                        {
                            continue 
                        }
                        
                        predecessor[c]            &+= composite.difference 
                        self[p][x: x, y: y, z: 0]   = predecessor[c] << a.lowerBound
                    }
                }
            }
        }
    }
    
    private mutating 
    func decode(_ data:[UInt8], bit a:Int, 
        components:[(c:Int, component:JPEG.Scan.Component)]) throws
    {
        guard components.count > 1 
        else 
        {
            // noninterleaved
            precondition(components.count == 1, "components array cannot be empty")
            let p:Int = components[0].c
            guard self.indices ~= p
            else 
            {
                return 
            }
            
            try self[p].decode(data, bit: a)
            return 
        }
        
        typealias Descriptor = (p:Int?, factor:(x:Int, y:Int))
        let descriptors:[Descriptor] = components.map 
        {
            let factor:(x:Int, y:Int) = self.layout.planes[$0.c].component.factor
            return (self.indices ~= $0.c ? $0.c : nil, factor)
        }
        
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        for (mx, my):(Int, Int) in (0, 0) ..< self.blocks 
        {
            for (p, factor):Descriptor in descriptors
            {
                let start:(x:Int, y:Int) = (     mx * factor.x,      my * factor.y), 
                    end:(x:Int, y:Int)   = (start.x + factor.x, start.y + factor.y) 
                for (x, y):(Int, Int) in start ..< end 
                {
                    let refinement:Int16 = try bits.refinement(&b) 
                    
                    guard let p:Int = p 
                    else 
                    {
                        continue 
                    }
                    
                    self[p][x: x, y: y, z: 0] |= refinement << a
                }
            }
        }
    } 
    
    // this function doesn’t actually dequantize anything, it just sets the quantization 
    // table pointer in the relevant plane structs to the corresponding quantization 
    // table already in `self`
    private mutating 
    func dequantize(components:[(c:Int, component:JPEG.Scan.Component)], 
        tables slots:JPEG.Table.Quantization.Slots) throws
    {
        for (p, _):(Int, JPEG.Scan.Component) in components 
        {
            guard self.indices ~= p
            else 
            {
                continue  
            }
            
            let selector:JPEG.Table.Quantization.Selector        = 
                self.layout.planes[p].component.selector
            guard let (q, qi):(Int, JPEG.Table.Quantization.Key) = slots[keyPath: selector]
            else 
            {
                throw JPEG.DecodingError.undefinedScanQuantizationReference(selector)
            }
            
            self[p].q                = q
            self.layout.planes[p].qi = qi
        }
    }
    
    public mutating 
    func decode(_ data:[UInt8], scan:JPEG.Header.Scan, tables slots:
        (
            dc:JPEG.Table.HuffmanDC.Slots, 
            ac:JPEG.Table.HuffmanAC.Slots,
            quanta:JPEG.Table.Quantization.Slots
        )) throws 
    {
        let scan:JPEG.Scan = try self.layout.push(scan: scan)
        
        switch (initial: scan.bits.upperBound == .max, band: scan.band)
        {
        case (initial: true,  band: 0 ..< 64):
            // sequential mode jpeg
            try self.dequantize(  components: scan.components, tables: slots.quanta)
            try self.decode(data, components: scan.components, tables: (slots.dc, slots.ac))
        
        case (initial: false, band: 0 ..< 64):
            // successive approximation cannot happen without spectral selection. 
            // the scan header parser should enforce this 
            fatalError("unreachable")
        
        case (initial: true,  band: 0 ..<  1):
            // in a progressive image, the dc scan must be the first scan for a 
            // particular component, so this is when we select and push the 
            // quantization tables
            try self.dequantize(components: scan.components, tables: slots.quanta)
            try self.decode(data, bits: scan.bits.lowerBound..., 
                components: scan.components, tables: slots.dc) 
        
        case (initial: false, band: 0 ..<  1):
            try self.decode(data, bit: scan.bits.lowerBound, components: scan.components)
        
        case (initial: true,  band: let band):
            // scan initializer should have validated this
            assert(scan.components.count == 1)
            
            let (p, component):(Int, JPEG.Scan.Component) = scan.components[0]
            guard self.indices ~= p
            else 
            {
                return 
            }
            
            try self[p].decode(data, band: band, bits: scan.bits.lowerBound..., 
                component: component, tables: slots.ac)
        
        case (initial: false, band: let band):
            // scan initializer should have validated this
            assert(scan.components.count == 1)
            
            let (p, component):(Int, JPEG.Scan.Component) = scan.components[0]
            guard self.indices ~= p
            else 
            {
                return 
            }
            
            try self[p].decode(data, band: band, bit: scan.bits.lowerBound, 
                component: component, tables: slots.ac)
        }
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
                fatalError("missing definition for component \($0) in format '\(format)'")
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
                    fatalError(error.message)
                }
                catch let error as JPEG.DecodingError // invalid progression 
                {
                    fatalError(error.message)
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
    public static 
    func sequential(_ components:
        [(
            ci:JPEG.Component.Key, 
            dc:JPEG.Table.HuffmanDC.Selector, 
            ac:JPEG.Table.HuffmanAC.Selector
        )]) -> Self 
    {
        .init(band: 0 ..< 64, bits: 0 ..< .max, 
            components: components.map{ .init(ci: $0.ci, selector: ($0.dc, $0.ac))})
    }
    
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
    
    public static 
    func progressive(_ 
        components:[(ci:JPEG.Component.Key, dc:JPEG.Table.HuffmanDC.Selector)], 
        bits:PartialRangeFrom<Int>) -> Self 
    {
        .init(band: 0 ..< 1, bits: bits.lowerBound ..< .max, 
            components: components.map{ .init(ci: $0.ci, selector: ($0.dc, \.0))})
    }
    public static 
    func progressive(_ 
        components:(ci:JPEG.Component.Key, dc:JPEG.Table.HuffmanDC.Selector)..., 
        bits:PartialRangeFrom<Int>) -> Self 
    {
        .progressive(components, bits: bits)
    }
    
    public static 
    func progressive(_ 
        components:[JPEG.Component.Key], 
        bit:Int) -> Self 
    {
        .init(band: 0 ..< 1, bits: bit ..< bit + 1, 
            components: components.map{ .init(ci: $0, selector: (\.0, \.0))})
    }
    public static 
    func progressive(_ 
        components:JPEG.Component.Key..., 
        bit:Int) -> Self 
    {
        .progressive(components, bit: bit)
    }
    
    public static 
    func progressive(_ 
        component:(ci:JPEG.Component.Key, ac:JPEG.Table.HuffmanAC.Selector), 
        band:Range<Int>, bits:PartialRangeFrom<Int>) -> Self 
    {
        .init(band: band, bits: bits.lowerBound ..< .max, 
            components: [.init(ci: component.ci, selector: (\.0, component.ac))])
    }
    
    public static 
    func progressive(_ 
        component:(ci:JPEG.Component.Key, ac:JPEG.Table.HuffmanAC.Selector), 
        band:Range<Int>, bit:Int) -> Self 
    {
        .init(band: band, bits: bit ..< bit + 1, 
            components: [.init(ci: component.ci, selector: (\.0, component.ac))])
    }
}
extension JPEG 
{
    struct Context<Format> where Format:JPEG.Format
    {
        private
        var tables:
        (
            dc:Table.HuffmanDC.Slots, 
            ac:Table.HuffmanAC.Slots, 
            quanta:Table.Quantization.Slots
        ) 
        
        private 
        var spectral:Data.Spectral<Format>, 
            progression:Layout<Format>.Progression 
        
        private 
        var counter:Int 
        
        var layout:Layout<Format> 
        {
            self.spectral.layout 
        }
    }
}
extension JPEG.Context 
{
    init(frame:JPEG.Header.Frame) throws 
    {
        self.counter        = 0
        self.spectral       = try .decode(frame: frame)
        self.progression    = .init(self.spectral.layout.recognized)
        self.tables         = 
        (
            (nil, nil, nil, nil),
            (nil, nil, nil, nil),
            (nil, nil, nil, nil)
        )
    }
    
    mutating 
    func push(height:JPEG.Header.HeightRedefinition) 
    {
        self.spectral.set(height: height.height)
    }
    mutating 
    func push(dc table:JPEG.Table.HuffmanDC) 
    {
        self.tables.dc[keyPath: table.target] = table
    }
    mutating 
    func push(ac table:JPEG.Table.HuffmanAC) 
    {
        self.tables.ac[keyPath: table.target] = table
    }
    mutating 
    func push(quanta table:JPEG.Table.Quantization) throws 
    {
        // generate a new `qi`, and get the corresponding `q` from the 
        // `spectral.push` function
        let qi:JPEG.Table.Quantization.Key          = .init(self.counter)
        let q:Int     = try self.spectral.push(qi: qi, quanta: table)
        self.counter += 1
        self.tables.quanta[keyPath: table.target]   = (q, qi)
    }
    mutating 
    func push(metadata:JPEG.Metadata) 
    {
        self.spectral.metadata.append(metadata)
    }
    
    mutating 
    func push(scan:JPEG.Header.Scan, ecs data:[UInt8]) throws 
    {
        try self.progression.update(scan)
        try self.spectral.decode(data, scan: scan, tables: self.tables)
    }
    
    static 
    func decompress<Source>(stream:inout Source) throws -> JPEG.Data.Spectral<Format> 
        where Source:JPEG.Bytestream.Source
    {
        var marker:(type:JPEG.Marker, data:[UInt8]) 
        
        // start of image 
        marker = try stream.segment()
        guard case .start = marker.type 
        else 
        {
            throw JPEG.DecodingError.missingStartOfImage(marker.type)
        }
        
        // read metadata headers. jfif and exif standard are incompatible (both 
        // segments are supposed to be the second segment in the file), but since 
        // many applications include both of them, we look for all “application”
        // segments immediately following the start-of-image 
        var metadata:[JPEG.Metadata] = []
        marker = try stream.segment()
        preamble: 
        while true 
        {
            switch marker.type
            {
            case .application(0): // JFIF 
                let jfif:JPEG.JFIF = try .parse(marker.data)
                metadata.append(.jfif(jfif))
            
            case .application(1): // EXIF 
                // unsupported 
                break  
            
            default:
                break preamble 
            }
            
            marker = try stream.segment() 
        }
        
        var dc:[JPEG.Table.HuffmanDC]           = [], 
            ac:[JPEG.Table.HuffmanAC]           = [], 
            quanta:[JPEG.Table.Quantization]    = []
        var frame:JPEG.Header.Frame?
        definitions:
        while true 
        {
            switch marker.type 
            {
            case .frame(let process):
                frame   = try .parse(marker.data, process: process)
                marker  = try stream.segment() 
                break definitions
            
            case .quantization:
                let parsed:[JPEG.Table.Quantization] = try JPEG.Table.parse(marker.data, 
                    as: JPEG.Table.Quantization.self)
                quanta.append(contentsOf: parsed)
            
            case .huffman:
                let parsed:(dc:[JPEG.Table.HuffmanDC], ac:[JPEG.Table.HuffmanAC]) = 
                    try JPEG.Table.parse(marker.data, 
                        as: (JPEG.Table.HuffmanDC.self, JPEG.Table.HuffmanAC.self))
                dc.append(contentsOf: parsed.dc)
                ac.append(contentsOf: parsed.ac)
            
            case .comment, .application:
                break 
            
            case .scan:
                throw JPEG.DecodingError.prematureScanHeader
            case .height:
                throw JPEG.DecodingError.prematureDefineHeightSegment
            case .interval:
                break 
            
            case .end:
                throw JPEG.DecodingError.prematureEndOfImage
            case .start:
                throw JPEG.DecodingError.duplicateStartOfImage
            
            // unimplemented 
            case .restart(_):
                break
            case .arithmeticCodingCondition:
                break 
            case .hierarchical:
                break 
            case .expandReferenceComponents:
                break 
            }
            
            marker = try stream.segment() 
        }
        
        // can use `!` here, previous loop cannot exit without initializing `frame`
        var context:Self = try .init(frame: frame!)
        for table:JPEG.Table.HuffmanDC in dc 
        {
            context.push(dc: table)
        }
        for table:JPEG.Table.HuffmanAC in ac 
        {
            context.push(ac: table)
        }
        for table:JPEG.Table.Quantization in quanta 
        {
            try context.push(quanta: table)
        }
        
        scans:
        while true 
        {
            switch marker.type 
            {
            case .frame:
                throw JPEG.DecodingError.duplicateFrameHeader
            
            case .quantization:
                for table:JPEG.Table.Quantization in 
                    try JPEG.Table.parse(marker.data, as: JPEG.Table.Quantization.self)
                {
                    try context.push(quanta: table)
                }
            
            case .huffman:
                let parsed:(dc:[JPEG.Table.HuffmanDC], ac:[JPEG.Table.HuffmanAC]) = 
                    try JPEG.Table.parse(marker.data, 
                        as: (JPEG.Table.HuffmanDC.self, JPEG.Table.HuffmanAC.self))
                for table:JPEG.Table.HuffmanDC in parsed.dc 
                {
                    context.push(dc: table)
                }
                for table:JPEG.Table.HuffmanAC in parsed.ac 
                {
                    context.push(ac: table)
                }
            
            case .comment, .application:
                break 
            
            case .scan:
                let scan:JPEG.Header.Scan   = try .parse(marker.data, 
                    process: context.layout.process)
                let ecs:[UInt8] 
                (ecs, marker)               = try stream.segment(prefix: true)
                
                try context.push(scan: scan, ecs: ecs)
                continue scans 
            
            case .height:
                context.push(height: try .parse(marker.data))
            
            case .interval:
                break 
            
            case .end:
                return context.spectral 
                
            case .start:
                throw JPEG.DecodingError.duplicateStartOfImage
            
            // unimplemented 
            case .restart(_):
                break
            case .arithmeticCodingCondition:
                break 
            case .hierarchical:
                break 
            case .expandReferenceComponents:
                break 
            }
            
            marker = try stream.segment() 
        }
    }
}

// signal processing and upscaling 
extension JPEG.Data.Spectral.Plane 
{
    typealias Block8x8<T> = 
        (SIMD8<T>, SIMD8<T>, SIMD8<T>, SIMD8<T>, SIMD8<T>, SIMD8<T>, SIMD8<T>, SIMD8<T>) 
        where T:SIMDScalar
    
    static 
    func transpose<T>(_ h:Block8x8<T>) -> Block8x8<T> where T:SIMDScalar
    {
        @inline(__always)
        func column(_ k:Int) -> SIMD8<T> 
        {
            .init(h.0[k], h.1[k], h.2[k], h.3[k], h.4[k], h.5[k], h.6[k], h.7[k])
        }
        
        return (column(0), column(1), column(2), column(3), 
            column(4), column(5), column(6), column(7))
    }
    
    static 
    func modulate(quanta table:JPEG.Table.Quantization, scale:Float) -> Block8x8<Float> 
    {
        @inline(__always)
        func row(_ h:Int) -> SIMD8<Float> 
        {
            scale * .init(.init(
                table[k: 0, h: h],
                table[k: 1, h: h],
                table[k: 2, h: h],
                table[k: 3, h: h],
                
                table[k: 4, h: h],
                table[k: 5, h: h],
                table[k: 6, h: h],
                table[k: 7, h: h]))
        }
        
        let r:SIMD8<Float>          = .init(
            1, 1.387039845, 1.306562965, 1.175875602, 
            1, 0.785694958, 0.541196100, 0.275899379)
        let h:Block8x8<Float>       = (r, r, r, r, r, r, r, r), 
            v:Block8x8<Float>       = Self.transpose(h)
        return 
            (
            h.0 * v.0 * row(0), 
            h.1 * v.1 * row(1), 
            h.2 * v.2 * row(2), 
            h.3 * v.3 * row(3), 
            h.4 * v.4 * row(4), 
            h.5 * v.5 * row(5), 
            h.6 * v.6 * row(6), 
            h.7 * v.7 * row(7)
            )
    }
    
    fileprivate 
    func load(x:Int, y:Int, quanta:Block8x8<Float>) -> Block8x8<Float>
    {
        @inline(__always)
        func row(_ h:Int) -> SIMD8<Float> 
        {
            .init(.init(
                self[x: x, y: y, k: 0, h: h],
                self[x: x, y: y, k: 1, h: h],
                self[x: x, y: y, k: 2, h: h],
                self[x: x, y: y, k: 3, h: h],
                
                self[x: x, y: y, k: 4, h: h],
                self[x: x, y: y, k: 5, h: h],
                self[x: x, y: y, k: 6, h: h],
                self[x: x, y: y, k: 7, h: h]))
        }
        
        return (quanta.0 * row(0), quanta.1 * row(1), quanta.2 * row(2), quanta.3 * row(3), 
            quanta.4 * row(4), quanta.5 * row(5), quanta.6 * row(6), quanta.7 * row(7))
    }
    
    private static 
    func idct8(_ h:Block8x8<Float>, shift:Float) -> Block8x8<Float>
    {
        // even rows 
        let a:(SIMD8<Float>, SIMD8<Float>) = 
        (
            shift + h.0 + h.4,
            shift + h.0 - h.4
        )
        let b:SIMD8<Float> =                h.2 + h.6, 
            c:SIMD8<Float> = 1.414213562 * (h.2 - h.6) - b
        
        let r:(SIMD8<Float>, SIMD8<Float>, SIMD8<Float>, SIMD8<Float>) = 
        (
            a.0     +     b, 
                a.1 + c, 
                a.1 - c,
            a.0     -     b
        )
        // odd rows 
        let d:(SIMD8<Float>, SIMD8<Float>, SIMD8<Float>, SIMD8<Float>) = 
        (
            h.5     -     h.3,
                h.1 + h.7    ,
                h.1 - h.7    ,
            h.5     +     h.3
        )
        let f:SIMD8<Float> = 1.414213562 * (d.1 - d.3), 
            l:SIMD8<Float> = 1.847759065 * (d.0 + d.2)
        let m:(SIMD8<Float>, SIMD8<Float>) = 
        (
            l - d.2 * 1.082392200,
            l - d.0 * 2.613125930
        )
        let s:(SIMD8<Float>, SIMD8<Float>, SIMD8<Float>, SIMD8<Float>)
        s.0 = d.1 + d.3
        s.1 = m.1 - s.0
        s.2 = f   - s.1
        s.3 = m.0 - s.2
        
        return 
            (
            r.0 + s.0,
            r.1 + s.1,
            r.2 + s.2,
            r.3 + s.3, 
            
            r.3 - s.3,
            r.2 - s.2,
            r.1 - s.1,
            r.0 - s.0
            )
    }
    private static 
    func idct8x8(_ h:Block8x8<Float>, shift:Float) -> Block8x8<Float>
    {
        let f:Block8x8<Float>   = Self.transpose(Self.idct8(h, shift: 0)), 
            g:Block8x8<Float>   = Self.transpose(Self.idct8(f, shift: shift))
        return g
    }
    func idct(quanta table:JPEG.Table.Quantization, precision:Int) 
        -> JPEG.Data.Planar<Format>.Plane
    {
        let count:Int               = 64 * self.units.x * self.units.y 
        let values:[UInt16]         = .init(unsafeUninitializedCapacity: count) 
        {
            let q:Block8x8<Float>   = Self.modulate(quanta: table, scale: 0x1p-3)
            
            let stride:Int          = 8 * self.units.x
            let level:Float         = 
                .init(sign: .plus, exponent: precision - 1, significand: 1)  + 0.5
            let limit:SIMD8<Float>  = .init(repeating: 
                .init(sign: .plus, exponent: precision    , significand: 1)) - 1
            for (x, y):(Int, Int) in (0, 0) ..< self.units 
            {
                let h:Block8x8<Float> = self.load(x: x, y: y, quanta: q),
                    g:Block8x8<Float> = Self.idct8x8(h, shift: level)
                for (i, t):(Int, SIMD8<Float>) in 
                    [g.0, g.1, g.2, g.3, g.4, g.5, g.6, g.7].enumerated()
                {
                    let u:SIMD8<UInt16> = 
                        .init(t.clamped(lowerBound: .zero, upperBound: limit))
                    for j:Int in 0 ..< 8 
                    {
                        $0[(8 * y + i) * stride + 8 * x + j] = u[j]
                    }
                }
            }
            
            $1 = count 
        }
        return .init(values, units: self.units, factor: self.factor) 
    }
}
extension JPEG.Data.Planar.Plane 
{
    init(_ values:[UInt16], units:(x:Int, y:Int), factor:(x:Int, y:Int))
    {
        self.buffer     = values 
        self.units      = units 
        self._factor    = .init(wrappedValue: factor)
    }
}

extension JPEG.Data.Spectral 
{
    public 
    func idct() -> JPEG.Data.Planar<Format> 
    {
        let precision:Int                           = self.layout.format.precision
        let planes:[JPEG.Data.Planar<Format>.Plane] = self.indices.map 
        {
            self[$0].idct(quanta: self.quanta[self[$0].q], precision: precision)
        }
        return .init(size: self.size, 
            layout:     self.layout, 
            metadata:   self.metadata,
            planes:     planes)
    }
}
extension JPEG.Data.Planar 
{
    public 
    func interleaved(cosite cosited:Bool = false) -> JPEG.Data.Rectangular<Format> 
    {
        var interleaved:[UInt16] 
        if self.count == 1 
        {
            let count:Int   = self.size.x * self.size.y
            interleaved     = .init(unsafeUninitializedCapacity: count)
            {
                for (x, y):(Int, Int) in (0, 0) ..< self.size 
                {
                    $0[y * self.size.x + x] = self[0][x: x, y: y] 
                }
                
                $1 = count
            }
        }
        else 
        {
            let scale:(x:Int, y:Int)    = self.layout.scale
            let count:Int               = self.size.x * self.size.y * self.count
            interleaved                 = .init(unsafeUninitializedCapacity: count)
            {
                for (p, plane):(Int, Plane) in self.enumerated() 
                {
                    guard plane.factor != scale
                    else 
                    {
                        // fast path 
                        for (x, y):(Int, Int) in (0, 0) ..< self.size 
                        {
                            $0[(y * self.size.x + x) * self.count + p] = plane[x: x, y: y]
                        }
                        continue 
                    }
                    
                    //  a + b * x
                    // -----------
                    //      c
                    let a:(x:Int, y:Int),
                        b:(x:Int, y:Int), 
                        c:(x:Int, y:Int)
                    if cosited 
                    {
                        a = (0, 0)
                        b = plane.factor 
                        c = scale 
                    }
                    else 
                    {
                        a = (plane.factor.x - scale.x, plane.factor.y - scale.y)
                        b = (2 * plane.factor.x, 2 * plane.factor.y)
                        c = (2 * scale.x,        2 * scale.y)
                    }
                    let d:(x:Int, y:Int) = (plane.size.x - 1,   plane.size.y - 1)
                    for (x, y):(Int, Int) in (0, 0) ..< self.size 
                    {
                        let i:(x:Int, y:Int), 
                            f:(x:Int, y:Int)
                        (i.x, f.x) = (a.x + b.x * x).quotientAndRemainder(dividingBy: c.x)
                        (i.y, f.y) = (a.y + b.y * y).quotientAndRemainder(dividingBy: c.y)
                        
                        let j:(x:Int, y:Int)     = 
                        (
                            Swift.min(i.x + 1, d.x), 
                            Swift.min(i.y + 1, d.y)
                        )
                        let t:(x:Float, y:Float) = 
                        (
                            Swift.max(0, Swift.min(.init(f.x) / .init(c.x), 1)),
                            Swift.max(0, Swift.min(.init(f.y) / .init(c.y), 1))
                        )
                        let u:((Float, Float), (Float, Float)) = 
                        (
                            (.init(plane[x: i.x, y: i.y]), .init(plane[x: j.x, y: i.y])),
                            (.init(plane[x: i.x, y: j.y]), .init(plane[x: j.x, y: j.y]))
                        )
                        let v:(Float, Float) = 
                        (
                            u.0.0 * (1 - t.x) + u.0.1 * t.x,
                            u.1.0 * (1 - t.x) + u.1.1 * t.x
                        )
                        $0[(y * self.size.x + x) * self.count + p] = 
                            .init((v.0 * (1 - t.y) + v.1 * t.y).rounded())
                    }
                }
                
                $1 = count
            }
        }
        
        return .init(size: self.size, 
            layout:     self.layout, 
            metadata:   self.metadata, 
            values:     interleaved)
    }
}

// staged APIs 
extension JPEG.Data.Spectral 
{
    public static 
    func decompress<Source>(stream:inout Source) throws -> Self
        where Source:JPEG.Bytestream.Source 
    {
        return try JPEG.Context.decompress(stream: &stream)
    }
}
extension JPEG.Data.Planar 
{
    public static 
    func decompress<Source>(stream:inout Source) throws -> Self
        where Source:JPEG.Bytestream.Source 
    {
        let spectral:JPEG.Data.Spectral<Format> = try .decompress(stream: &stream)
        return spectral.idct()
    }
}
extension JPEG.Data.Rectangular 
{
    public static 
    func decompress<Source>(stream:inout Source) throws -> Self
        where Source:JPEG.Bytestream.Source 
    {
        let planar:JPEG.Data.Planar<Format> = try .decompress(stream: &stream) 
        return planar.interleaved()
    }
}

// pixel accessors 
extension JPEG  
{
    public 
    enum Common 
    {
        case y8
        case ycc8
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
    
    public static 
    func recognize(_ components:Set<JPEG.Component.Key>, precision:Int) -> Self? 
    {
        switch (components.sorted(), precision) 
        {
        case ([1],          8): 
            return .y8
        case ([1, 2, 3],    8): 
            return .ycc8
        default:
            return nil
        }
    }
    
    public 
    var components:[JPEG.Component.Key] 
    {
        switch self 
        {
        case .y8:
            return [1]
        case .ycc8:
            return [1, 2, 3]
        }
    }
    public 
    var precision:Int 
    {
        8
    }
}

extension JPEG.Data.Rectangular 
{
    // @_specialize(exported: true, where Color == JPEG.YCbCr, Format == JPEG.Common)
    // @_specialize(exported: true, where Color == JPEG.RGB, Format == JPEG.Common)
    public 
    func pixels<Color>(as _:Color.Type) -> [Color] 
        where Color:JPEG.Color, Color.Format == Format 
    {
        Color.pixels(self.values, format: self.layout.format)
    }
}
extension JPEG.YCbCr
{
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
    public static 
    func pixels(_ interleaved:[UInt16], format:JPEG.Common) -> [Self]
    {
        // no need to clamp uint16 to uint8,, the idct should have already done 
        // this alongside the level shift 
        switch format 
        {
        case .y8:
            return interleaved.map 
            {
                .init(y: .init($0))
            }
        
        case .ycc8:
            return stride(from: 0, to: interleaved.count, by: 3).map 
            {
                .init(
                    y:  .init(interleaved[$0    ]), 
                    cb: .init(interleaved[$0 + 1]), 
                    cr: .init(interleaved[$0 + 2]))
            }
        }
    }
}

extension JPEG.RGB:JPEG.Color 
{
    public static 
    func pixels(_ interleaved:[UInt16], format:JPEG.Common) -> [Self]
    {
        switch format 
        {
        case .y8:
            return interleaved.map 
            {
                let ycc:JPEG.YCbCr = .init(y: .init($0))
                return ycc.rgb 
            }
        
        case .ycc8:
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
}
