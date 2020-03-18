import Glibc

public 
enum JPEG 
{
    // property types 
    public 
    enum Format 
    {
        case y8
        case ycc8
    }
    
    public 
    struct Properties 
    {
        let format:Format 
    }
    
    // sample types 
    @frozen 
    public 
    struct YCbCr<Component>:Hashable where Component:FixedWidthInteger & UnsignedInteger 
    {
        /// The luminance component of this color. 
        public 
        var y:Component 
        /// The blue component of this color. 
        public 
        var cb:Component 
        /// The red component of this color. 
        public 
        var cr:Component 
        
        @_specialize(exported: true, where Component == UInt8)
        @_specialize(exported: true, where Component == UInt16)
        @_specialize(exported: true, where Component == UInt32)
        @_specialize(exported: true, where Component == UInt64)
        @_specialize(exported: true, where Component == UInt)
        public 
        init(y:Component) 
        {
            self.init(y: y, cb: 0, cr: 0)
        }
        
        @_specialize(exported: true, where Component == UInt8)
        @_specialize(exported: true, where Component == UInt16)
        @_specialize(exported: true, where Component == UInt32)
        @_specialize(exported: true, where Component == UInt64)
        @_specialize(exported: true, where Component == UInt)
        public 
        init(y:Component, cb:Component, cr:Component) 
        {
            self.y  = y 
            self.cb = cb 
            self.cr = cr 
        }
    }
    @frozen
    public 
    struct RGB<Component>:Hashable where Component:FixedWidthInteger & UnsignedInteger
    {
        /// The red component of this color.
        public
        var r:Component
        /// The green component of this color.
        public
        var g:Component
        /// The blue component of this color.
        public
        var b:Component
        
        /// Creates an opaque grayscale color with all color components set to the given
        /// value sample.
        /// 
        /// *Specialized* for `Component` types `UInt8`, `UInt16`, `UInt32`, UInt64,
        ///     and `UInt`.
        /// - Parameters:
        ///     - value: The value to initialize all color components to.
        @_specialize(exported: true, where Component == UInt8)
        @_specialize(exported: true, where Component == UInt16)
        @_specialize(exported: true, where Component == UInt32)
        @_specialize(exported: true, where Component == UInt64)
        @_specialize(exported: true, where Component == UInt)
        public
        init(_ value:Component)
        {
            self.init(value, value, value)
        }
        
        /// Creates an opaque color with the given color samples.
        /// 
        /// *Specialized* for `Component` types `UInt8`, `UInt16`, `UInt32`, UInt64,
        ///     and `UInt`.
        /// - Parameters:
        ///     - red: The value to initialize the red component to.
        ///     - green: The value to initialize the green component to.
        ///     - blue: The value to initialize the blue component to.
        @_specialize(exported: true, where Component == UInt8)
        @_specialize(exported: true, where Component == UInt16)
        @_specialize(exported: true, where Component == UInt32)
        @_specialize(exported: true, where Component == UInt64)
        @_specialize(exported: true, where Component == UInt)
        public
        init(_ red:Component, _ green:Component, _ blue:Component)
        {
            self.r = red 
            self.g = green 
            self.b = blue
        }
    }     
}

// compound types 
public 
extension JPEG 
{
    enum DensityUnit
    {
        case none
        case dpi 
        case dpcm 
        
        init?(code:UInt8) 
        {
            switch code 
            {
            case 0:
                self = .none 
            case 1:
                self = .dpi 
            case 2:
                self = .dpcm 
            default:
                return nil 
            }
        }
    }
    
    enum Coding 
    {
        case huffman 
        case arithmetic 
    }
    
    enum Process 
    {
        case baseline 
        case extended(coding:Coding, differential:Bool)
        case progressive(coding:Coding, differential:Bool)
        case lossless(coding:Coding, differential:Bool)
    }
    
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
public 
extension JPEG 
{
    enum Bytestream 
    {
        typealias Source = _JPEGBytestreamSource
    }
    
    struct Bitstream 
    {
        private 
        var atoms:[UInt16]
        private(set)
        var count:Int
        
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
            
            // insert two more 0xffff atoms to serve as a barrier
            atoms.append(0xffff)
            atoms.append(0xffff)
            
            self.atoms = atoms
            self.count = 8 * data.count
        }
        
        // single bit (0 or 1)
        subscript(i:Int) -> Int 
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
        func append(bit:Int) 
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
            let clear:UInt16    = ~(.init(~bit & 1) &<< shift)
            // all bits at and beyond bit index `self.count` should be `1`-bits 
            self.atoms[a]      &= clear 
            self.count         += 1
        }
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
public 
extension JPEG 
{
    typealias Error = _JPEGError
    
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
    
    enum ParsingError:JPEG.Error 
    {
        case truncatedMarkerSegmentBody(Marker, Int, expected:ClosedRange<Int>)
        case extraneousMarkerSegmentData(Marker, Int, expected:Int)
        
        case invalidJFIFSignature([UInt8])
        case invalidJFIFVersion((major:Int, minor:Int))
        case invalidJFIFDensityUnit(Int)
        
        case unsupportedFrameCodingProcess(Process)
        case invalidFramePrecision(Int, Process)
        case invalidFrameComponentCount(Int, Process)
        case invalidFrameQuantizationSelector(Int)
        case invalidFrameComponentSamplingFactor((x:Int, y:Int), Int)
        case duplicateFrameComponentIndex(Int)
        
        case invalidScanComponentCount(Int)
        case invalidScanHuffmanSelectors((dc:Int, ac:Int), Process)
        case undefinedScanComponentReference(Int, [Int])
        case invalidScanSamplingVolume(Int)
        case invalidScanProgressiveSubset(band:(Int, Int), bits:(Int, Int), Int, Process)
        
        case invalidHuffmanTarget(Int)
        case invalidHuffmanTable
        
        case invalidQuantizationTarget(Int)
        case invalidQuantizationPrecision(Int)
        
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
            case .invalidJFIFVersion:
                return "invalid JFIF version"
            case .invalidJFIFDensityUnit:
                return "invalid JFIF density unit"
            
            case .unsupportedFrameCodingProcess:
                return "unsupported encoding process"
            case .invalidFramePrecision:
                return "invalid precision specifier"
            case .invalidFrameComponentCount:
                return "invalid total component count"
            case .invalidFrameQuantizationSelector:
                return "invalid quantization table selector"
            case .invalidFrameComponentSamplingFactor:
                return "invalid component sampling factors"
            case .duplicateFrameComponentIndex:
                return "duplicate component indices"
            
            case .invalidScanComponentCount:
                return "invalid scan component count"
            case .invalidScanHuffmanSelectors:
                return "invalid huffman table selectors"
            case .undefinedScanComponentReference:
                return "undefined component reference"
            case .invalidScanSamplingVolume:
                return "invalid scan component sampling volume"
            case .invalidScanProgressiveSubset:
                return "invalid spectral or binary subset"
            
            case .invalidHuffmanTarget:
                return "invalid huffman table destination"
            case .invalidHuffmanTable:
                return "malformed huffman table"
            
            case .invalidQuantizationTarget:
                return "invalid quantization table destination"
            case .invalidQuantizationPrecision:
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
            case .invalidJFIFVersion(let version):
                return "version (\(version.major).\(version.minor)) must be within 1.0 ... 1.2"
            case .invalidJFIFDensityUnit(let code):
                return "density code (\(code)) does not correspond to a valid density unit"
            
            case .unsupportedFrameCodingProcess(let process):
                return "frame coding process (\(process)) is not supported"
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
            case .invalidFrameQuantizationSelector(let i):
                return "quantization table selector (\(i)) must be within 0 ... 3"
            case .invalidFrameComponentSamplingFactor(let factor, let ci):
                return "both sampling factors (\(factor.x), \(factor.y)) for component index \(ci) must be within 1 ... 4"
            case .duplicateFrameComponentIndex(let ci):
                return "component index (\(ci)) conflicts with previously defined component"
            
            case .invalidScanComponentCount(let count):
                if count == 0 
                {
                    return "scan must contain at least one component"
                }
                else 
                {
                    return "scan (\(count) components) cannot have more than 4 components"
                } 
            case .invalidScanHuffmanSelectors(let (dc: dc, ac: ac), let process):
                return "huffman table selectors (dc: \(dc), ac: \(ac)) are not allowed for coding process '\(process)'"
            case .undefinedScanComponentReference(let ci, let defined):
                return "component with index (\(ci)) is not one of the components (\(defined)) defined in frame header"
            case .invalidScanSamplingVolume(let volume):
                return "scan mcu sample volume (\(volume)) can be at most 10"
            case .invalidScanProgressiveSubset(band: let band, bits: let bits, let count, let process):
                return "scan (\(count) components) with coding process '\(process)' cannot define bits [\(bits.1):\(bits.0)] for coefficients [\(band.0) ... \(band.1)]"
            
            case .invalidHuffmanTarget(let code):
                return "selector code (0x\(String.init(code, radix: 16))) does not correspond to a valid huffman table destination"
            case .invalidHuffmanTable:
                return nil
            
            case .invalidQuantizationTarget(let code):
                return "selector code (0x\(String.init(code, radix: 16))) does not correspond to a valid quantization table destination"
            case .invalidQuantizationPrecision(let code):
                return "code (\(code)) does not correspond to a valid quantization table precision"
            }
        }
    }
    enum DecodingError:JPEG.Error 
    {
        case truncatedEntropyCodedSegment
        
        case invalidCompositeValue(Int, expected:ClosedRange<Int>)
        
        case undefinedScanHuffmanDCReference(Table.HuffmanDC.Selector)
        case undefinedScanHuffmanACReference(Table.HuffmanAC.Selector)
        case undefinedScanQuantizationReference(Table.Quantization.Selector)
        
        case undefinedScanComponentReference(Int, [Int])
        case invalidScanInterleaving(Int)
        
        case missingStartOfImage(Marker)
        case missingJFIFHeader(Marker)
        case duplicateStartOfImage
        case duplicateFrameHeader
        case prematureScanHeader
        case prematureDefineHeightSegment
        case prematureEntropyCodedSegment
        case prematureEndOfImage
        
        case unsupportedColorFormat([Int], Int)
        
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
                
            case .invalidCompositeValue:
                return "invalid composite value"
            
            case .undefinedScanHuffmanDCReference:
                return "undefined dc huffman table reference"
            case .undefinedScanHuffmanACReference:
                return "undefined ac huffman table reference"
            case .undefinedScanQuantizationReference:
                return "undefined quantization table reference"
            
            case .undefinedScanComponentReference:
                return "undefined component reference"
            case .invalidScanInterleaving:
                return "invalid scan interleaving"
            
            case .missingStartOfImage:
                return "missing start-of-image marker"
            case .missingJFIFHeader:
                return "missing JFIF header"
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
            
            case .unsupportedColorFormat:
                return "unsupported color format"
            }
        }
        public 
        var details:String? 
        {
            switch self 
            {
            case .truncatedEntropyCodedSegment:
                return "not enough data in entropy coded segment bitstream"
            case .invalidCompositeValue(let value, expected: let expected):
                return "magnitude-tail encoded value (\(value)) must be within \(expected.lowerBound) ... \(expected.upperBound)"
            
            case .undefinedScanHuffmanDCReference(let selector):
                return "no dc huffman table has been installed at the location <\(String.init(selector: selector))>"
            case .undefinedScanHuffmanACReference(let selector):
                return "no ac huffman table has been installed at the location <\(String.init(selector: selector))>"
            case .undefinedScanQuantizationReference(let selector):
                return "no quantization table has been installed at the location <\(String.init(selector: selector))>"
                
            case .undefinedScanComponentReference(let ci, let defined):
                return "component with index (\(ci)) is not one of the components (\(defined)) defined in frame header"
            case .invalidScanInterleaving(let count):
                return "scan (\(count) components) is interleaved, which is not allowed"
            
            case .missingStartOfImage:
                return "start-of-image marker must be the first marker in image"
            case .missingJFIFHeader:
                return "JFIF header must be the second marker segment in image"
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
            
            case .unsupportedColorFormat(let components, let precision):
                return "component set \(components) with precision \(precision) is not a JFIF color format"
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
    typealias Slots    = (Self?, Self?, Self?, Self?)
    typealias Selector = WritableKeyPath<Slots, Self?>
}
public 
protocol _JPEGBitstreamAnySymbol 
{
    init(_:UInt8)
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
            private 
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
            private 
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
    public 
    struct JFIF
    {
        public 
        let version:(major:Int, minor:Int),
            density:(x:Int, y:Int, unit:DensityUnit)
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
            struct Entry 
            {
                let symbol:Symbol
                @Storage<UInt8> 
                var length:Int 
            }
            
            let storage:[Entry], 
                n:Int, // number of level 0 entries
                ζ:Int  // logical size of the table (where the n level 0 entries are each 256 units big)
            
            let target:Selector
        }
        
        public 
        struct Quantization:AnyTable
        {
            private 
            let elements:[Int]
            let target:Selector
        }

    }
    
    public 
    struct Frame
    {
        struct Component
        {
            let factor:(x:Int, y:Int)
            let selector:Table.Quantization.Selector 
        }

        let process:JPEG.Process,
            precision:Int

        private(set) // DNL segment may change this later on
        var size:(x:Int, y:Int)

        let components:[Int: Component]
    }
    
    public 
    struct Scan
    {
        struct Component 
        {
            let ci:Int
            let factor:(x:Int, y:Int)
            // can only store selectors because DC-only scans do not need an AC table, 
            // and vice-versa
            let selectors:
            (
                huffman:(dc:Table.HuffmanDC.Selector, ac:Table.HuffmanAC.Selector), 
                quantization:Table.Quantization.Selector 
            )
        }
        
        let band:Range<Int>, 
            bits:Range<Int>, 
            components:[Component] 
    }
}
// jfif segment parsing 
public 
extension JPEG.JFIF 
{
    static 
    func parse(_ data:[UInt8]) throws -> Self
    {
        guard data.count >= 14
        else
        {
            throw JPEG.ParsingError.mismatched(marker: .application(0), 
                count: data.count, minimum: 14)
        }
        
        // look for 'JFIF' signature
        guard data[0 ..< 5] == [0x4a, 0x46, 0x49, 0x46, 0x00]
        else 
        {
            throw JPEG.ParsingError.invalidJFIFSignature(.init(data[0 ..< 5]))
        }

        let version:(major:Int, minor:Int)
        version.major = .init(data[5])
        version.minor = .init(data[6])

        guard   1 ... 1 ~= version.major, 
                0 ... 2 ~= version.minor
        else
        {
            // bad JFIF version number (expected 1.0 ... 1.2)
            throw JPEG.ParsingError.invalidJFIFVersion(version)
        }

        guard let unit:JPEG.DensityUnit = JPEG.DensityUnit.init(code: data[7])
        else
        {
            // invalid JFIF density unit
            throw JPEG.ParsingError.invalidJFIFDensityUnit(.init(data[7]))
        }

        let density:(x:Int, y:Int) = 
        (
            data.load(bigEndian: UInt16.self, as: Int.self, at:  8), 
            data.load(bigEndian: UInt16.self, as: Int.self, at: 10)
        )

        // we ignore the thumbnail data
        return .init(version: version, density: (density.x, density.y, unit))
    }
}
// table parsing 
public 
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
public 
extension JPEG.Table 
{
    static 
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
                    .build(counts: leaf.counts, values: leaf.values, target: target)
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
                    .build(counts: leaf.counts, values: leaf.values, target: target)
                else 
                {
                    throw JPEG.ParsingError.invalidHuffmanTable
                }
                
                tables.ac.append(table)
                continue 
            
            default:
                break 
            }
            
            // huffman table has invalid binding index
            throw JPEG.ParsingError.invalidHuffmanTarget(.init(data[base]))
        }
        
        return tables
    }
    
    static 
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
                throw JPEG.ParsingError.invalidQuantizationTarget(.init(data[base] & 0x0f)) 
            }
            
            let table:Quantization
            switch data[base] & 0xf0 
            {
            case 0x00:
                guard data.count >= base + 65 
                else 
                {
                    throw JPEG.ParsingError.mismatched(marker: .quantization, 
                        count: data.count, minimum: base + 65)
                }
                
                table = .build(values: data[base + 1 ..< base + 65], target: target)
                base += 65 
            case 0x10:
                guard data.count >= base + 129 
                else 
                {
                    throw JPEG.ParsingError.mismatched(marker: .quantization, 
                        count: data.count, minimum: base + 129)
                }
                
                table = .build(values: data[base + 1 ..< base + 129], target: target)
                base += 129 
            
            default:
                throw JPEG.ParsingError.invalidQuantizationPrecision(.init(data[base] >> 4))
            }
            
            tables.append(table)
        }
        
        return tables
    }
}
// frame/scan header parsing 
public 
extension JPEG.Frame 
{
    static
    func parse(_ data:[UInt8], process:JPEG.Process) throws -> Self
    {
        switch process 
        {
        case    .baseline, 
                .extended(coding: .huffman, differential: false),
                .progressive(coding: .huffman, differential: false):
            break 
        default:
            throw JPEG.ParsingError.unsupportedFrameCodingProcess(process)
        }
        
        guard data.count >= 6
        else
        {
            throw JPEG.ParsingError.mismatched(marker: .frame(process), 
                count: data.count, minimum: 6)
        }

        let precision:Int = .init(data[0])
        switch (process, precision) 
        {
        case    (.baseline,     8), 
                (.extended,     8), (.extended,     12), 
                (.progressive,  8), (.progressive,  12):
            break

        default:
            // invalid precision
            throw JPEG.ParsingError.invalidFramePrecision(precision, process)
        }
        
        let size:(x:Int, y:Int) = 
        (
            data.load(bigEndian: UInt16.self, as: Int.self, at: 3),
            data.load(bigEndian: UInt16.self, as: Int.self, at: 1)
        )

        let count:Int = .init(data[5])
        switch (process, count) 
        {
        case    (.baseline,     1 ... .max), 
                (.extended,     1 ... .max), 
                (.progressive,  1 ... 4   ):
            break

        default:
            // invalid count
            throw JPEG.ParsingError.invalidFrameComponentCount(count, process)
        }

        guard data.count == 3 * count + 6
        else
        {
            // wrong segment size
            throw JPEG.ParsingError.mismatched(marker: .frame(process), 
                count: data.count, expected: 3 * count + 6)
        }

        var components:[Int: Component] = [:]
        for i:Int in 0 ..< count
        {
            let base:Int = 3 * i + 6
            let byte:(UInt8, UInt8, UInt8) = (data[base], data[base + 1], data[base + 2])
            
            let factor:(x:Int, y:Int)  = (.init(byte.1 >> 4), .init(byte.1 & 0x0f))
            let ci:Int                  = .init(byte.0)
            
            guard let selector:JPEG.Table.Quantization.Selector = 
                JPEG.Table.Quantization.parse(selector: byte.2)
            else 
            {
                throw JPEG.ParsingError.invalidFrameQuantizationSelector(.init(byte.2))
            }
            
            guard   1 ... 4 ~= factor.x,
                    1 ... 4 ~= factor.y
            else
            {
                throw JPEG.ParsingError.invalidFrameComponentSamplingFactor(factor, ci)
            }
            
            let component:Component = .init(factor: factor, selector: selector)
            // make sure no duplicate component indices are used 
            guard components.updateValue(component, forKey: ci) == nil 
            else 
            {
                throw JPEG.ParsingError.duplicateFrameComponentIndex(ci)
            }
        }

        return .init(process: process, precision: precision, size: size, components: components)
    }
    
    // parse DNL segment 
    mutating
    func height(_ data:[UInt8]) throws 
    {
        guard data.count == 2
        else
        {
            throw JPEG.ParsingError.mismatched(marker: .height, count: data.count, expected: 2)
        }

        self.size.y = data.load(bigEndian: UInt16.self, as: Int.self, at: 0)
    } 
}
public 
extension JPEG.Scan 
{
    static 
    func parse(_ data:[UInt8], frame:JPEG.Frame) 
        throws -> Self
    {
        guard data.count >= 4 
        else 
        {
            throw JPEG.ParsingError.mismatched(marker: .scan, 
                count: data.count, minimum: 4)
        }
        
        let count:Int = .init(data[0])
        guard 1 ... 4 ~= count
        else 
        {
            throw JPEG.ParsingError.invalidScanComponentCount(count)
        } 
        
        guard data.count == 2 * count + 4
        else 
        {
            // wrong segment size
            throw JPEG.ParsingError.mismatched(marker: .scan, 
                count: data.count, expected: 2 * count + 4)
        }
        
        let components:[Component] = try (0 ..< count).map 
        {
            let base:Int            = 2 * $0 + 1
            let byte:(UInt8, UInt8) = (data[base], data[base + 1])
            
            let ci:Int = .init(byte.0)
            
            switch (frame.process, byte.1 >> 4, byte.1 & 0x0f) 
            {
            case    (.baseline,     0 ... 1, 0 ... 1), 
                    (.extended,     0 ... 3, 0 ... 3), 
                    (.progressive,  0 ... 3, 0 ... 3):
                break 
            
            default:
                throw JPEG.ParsingError.invalidScanHuffmanSelectors(
                    (.init(byte.1 >> 4), .init(byte.1 & 0x0f)), frame.process)
            }
            
            guard   let dc:JPEG.Table.HuffmanDC.Selector = 
                    JPEG.Table.HuffmanDC.parse(selector: byte.1 >> 4), 
                    let ac:JPEG.Table.HuffmanAC.Selector = 
                    JPEG.Table.HuffmanAC.parse(selector: byte.1 & 0xf)
            else 
            {
                fatalError("unreachable") 
            }
            
            guard let component:JPEG.Frame.Component = frame.components[ci]
            else 
            {
                throw JPEG.ParsingError.undefinedScanComponentReference(ci, 
                    frame.components.keys.sorted())
            }
            
            return .init(ci: ci, factor: component.factor, 
                selectors: ((dc, ac), component.selector))
        }
        
        // validate sampling factor sum 
        let volume:Int = components.map{ $0.factor.x * $0.factor.y }.reduce(0, +) 
        guard 0 ... 10 ~= volume
        else 
        {
            throw JPEG.ParsingError.invalidScanSamplingVolume(volume)
        }
        
        // parse spectral parameters 
        let base:Int                    = 2 * count + 1
        let byte:(UInt8, UInt8, UInt8)  = (data[base], data[base + 1], data[base + 2])
        
        let band:(Int, Int)             = (.init(byte.0), .init(byte.1))
        let bits:(Int, Int)             = 
        (
            .init(byte.2 & 0xf), 
            byte.2 >> 4 == 0 ? frame.precision : .init(byte.2 >> 4)
        )
        
        guard   band.0 <= band.1, 
                band == (0, 0) || count == 1, 
                bits.0 <= bits.1, 
                bits.1 == frame.precision || bits.1 - bits.0 == 1 // 1 bit per refining scan
        else 
        {
            throw JPEG.ParsingError.invalidScanProgressiveSubset(
                band: band, bits: bits, count, frame.process)
        }
        
        switch (frame.process, band.0, band.1, bits.0, bits.1) 
        {
        case    (.baseline,     0,                      63, 
                                0,                      frame.precision), 
                (.extended,     0,                      63, 
                                0,                      frame.precision),
                (.progressive,  0,                      0,                 
                                0 ..< frame.precision,  bits.0 + 1 ... frame.precision),
                (.progressive,  1 ..< 64,               band.0 + 1 ..< 64, 
                                0 ..< frame.precision,  bits.0 + 1 ... frame.precision):
            break 
        
        default:
            throw JPEG.ParsingError.invalidScanProgressiveSubset(
                band: band, bits: bits, count, frame.process)
        }
        
        return .init(band: band.0 ..< band.1 + 1, bits: bits.0 ..< bits.1, components: components)
    }
}

// table builders 
extension JPEG.Table.Huffman
{
    // determine the value of n, explained in create(leafCounts:leafValues:coefficientClass),
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

    public static 
    func build<RAC>(counts:[Int], values:RAC, target:Selector) -> Self?
        where RAC:RandomAccessCollection, RAC.Element == UInt8, RAC.Index == Int
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
        guard let (n, z):(Int, Int) = Self.size(counts) 
        else 
        {
            return nil
        }
        
        var storage:[Entry] = []
            storage.reserveCapacity(z)
        
        var begin:Int = values.startIndex
        for (l, leaves):(Int, Int) in counts.enumerated()
        {
            guard storage.count < z 
            else 
            {
                break
            }            
            
            let clones:Int  = 0x8080 >> l & 0xff
            let end:Int     = begin + leaves 
            for value:UInt8 in values[begin ..< end] 
            {
                let entry:Entry = .init(symbol: .init(value), length: l + 1)
                storage.append(contentsOf: repeatElement(entry, count: clones))
            }
            
            begin = end 
        }
        
        assert(storage.count == z)
        
        return .init(storage: storage, n: n, ζ: z + n * 255, target: target)
    }
    
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
    public static 
    func build<RAC>(values:RAC, target:Selector) -> Self
        where RAC:RandomAccessCollection, RAC.Element == UInt8, RAC.Index == Int
    {
        let elements:[Int]
        switch values.count 
        {
        case 64:
            elements = values.map(Int.init(_:))
        case 128:
            let base:Int = values.startIndex 
            elements = (0 ..< 64).map 
            {
                let bytes:[UInt8] = .init(values[base + 2 * $0 ..< base + 2 * $0 + 2])
                return bytes.load(bigEndian: UInt16.self, as: Int.self, at: 0)
            }
        default:
            fatalError("unreachable")
        }
        
        return .init(elements: elements, target: target)
    }
    
    subscript(z z:Int) -> Int 
    {
        self.elements[z]
    }
}

// intermediate forms
extension JPEG 
{
    public 
    enum Data 
    {
        public 
        struct Spectral 
        {
            public 
            struct Plane 
            {
                var units:(x:Int, y:Int)
                public 
                var size:(x:Int, y:Int) 
                {
                    (8 * self.units.x, 8 * self.units.y)
                }
                
                // have to be `Int16` to circumvent compiler size limits for `_read` and `_modify`
                @Storage2<Int16>
                public 
                var factor:(x:Int, y:Int) 
                @Storage<Int16>
                public 
                var ci:Int 
                
                private 
                var buffer:[Int]
                
                // subscript with a zigzag coordinate
                public 
                subscript(x x:Int, y y:Int, z z:Int) -> Int 
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
            
            public 
            let properties:Properties
            
            public  
            let scale:(x:Int, y:Int)
            public private(set)
            var blocks:(x:Int, y:Int), 
                size:(x:Int, y:Int)
            
            private 
            var planes:[Plane] 
            
            public 
            subscript(p:Int) -> Plane 
            {
                _read  
                {
                    yield self.planes[p]
                }
                _modify
                {
                    yield &self.planes[p]
                }
            }
        }
        
        public 
        struct Planar 
        {
            public 
            struct Plane 
            {
                let units:(x:Int, y:Int)
                public 
                var size:(x:Int, y:Int) 
                {
                    (8 * self.units.x, 8 * self.units.y)
                }
                
                // have to be `Int16` to circumvent compiler size limits for `_read` and `_modify`
                @Storage2<Int16>
                public 
                var factor:(x:Int, y:Int) 
                @Storage<Int16>
                public 
                var ci:Int 
                
                private 
                var buffer:[Float]
                
                public 
                subscript(x x:Int, y y:Int) -> Float
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
            let properties:Properties, 
                size:(x:Int, y:Int)
            public  
            let scale:(x:Int, y:Int)
            
            private 
            var planes:[Plane] 
            
            public 
            subscript(p:Int) -> Plane 
            {
                _read  
                {
                    yield self.planes[p]
                }
                _modify
                {
                    yield &self.planes[p]
                }
            }
        }
        
        public 
        struct Rectangular 
        {
            public 
            let properties:Properties, 
                size:(x:Int, y:Int)
            
            private 
            let values:[Float]
        }
    }
}

// RAC conformance for planar types 
extension JPEG.Data.Spectral:RandomAccessCollection 
{
    public 
    var startIndex:Int 
    {
        0
    }
    public 
    var endIndex:Int 
    {
        self.planes.endIndex
    }
}
extension JPEG.Data.Planar:RandomAccessCollection 
{
    public 
    var startIndex:Int 
    {
        0
    }
    public 
    var endIndex:Int 
    {
        self.planes.endIndex
    }
}

// spectral type APIs
extension JPEG.Data.Spectral.Plane 
{
    init(stride:Int, factor:(x:Int, y:Int), ci:Int)
    {
        self.buffer     = []
        self.units      = (stride, 0)
        self._factor    = .init(wrappedValue: factor)
        self._ci        = .init(wrappedValue: ci)
    }
    
    mutating 
    func resize(to y:Int) 
    {
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
    
    // convert a 2D coordinate to a zigzag parameter
    public static 
    func z(x:Int, y:Int) -> Int 
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
    public 
    subscript(x x:Int, y y:Int, k k:Int, h h:Int) -> Int 
    {
        get 
        {
            self[x: x, y: y, z: Self.z(x: k, y: h)]
        }
        set(value)
        {
            self[x: x, y: y, z: Self.z(x: k, y: h)] = value 
        }
    }
}
extension JPEG.Data.Spectral 
{
    private static  
    func units(_ size:Int, stride:Int) -> Int  
    {
        let complete:Int = size / stride, 
            partial:Int  = size % stride != 0 ? 1 : 0 
        return complete + partial 
    }
    
    init(components:[Int: JPEG.Frame.Component], size:(x:Int, y:Int), properties:JPEG.Properties)
    {
        self.properties = properties
        self.scale      = components.values.reduce((0, 0))
        {
            (Swift.max($0.x, $1.factor.x), Swift.max($0.y, $1.factor.y))
        }
        self.blocks = (Self.units(size.x, stride: 8 * self.scale.x), 0)
        
        var planes:[Plane] = [ ]
        for (ci, component):(Int, JPEG.Frame.Component) in 
            components.sorted(by: { $0.key < $1.key })
        {
            let numerator:Int   = size.x * component.factor.x
            let plane:Plane     = .init(
                stride: Self.units(numerator, stride: 8 * self.scale.x), 
                factor: component.factor, 
                ci:     ci)
            planes.append(plane)
        }
        
        self.planes = planes 
        self.size   = (size.x, 0)
        
        self.set(height: size.y)
    }
    
    mutating 
    func set(height:Int) 
    {
        self.blocks.y   = Self.units(height, stride: 8 * self.scale.y)
        self.size.y     = height
        for p:Int in self.indices
        {
            let numerator:Int = height * self[p].factor.y
            self[p].resize(to: Self.units(numerator, stride: 8 * self.scale.y))
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
            let difference:Int 
        }
        public 
        enum AC 
        {
            case run(Int, value:Int)
            case eob(Int)
        }
    }
    
    public static 
    func extend<I>(binade:Int, _ tail:UInt16, as _:I.Type) -> I
        where I:FixedWidthInteger & SignedInteger
    {
        // 0 for lower half of range, 1 for upper half 
        let sign:UInt16     = tail &>> (binade &- 1)
        // [0000 0000 0000 0000]
        // [1111 1111 1100 0000]
        let high:UInt16     = (0xffff &+ sign) &<< binade  
        let low:UInt16      = tail &+ (sign ^ 1)
        let combined:Int16  = .init(bitPattern: high | low)
        return .init(combined)
    }
    
    public static 
    func compact<I>(_ x:I) -> (binade:Int, tail:UInt16)
        where I:FixedWidthInteger & SignedInteger
    {
        let x:Int16         = .init(x)
        // one of the advantages of swift is that we can query this through a CPU 
        // intrinsic as opposed to loop-based queries found in much example c code 
        let position:Int    = abs(x).leadingZeroBitCount
        let binade:Int      = Int16.bitWidth &- position
        
        let sign:UInt16     = .init(bitPattern: x) &>> (Int16.bitWidth - 1)
        let tail:UInt16     = .init(bitPattern: x) & .max &>> position &- sign 
        
        return (binade: binade, tail: tail)
    }
    
    func refinement(_ i:inout Int) throws -> Int
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
        return self[i] 
    }
    
    func composite(_ i:inout Int, table:JPEG.Table.HuffmanDC) throws -> Composite.DC  
    {
        // read SSSS:[extra] (huffman coded)
        guard i < self.count 
        else 
        {
            throw JPEG.DecodingError.truncatedEntropyCodedSegment
        }
        
        let entry:JPEG.Table.HuffmanDC.Entry    = table[self[i, count: 16]]
        let binade:Int                          = entry.symbol.binade 
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
        
        let value:Int = Self.extend(binade: binade, self[i, count: binade], as: Int.self)
        return .init(difference: value)
    }
    
    func composite(_ i:inout Int, table:JPEG.Table.HuffmanAC) throws -> Composite.AC  
    {
        // read RRRR:SSSS:[extra] (huffman coded)
        guard i < self.count 
        else 
        {
            throw JPEG.DecodingError.truncatedEntropyCodedSegment
        }
        
        let entry:JPEG.Table.HuffmanAC.Entry    = table[self[i, count: 16]]
        let zeroes:Int                          = entry.symbol.zeroes, 
            binade:Int                          = entry.symbol.binade 
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
            
            let value:Int = Self.extend(binade: binade, self[i, count: binade], as: Int.self)
            return .run(zeroes, value: value)
        }
    }
}

// progressive decoding processes
extension JPEG.Data.Spectral  
{
    // creates ci to plane index dictionary  
    private 
    func plane() -> [Int: Int] 
    {
        .init(uniqueKeysWithValues: zip(self.indices, self).map{ ($0.1.ci, $0.0) })
    }
    private 
    func plane(ci:Int) throws -> Int 
    {
        for (p, cj):(Int, Int) in zip(self.indices, self.map(\.ci)) 
        {
            if cj == ci
            {
                return p
            }
        }
        
        // this error condition shouldn’t be possible normally, but we 
        // handle it anyway in case the Data.Spectral object was created 
        // irregularly
        throw JPEG.DecodingError.undefinedScanComponentReference(ci, self.map(\.ci).sorted())
    }
    mutating 
    func initial(dc data:[UInt8], scan:JPEG.Scan, tables slots:JPEG.Table.HuffmanDC.Slots) 
        throws
    {
        let plane:[Int: Int] = self.plane()
        let descriptors:[(plane:Int, factor:(x:Int, y:Int), table:JPEG.Table.HuffmanDC)] = 
            try scan.components.map 
        {
            guard let huffman:JPEG.Table.HuffmanDC = slots[keyPath: $0.selectors.huffman.dc]
            else 
            {
                throw JPEG.DecodingError.undefinedScanHuffmanDCReference($0.selectors.huffman.dc)
            }
            
            guard let p:Int = plane[$0.ci] 
            else 
            {
                // this error condition shouldn’t be possible normally, but we 
                // handle it anyway in case the Data.Spectral object was created 
                // irregularly
                throw JPEG.DecodingError.undefinedScanComponentReference($0.ci, plane.keys.sorted())
            }
            return (p, $0.factor, huffman)
        }
        
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        if descriptors.count > 1 
        {
            // interleaved 
            var predecessor:[Int] = .init(repeating: 0, count: descriptors.count)
            row:
            for h:Int in 0... 
            {
                guard b < bits.count, bits[b, count: 16] != 0xffff 
                else 
                {
                    break row 
                }
                
                for (p, factor, _):(plane:Int, factor:(x:Int, y:Int), table:JPEG.Table.HuffmanDC) in 
                    descriptors 
                {
                    let height:Int = (h + 1) * factor.y
                    if height > self[p].units.y
                    {
                        self[p].resize(to: height)
                    }
                }
                
                column:
                for k:Int in 0 ..< self.blocks.x 
                {
                    for (c, (p, factor, table)):(Int, (plane:Int, factor:(x:Int, y:Int), table:JPEG.Table.HuffmanDC)) in 
                        zip(predecessor.indices, descriptors)
                    {
                        let base:(x:Int, y:Int) = (k * factor.x, h * factor.y)
                        for y:Int in 0 ..< factor.y 
                        {
                            for x:Int in 0 ..< factor.x 
                            {
                                let composite:JPEG.Bitstream.Composite.DC   = try bits.composite(&b, table: table)
                                predecessor[c]                             += composite.difference 
                                self[p][x: base.x + x, y: base.y + y, z: 0] = predecessor[c] << scan.bits.lowerBound
                            }
                        }
                    }
                }
            }
        }
        else 
        {
            let p:Int                       = descriptors[0].plane, 
                table:JPEG.Table.HuffmanDC  = descriptors[0].table
            var predecessor:Int             = 0
            row: 
            for y:Int in 0... 
            {
                guard b < bits.count, bits[b, count: 16] != 0xffff 
                else 
                {
                    break row 
                }
                
                if y >= self[p].units.y
                {
                    self[p].resize(to: y + 1)
                }
                
                column:
                for x:Int in 0 ..< self[p].units.x 
                {
                    let composite:JPEG.Bitstream.Composite.DC   = try bits.composite(&b, table: table)
                    predecessor                                += composite.difference
                    self[p][x: x, y: y, z: 0]                   = predecessor << scan.bits.lowerBound
                }
            }
        }
    }
    
    mutating 
    func refining(dc data:[UInt8], scan:JPEG.Scan) throws
    {
        let plane:[Int: Int] = self.plane()
        let descriptors:[(plane:Int, factor:(x:Int, y:Int))] = 
            try scan.components.map 
        {
            guard let p:Int = plane[$0.ci] 
            else 
            {
                // this error condition shouldn’t be possible normally, but we 
                // handle it anyway in case the Data.Spectral object was created 
                // irregularly
                throw JPEG.DecodingError.undefinedScanComponentReference($0.ci, plane.keys.sorted())
            }
            
            return (p, $0.factor)
        }
        
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        if descriptors.count > 1 
        {
            // interleaved 
            row:
            for h:Int in 0 ..< self.blocks.y 
            {
                column:
                for k:Int in 0 ..< self.blocks.x 
                {
                    for (p, factor):(plane:Int, factor:(x:Int, y:Int)) in descriptors
                    {
                        let base:(x:Int, y:Int) = (k * factor.x, h * factor.y)
                        for y:Int in 0 ..< factor.y 
                        {
                            for x:Int in 0 ..< factor.x 
                            {
                                let refinement:Int                           = try bits.refinement(&b)
                                self[p][x: base.x + x, y: base.y + y, z: 0] |= refinement << scan.bits.lowerBound
                            }
                        }
                    }
                }
            }
        }
        else 
        {
            let p:Int = descriptors[0].plane
            row: 
            for y:Int in 0 ..< self[p].units.y
            {
                column:
                for x:Int in 0 ..< self[p].units.x 
                {
                    let refinement:Int         = try bits.refinement(&b)
                    self[p][x: x, y: y, z: 0] |= refinement << scan.bits.lowerBound
                }
            }
        }
    } 
    
    mutating 
    func initial(ac data:[UInt8], scan:JPEG.Scan, tables slots:JPEG.Table.HuffmanAC.Slots) 
        throws
    {
        // count should have been validated in scan parser, this check is for the 
        // manual case 
        guard scan.components.count == 1 
        else 
        {
            throw JPEG.DecodingError.invalidScanInterleaving(scan.components.count)
        }
        
        let component:JPEG.Scan.Component       = scan.components[0]
        let p:Int                               = try self.plane(ci: component.ci)
        guard let table:JPEG.Table.HuffmanAC    = slots[keyPath: component.selectors.huffman.ac]
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanACReference(component.selectors.huffman.ac)
        }
        
        let bits:JPEG.Bitstream     = .init(data)
        var b:Int                   = 0, 
            skip:Int                = 0
        row: 
        for y:Int in 0 ..< self[p].units.y
        {
            column:
            for x:Int in 0 ..< self[p].units.x 
            {
                var z:Int = scan.band.lowerBound
                frequency: 
                while z < scan.band.upperBound  
                {
                    // we spell the body of this loop this way to match the 
                    // flow logic of `refining(ac:scan:tables)`
                    let (zeroes, value):(Int, Int) 
                    if skip > 0 
                    {
                        zeroes = 64 
                        value  = 0
                        skip  -= 1
                    } 
                    else 
                    {
                        switch try bits.composite(&b, table: table)
                        {
                        case .run(let run, value: let v):
                            zeroes = run 
                            value  = v 
                        
                        case .eob(let blocks):
                            zeroes = 64 
                            value  = 0 
                            skip   = blocks - 1
                        }
                    }
                    
                    z += zeroes 
                    if z < scan.band.upperBound 
                    {
                        defer 
                        {
                            z += 1
                        }
                        
                        self[p][x: x, y: y, z: z] = value << scan.bits.lowerBound
                        continue frequency  
                    }
                    
                    break frequency
                } 
            }
        }
    }
    
    mutating 
    func refining(ac data:[UInt8], scan:JPEG.Scan, tables slots:JPEG.Table.HuffmanAC.Slots) 
        throws
    {
        // count should have been validated in scan parser, this check is for the 
        // manual case 
        guard scan.components.count == 1 
        else 
        {
            throw JPEG.DecodingError.invalidScanInterleaving(scan.components.count)
        }
        
        let component:JPEG.Scan.Component       = scan.components[0]
        let p:Int                               = try self.plane(ci: component.ci)
        guard let table:JPEG.Table.HuffmanAC    = slots[keyPath: component.selectors.huffman.ac]
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanACReference(component.selectors.huffman.ac)
        }
        
        let bits:JPEG.Bitstream     = .init(data)
        var b:Int                   = 0, 
            skip:Int                = 0
        row: 
        for y:Int in 0 ..< self[p].units.y
        {
            column:
            for x:Int in 0 ..< self[p].units.x 
            {
                var z:Int = scan.band.lowerBound
                frequency:
                while z < scan.band.upperBound  
                {
                    let (zeroes, delta):(Int, Int) 
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
                        
                        let unrefined:Int = self[p][x: x, y: y, z: z]
                        if unrefined == 0 
                        {
                            guard skipped < zeroes 
                            else 
                            {
                                self[p][x: x, y: y, z: z] = delta << scan.bits.lowerBound
                                continue frequency  
                            }
                            
                            skipped += 1
                        }
                        else 
                        {
                            let delta:Int = (unrefined < 0 ? -1 : 1) * (try bits.refinement(&b))
                            self[p][x: x, y: y, z: z] += delta << scan.bits.lowerBound
                        }
                    } while z < scan.band.upperBound
                    
                    break frequency
                }
            }
        } 
    } 
    
    // performs dequantization for the *relevant* coefficients specified in the 
    // scan header, which may be no coefficients at all
    mutating 
    func dequantize(scan:JPEG.Scan, tables slots:JPEG.Table.Quantization.Slots) throws
    {
        guard scan.bits.lowerBound == 0 
        else 
        {
            return 
        }
        
        let plane:[Int: Int] = self.plane()
        let descriptors:[(plane:Int, table:JPEG.Table.Quantization)] = 
            try scan.components.map 
        {
            guard let quantization:JPEG.Table.Quantization = 
                slots[keyPath: $0.selectors.quantization]
            else 
            {
                throw JPEG.DecodingError.undefinedScanQuantizationReference($0.selectors.quantization)
            }
            
            guard let p:Int = plane[$0.ci] 
            else 
            {
                // this error condition shouldn’t be possible normally, but we 
                // handle it anyway in case the Data.Spectral object was created 
                // irregularly
                throw JPEG.DecodingError.undefinedScanComponentReference($0.ci, plane.keys.sorted())
            }
            
            return (p, quantization)
        }
        
        for (p, table):(Int, JPEG.Table.Quantization) in descriptors 
        {
            for y:Int in 0 ..< self[p].units.y
            {
                for x:Int in 0 ..< self[p].units.x 
                {
                    for z:Int in scan.band 
                    {
                        self[p][x: x, y: y, z: z] *= table[z: z]
                    }
                }
            }
        }
    }
}

// signal processing and upscaling 
extension JPEG.Data.Spectral.Plane 
{
    func idct(x:Int, y:Int) -> [Float] 
    {
        let values:[Float] = .init(unsafeUninitializedCapacity: 64) 
        {
            for i:Int in 0 ..< 8
            {
                for j:Int in 0 ..< 8
                {
                    let t:(Float, Float) = 
                    (
                        2 * .init(i) + 1,
                        2 * .init(j) + 1
                    )
                    var s:Float = 0
                    for h:Int in 0 ..< 8 
                    {
                        for k:Int in 0 ..< 8 
                        {
                            let c:Float 
                            switch (h * k, h + k) 
                            {
                            case (0, 0):
                                c = 1 
                            case (0, _):
                                c = (2 as Float).squareRoot()
                            case (_, _):
                                c = 2
                            }
                            
                            let ω:(Float, Float) = 
                            (
                                .init(h) * .pi / 16, 
                                .init(k) * .pi / 16
                            )
                            let a:Float = _cos(ω.0 * t.0) * _cos(ω.1 * t.1)
                            s += a * c * .init(self[x: x, y: y, k: k, h: h])
                        }
                    }
                    
                    $0[8 * i + j] = s / 8
                }
            }
            
            $1 = 64
        }
        return values 
    }
    func idct() -> JPEG.Data.Planar.Plane
    {
        let count:Int = 64 * self.units.x * self.units.y
        let values:[Float] = .init(unsafeUninitializedCapacity: count) 
        {
            let stride:Int = 8 * self.units.x
            for y:Int in 0 ..< self.units.y 
            {
                for x:Int in 0 ..< self.units.x 
                {
                    let block:[Float] = self.idct(x: x, y: y)
                    for i:Int in 0 ..< 8 
                    {
                        for j:Int in 0 ..< 8 
                        {
                            $0[(8 * y + i) * stride + 8 * x + j] = block[8 * i + j]
                        }
                    }
                }
            }
            
            $1 = count 
        }
        return .init(values, units: self.units, factor: self.factor, ci: self.ci) 
    }
}
extension JPEG.Data.Planar.Plane 
{
    init(_ values:[Float], units:(x:Int, y:Int), factor:(x:Int, y:Int), ci:Int)
    {
        self.buffer     = values 
        self.units      = units 
        self._factor    = .init(wrappedValue: factor)
        self._ci        = .init(wrappedValue: ci)
    }
}

extension JPEG.Data.Spectral 
{
    public 
    func idct() -> JPEG.Data.Planar 
    {
        .init(self.map{ $0.idct() }, scale: self.scale, size: self.size, 
            properties: self.properties)
    }
}
extension JPEG.Data.Planar 
{
    init(_ planes:[JPEG.Data.Planar.Plane], scale:(x:Int, y:Int), size:(x:Int, y:Int), 
        properties:JPEG.Properties)
    {
        self.properties = properties 
        self.scale      = scale
        self.size       = size
        self.planes     = planes 
    }
    
    public 
    func interleave() -> JPEG.Data.Rectangular 
    {
        var interleaved:[Float]
        switch self.properties.format 
        {
        case .y8:
            interleaved = .init(repeatElement(0, count: self.size.x * self.size.y))
            for y:Int in 0 ..< self.size.y 
            {
                for x:Int in 0 ..< self.size.x 
                {
                    interleaved[y * self.size.x + x] = self[0][x: x, y: y]
                }
            }
        
        case .ycc8:
            interleaved = .init(repeatElement(0, count: self.size.x * self.size.y * 3))
            for (p, plane):(Int, Plane) in self.enumerated() 
            {
                let d:(x:Int, y:Int) = 
                (
                    self.scale.x / plane.factor.x,
                    self.scale.y / plane.factor.y
                )
                
                assert(self.scale.x % plane.factor.x == 0)
                assert(self.scale.y % plane.factor.y == 0)
                
                for y:Int in 0 ..< self.size.y 
                {
                    for x:Int in 0 ..< self.size.x 
                    {
                        interleaved[(y * self.size.x + x) * 3 + p] = plane[x: x / d.x, y: y / d.y]
                    }
                }
            }
        }
        
        return .init(interleaved, size: self.size, properties: self.properties)
    }
}
extension JPEG.Data.Rectangular 
{
    init(_ values:[Float], size:(x:Int, y:Int), properties:JPEG.Properties)
    {
        self.properties = properties 
        self.size       = size
        self.values     = values
    }
}

// high-level state handling
extension JPEG 
{
    struct Context
    {
        private
        var tables:
        (
            huffman:(dc:Table.HuffmanDC.Slots, ac:Table.HuffmanAC.Slots), 
            quantization:Table.Quantization.Slots
        ) = 
        (
            (
            (nil, nil, nil, nil),
            (nil, nil, nil, nil)
            ), 
            (nil, nil, nil, nil)
        )
        
        private 
        var frame:Frame?  = nil, 
            scan:Scan?    = nil 
        
        var spectral:Data.Spectral? = nil
    }
}
extension JPEG.Context 
{
    mutating
    func handle(huffman data:[UInt8]) throws
    {
        let tables:(dc:[JPEG.Table.HuffmanDC], ac:[JPEG.Table.HuffmanAC]) = 
            try JPEG.Table.parse(data, as: (JPEG.Table.HuffmanDC.self, JPEG.Table.HuffmanAC.self))
        for table:JPEG.Table.HuffmanDC in tables.dc 
        {
            self.tables.huffman.dc[keyPath: table.target] = table
        }
        for table:JPEG.Table.HuffmanAC in tables.ac 
        {
            self.tables.huffman.ac[keyPath: table.target] = table
        }
    }
    mutating 
    func handle(quantization data:[UInt8]) throws
    {
        let tables:[JPEG.Table.Quantization] = 
            try JPEG.Table.parse(data, as: JPEG.Table.Quantization.self)
        for table:JPEG.Table.Quantization in tables 
        {
            self.tables.quantization[keyPath: table.target] = table
        }
    }
    mutating 
    func handle(frame data:[UInt8], process:JPEG.Process) throws
    {
        guard self.frame == nil 
        else 
        {
            throw JPEG.DecodingError.duplicateFrameHeader
        }
        
        let frame:JPEG.Frame    = try .parse(data, process: process)
        
        // parse format 
        // check if component indices are 1, 2, 3...
        let monotonic:Bool = 
            frame.components.keys.sorted() == .init(1 ... frame.components.count)
        let format:JPEG.Format
        switch (frame.components.count, frame.precision, monotonic) 
        {
        case (1,  8, true): 
            format = .y8
        case (3,  8, true): 
            format = .ycc8
        default:
            throw JPEG.DecodingError.unsupportedColorFormat(frame.components.keys.sorted(), frame.precision)
        }
        
        let properties:JPEG.Properties = .init(format: format)
        
        self.spectral           = .init(components: frame.components, 
            size: frame.size, properties: properties)
        self.frame              = frame
    }
    mutating 
    func handle(scan data:[UInt8]) throws 
    {
        guard let frame:JPEG.Frame = self.frame 
        else 
        {
            throw JPEG.DecodingError.prematureScanHeader
        }
        
        self.scan               = try .parse(data, frame: frame)
    }
    mutating 
    func handle(height data:[UInt8]) throws 
    {
        guard self.frame != nil 
        else 
        {
            throw JPEG.DecodingError.prematureDefineHeightSegment
        }
        
        try self.frame?.height(data)
    }
    func handle(interval data:[UInt8]) throws 
    {
    }
    
    mutating 
    func handle(ecs data:[UInt8]) throws 
    {
        guard   let frame:JPEG.Frame    = self.frame, 
                let scan:JPEG.Scan      = self.scan 
        else 
        {
            throw JPEG.DecodingError.prematureEntropyCodedSegment
        }
        
        if scan.bits != 0 ..< frame.precision 
        {
            // successive approximation 
            switch (scan.bits.upperBound == frame.precision, scan.band == 0 ..< 1)
            {
            case (true, true):
                // initial dc scan 
                try self.spectral?.initial(dc: data, scan: scan, tables: self.tables.huffman.dc) 
                try self.spectral?.dequantize(scan: scan, tables: self.tables.quantization)
                if self.spectral?.size.y == 0 
                {
                    self.spectral?.set(height: frame.size.y)
                }
                
            case (true, false):
                // initial ac scan 
                try self.spectral?.initial(ac: data, scan: scan, tables: self.tables.huffman.ac)
                try self.spectral?.dequantize(scan: scan, tables: self.tables.quantization)
                 
            case (false, true):
                // refining dc scan 
                try self.spectral?.refining(dc: data, scan: scan)
                try self.spectral?.dequantize(scan: scan, tables: self.tables.quantization)
            
            case (false, false):
                // refining ac scan 
                try self.spectral?.refining(ac: data, scan: scan, tables: self.tables.huffman.ac)
                try self.spectral?.dequantize(scan: scan, tables: self.tables.quantization)
            }
        }
        else if scan.band != 0 ..< 64
        {
            // spectral selection 
            fatalError("unimplemented")
        }
        else 
        {
            // baseline sequential mode 
            fatalError("unimplemented")
        }
    }
    
    static 
    func decompress(stream:inout JPEG.File.Source) throws -> JPEG.Data.Spectral 
    {
        var marker:(type:JPEG.Marker, data:[UInt8]) 
        
        // start of image 
        marker = try stream.segment()
        guard case .start = marker.type 
        else 
        {
            throw JPEG.DecodingError.missingStartOfImage(marker.type)
        }
        
        // jfif header (must immediately follow start of image)
        marker = try stream.segment()
        guard case .application(0) = marker.type 
        else 
        {
            throw JPEG.DecodingError.missingJFIFHeader(marker.type)
        }
        let image:JPEG.JFIF = try .parse(marker.data) 
        
        var context:Self = .init()
        marker = try stream.segment()
        loop:
        while true 
        {
            switch marker.type 
            {
            case .frame(let process):
                try context.handle(frame: marker.data, process: process)
            
            case .quantization:
                try context.handle(quantization: marker.data) 
            case .huffman:
                try context.handle(huffman: marker.data) 
            
            case .comment, .application:
                break 
            
            case .scan:
                try context.handle(scan: marker.data)
                
                let ecs:[UInt8] 
                (ecs, marker) = try stream.segment(prefix: true)
                
                try context.handle(ecs: ecs)
                continue loop
            
            case .height:
                try context.handle(height: marker.data)
            case .interval:
                try context.handle(interval: marker.data)
            
            case .end:
                guard let spectral:JPEG.Data.Spectral = context.spectral
                else 
                {
                    throw JPEG.DecodingError.prematureEndOfImage
                }
                
                return spectral 
                
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

// staged APIs 
extension JPEG.Data.Spectral 
{
    public static 
    func decompress(path:String) throws -> Self? 
    {
        return try JPEG.File.Source.open(path: path, JPEG.Context.decompress(stream:))
    }
}
extension JPEG.Data.Planar 
{
    public static 
    func decompress(path:String) throws -> Self?
    {
        guard let spectral:JPEG.Data.Spectral = try .decompress(path: path)
        else 
        {
            return nil 
        }
        return spectral.idct()
    }
}
extension JPEG.Data.Rectangular 
{
    public static 
    func decompress(path:String) throws -> Self? 
    {
        guard let planar:JPEG.Data.Planar = try .decompress(path: path) 
        else 
        {
            return nil 
        }
        
        return planar.interleave()
    }
}

// pixel accessors 
extension JPEG.YCbCr where Component == UInt8 
{
    // y cb cr conversion is only defined for 8-bit precision 
    static 
    func clamp8(_ x:Float) -> UInt8 
    {
        .init(max(.init(UInt8.min), min(x, .init(UInt8.max))))
    }
    
    public 
    var rgb:JPEG.RGB<UInt8>
    {
        let y:Float     = .init(self.y),
            cr:Float    = .init(self.cr),
            cb:Float    = .init(self.cb)
        let r:UInt8     = Self.clamp8(y + 1.40200 * (cr - 128)), 
            g:UInt8     = Self.clamp8(y - 0.34414 * (cb - 128) - 0.71414 * (cr - 128)), 
            b:UInt8     = Self.clamp8(y + 1.77200 * (cb - 128))
        return .init(r, g, b)
    }
}

extension JPEG.Data.Rectangular 
{
    public 
    func ycc() -> [JPEG.YCbCr<UInt8>] 
    {
        switch self.properties.format 
        {
        case .y8:
            return self.values.map 
            {
                .init(y: JPEG.YCbCr.clamp8($0 + 128))
            }
        
        case .ycc8:
            return stride(from: 0, to: self.values.count, by: 3).map 
            {
                .init(
                    y:  JPEG.YCbCr.clamp8(self.values[$0    ] + 128), 
                    cb: JPEG.YCbCr.clamp8(self.values[$0 + 1] + 128), 
                    cr: JPEG.YCbCr.clamp8(self.values[$0 + 2] + 128))
            }
        }
    }
    public 
    func rgb() -> [JPEG.RGB<UInt8>] 
    {
        switch self.properties.format 
        {
        case .y8:
            return self.values.map 
            {
                let ycc:JPEG.YCbCr<UInt8> = .init(y: JPEG.YCbCr.clamp8($0 + 128))
                return ycc.rgb 
            }
        
        case .ycc8:
            return stride(from: 0, to: self.values.count, by: 3).map 
            {
                let ycc:JPEG.YCbCr<UInt8> = .init(
                    y:  JPEG.YCbCr.clamp8(self.values[$0    ] + 128), 
                    cb: JPEG.YCbCr.clamp8(self.values[$0 + 1] + 128), 
                    cr: JPEG.YCbCr.clamp8(self.values[$0 + 2] + 128))
                return ycc.rgb 
            }
        }
    }
}

/// A namespace for file IO functionality.
extension JPEG
{
    public
    enum File
    {
        private
        typealias Descriptor = UnsafeMutablePointer<FILE>
        
        /// Read data from files on disk.
        public
        struct Source
        {
            private
            let descriptor:Descriptor
        }
    }
}
extension JPEG.File.Source:JPEG.Bytestream.Source 
{
    /// Calls a closure with an interface for reading from the specified file.
    /// 
    /// This method automatically closes the file when its function argument returns.
    /// - Parameters:
    ///     - path: A path to the file to open.
    ///     - body: A closure with a `Source` parameter from which data in
    ///         the specified file can be read. This interface is only valid
    ///         for the duration of the method’s execution. The closure is
    ///         only executed if the specified file could be successfully
    ///         opened, otherwise `nil` is returned. If `body` has a return
    ///         value and the specified file could be opened, its return
    ///         value is returned as the return value of the `open(path:body:)`
    ///         method.
    /// - Returns: `nil` if the specified file could not be opened, or the
    ///     return value of the function argument otherwise.
    public static
    func open<Result>(path:String, _ body:(inout Self) throws -> Result)
        rethrows -> Result?
    {
        guard let descriptor:JPEG.File.Descriptor = fopen(path, "rb")
        else
        {
            return nil
        }

        var file:Self = .init(descriptor: descriptor)
        defer
        {
            fclose(file.descriptor)
        }

        return try body(&file)
    }

    /// Read the specified number of bytes from this file interface.
    /// 
    /// This method only returns an array if the exact number of bytes
    /// specified could be read. This method advances the file pointer.
    /// 
    /// - Parameters:
    ///     - capacity: The number of bytes to read.
    /// - Returns: An array containing the read data, or `nil` if the specified
    ///     number of bytes could not be read.
    public
    func read(count capacity:Int) -> [UInt8]?
    {
        let buffer:[UInt8] = .init(unsafeUninitializedCapacity: capacity)
        {
            (buffer:inout UnsafeMutableBufferPointer<UInt8>, count:inout Int) in

            count = fread(buffer.baseAddress, MemoryLayout<UInt8>.stride,
                capacity, self.descriptor)
        }

        guard buffer.count == capacity
        else
        {
            return nil
        }

        return buffer
    }
}

// raw buffer utilities 
fileprivate
extension Array where Element == UInt8
{
    /// Loads a misaligned big-endian integer value from the given byte offset
    /// and casts it to a desired format.
    /// - Parameters:
    ///     - bigEndian: The size and type to interpret the data to load as.
    ///     - type: The type to cast the read integer value to.
    ///     - byte: The byte offset to load the big-endian integer from.
    /// - Returns: The read integer value, cast to `U`.
    func load<T, U>(bigEndian:T.Type, as type:U.Type, at byte:Int) -> U
        where T:FixedWidthInteger, U:BinaryInteger
    {
        return self[byte ..< byte + MemoryLayout<T>.size].load(bigEndian: T.self, as: U.self)
    }
}

fileprivate
extension ArraySlice where Element == UInt8
{
    /// Loads this array slice as a misaligned big-endian integer value,
    /// and casts it to a desired format.
    /// - Parameters:
    ///     - bigEndian: The size and type to interpret this array slice as.
    ///     - type: The type to cast the read integer value to.
    /// - Returns: The read integer value, cast to `U`.
    func load<T, U>(bigEndian:T.Type, as type:U.Type) -> U
        where T:FixedWidthInteger, U:BinaryInteger
    {
        return self.withUnsafeBufferPointer
        {
            (buffer:UnsafeBufferPointer<UInt8>) in

            assert(buffer.count >= MemoryLayout<T>.size,
                "attempt to load \(T.self) from slice of size \(buffer.count)")

            var storage:T = .init()
            let value:T   = withUnsafeMutablePointer(to: &storage)
            {
                $0.deinitialize(count: 1)

                let source:UnsafeRawPointer     = .init(buffer.baseAddress!),
                    raw:UnsafeMutableRawPointer = .init($0)

                raw.copyMemory(from: source, byteCount: MemoryLayout<T>.size)

                return raw.load(as: T.self)
            }

            return U(T(bigEndian: value))
        }
    }
}

// language support 
extension JPEG 
{
    @propertyWrapper 
    public 
    struct Storage<I> where I:FixedWidthInteger & BinaryInteger 
    {
        private 
        var storage:I 
        
        public 
        init(wrappedValue:Int) 
        {
            self.storage = .init(truncatingIfNeeded: wrappedValue)
        }
        
        public 
        var wrappedValue:Int 
        {
            get 
            {
                .init(self.storage)
            }
        }
    }
    @propertyWrapper 
    public 
    struct Storage2<I> where I:FixedWidthInteger & BinaryInteger 
    {
        private 
        var storage:(x:I, y:I) 
        
        public 
        init(wrappedValue:(x:Int, y:Int)) 
        {
            self.storage = 
            (
                .init(truncatingIfNeeded: wrappedValue.x),
                .init(truncatingIfNeeded: wrappedValue.y)
            )
        }
        
        public 
        var wrappedValue:(x:Int, y:Int) 
        {
            get 
            {
                (.init(self.storage.x), .init(self.storage.y))
            }
        }
    }
}
