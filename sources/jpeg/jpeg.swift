import Glibc

func decode(path:String) throws
{
    try JPEG.File.Source.open(path: path) 
    {
        (stream:inout JPEG.File.Source) in 
        
        var marker:(type:JPEG.Marker, data:[UInt8]) 
        
        // start of image 
        marker = try stream.segment()
        guard case .start = marker.type 
        else 
        {
            throw JPEG.Decode.Error.unexpected
        }
        
        // jfif header (must immediately follow start of image)
        marker = try stream.segment()
        guard case .application(0) = marker.type 
        else 
        {
            throw JPEG.Decode.Error.unexpected
        }
        let image:JPEG.JFIF = try .parse(marker.data) 
        
        print(image)
        
        var context:JPEG.Context = .init()
        marker = try stream.segment()
        loop:
        while true 
        {
            switch marker.type 
            {
            case .frame(let mode):
                try context.handle(frame: marker.data, mode: mode)
            
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
                print("ecs(\(ecs.count))")
                
                try context.handle(ecs: ecs)
                continue loop
            
            case .height:
                try context.handle(height: marker.data)
            case .restart:
                try context.handle(restart: marker.data)
            
            case .end:
                let (values, stride):([(Float, Float, Float)], Int) = context.ycbcr()
                for y:Int in 0 ..< values.count / stride 
                {
                    let line:String = (2 * stride / 8 ..< 3 * stride / 8).map 
                    {
                        (x:Int) in 
                        
                        let (y, cb, cr):(Float, Float, Float) = values[y * stride + x]
                        let r:Float = 128 + y + 1.40200 * cr, 
                            g:Float = 128 + y - 0.34414 * cb - 0.714136 * cr, 
                            b:Float = 128 + y + 1.77200 * cb
                        return Highlight.square((r / 255, g / 255, b / 255))
                    }.joined(separator: "")
                    print(line)
                }
                
                break loop
                // throw JPEG.Parse.Error.premature(marker.type)
            
            case .start:
                throw JPEG.Decode.Error.duplicate
            }
            
            marker = try stream.segment() 
        }
    }
    
    print()
    print()
    print()
}


protocol _JPEGBytestreamSource 
{
    mutating 
    func read(count:Int) -> [UInt8]?
}

enum JPEG 
{
    enum Bytestream 
    {
        typealias Source = _JPEGBytestreamSource
    }
    struct Bitstream 
    {
        private 
        let atoms:[UInt16]
        let count:Int
    }
    
    enum Marker
    {
        case start
        case end
        
        case quantization 
        case huffman 
        
        case height 
        case restart 
        case comment 
        case application(Int)
        
        case frame(Mode)
        case scan 
        
        init?(code:UInt8) 
        {
            switch code 
            {
            case 0xd8:
                self = .start 
            case 0xd9:
                self = .end 
            case 0xdb:
                self = .quantization
            case 0xc4:
                self = .huffman
            case 0xdc:
                self = .height 
            case 0xdd:
                self = .restart 
            case 0xfe:
                self = .comment 
            case 0xe0 ..< 0xf0:
                self = .application(.init(code) - 0xe0)
                
            case 0xda:
                self = .scan 
            
            case 0xc0:
                self = .frame(.baselineDCT)

            case 0xc1:
                self = .frame(.extendedDCT)

            case 0xc2:
                self = .frame(.progressiveDCT)

            case 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf:
                self = .frame(.unsupported(.init(code & 0x0f)))
            
            default:
                return nil
            }
        }
    }
}

protocol _JPEGError:Swift.Error 
{
    typealias Location = (file:String, line:Int)
    
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
    var location:Location 
    {
        get 
    }
}
extension JPEG 
{
    typealias Error = _JPEGError
    enum Lex
    {
        fileprivate 
        enum Lexeme 
        {
            case eos 
            
            case byte(UInt8)
            
            case markerSegmentPrefix
            case markerSegmentType 
            case markerSegmentLength
            case markerSegmentBody
            
            case entropyCodedSegment
        }
        
        enum Error
        {
            case eos(String, details:String?, location:Location)
            case other(String, details:String?, location:Location)
        }
    }
    enum Parse 
    {
        enum Error:Swift.Error 
        {
            case invalidSegmentLength(Int, expected:ClosedRange<Int>, location:Location)
            
            case invalidSignature([UInt8], location:Location)
            case invalidVersion((major:Int, minor:Int), location:Location)
            case invalidDensityUnit(Int, location:Location)
            
            case unsupportedEncodingMode(Int, location:Location)
            case invalidPrecision(Int, JPEG.Mode, location:Location)
            case invalidComponentCount(Int, JPEG.Mode, location:Location)
            case invalidQuantizationSelector(Int, location:Location)
            case invalidSamplingFactors((x:Int, y:Int), location:Location)
            case duplicateComponentIndex(Int, location:Location)
            
            case invalidScanComponentCount(Int, location:Location)
            case invalidHuffmanSelectors((dc:Int, ac:Int), JPEG.Mode, location:Location)
            case undefinedComponentReference(Int, [Int], location:Location)
            case invalidSamplingVolume(Int, location:Location)
            case invalidProgressiveSubset(band:(Int, Int), bits:(Int, Int), Int, JPEG.Mode, location:Location)
            
            case invalidHuffmanTarget(Int, location:Location)
            case invalidHuffmanTable(location:Location)
            
            case invalidQuantizationTarget(Int, location:Location)
            case invalidQuantizationPrecision(Int, location:Location)
        }
    }
    enum Decode 
    {
        enum Error:Swift.Error 
        {
            case unexpected, duplicate, premature
            case missingBits(location:Location)
            case invalidCoefficientBinade(Int, expected:ClosedRange<Int>, location:Location)
            
            case undefinedHuffmanTableReference(JPEG.HuffmanTable.Selector, location:Location)
            case undefinedQuantizationTableReference(JPEG.QuantizationTable.Selector, location:Location)
        }
    }
}
 
extension JPEG.Lex.Lexeme:CustomStringConvertible 
{
    var description:String 
    {
        switch self 
        {
        case .eos:
            return "end-of-stream"
        
        case .byte(let byte):
            return "byte 0x\(String.init(byte, radix: 16))"
        
        case .markerSegmentPrefix:
            return "marker segment prefix"
        case .markerSegmentType:
            return "marker segment type"
        case .markerSegmentLength:
            return "marker segment length field"
        case .markerSegmentBody:
            return "marker segment body"
        
        case .entropyCodedSegment:
            return "entropy-coded segment"
        }
    }
}
extension JPEG.Lex.Error:JPEG.Error 
{
    static 
    var namespace:String 
    {
        "lexing error" 
    }
    var message:String 
    {
        switch self 
        {
        case    .eos    (let message, details: _, location: _),
                .other  (let message, details: _, location: _):
            return message 
        } 
    }
    var details:String? 
    {
        switch self 
        {
        case    .eos    (_, details: let details, location: _),
                .other  (_, details: let details, location: _):
            return details 
        } 
    }
    var location:Location 
    {
        switch self 
        {
        case    .eos    (_, details: _, location: let location),
                .other  (_, details: _, location: let location):
            return location
        } 
    }
    
    fileprivate static 
    func unexpected(_ lexeme:JPEG.Lex.Lexeme, lexing context:JPEG.Lex.Lexeme, _ message:String? = nil, file:String = #file, line:Int = #line)
        -> Self 
    {
        switch lexeme
        {
        case .eos:
            return .eos("unexpected \(lexeme) while lexing \(context)",   details: message, location: (file, line))
        default:
            return .other("unexpected \(lexeme) while lexing \(context)", details: message, location: (file, line))
        }
    }
    fileprivate static 
    func invalid(_ lexeme:JPEG.Lex.Lexeme, _ message:String? = nil, file:String = #file, line:Int = #line)
        -> Self 
    {
        return .other("invalid \(lexeme)", details: message, location: (file, line))
    }
}
extension JPEG.Parse.Error:JPEG.Error 
{
    static 
    var namespace:String 
    {
        "parsing error" 
    }
    var message:String 
    {
        switch self 
        {
        case .invalidSegmentLength:
            return "invalid segment length"
        
        case .invalidSignature:
            return "invalid JFIF signature"
        case .invalidVersion:
            return "invalid JFIF version"
        case .invalidDensityUnit:
            return "invalid JFIF density unit"
        
        case .unsupportedEncodingMode:
            return "unsupported encoding mode"
        case .invalidPrecision:
            return "invalid precision specifier"
        case .invalidComponentCount:
            return "invalid total component count"
        case .invalidQuantizationSelector:
            return "invalid quantization table selector"
        case .invalidSamplingFactors:
            return "invalid component sampling factors"
        case .duplicateComponentIndex:
            return "duplicate component indices"
        
        case .invalidScanComponentCount:
            return "invalid scan component count"
        case .invalidHuffmanSelectors:
            return "invalid huffman table selectors"
        case .undefinedComponentReference:
            return "undefined component reference"
        case .invalidSamplingVolume:
            return "invalid scan component sampling volume"
        case .invalidProgressiveSubset:
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
    
    var details:String? 
    {
        switch self 
        {
        case .invalidSegmentLength(let count, expected: let expected, location: _):
            if expected.count == 1
            {
                return "segment (\(count) bytes) must be exactly \(expected.lowerBound) bytes long"
            }
            else 
            {
                return "segment (\(count) bytes) must be at least \(expected.lowerBound) bytes long"
            }
        
        case .invalidSignature(let string, location: _):
            return "string (\(string.map{ "0x\(String.init($0, radix: 16))" }.joined(separator: ", "))) is not a valid JFIF signature"
        case .invalidVersion(let version, location: _):
            return "version (\(version.major).\(version.minor)) must be within 1.0 ... 1.2"
        case .invalidDensityUnit(let code, location: _):
            return "density code (\(code)) does not correspond to a valid density unit"
        
        case .unsupportedEncodingMode(let code, location: _):
            return "encoding mode (\(code)) is not supported"
        case .invalidPrecision(let precision, let mode, location: _):
            return "precision (\(precision)) is not allowed for encoding mode '\(mode)'"
        case .invalidComponentCount(let count, let mode, location: _):
            if count == 0 
            {
                return "frame must have at least one component"
            }
            else 
            {
                return "frame (\(count) components) with encoding mode '\(mode)' has disallowed component count"
            }  
        case .invalidQuantizationSelector(let i, location: _):
            return "quantization table selector (\(i)) must be within 0 ... 3"
        case .invalidSamplingFactors(let factor, location: _):
            return "both sampling factors (\(factor.x), \(factor.y)) must be within 1 ... 4"
        case .duplicateComponentIndex(let ci, location: _):
            return "component index (\(ci)) conflicts with previously defined component"
        
        case .invalidScanComponentCount(let count, location: _):
            if count == 0 
            {
                return "scan must contain at least one component"
            }
            else 
            {
                return "scan (\(count) components) cannot have more than 4 components"
            } 
        case .invalidHuffmanSelectors(let (dc: dc, ac: ac), let mode, location: _):
            return "huffman table selectors (dc: \(dc), ac: \(ac)) are not allowed for encoding mode '\(mode)'"
        case .undefinedComponentReference(let ci, let defined, location: _):
            return "component with index (\(ci)) is not one of the components (\(defined)) defined in frame header"
        case .invalidSamplingVolume(let volume, location: _):
            return "scan mcu sample count (\(volume)) can be at most 10"
        case .invalidProgressiveSubset(band: let band, bits: let bits, let count, let mode, location: _):
            return "scan (\(count) components) with encoding mode '\(mode)' cannot define bits [\(bits.1):\(bits.0)] for coefficients [\(band.0) ... \(band.1)]"
        
        case .invalidHuffmanTarget(let code, location: _):
            return "selector code (0x\(String.init(code, radix: 16))) does not correspond to a valid huffman table destination"
        case .invalidHuffmanTable(location: _):
            return nil
        
        case .invalidQuantizationTarget(let code, location: _):
            return "selector code (0x\(String.init(code, radix: 16))) does not correspond to a valid quantization table destination"
        case .invalidQuantizationPrecision(let code, location: _):
            return "code (\(code)) does not correspond to a valid quantization table precision"
        }
    }
    var location:Location 
    {
        switch self 
        {
        case    .invalidSegmentLength(_, expected: _,            location: let location),
                .invalidSignature(_,                             location: let location),
                .invalidVersion(_,                               location: let location),
                .invalidDensityUnit(_,                           location: let location),
                .unsupportedEncodingMode(_,                      location: let location),
                .invalidPrecision(_, _,                          location: let location),
                .invalidComponentCount(_, _,                     location: let location),
                .invalidQuantizationSelector(_,                  location: let location),
                .invalidSamplingFactors(_,                       location: let location),
                .duplicateComponentIndex(_,                      location: let location),
                .invalidScanComponentCount(_,                    location: let location),
                .invalidHuffmanSelectors(_, _,                   location: let location),
                .undefinedComponentReference(_, _,               location: let location),
                .invalidSamplingVolume(_,                        location: let location),
                .invalidProgressiveSubset(band: _, bits: _, _, _,location: let location),
                .invalidHuffmanTarget(_,                         location: let location),
                .invalidHuffmanTable(                            location: let location),
                .invalidQuantizationTarget(_,                    location: let location),
                .invalidQuantizationPrecision(_,                 location: let location):
            return location
        }
    }
    
    fileprivate static 
    func invalid(markerLength count:Int, minimum:Int, file:String = #file, line:Int = #line)
        -> Self 
    {
        return .invalidSegmentLength(count, expected: minimum ... .max, location: (file, line))
    }
    fileprivate static 
    func invalid(markerLength count:Int, required:Int, file:String = #file, line:Int = #line)
        -> Self 
    {
        return .invalidSegmentLength(count, expected: required ... required, location: (file, line))
    }
}
extension JPEG.Decode.Error:JPEG.Error 
{
    static 
    var namespace:String 
    {
        "decoding error" 
    }
    var message:String 
    {
        switch self 
        {
        case .unexpected, .duplicate, .premature:
            return ""
        
        case .missingBits:
            return "not enough data in ecs segment bitstream"
        case .undefinedHuffmanTableReference:
            return "undefined huffman table reference"
        case .undefinedQuantizationTableReference:
            return "undefined quantization table reference"
        case .invalidCoefficientBinade:
            return "invalid DCT coefficient binade"
        }
    }
    
    var details:String? 
    {
        switch self 
        {
        case .unexpected, .duplicate, .premature:
            return nil

        case .missingBits:
            return "not enough data in ecs segment bitstream"
        case .undefinedHuffmanTableReference(let selector, location: _):
            return "no huffman table has been installed at the location <\(String.init(selector: selector))>"
        case .undefinedQuantizationTableReference(let selector, location: _):
            return "no quantization table has been installed at the location <\(String.init(selector: selector))>"
        case .invalidCoefficientBinade(let binade, expected: let expected, location: _):
            return "DCT coefficient binade (\(binade)) must be within \(expected.lowerBound) ... \(expected.upperBound)"
        }
    }
    var location:Location 
    {
        switch self 
        {
        case    .unexpected, .duplicate, .premature:
            return ("", -1)

        case    .missingBits(                               location: let location), 
                .undefinedHuffmanTableReference(_,          location: let location),
                .invalidCoefficientBinade(_, expected: _,   location: let location),
                .undefinedQuantizationTableReference(_,     location: let location):
            return location
        }
    }
}

// compound types 
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
    
    enum Mode 
    {
        case baselineDCT, extendedDCT, progressiveDCT
        case unsupported(Int)
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
                throw JPEG.Lex.Error.unexpected(.eos, lexing: .markerSegmentLength)
            }
            let length:Int = header.load(bigEndian: UInt16.self, as: Int.self, at: 0)
            
            guard length >= 2
            else 
            {
                throw JPEG.Lex.Error.invalid(.markerSegmentLength, "length (\(length)) must be at least 2")
            }
            guard let data:[UInt8] = self.read(count: length - 2)
            else 
            {
                throw JPEG.Lex.Error.unexpected(.eos, lexing: .markerSegmentBody, "expected \(length - 2) bytes")
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
                throw JPEG.Lex.Error.unexpected(.byte($0), lexing: .markerSegmentPrefix, "expected 0xff byte")
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
                    throw JPEG.Lex.Error.unexpected(.eos, lexing: .markerSegmentType)
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
                throw JPEG.Lex.Error.invalid(.markerSegmentType, "0x\(String.init(byte, radix: 16)) is not a valid JPEG marker")
            }
                
            let data:[UInt8] = try self.tail(type: marker)
            return (ecs, (marker, data))
        }
        
        throw JPEG.Lex.Error.unexpected(.eos, lexing: .entropyCodedSegment)
    }
}

// parsing 
extension JPEG 
{
    struct JFIF
    {
        let version:(major:Int, minor:Int),
            density:(x:Int, y:Int, unit:DensityUnit)

        static 
        func parse(_ data:[UInt8]) throws -> Self
        {
            guard data.count >= 14
            else
            {
                throw JPEG.Parse.Error.invalid(markerLength: data.count, minimum: 14)
            }
            
            // look for 'JFIF' signature
            guard data[0 ..< 5] == [0x4a, 0x46, 0x49, 0x46, 0x00]
            else 
            {
                throw JPEG.Parse.Error.invalidSignature(.init(data[0 ..< 5]), location: (#file, #line))
            }

            let version:(major:Int, minor:Int)
            version.major = .init(data[5])
            version.minor = .init(data[6])

            guard   1 ... 1 ~= version.major, 
                    0 ... 2 ~= version.minor
            else
            {
                // bad JFIF version number (expected 1.0 ... 1.2)
                throw JPEG.Parse.Error.invalidVersion(version, location: (#file, #line))
            }

            guard let unit:DensityUnit = DensityUnit.init(code: data[7])
            else
            {
                // invalid JFIF density unit
                throw JPEG.Parse.Error.invalidDensityUnit(.init(data[7]), location: (#file, #line))
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
    
    struct Frame
    {
        struct Component
        {
            let factor:(x:Int, y:Int)
            let selector:JPEG.QuantizationTable.Selector 
        }

        let mode:Mode,
            precision:Int

        private(set) // DNL segment may change this later on
        var size:(x:Int, y:Int)

        let components:[Int: Component]

        static
        func parse(_ data:[UInt8], mode:JPEG.Mode) throws -> Self
        {
            if case .unsupported(let code) = mode 
            {
                throw JPEG.Parse.Error.unsupportedEncodingMode(code, location: (#file, #line))
            }
            
            guard data.count >= 6
            else
            {
                throw JPEG.Parse.Error.invalid(markerLength: data.count, minimum: 6)
            }

            let precision:Int = .init(data[0])
            switch (mode, precision) 
            {
            case    (.baselineDCT,      8), 
                    (.extendedDCT,      8), (.extendedDCT,      16), 
                    (.progressiveDCT,   8), (.progressiveDCT,   16):
                break

            default:
                // invalid precision
                throw JPEG.Parse.Error.invalidPrecision(precision, mode, location: (#file, #line))
            }
            
            let size:(x:Int, y:Int) = 
            (
                data.load(bigEndian: UInt16.self, as: Int.self, at: 3),
                data.load(bigEndian: UInt16.self, as: Int.self, at: 1)
            )

            let count:Int = .init(data[5])
            switch (mode, count) 
            {
            case    (.baselineDCT,      1 ... .max), 
                    (.extendedDCT,      1 ... .max), 
                    (.progressiveDCT,   1 ... 4   ):
                break

            default:
                // invalid count
                throw JPEG.Parse.Error.invalidComponentCount(count, mode, location: (#file, #line))
            }

            guard data.count == 3 * count + 6
            else
            {
                // wrong segment size
                throw JPEG.Parse.Error.invalid(markerLength: data.count, required: 3 * count + 6)
            }

            var components:[Int: Component] = [:]
            for i:Int in 0 ..< count
            {
                let base:Int = 3 * i + 6
                let byte:(UInt8, UInt8, UInt8) = (data[base], data[base + 1], data[base + 2])
                
                let factor:(x:Int, y:Int)  = (.init(byte.1 >> 4), .init(byte.1 & 0x0f))
                let ci:Int                  = .init(byte.0)
                
                let selector:JPEG.QuantizationTable.Selector 
                switch byte.2 
                {
                case 0:
                    selector = \.0
                case 1:
                    selector = \.1
                case 2:
                    selector = \.2
                case 3:
                    selector = \.3
                default:
                    throw JPEG.Parse.Error.invalidQuantizationSelector(.init(byte.2), location: (#file, #line))
                }
                
                guard   1 ... 4 ~= factor.x,
                        1 ... 4 ~= factor.y
                else
                {
                    throw JPEG.Parse.Error.invalidSamplingFactors(factor, location: (#file, #line))
                }
                
                let component:Component = .init(factor: factor, selector: selector)
                // make sure no duplicate component indices are used 
                guard components.updateValue(component, forKey: ci) == nil 
                else 
                {
                    throw JPEG.Parse.Error.duplicateComponentIndex(ci, location: (#file, #line))
                }
            }

            return .init(mode: mode, precision: precision, size: size, components: components)
        }
        
        // parse DNL segment 
        mutating
        func height(_ data:[UInt8]) throws 
        {
            guard data.count == 2
            else
            {
                throw JPEG.Parse.Error.invalid(markerLength: data.count, required: 2)
            }

            self.size.y = data.load(bigEndian: UInt16.self, as: Int.self, at: 0)
        }
    }
    
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
                huffman:(dc:JPEG.HuffmanTable.Selector, ac:JPEG.HuffmanTable.Selector), 
                quantization:JPEG.QuantizationTable.Selector 
            )
        }
        
        let band:Range<Int>, 
            bits:Range<Int>, 
            components:[Component] 
        
        static 
        func parse(_ data:[UInt8], frame:JPEG.Frame, 
            tables:(huffman:JPEG.HuffmanTable.Slots, quantization:JPEG.QuantizationTable.Slots)) 
            throws -> Self
        {
            guard data.count >= 4 
            else 
            {
                throw JPEG.Parse.Error.invalid(markerLength: data.count, minimum: 4)
            }
            
            let count:Int = .init(data[0])
            guard 1 ... 4 ~= count
            else 
            {
                throw JPEG.Parse.Error.invalidScanComponentCount(count, location: (#file, #line))
            } 
            
            guard data.count == 2 * count + 4
            else 
            {
                // wrong segment size
                throw JPEG.Parse.Error.invalid(markerLength: data.count, required: 2 * count + 4)
            }
            
            let components:[Component] = try (0 ..< count).map 
            {
                let base:Int            = 2 * $0 + 1
                let byte:(UInt8, UInt8) = (data[base], data[base + 1])
                
                let ci:Int = .init(byte.0)
                let selector:(dc:JPEG.HuffmanTable.Selector, ac:JPEG.HuffmanTable.Selector) 
                
                switch (frame.mode, byte.1 >> 4, byte.1 & 0x0f) 
                {
                case    (.baselineDCT,      0 ... 1, 0 ... 1), 
                        (.extendedDCT,      0 ... 3, 0 ... 3), 
                        (.progressiveDCT,   0 ... 3, 0 ... 3):
                    break 
                
                default:
                    throw JPEG.Parse.Error.invalidHuffmanSelectors((.init(byte.1 >> 4), .init(byte.1 & 0x0f)), frame.mode, location: (#file, #line))
                }
                
                switch byte.1 >> 4
                {
                case 0:
                    selector.dc = \.dc.0
                case 1:
                    selector.dc = \.dc.1
                case 2:
                    selector.dc = \.dc.2
                case 3:
                    selector.dc = \.dc.3
                default:
                    fatalError("unreachable")
                }
                switch byte.1 & 0xf
                {
                case 0:
                    selector.ac = \.ac.0
                case 1:
                    selector.ac = \.ac.1
                case 2:
                    selector.ac = \.ac.2
                case 3:
                    selector.ac = \.ac.3
                default:
                    fatalError("unreachable")
                }
                
                guard let component:JPEG.Frame.Component    = frame.components[ci]
                else 
                {
                    throw JPEG.Parse.Error.undefinedComponentReference(ci, frame.components.keys.sorted(), location: (#file, #line))
                }
                
                return .init(ci: ci, factor: component.factor, selectors: (selector, component.selector))
            }
            
            // validate sampling factor sum 
            let volume:Int = components.map{ $0.factor.x * $0.factor.y }.reduce(0, +) 
            guard 0 ... 10 ~= volume
            else 
            {
                throw JPEG.Parse.Error.invalidSamplingVolume(volume, location: (#file, #line))
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
                throw JPEG.Parse.Error.invalidProgressiveSubset(band: band, bits: bits, count, frame.mode, location: (#file, #line))
            }
            
            switch (frame.mode, band.0, band.1, bits.0, bits.1) 
            {
            case    (.baselineDCT,      0,        63,                0,                     frame.precision), 
                    (.extendedDCT,      0,        63,                0,                     frame.precision),
                    (.progressiveDCT,   0,        0,                 0 ..< frame.precision, bits.0 + 1 ... frame.precision),
                    (.progressiveDCT,   1 ..< 64, band.0 + 1 ..< 64, 0 ..< frame.precision, bits.0 + 1 ... frame.precision):
                break 
            
            default:
                throw JPEG.Parse.Error.invalidProgressiveSubset(band: band, bits: bits, count, frame.mode, location: (#file, #line))
            }
            
            return .init(band: band.0 ..< band.1 + 1, bits: bits.0 ..< bits.1, components: components)
        }
    }
    
    struct HuffmanTable 
    {
        typealias Slots    = (dc:(Self?, Self?, Self?, Self?), ac:(Self?, Self?, Self?, Self?))
        typealias Selector = WritableKeyPath<Slots, Self?>
        
        typealias Entry  = (value:UInt8, length:UInt8)
        
        let storage:[Entry], 
            n:Int, // number of level 0 entries
            ζ:Int  // logical size of the table (where the n level 0 entries are each 256 units big)
        
        let target:Selector
        
        static 
        func parse(_ data:[UInt8]) throws -> [Self] 
        {
            var tables:[Self] = []
            
            var base:Int = 0
            while base < data.count
            {
                guard data.count >= base + 17
                else
                {
                    // data buffer does not contain enough data
                    throw JPEG.Parse.Error.invalid(markerLength: data.count, minimum: base + 17)
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
                    throw JPEG.Parse.Error.invalid(markerLength: data.count, minimum: base + 17 + count)
                }
                
                leaf.values = data[base + 17 ..< base + 17 + count]
                
                let target:Selector
                switch data[base] 
                {
                case 0x00:
                    target = \.dc.0
                case 0x01:
                    target = \.dc.1
                case 0x02:
                    target = \.dc.2
                case 0x03:
                    target = \.dc.3
                case 0x10:
                    target = \.ac.0
                case 0x11:
                    target = \.ac.1
                case 0x12:
                    target = \.ac.2
                case 0x13:
                    target = \.ac.3

                default:
                    // huffman table has invalid binding index
                    throw JPEG.Parse.Error.invalidHuffmanTarget(.init(data[base]), location: (#file, #line))
                }
                
                guard let table:Self = .build(counts: leaf.counts, values: leaf.values, target: target)
                else 
                {
                    throw JPEG.Parse.Error.invalidHuffmanTable(location: (#file, #line))
                }
                
                tables.append(table)
                
                base += 17 + count
            }
            
            return tables
        }
    }
    
    struct QuantizationTable 
    {
        typealias Slots    = (Self?, Self?, Self?, Self?)
        typealias Selector = WritableKeyPath<Slots, Self?>
        
        private 
        let elements:[Int]
        let target:Selector
        
        static 
        func parse(_ data:[UInt8]) throws -> [Self] 
        {
            var tables:[Self] = []
            
            var base:Int = 0 
            while base < data.count 
            {
                let target:Selector
                switch data[base] & 0x0f
                {
                case 0:
                    target = \.0 
                case 1:
                    target = \.1 
                case 2:
                    target = \.2 
                case 3:
                    target = \.3 
                default:
                    throw JPEG.Parse.Error.invalidQuantizationTarget(.init(data[base] & 0x0f), location: (#file, #line))
                }
                
                let table:Self
                switch data[base] & 0xf0 
                {
                case 0x00:
                    guard data.count >= base + 65 
                    else 
                    {
                        throw JPEG.Parse.Error.invalid(markerLength: data.count, minimum: base + 65)
                    }
                    
                    table = .build(values: data[base + 1 ..< base + 65], target: target)
                    base += 65 
                case 0x10:
                    guard data.count >= base + 129 
                    else 
                    {
                        throw JPEG.Parse.Error.invalid(markerLength: data.count, minimum: base + 129)
                    }
                    
                    table = .build(values: data[base + 1 ..< base + 129], target: target)
                    base += 129 
                
                default:
                    throw JPEG.Parse.Error.invalidQuantizationPrecision(.init(data[base] >> 4), location: (#file, #line))
                }
                
                tables.append(table)
            }
            
            return tables
        }
    }
}

// table builders 
extension JPEG.HuffmanTable 
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

    static 
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
                let entry:Entry = (value: value, length: .init(l + 1))
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
                return (0, 16)
            }
            
            return self.storage[j - self.n * 255]
        }
    }
} 

extension JPEG.QuantizationTable 
{
    static 
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

// decoding procedure
extension JPEG 
{
    struct Spectral
    {
        struct Plane 
        {
            struct Key 
            {
                private 
                let key:[Int: Int]
                
                subscript(ci ci:Int) -> Int 
                {
                    guard let p:Int = self.key[ci]
                    else 
                    {
                        // scan header parsing should filter out all undefined 
                        // component references
                        fatalError("unreachable")
                    }
                    
                    return p
                }
                
                init(_ key:[Int: Int]) 
                {
                    self.key = key
                }
            }
            
            private 
            var buffer:[Int]
            private(set)
            var units:(x:Int, y:Int)
            
            // have to be `Int32` to circumvent compiler size limits for `_read` and `_modify`
            private 
            let _factor:(x:Int32, y:Int32) 
            var factor:(x:Int, y:Int) 
            {
                (.init(self._factor.x), .init(self._factor.y))
            }
            
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
            
            // it is easier to convert (k, h) 2-d coordinates to z zig-zag coordinates
            // than the other way around, so we store the coefficients in zig-zag 
            // order, and provide a subscript that converts 2-d coordinates into 
            // zig-zag coordinates 
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
            
            static 
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
            
            init(factor:(x:Int, y:Int), stride:Int)
            {
                self.buffer = []
                self.units  = (stride, 0)
                self._factor = (.init(factor.x), .init(factor.y))
            }
            
            mutating 
            func resize(to y:Int) 
            {
                let count:Int = 64 * self.units.x * y 
                if count < self.buffer.count 
                {
                    self.buffer.removeLast(self.buffer.count - count)
                }
                else 
                {
                    self.buffer.append(contentsOf: repeatElement(0, count: count - self.buffer.count))
                }
                
                self.units.y = y
            }
        }
        
        private 
        var planes:[Plane] 
        private(set)
        var blocks:(x:Int, y:Int)
        private 
        let scale:(x:Int, y:Int)
        let plane:Plane.Key  
        
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
        
        private static  
        func units(_ size:Int, stride:Int) -> Int  
        {
            let complete:Int = size / stride, 
                partial:Int  = size % stride != 0 ? 1 : 0 
            return complete + partial 
        }
        
        init(components:[Int: JPEG.Frame.Component], width:Int)
        {
            self.scale  = components.values.reduce((0, 0))
            {
                (Swift.max($0.x, $1.factor.x), Swift.max($0.y, $1.factor.y))
            }
            self.blocks = (Self.units(width, stride: 8 * self.scale.x), 0)
            
            var planes:[Plane] = [ ]
            var key:[Int: Int] = [:]
            
            for (p, (ci, component)):(Int, (Int, JPEG.Frame.Component)) in 
                components.sorted(by: { $0.key < $1.key }).enumerated()
            {
                key[ci] = p
                let numerator:Int = width * component.factor.x
                let plane:Plane   = .init(
                    factor: component.factor, 
                    stride: Self.units(numerator, stride: 8 * self.scale.x))
                planes.append(plane)
            }
            
            self.planes = planes 
            self.plane  = .init(key)
        }
    }
}
extension JPEG.Spectral  
{
    mutating 
    func set(height:Int) 
    {
        self.blocks.y = Self.units(height, stride: 8 * self.scale.y)
        for p:Int in self.indices
        {
            let numerator:Int = height * self[p].factor.y
            self[p].resize(to: Self.units(numerator, stride: 8 * self.scale.y))
        }
    }
    mutating 
    func initial(dc data:[UInt8], scan:JPEG.Scan, tables slots:JPEG.HuffmanTable.Slots) 
        throws
    {
        let descriptors:[(plane:Int, factor:(x:Int, y:Int), table:JPEG.HuffmanTable)] = 
            try scan.components.map 
        {
            guard let huffman:JPEG.HuffmanTable = slots[keyPath: $0.selectors.huffman.dc]
            else 
            {
                throw JPEG.Decode.Error.undefinedHuffmanTableReference($0.selectors.huffman.dc, 
                    location: (#file, #line))
            }
            
            return (self.plane[ci: $0.ci], $0.factor, huffman)
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
                
                for (p, factor, _):(plane:Int, factor:(x:Int, y:Int), table:JPEG.HuffmanTable) in 
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
                    for (c, (p, factor, table)):(Int, (plane:Int, factor:(x:Int, y:Int), table:JPEG.HuffmanTable)) in 
                        zip(predecessor.indices, descriptors)
                    {
                        let base:(x:Int, y:Int) = (k * factor.x, h * factor.y)
                        for y:Int in 0 ..< factor.y 
                        {
                            for x:Int in 0 ..< factor.x 
                            {
                                predecessor[c]                             += try bits.ssssx(&b, table: table) 
                                self[p][x: base.x + x, y: base.y + y, z: 0] = predecessor[c] << scan.bits.lowerBound
                            }
                        }
                    }
                }
            }
        }
        else 
        {
            let p:Int                   = descriptors[0].plane, 
                table:JPEG.HuffmanTable = descriptors[0].table
            var predecessor:Int         = 0
            row: 
            for y:Int in 0... 
            {
                if y >= self[p].units.y
                {
                    self[p].resize(to: y + 1)
                }
                
                column:
                for x:Int in 0 ..< self[p].units.x 
                {
                    predecessor              += try bits.ssssx(&b, table: table) 
                    self[p][x: x, y: y, z: 0] = predecessor << scan.bits.lowerBound
                }
            }
        }
    }
    
    mutating 
    func refining(dc data:[UInt8], scan:JPEG.Scan) throws
    {
        let descriptors:[(plane:Int, factor:(x:Int, y:Int))] = 
            scan.components.map 
        {
            return (self.plane[ci: $0.ci], $0.factor)
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
                                let refinement:Int                           = try bits.y(&b)
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
                    let refinement:Int         = try bits.y(&b) 
                    self[p][x: x, y: y, z: 0] |= refinement << scan.bits.lowerBound
                }
            }
        }
    } 
    
    mutating 
    func initial(ac data:[UInt8], scan:JPEG.Scan, tables slots:JPEG.HuffmanTable.Slots) 
        throws
    {
        // count is validated in scan parser
        assert(scan.components.count == 1)
        let component:JPEG.Scan.Component   = scan.components[0]
        let p:Int                           = self.plane[ci: component.ci]
        guard let table:JPEG.HuffmanTable   = slots[keyPath: component.selectors.huffman.ac]
        else 
        {
            throw JPEG.Decode.Error.undefinedHuffmanTableReference(component.selectors.huffman.ac, 
                location: (#file, #line))
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
                /* guard skip <= 0 
                else 
                {
                    skip -= 1 
                    continue column 
                }
                
                var z:Int = scan.band.lowerBound
                while z < scan.band.upperBound  
                {
                    let (zeroes, run, coefficient):(zeroes:Int, run:Int, coefficient:Int) =
                        try bits.rrrrssssx(&b, table: table)
                    
                    z   += zeroes 
                    skip = run - 1
                    
                    guard z < scan.band.upperBound 
                    else 
                    {
                        continue column  
                    }
                    self[p][x: x, y: y, z: z] = coefficient << scan.bits.lowerBound
                    z += 1
                } */
                
                var z:Int = scan.band.lowerBound
                frequency: 
                while z < scan.band.upperBound  
                {
                    // we spell the body of this loop this way to match the 
                    // flow logic of `refining(ac:scan:tables)`
                    let (zeroes, run, coefficient):(zeroes:Int, run:Int, coefficient:Int) 
                    if skip > 0 
                    {
                        (zeroes, run, coefficient) = (64, skip, 0)
                    } 
                    else 
                    {
                        (zeroes, run, coefficient) = try bits.rrrrssssx(&b, table: table)
                    }
                    
                    skip = run - 1
                    
                    z += zeroes 
                    if z < scan.band.upperBound 
                    {
                        defer 
                        {
                            z += 1
                        }
                        
                        self[p][x: x, y: y, z: z] = coefficient << scan.bits.lowerBound
                        continue frequency  
                    }
                    
                    break frequency
                } 
            }
        }
    }
    
    mutating 
    func refining(ac data:[UInt8], scan:JPEG.Scan, tables slots:JPEG.HuffmanTable.Slots) 
        throws
    {
        // count is validated in scan parser
        assert(scan.components.count == 1)
        let component:JPEG.Scan.Component   = scan.components[0]
        let p:Int                           = self.plane[ci: component.ci]
        guard let table:JPEG.HuffmanTable   = slots[keyPath: component.selectors.huffman.ac]
        else 
        {
            throw JPEG.Decode.Error.undefinedHuffmanTableReference(component.selectors.huffman.ac, 
                location: (#file, #line))
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
                    let (zeroes, run, delta):(zeroes:Int, run:Int, delta:Int) 
                    
                    if skip > 0 
                    {
                        (zeroes, run, delta) = (64, skip, 0)
                    } 
                    else 
                    {
                        (zeroes, run, delta) = try bits.rrrrssssy(&b, table: table)
                    }
                    
                    skip = run - 1
                    
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
                            guard b < bits.count 
                            else 
                            {
                                throw JPEG.Decode.Error.missingBits(location: (#file, #line))
                            }
                            
                            let delta:Int = bits[b]
                            b += 1
                            
                            let sign:Int = unrefined < 0 ? -1 : 1
                            self[p][x: x, y: y, z: z] += delta * sign << scan.bits.lowerBound
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
    func dequantize(scan:JPEG.Scan, tables slots:JPEG.QuantizationTable.Slots) throws
    {
        guard scan.bits.lowerBound == 0 
        else 
        {
            return 
        }
        
        let descriptors:[(plane:Int, table:JPEG.QuantizationTable)] = 
            try scan.components.map 
        {
            guard let quantization:JPEG.QuantizationTable = 
                slots[keyPath: $0.selectors.quantization]
            else 
            {
                throw JPEG.Decode.Error.undefinedQuantizationTableReference($0.selectors.quantization, 
                    location: (#file, #line))
            }
            
            return (self.plane[ci: $0.ci], quantization)
        }
        
        for (p, table):(Int, JPEG.QuantizationTable) in descriptors 
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
extension JPEG.Spectral:RandomAccessCollection 
{
    var startIndex:Int 
    {
        0
    }
    var endIndex:Int 
    {
        self.planes.endIndex
    }
}

extension JPEG 
{
    struct Context
    {
        private
        var tables:(huffman:JPEG.HuffmanTable.Slots, quantization:JPEG.QuantizationTable.Slots) = 
        (
            (
                dc: (nil, nil, nil, nil),
                ac: (nil, nil, nil, nil)
            ), 
            
            (nil, nil, nil, nil)
        )
        
        private 
        var frame:JPEG.Frame?  = nil, 
            scan:JPEG.Scan?    = nil 
        
        private 
        var spectral:Spectral? = nil
        
        mutating
        func handle(huffman data:[UInt8]) throws
        {
            let tables:[JPEG.HuffmanTable] = try JPEG.HuffmanTable.parse(data)
            print("[")
            for table:JPEG.HuffmanTable in tables 
            {
                self.tables.huffman[keyPath: table.target] = table
                print(table.description.split(separator: "\n", omittingEmptySubsequences: false).map{ "    \($0)" }.joined(separator: "\n"))
            }
            print("]")
        }
        mutating 
        func handle(quantization data:[UInt8]) throws
        {
            let tables:[JPEG.QuantizationTable] = try JPEG.QuantizationTable.parse(data)
            print("[")
            for table:JPEG.QuantizationTable in tables 
            {
                self.tables.quantization[keyPath: table.target] = table
                print(table.description.split(separator: "\n", omittingEmptySubsequences: false).map{ "    \($0)" }.joined(separator: "\n"))
            }
            print("]") 
        }
        mutating 
        func handle(frame data:[UInt8], mode:JPEG.Mode) throws
        {
            guard self.frame == nil 
            else 
            {
                throw JPEG.Decode.Error.duplicate
            }
            
            let frame:JPEG.Frame    = try .parse(data, mode: mode)
            print(frame)
            self.frame              = frame
            self.spectral           = .init(components: frame.components, width: frame.size.x)
        }
        mutating 
        func handle(scan data:[UInt8]) throws 
        {
            guard let frame:JPEG.Frame = self.frame 
            else 
            {
                throw JPEG.Decode.Error.premature
            }
            
            let scan:JPEG.Scan      = try .parse(data, frame: frame, tables: self.tables)
            print(scan)
            self.scan               = scan
        }
        func handle(height data:[UInt8]) throws 
        {
        }
        func handle(restart data:[UInt8]) throws 
        {
        }
        
        mutating 
        func handle(ecs data:[UInt8]) throws 
        {
            guard   let frame:JPEG.Frame    = self.frame, 
                    let scan:JPEG.Scan      = self.scan 
            else 
            {
                throw JPEG.Decode.Error.premature
            }
            
            if scan.bits != 0 ..< frame.precision 
            {
                // successive approximation 
                switch (scan.bits.upperBound == frame.precision, scan.band == 0 ..< 1)
                {
                case (true, true):
                    // initial dc scan 
                    try self.spectral?.initial(dc: data, scan: scan, tables: self.tables.huffman) 
                    try self.spectral?.dequantize(scan: scan, tables: self.tables.quantization)
                    if self.spectral?.blocks.y == 0 
                    {
                        self.spectral?.set(height: frame.size.y)
                    }
                    
                case (true, false):
                    // initial ac scan 
                    try self.spectral?.initial(ac: data, scan: scan, tables: self.tables.huffman)
                    try self.spectral?.dequantize(scan: scan, tables: self.tables.quantization)
                     
                case (false, true):
                    // refining dc scan 
                    try self.spectral?.refining(dc: data, scan: scan)
                    try self.spectral?.dequantize(scan: scan, tables: self.tables.quantization)
                
                case (false, false):
                    // refining ac scan 
                    try self.spectral?.refining(ac: data, scan: scan, tables: self.tables.huffman)
                    try self.spectral?.dequantize(scan: scan, tables: self.tables.quantization)
                }
            }
            else if scan.band != 0 ..< 64
            {
                // spectral selection 
            }
            else 
            {
                // baseline sequential mode 
            }
        }
        
        func ycbcr() -> (values:[(Float, Float, Float)], stride:Int) 
        {
            
            guard let spectral:JPEG.Spectral = self.spectral 
            else 
            {
                return ([(0, 0, 0)], 1)
            }

            let Y:[Float]  =     spectral[0].idct(), 
                Cb:[Float] =     spectral[1].idct(),
                Cr:[Float] =     spectral[2].idct(), 
                stride:Int = 8 * spectral[0].units.x
            
            let values:[(Float, Float, Float)] = zip(Y, zip(Cb, Cr)).map 
            {
                ($0.0, $0.1.0, $0.1.1)
            }
            return (values, stride)
        }
    }
}

extension JPEG.Bitstream 
{
    static 
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
    
    func y(_ i:inout Int) throws -> Int
    {
        guard i < self.count 
        else 
        {
            throw JPEG.Decode.Error.missingBits(location: (#file, #line))
        }
        
        defer 
        {
            i += 1
        }
        return self[i] 
    }
    
    // reads an `SSSS:[extra]` pattern from the bitstream
    func ssssx(_ i:inout Int, table:JPEG.HuffmanTable) throws -> Int
    {
        guard i < self.count 
        else 
        {
            throw JPEG.Decode.Error.missingBits(location: (#file, #line))
        }
        
        // read 4 category bits (huffman coded)
        let entry:(value:UInt8, length:UInt8)   = table[self[i, count: 16]]
        let binade:Int                          = .init(entry.value)
        i += .init(entry.length)
        
        if binade == 0 
        {
            return 0 
        }
        else 
        {
            // read `binade` additional bits (raw)
            guard i + binade <= self.count 
            else 
            {
                throw JPEG.Decode.Error.missingBits(location: (#file, #line))
            }
            
            defer 
            {
                i += binade
            }
            
            return Self.extend(binade: binade, self[i, count: binade], as: Int.self)
        }
    }
    
    private 
    func zerorun(_ i:inout Int, zeroes:Int) throws -> (zeroes:Int, run:Int) 
    {
        switch zeroes 
        {
        case 0:
            return (zeroes: 64,     run: 1)
        
        case 1 ... 14:
            // read `zeroes` additional bits (raw)
            guard i + zeroes <= self.count 
            else 
            {
                throw JPEG.Decode.Error.missingBits(location: (#file, #line))
            } 
            
            let run:Int = 1 &<< zeroes | .init(self[i, count: zeroes])
            i += zeroes 
            return (zeroes: 64,     run: run)
        
        case 15:
            return (zeroes: zeroes, run: 1)
        
        default:
            fatalError("unreachable")
        }
    }
    func rrrrssssx(_ i:inout Int, table:JPEG.HuffmanTable) 
        throws -> (zeroes:Int, run:Int, coefficient:Int) 
    {
        // read RRRR:SSSS:[extra] (huffman coded)
        guard i < self.count 
        else 
        {
            throw JPEG.Decode.Error.missingBits(location: (#file, #line))
        }
        
        let entry:(value:UInt8, length:UInt8)   = table[self[i, count: 16]]
        let zeroes:Int                          = .init(entry.value >> 4),
            binade:Int                          = .init(entry.value & 0x0f)
        i += .init(entry.length)
        
        switch binade 
        {
        case 0:
            let zerorun:(zeroes:Int, run:Int) = try self.zerorun(&i, zeroes: zeroes)
            return (zeroes: zerorun.zeroes, run: zerorun.run, coefficient: 0)
        default:
            guard i + binade <= self.count 
            else 
            {
                throw JPEG.Decode.Error.missingBits(location: (#file, #line))
            }
            
            let coefficient:Int = Self.extend(binade: binade, self[i, count: binade], as: Int.self)
            i += binade
            return (zeroes: zeroes, run: 1, coefficient: coefficient)
        }
    } 
    
    func rrrrssssy(_ i:inout Int, table:JPEG.HuffmanTable) 
        throws -> (zeroes:Int, run:Int, delta:Int) 
    {
        guard i < self.count 
        else 
        {
            throw JPEG.Decode.Error.missingBits(location: (#file, #line))
        }
        
        let entry:(value:UInt8, length:UInt8)   = table[self[i, count: 16]]
        let zeroes:Int                          = .init(entry.value >> 4),
            binade:Int                          = .init(entry.value & 0x0f)
        i += .init(entry.length)
        
        switch binade
        {
        case 0:
            let zerorun:(zeroes:Int, run:Int) = try self.zerorun(&i, zeroes: zeroes)
            return (zeroes: zerorun.zeroes, run: zerorun.run, delta: 0)
        case 1:
            guard i < self.count 
            else 
            {
                throw JPEG.Decode.Error.missingBits(location: (#file, #line))
            }
            
            let delta:Int = self[i] * 2 - 1
            i += 1
            return (zeroes: zeroes, run: 1, delta: delta)
        
        default:
            throw JPEG.Decode.Error.invalidCoefficientBinade(binade, expected: 0 ... 1, location: (#file, #line))
        }
    } 
}


// signal processing 
extension JPEG.Spectral.Plane 
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
    func idct() -> [Float] 
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
        return values 
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

        public
        enum Error:Swift.Error
        {
            /// A file could not be opened.
            ///
            /// This error is not thrown by any `File` methods, but is used by users
            /// of these APIs.
            case couldNotOpen
        }

        /// Read data from files on disk.
        public
        struct Source:JPEG.Bytestream.Source
        {
            private
            let descriptor:Descriptor

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
            func open<Result>(path:String, _ body:(inout Source) throws -> Result)
                rethrows -> Result?
            {
                guard let descriptor:Descriptor = fopen(path, "rb")
                else
                {
                    return nil
                }

                var file:Source = .init(descriptor: descriptor)
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
    }
}

// binary utilities 
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
}

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
