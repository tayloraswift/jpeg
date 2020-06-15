/* This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/. */

// binary utilities 

/// protocol JPEG.Bytestream.Source 
///     A source bytestream.
/// 
///     To implement a custom data source type, conform it to this protocol by 
///     implementing [`(Source).read(count:)`]. It can 
///     then be used with the library’s core decompression interfaces.
/// #  [See also](file-io-protocols)
/// ## (1:file-io-protocols)
/// ## (1:lexing-and-formatting)
public 
protocol _JPEGBytestreamSource 
{
    /// mutating func JPEG.Bytestream.Source.read(count:)
    /// required 
    ///     Attempts to read and return the given number of bytes from this stream.
    /// 
    ///     A successful call to this function should affect the bytestream state 
    ///     such that subsequent calls should pick up where the last call left off.
    /// 
    ///     The rest of the library interprets a `nil` return value from this function 
    ///     as indicating end-of-stream.
    /// - count     : Swift.Int 
    ///     The number of bytes to read. 
    /// - ->        : [Swift.UInt8]?
    ///     The `count` bytes read, or `nil` if the read attempt failed. This 
    ///     method should return `nil` even if any number of bytes less than `count`
    ///     were successfully read.
    mutating 
    func read(count:Int) -> [UInt8]?
}
extension JPEG 
{
    /// enum JPEG.Bytestream 
    ///     A namespace for bytestream utilities.
    /// #  [File IO](file-io-protocols)
    /// ## (0:file-io-protocols)
    /// ## (0:lexing-and-formatting)
    public 
    enum Bytestream 
    {
        public 
        typealias Source = _JPEGBytestreamSource
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
        case .start, .end, .restart:
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
    /// mutating func JPEG.Bytestream.Source.segment() 
    /// throws
    ///     Lexes a single marker segment from this bytestream, assuming there 
    ///     is no entropy-coded data prefixed to it. 
    /// 
    ///     Calling this function is roughly equivalent to calling [`segment(prefix:)`]
    ///     with the `prefix` parameter set to `false`, except that the empty 
    ///     prefix array is omitted from the return value.
    /// 
    ///     This function can throw a [`(JPEG).LexingError`] if it encounters an 
    ///     unexpected end-of-stream.
    /// - ->        : (JPEG.Marker, [Swift.UInt8])
    ///     A tuple containing the marker segment type and the marker segment data. 
    ///     The data array does *not* include the marker segment length field
    ///     from the segment header.
    public mutating 
    func segment() throws -> (JPEG.Marker, [UInt8])
    {
        try self.segment(prefix: false).1
    }
    /// mutating func JPEG.Bytestream.Source.segment(prefix:) 
    /// throws
    ///     Optionally lexes a single entropy-coded segment followed by a single marker 
    ///     segment from this bytestream.
    /// 
    ///     This function can throw a [`(JPEG).LexingError`] if it encounters an 
    ///     unexpected end-of-stream.
    /// - prefix    : Swift.Bool 
    ///     Whether this function should expect an entropy-coded segment prefixed 
    ///     to the marker segment. If this parameter is set to `false`, and this 
    ///     function encounters a prefixed entropy-coded segment, it will throw 
    ///     a [`(JPEG).LexingError`].
    /// - ->        : ([Swift.UInt8], (JPEG.Marker, [Swift.UInt8]))
    ///     A tuple containing the entropy-coded segment, marker segment type, 
    ///     and the marker segment data, in that order. If `prefix` was false, 
    ///     the entropy-coded segment data array will be empty. 
    ///     The data array does *not* include the marker segment length field
    ///     from the segment header.
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
            
            return (ecs, (marker, try self.tail(type: marker)))
        }
        
        throw JPEG.LexingError.truncatedEntropyCodedSegment
    }
}

// parsing 

/// protocol JPEG.Bitstream.AnySymbol 
/// :   Swift.Hashable 
///     Functionality common to all bitstream symbols.
/// #  [Symbol types](entropy-coding-symbols)
/// ## (3:entropy-coding-symbols)
/// ## (4:entropy-coding)
public 
protocol _JPEGBitstreamAnySymbol:Hashable
{
    /// init JPEG.Bitstream.AnySymbol.init(_:)
    /// required 
    ///     Creates a symbol instance.
    /// - _     : Swift.UInt8 
    ///     The byte value of this symbol.
    init(_:UInt8)
    /// var JPEG.Bitstream.AnySymbol.value:Swift.UInt8 { get }
    ///     The byte value of this symbol.
    var value:UInt8 
    {
        get 
    }
}
extension JPEG.Bitstream 
{
    public 
    typealias AnySymbol = _JPEGBitstreamAnySymbol
    /// enum JPEG.Bitstream.Symbol
    ///     A namespace for bitstream symbol types.
    /// #  [Symbol types](entropy-coding-symbols)
    /// ## (0:entropy-coding-symbols)
    /// ## (1:entropy-coding)
    public 
    enum Symbol 
    {
        /// enum JPEG.Bitstream.Symbol.DC
        /// :   JPEG.Bitstream.AnySymbol
        ///     A DC symbol.
        /// #  [See also](entropy-coding-symbols)
        /// ## (1:entropy-coding-symbols)
        /// ## (2:entropy-coding)
        public 
        struct DC:AnySymbol
        {
            /// let JPEG.Bitstream.Symbol.DC.value:Swift.UInt8
            /// ?:  JPEG.Bitstream.AnySymbol
            ///     The raw byte value of this symbol.
            public  
            let value:UInt8 
            /// init JPEG.Bitstream.Symbol.DC.init(_:)
            /// ?:  JPEG.Bitstream.AnySymbol
            ///     Creates a DC symbol instance.
            /// - value : Swift.UInt8 
            ///     The raw byte value of this symbol.
            public 
            init(_ value:UInt8) 
            {
                self.value = value 
            }
        }
        /// enum JPEG.Bitstream.Symbol.AC
        /// :   JPEG.Bitstream.AnySymbol
        ///     An AC symbol.
        /// #  [See also](entropy-coding-symbols)
        /// ## (2:entropy-coding-symbols)
        /// ## (3:entropy-coding)
        public 
        struct AC:AnySymbol
        {
            /// let JPEG.Bitstream.Symbol.AC.value:Swift.UInt8
            /// ?:  JPEG.Bitstream.AnySymbol
            ///     The raw byte value of this symbol.
            public  
            let value:UInt8
            /// init JPEG.Bitstream.Symbol.AC.init(_:)
            /// ?:  JPEG.Bitstream.AnySymbol
            ///     Creates an AC symbol instance.
            /// - value : Swift.UInt8 
            ///     The raw byte value of this symbol.
            public 
            init(_ value:UInt8) 
            {
                self.value = value 
            }
        }
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
    /// init JPEG.Table.Huffman.init?(_:target:)
    ///     Creates a huffman tree from the given leaf nodes.
    /// 
    ///     This initializer determines the shape of the tree from the shape of 
    ///     the leaf array input. It has no knowledge of symbol frequencies or 
    ///     priority. To build an *optimal* huffman tree, use the [`init(frequencies:target:)`]
    ///     initializer.
    /// 
    ///     This initializer will return `nil` if the sizes of the given leaf arrays do not 
    ///     describe a [full binary tree](https://en.wikipedia.org/wiki/Binary_tree#full). 
    ///     (The last level is allowed to be incomplete.)
    ///     For example, the leaf counts (3,\ 0,\ 0,\ …\ ) are invalid because 
    ///     no binary tree can have three leaf nodes in its first level.
    /// - symbols   : [[Symbol]]
    ///     The leaf nodes in each level of the tree. The tree root is always 
    ///     assumed to be internal, so the 0th sub-array of this array should 
    ///     contain the leaves in the first level of the tree. This array must 
    ///     contain 16 sub-arrays, even if the deeper levels of the tree are 
    ///     empty, or this initializer will suffer a precondition failure.
    /// - target    : Selector 
    ///     The table selector this huffman table is meant to be stored at.
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
    /// init JPEG.Table.Quantization.init(precision:values:target:)
    ///     Creates a quantization table from the given quantum values.
    /// - precision : Precision 
    ///     The bit width of the integer type to encode the quanta as.
    /// - values    : [Swift.UInt16]
    ///     The quantum values, in zigzag order. This array must have exactly 64 
    ///     elements. If the `precision` is [`(Precision).uint8`], all of the values 
    ///     must be within the range of a [`Swift.UInt8`]. Passing an invalid 
    ///     array will result in a precondition failure.
    /// - target    : Selector 
    ///     The table selector this quantization table is meant to be stored at.
    public 
    init(precision:Precision, values:[UInt16], target:Selector) 
    {
        precondition(values.count == 64, "quantization table must have exactly 64 quanta")
        precondition(precision == .uint16 || values.allSatisfy{ $0 & 0xff00 == 0 }, "8-bit quantization table values must be representable by `UInt8`")
        self.precision  = precision
        self.storage    = values 
        self.target     = target 
    }
}
extension JPEG.Table 
{
    /// static func JPEG.Table.parse(huffman:)
    /// throws 
    ///     Parses a [`(Marker).huffman`] segment into huffman tables.
    /// 
    ///     If the given data does not parse to valid huffman tables, this function 
    ///     will throw a [`(JPEG).ParsingError`].
    /// - data  : [Swift.UInt8]
    ///     The segment data to parse.
    /// - ->    : (dc:[HuffmanDC], ac:[HuffmanAC]) 
    ///     The parsed DC and AC huffman tables.
    public static 
    func parse(huffman data:[UInt8]) throws -> (dc:[HuffmanDC], ac:[HuffmanAC]) 
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
    /// static func JPEG.Table.parse(quantization:)
    /// throws 
    ///     Parses a [`(Marker).quantization`] segment into huffman tables.
    /// 
    ///     If the given data does not parse to valid quantization tables, this function 
    ///     will throw a [`(JPEG).ParsingError`].
    /// - data  : [Swift.UInt8]
    ///     The segment data to parse.
    /// - ->    : [Quantization] 
    ///     The parsed quantization tables.
    public static 
    func parse(quantization data:[UInt8]) throws -> [Quantization] 
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
    /// static func JPEG.Header.HeightRedefinition.parse(_:)
    /// throws 
    ///     Parses a [`(Marker).height`] segment into a height redefinition.
    /// 
    ///     If the given data does not parse to a valid height redefinition, 
    ///     this function will throw a [`(JPEG).ParsingError`].
    /// - data  : [Swift.UInt8]
    ///     The segment data to parse.
    /// - ->    : Self 
    ///     The parsed height redefinition.
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
extension JPEG.Header.RestartInterval 
{
    /// static func JPEG.Header.RestartInterval.parse(_:)
    /// throws 
    ///     Parses an [`(Marker).interval`] segment into a restart interval definition.
    /// 
    ///     If the given data does not parse to a valid restart interval definition, 
    ///     this function will throw a [`(JPEG).ParsingError`].
    /// - data  : [Swift.UInt8]
    ///     The segment data to parse.
    /// - ->    : Self 
    ///     The parsed restart definition.
    public static
    func parse(_ data:[UInt8]) throws -> Self
    {
        guard data.count == 2
        else
        {
            throw JPEG.ParsingError.mismatched(marker: .height, count: data.count, expected: 2)
        }
        
        let value:Int = data.load(bigEndian: UInt16.self, as: Int.self, at: 0)
        return .init(interval: value == 0 ? nil : value)
    } 
}
extension JPEG.Header.Frame 
{
    /// static func JPEG.Header.Frame.validate(process:precision:size:components:)
    /// throws 
    ///     Creates a frame header after validating the given field values.
    /// 
    ///     If the given parameters are not consistent with one another, and the 
    ///     [JPEG standard](https://www.w3.org/Graphics/JPEG/itu-t81.pdf), this 
    ///     function will throw a [`(JPEG).ParsingError`], unless otherwise noted.
    /// - process   : JPEG.Process 
    ///     The coding process used by the image.
    /// - precision : Swift.Int 
    ///     The bit depth of the image. If the `process` is [`(JPEG.Process).baseline`], 
    ///     this parameter must be 8. If the `process` is [`(JPEG.Process).extended(coding:differential:)`] 
    ///     or [`(JPEG.Process).progressive(coding:differential:)`], this parameter 
    ///     must be either 8 or 12. If the process is [`(JPEG.Process).lossless(coding:differential:)`], 
    ///     this parameter must be within the interval `2 ... 16`.
    /// - size      : (x:Swift.Int, y:Swift.Int)
    ///     The size of the image, in pixels. Passing a negative height will result 
    ///     in a precondition failure. Passing a negative or zero width will result 
    ///     in a [`(JPEG).ParsingError`]. This constructor treats the two failure 
    ///     conditions differently because the latter one is the only one that can 
    ///     occur when parsing a frame header from input data.
    /// - components: [JPEG.Component.Key: JPEG.Component]
    ///     The components in the image. This dictionary must have at least one 
    ///     element. If the `process` is [`(JPEG.Process).progressive(coding:differential:)`], 
    ///     it can have no more than four elements. The sampling factors of each 
    ///     component must be within the interval `1 ... 4` in both directions. 
    ///     if the `process` is [`(JPEG.Process).baseline`], the components can 
    ///     only use the quantization table selectors `\.0` and `\.1`.
    /// - ->        : Self 
    ///     A frame header.
    public static 
    func validate(process:JPEG.Process, precision:Int, size:(x:Int, y:Int), 
        components:[JPEG.Component.Key: JPEG.Component]) throws -> Self 
    {
        // this is a precondition and not a guard because the height field 
        // gets parsed from a UInt16, so the only way for this value to be negative 
        // is through direct programmer action
        precondition(size.y >= 0, "frame header cannot have negative height")
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
    /// static func JPEG.Header.Frame.parse(_:process:)
    /// throws 
    ///     Parses a [`(Marker).frame(_:)`] segment into a frame header.
    /// 
    ///     If the given data does not parse to a valid frame header, 
    ///     this function will throw a [`(JPEG).ParsingError`]. This function 
    ///     invokes [`validate(process:precision:size:components:)`], so any errors 
    ///     it can throw can also be thrown by this function.
    /// - data      : [Swift.UInt8]
    ///     The segment data to parse.
    /// - process   : JPEG.Process 
    ///     The coding process used by the image.
    /// - ->        : Self 
    ///     The parsed frame header.
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
    /// static func JPEG.Header.Scan.validate(process:band:bits:components:)
    /// throws
    ///     Creates a scan header after validating the given field values.
    /// 
    ///     If the given parameters are not consistent with one another, and the 
    ///     [JPEG standard](https://www.w3.org/Graphics/JPEG/itu-t81.pdf), this 
    ///     function will throw a [`(JPEG).ParsingError`].
    /// - process   : JPEG.Process 
    ///     The coding process used by the image.
    /// - band      : Swift.Range<Swift.Int>
    ///     The frequency band encoded by the scan, in zigzag order. It must be 
    ///     within the interval of 0 to 64. If the `process` is 
    ///     [`(Process).progressive(coding:differential:)`], this parameter must 
    ///     either be `0 ..< 1`, or some range within the interval `1 ..< 64`. 
    ///     Otherwise, this parameter must be set to `0 ..< 64`.
    /// - bits      : Swift.Range<Swift.Int>
    ///     The bit range encoded by the scan, where bit zero is the least significant 
    ///     bit. The upper range bound must be either infinity ([`Swift.Int`max`]) 
    ///     or one greater than the lower bound. If the `process` is not
    ///     [`(Process).progressive(coding:differential:)`], this value must 
    ///     be set to `0 ..< .max`.
    /// - components: [JPEG.Scan.Component]
    ///     The color components in the scan, in the order in which their 
    ///     data units are interleaved. If the scan is an AC progressive scan, 
    ///     this array must have exactly one element. Otherwise, it must have 
    ///     between one and four elements. If the `process` is [`(Process).baseline`], 
    ///     the components can only use the huffman table selectors `\.0` and `\.1`.
    /// - ->        : Self 
    ///     A scan header.
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
        case    (.baseline,    (0,       64), (0,     .max)), 
                (.extended,    (0,       64), (0,     .max)), 
                (.progressive, (0,        1), (0...,  .max)), // unlimited bits per initial scan
                (.progressive, (0,        1), (0..., a + 1)): // 1 bit per refining scan 
            guard 1 ... 4 ~= components.count
            else 
            {
                throw JPEG.ParsingError.invalidScanComponentCount(components.count, 
                    process)
            }  
        case    (.progressive, (1..., 2 ... 64), (0...,  .max)), 
                (.progressive, (1..., 2 ... 64), (0..., a + 1)): 
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
    /// static func JPEG.Header.Scan.parse(_:process:)
    /// throws 
    ///     Parses a [`(Marker).scan`] segment into a scan header.
    /// 
    ///     If the given data does not parse to a valid scan header, 
    ///     this function will throw a [`(JPEG).ParsingError`]. This function 
    ///     invokes [`validate(process:band:bits:components:)`], so any errors 
    ///     it can throw can also be thrown by this function.
    /// - data      : [Swift.UInt8]
    ///     The segment data to parse.
    /// - process   : JPEG.Process 
    ///     The coding process used by the image.
    /// - ->        : Self 
    ///     The parsed scan header.
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
            @General.Storage<UInt8> 
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
                 /                               /////////////////////
        
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
    /// static func JPEG.Table.Quantization.z(k:h:)
    /// @inlinable 
    ///     Converts a coefficient grid index to a zigzag index.
    ///
    ///     It is easier to convert grid indices (*k*,\ *h*) to zigzag indices (*z*)
    ///     than the other way around, so most library APIs store coefficient-related 
    ///     information natively in zigzag order.
    /// 
    ///     The JPEG format only uses the grid domain `0 ..< 8`\ ×\ `0 ..< 8`, which 
    ///     maps to the zigzag range `0 ..< 64`. However, this function works for 
    ///     any non-negative input coordinate.
    /// - x : Swift.Int 
    ///     The horizontal frequency index.
    /// - y : Swift.Int 
    ///     The vertical frequency index.
    /// - ->: Swift.Int 
    ///     The corresponding zigzag index.
    /// #  [See also](quantization-table-subscripts)
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
    
    /// subscript JPEG.Table.Quantization[k:h:] { get set }
    /// @inlinable
    ///     Accesses the quantum value at the given grid index.
    /// 
    ///     Using this subscript is equivalent to using [`[z:]`] with the output 
    ///     of [`z(k:h:)`].
    /// - k     : Swift.Int
    ///     The horizontal frequency index. This value must be in the range `0 ..< 8`.
    /// - h     : Swift.Int
    ///     The vertical frequency index. This value must be in the range `0 ..< 8`.
    /// - ->    : Swift.UInt16
    ///     The quantum value.
    /// #  [See also](quantization-table-subscripts)
    /// ## (quantization-table-subscripts)
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
    /// subscript JPEG.Table.Quantization[z:] { get set }
    ///     Accesses the quantum value at the given zigzag index.
    /// - z     : Swift.Int
    ///     The zigzag index. This value must be in the range `0 ..< 64`.
    /// - ->    : Swift.UInt16
    ///     The quantum value.
    /// #  [See also](quantization-table-subscripts)
    /// ## (quantization-table-subscripts)
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
    /// enum JPEG.Data 
    ///     A namespace for image representation types.
    /// #  [Image representations](image-data-types)
    /// ## (image-data-types-and-namespace)
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
    /// struct JPEG.Data.Spectral<Format> 
    /// where Format:JPEG.Format
    /// :   Swift.RandomAccessCollection
    ///     A planar image represented in the frequency domain.
    /// 
    ///     A spectral image stores its data in blocks called *data units*. Each 
    ///     block is a square 8×8 matrix of frequency coefficients. The data units 
    ///     themselves have the same spatial arrangement they do in the spatial domain.
    /// 
    ///     A spectral image always stores a whole number of data units in both 
    ///     dimensions, even if the image dimensions in pixels are not multiples of 8.
    ///     Because each component in an image has its own sampling factors, the 
    ///     image planes may not have the same size.
    /// 
    ///     The spectral representation is a lossless representation. JPEG 
    ///     images that have been decoded to this representation can be re-encoded 
    ///     without loss of information or compression.
    /// #  [Creating an image](spectral-create-image)
    /// #  [Saving an image](spectral-save-image)
    /// #  [Querying an image](spectral-query-image)
    /// #  [Editing an image](spectral-edit-image)
    /// #  [Changing representations](spectral-change-representation)
    /// #  [Accessing planes](spectral-accessing-planes)
    /// #  [See also](image-data-types)
    /// ## (image-data-types)
    /// ## (image-data-types-and-namespace)
    public 
    struct Spectral<Format> where Format:JPEG.Format 
    {
        /// struct JPEG.Data.Spectral.Quanta 
        /// :   Swift.RandomAccessCollection
        ///     A container for the quantization tables used by a spectral image.
        public 
        struct Quanta 
        {
            private 
            var quanta:[JPEG.Table.Quantization], 
                q:[JPEG.Table.Quantization.Key: Int]
        }
        /// struct JPEG.Data.Spectral.Plane 
        ///     A plane of an image in the frequency domain, containing one color channel.
        public 
        struct Plane 
        {
            /// var JPEG.Data.Spectral.Plane.units  : (x:Swift.Int, y:Swift.Int) { get }
            ///     The number of data units in this plane in the horizontal and 
            ///     vertical directions.
            public internal(set)
            var units:(x:Int, y:Int)
            
            /// var JPEG.Data.Spectral.Plane.factor : (x:Swift.Int, y:Swift.Int) { get }
            /// @ : General.Storage2<Swift.Int16>
            ///     The sampling factors of the color component this plane stores.
            /// 
            ///     This property is backed by two [`Swift.Int16`]s to circumvent compiler 
            ///     size limits for the `read` and `modify` accessors that the image 
            ///     planes are subscriptable through.
            @General.Storage2<Int16>
            public 
            var factor:(x:Int, y:Int) 
            @General.MutableStorage<Int32>
            var q:Int
            
            private 
            var buffer:[Int16]
            
            /// subscript JPEG.Data.Spectral.Plane[x:y:z:] { get set }
            ///     Accesses the frequency coefficient at the specified zigzag index 
            ///     in the specified data unit.
            /// 
            ///     The `x` and `y` indices of this subscript have no index bounds. 
            ///     Out-of-bounds reads will return 0; out-of-bounds writes will 
            ///     have no effect. The `z` index still has to be within the 
            ///     correct range.
            /// - x : Swift.Int 
            ///     The horizontal index of the data unit to access.
            /// - y : Swift.Int 
            ///     The vertical index of the data unit to access. Index 0 
            ///     corresponds to the visual top of the image.
            /// - z : Swift.Int 
            ///     The zigzag index of the coefficient to access. This index must 
            ///     be in the range `0 ..< 64`. 
            /// - ->: Swift.Int16 
            ///     The frequency coefficient.
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
        /// var JPEG.Data.Spectral.size     : (x:Swift.Int, y:Swift.Int) { get }
        ///     The size of this image, in pixels. 
        /// 
        ///     In general, this size is not the same as the size of the image planes.
        /// #  [See also](spectral-query-image)
        /// ## (0:spectral-query-image)
        public private(set)
        var size:(x:Int, y:Int), 
        /// var JPEG.Data.Spectral.blocks   : (x:Swift.Int, y:Swift.Int) { get }
        ///     The number of minimum-coded units in this image, in the horizontal 
        ///     and vertical directions.
        /// 
        ///     The size of the minimum-coded unit, in 8×8 blocks of pixels, 
        ///     is given by [`layout``(Layout).scale`]. 
        /// #  [See also](spectral-query-image)
        /// ## (1:spectral-query-image)
            blocks:(x:Int, y:Int)
        /// var JPEG.Data.Spectral.layout   : JPEG.Layout<Format> { get }
        ///     The layout of this image.
        /// #  [See also](spectral-query-image)
        /// ## (2:spectral-query-image)
        public private(set)
        var layout:JPEG.Layout<Format>
        /// var JPEG.Data.Spectral.metadata : [JPEG.Metadata]
        ///     The metadata records in this image.
        /// #  [See also](spectral-query-image)
        /// ## (4:spectral-query-image)
        public 
        var metadata:[JPEG.Metadata]
        
        /// var JPEG.Data.Spectral.quanta   : Quanta { get }
        ///     The quantization tables used by this image.
        /// #  [See also](spectral-query-image)
        /// ## (3:spectral-query-image)
        public private(set) 
        var quanta:Quanta
        private 
        var planes:[Plane]
    }
    /// struct JPEG.Data.Planar<Format> 
    /// where Format:JPEG.Format
    ///     A planar image represented in the spatial domain.
    /// 
    ///     A planar image stores its data in blocks called *data units*. Each 
    ///     block is an 8×8-pixel square. A planar image always stores a whole 
    ///     number of data units in both dimensions, even if the image dimensions 
    ///     in pixels are not multiples of 8. Because each component in an image 
    ///     has its own sampling factors, the image planes may not have the same size.
    /// 
    ///     A planar image is the result of applying an *inverse discrete cosine 
    ///     transformation* to a spectral image. It can be converted back into a spectral 
    ///     image (with some floating point error) with a *forward discrete cosine 
    ///     transformation*.
    /// #  [Creating an image](planar-create-image)
    /// #  [Saving an image](planar-save-image)
    /// #  [Querying an image](planar-query-image)
    /// #  [Changing representations](planar-change-representation)
    /// #  [Accessing planes](planar-accessing-planes)
    /// #  [See also](image-data-types)
    /// ## (image-data-types)
    /// ## (image-data-types-and-namespace)
    public 
    struct Planar<Format> where Format:JPEG.Format
    {
        /// struct JPEG.Data.Planar.Plane 
        ///     A plane of an image in the spatial domain, containing one color channel.
        public 
        struct Plane 
        {
            /// let JPEG.Data.Planar.Plane.units    : (x:Swift.Int, y:Swift.Int)
            ///     The number of data units in this plane in the horizontal and 
            ///     vertical directions.
            public 
            let units:(x:Int, y:Int)
            /// var JPEG.Data.Planar.Plane.size     : (x:Swift.Int, y:Swift.Int) { get }
            ///     The size of this plane, in pixels. It is equivalent to multiplying 
            ///     [`units`] by 8.
            public 
            var size:(x:Int, y:Int) 
            {
                (8 * self.units.x, 8 * self.units.y)
            }
            
            /// var JPEG.Data.Planar.Plane.factor   : (x:Swift.Int, y:Swift.Int) { get }
            /// @ : General.Storage2<Swift.Int32>
            ///     The sampling factors of the color component this plane stores.
            /// 
            ///     This property is backed by two [`Swift.Int32`]s to circumvent compiler 
            ///     size limits for the `read` and `modify` accessors that the image 
            ///     planes are subscriptable through.
            @General.Storage2<Int32>
            public 
            var factor:(x:Int, y:Int) 
            
            private 
            var buffer:[UInt16]
            /// subscript JPEG.Data.Planar.Plane[x:y:] { get set }
            ///     Accesses the sample at the specified pixel location.
            /// - x : Swift.Int 
            ///     The horizontal pixel index of the sample to access.
            /// - y : Swift.Int 
            ///     The vertical pixel index of the sample to access. Index 0 
            ///     corresponds to the visual top of the image.
            /// - ->: Swift.UInt16 
            ///     The sample.
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
        /// let JPEG.Data.Planar.size       : (x:Swift.Int, y:Swift.Int)
        ///     The size of this image, in pixels. 
        /// 
        ///     In general, this size is not the same as the size of the image planes.
        /// #  [See also](planar-query-image)
        /// ## (planar-query-image)
        public 
        let size:(x:Int, y:Int)
        /// let JPEG.Data.Planar.layout     : JPEG.Layout<Format>
        ///     The layout of this image.
        /// #  [See also](planar-query-image)
        /// ## (planar-query-image)
        public 
        let layout:JPEG.Layout<Format>, 
        /// let JPEG.Data.Planar.metadata   : [JPEG.Metadata]
        ///     The metadata records in this image.
        /// #  [See also](planar-query-image)
        /// ## (planar-query-image)
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
    /// struct JPEG.Data.Rectangular<Format> 
    /// where Format:JPEG.Format
    ///     A rectangular image.
    /// 
    ///     A rectangular image resamples all planes at the same sampling level, 
    ///     giving a rectangular array of interleaved samples.
    /// 
    ///     It can be unpacked to various color targets to get a pixel color array.
    /// #  [Creating an image](rectangular-create-image)
    /// #  [Saving an image](rectangular-save-image)
    /// #  [Querying an image](rectangular-query-image)
    /// #  [Changing representations](rectangular-change-representation)
    /// #  [Accessing samples](rectangular-accessing-samples)
    /// #  [See also](image-data-types)
    /// ## (image-data-types)
    /// ## (image-data-types-and-namespace)
    public 
    struct Rectangular<Format> where Format:JPEG.Format 
    {
        /// let JPEG.Data.Rectangular.size      : (x:Swift.Int, y:Swift.Int)
        ///     The size of this image, in pixels. 
        /// #  [See also](rectangular-query-image)
        /// ## (rectangular-query-image)
        public 
        let size:(x:Int, y:Int), 
        /// let JPEG.Data.Rectangular.layout    : JPEG.Layout<Format>
        ///     The layout of this image.
        /// #  [See also](rectangular-query-image)
        /// ## (rectangular-query-image)
            layout:JPEG.Layout<Format>, 
        /// let JPEG.Data.Rectangular.metadata  : [JPEG.Metadata]
        ///     The metadata records in this image.
        /// #  [See also](rectangular-query-image)
        /// ## (rectangular-query-image)
            metadata:[JPEG.Metadata]
        
        var values:[UInt16]
        /// let JPEG.Data.Rectangular.stride    : JPEG.Layout<Format>
        ///     The stride of the interleaved samples in this image. 
        /// 
        ///     This value is analogous to the plane `count` of a planar or spectral image.
        ///     For example, the rectangular representation of a planar YCbCr image
        ///     with 3 planes would have a stride of 3.
        /// #  [See also](rectangular-accessing-samples)
        /// ## (1:rectangular-accessing-samples)
        public 
        var stride:Int 
        {
            self.layout.recognized.count 
        }
        /// init JPEG.Data.Rectangular.init(size:layout:metadata:values:) 
        ///     Creates a rectangular image with the given image parameters and 
        ///     interleaved samples.
        /// 
        ///     Passing an invalid `size`, or an array of the wrong `count` will 
        ///     result in a precondition failure.
        /// - size      : (x:Swift.Int, y:Swift.Int)
        ///     The size of the image, in pixels. Both dimensions must be positive.
        /// - layout    : JPEG.Layout<Format> 
        ///     The layout of the image.
        /// - metadata  : [JPEG.Metadata]
        ///     The metadata records in the image.
        /// - values    : [Swift.UInt16]
        ///     An array of interleaved samples, in row major order, and without 
        ///     padding. The array must have exactly 
        ///     [`layout``(Layout).recognized`count`]\ ×\ [`size`x`]\ ×\ [`size`y`] samples.
        ///     Each [`Swift.UInt16`] is one sample. The samples should not be 
        ///     normalized, so an image with a [`layout``(Layout).format``(Format).precision`] of 
        ///     8 should only have samples in the range `0 ... 255`. 
        /// #  [See also](rectangular-create-image)
        /// ## (0:rectangular-create-image)
        public 
        init(size:(x:Int, y:Int), 
            layout:JPEG.Layout<Format>, 
            metadata:[JPEG.Metadata], 
            values:[UInt16])
        {
            precondition(values.count == layout.recognized.count * size.x * size.y, 
                "array count does not match size and layout")
            precondition(size.x > 0 && size.y > 0, "size must be positive")
            self.size       = size
            self.layout     = layout
            self.metadata   = metadata
            self.values     = values
        }
    }
}

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
    /// func JPEG.Data.Spectral.Quanta.mapValues<R>(_:)
    /// rethrows 
    ///     Returns a dictionary of the quantization tables in this container with 
    ///     the quantum values of each table transformed by the given closure.
    /// - transform : ([Swift.UInt16]) throws -> [Swift.UInt16]
    ///     A closure that transforms a value. This closure accepts a 64-element 
    ///     zigzag-indexed array of the quantum values in each table as its parameter, 
    ///     and returns a transformed value of the same or of a different type.
    /// - ->        : [JPEG.Table.Quantization.Key: R]
    ///     A dictionary containing the keys and transformed quanta of the 
    ///     quantization tables in this container.
    public 
    func mapValues<R>(_ transform:([UInt16]) throws -> R) 
        rethrows -> [JPEG.Table.Quantization.Key: R]
    {
        try self.q.mapValues
        {
            try transform(self.quanta[$0].storage)
        }
    }
}
// RAC conformance for planar types 
extension JPEG.Data.Spectral.Quanta:RandomAccessCollection 
{
    /// var JPEG.Data.Spectral.Quanta.startIndex:Swift.Int { get }
    /// ?:  Swift.RandomAccessCollection
    ///     The index of the first quantization table in this container. 
    /// 
    ///     The default (all-zeroes) quantization table is not part of the 
    ///     [`Swift.RandomAccessCollection`]. This index is 1 greater than the 
    ///     index of the default quanta.
    public 
    var startIndex:Int 
    {
        // don’t include the default quanta
        self.quanta.startIndex + 1
    }
    /// var JPEG.Data.Spectral.Quanta.endIndex:Swift.Int { get }
    /// ?:  Swift.RandomAccessCollection
    ///     The index one greater than the index of the last quantization table 
    ///     in this container. 
    public 
    var endIndex:Int 
    {
        self.quanta.endIndex
    }
    /// subscript JPEG.Data.Spectral.Quanta[_:] { get set }
    /// ?:  Swift.RandomAccessCollection
    ///     Accesses the quantization table at the given index.
    /// 
    ///     The getter and setter of this subscript yield the quantization table 
    ///     using `read` and `modify`.
    /// - q     : Swift.Int 
    ///     The index of the quantization table to access.
    /// - ->    : JPEG.Table.Quantization
    ///     The quantization table.
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
    /// func JPEG.Data.Spectral.Quanta.index(forKey:)
    ///     Returns the index of the table with the given key.
    /// 
    ///     An instance of this type which is part of a [`Spectral`]
    ///     instance will always contain all quanta keys used by its [`(Spectral).layout`], 
    ///     including keys used only by non-recognized components.
    /// - qi    : JPEG.Table.Quantization.Key 
    ///     The quanta key. Passing a key that does not exist in this container
    ///     will result in a precondition failure.
    /// - ->    : Swift.Int 
    ///     The integer index. This index can be used with the [`[_:]`] subscript.
    public 
    func index(forKey qi:JPEG.Table.Quantization.Key) -> Int
    {
        guard let q:Int = self.q[qi] 
        else 
        {
            preconditionFailure("key error: attempt to lookup index for invalid quanta key")
        }
        return q
    }
    // impossible for lookup to fail if only public apis are used 
    func contains(key qi:JPEG.Table.Quantization.Key) -> Int?
    {
        self.q[qi]
    }
}
extension JPEG.Data.Spectral:RandomAccessCollection 
{
    /// var JPEG.Data.Spectral.startIndex:Swift.Int { get }
    /// ?:  Swift.RandomAccessCollection
    ///     The index of the first plane in this image. 
    /// 
    ///     This index is always 0.
    /// #  [See also](spectral-accessing-planes)
    /// ## (1:spectral-accessing-planes)
    public 
    var startIndex:Int 
    {
        self.planes.startIndex
    }
    /// var JPEG.Data.Spectral.endIndex:Swift.Int { get }
    /// ?:  Swift.RandomAccessCollection
    ///     The index one greater than the index of the last plane in this image. 
    /// 
    ///     This index is always the number of recognized components in the image’s 
    ///     [`layout``(JPEG.Layout).format`].
    /// #  [See also](spectral-accessing-planes)
    /// ## (2:spectral-accessing-planes)
    public 
    var endIndex:Int 
    {
        self.planes.endIndex
    }
    /// subscript JPEG.Data.Spectral[_:] { get set }
    /// ?:  Swift.RandomAccessCollection
    ///     Accesses the plane at the given index.
    /// 
    ///     The getter and setter of this subscript yield the plane 
    ///     using `read` and `modify`.
    /// - p     : Swift.Int 
    ///     The index of the plane to access. This index must be within the index 
    ///     bounds of this [`Swift.RandomAccessCollection`].
    /// - ->    : Plane
    ///     The plane.
    /// #  [See also](spectral-accessing-planes)
    /// ## (0:spectral-accessing-planes)
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
    /// func JPEG.Data.Spectral.index(forKey:)
    ///     Returns the index of the plane storing the color channel represented 
    ///     by the given component key, or `nil` if the component key is a 
    ///     non-recognized component.
    /// - ci    : JPEG.Component.Key 
    ///     The component key. 
    /// - ->    : Swift.Int? 
    ///     The integer index of the plane, or `nil`. If not `nil`, this index 
    ///     can be used with the [`[_:]`] subscript.
    /// #  [See also](spectral-accessing-planes)
    /// ## (3:spectral-accessing-planes)
    public 
    func index(forKey ci:JPEG.Component.Key) -> Int? 
    {
        self.layout.index(ci: ci)
    }
}
extension JPEG.Data.Planar:RandomAccessCollection 
{
    /// var JPEG.Data.Planar.startIndex:Swift.Int { get }
    /// ?:  Swift.RandomAccessCollection
    ///     The index of the first plane in this image. 
    /// 
    ///     This index is always 0.
    /// #  [See also](planar-accessing-planes)
    /// ## (1:planar-accessing-planes)
    public 
    var startIndex:Int 
    {
        self.planes.startIndex
    }
    /// var JPEG.Data.Planar.endIndex:Swift.Int { get }
    /// ?:  Swift.RandomAccessCollection
    ///     The index one greater than the index of the last plane in this image. 
    /// 
    ///     This index is always the number of recognized components in the image’s 
    ///     [`layout``(JPEG.Layout).format`].
    /// #  [See also](planar-accessing-planes)
    /// ## (2:planar-accessing-planes)
    public 
    var endIndex:Int 
    {
        self.planes.endIndex
    }
    /// subscript JPEG.Data.Planar[_:] { get set }
    /// ?:  Swift.RandomAccessCollection
    ///     Accesses the plane at the given index.
    /// 
    ///     The getter and setter of this subscript yield the plane 
    ///     using `read` and `modify`.
    /// - p     : Swift.Int 
    ///     The index of the plane to access. This index must be within the index 
    ///     bounds of this [`Swift.RandomAccessCollection`].
    /// - ->    : Plane
    ///     The plane.
    /// #  [See also](planar-accessing-planes)
    /// ## (0:planar-accessing-planes)
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
    /// func JPEG.Data.Planar.index(forKey:)
    ///     Returns the index of the plane storing the color channel represented 
    ///     by the given component key, or `nil` if the component key is a 
    ///     non-recognized component.
    /// - ci    : JPEG.Component.Key 
    ///     The component key. 
    /// - ->    : Swift.Int? 
    ///     The integer index of the plane, or `nil`. If not `nil`, this index 
    ///     can be used with the [`[_:]`] subscript.
    /// #  [See also](planar-accessing-planes)
    /// ## (3:planar-accessing-planes)
    public 
    func index(forKey ci:JPEG.Component.Key) -> Int? 
    {
        self.layout.index(ci: ci)
    }
}
extension JPEG.Data.Rectangular 
{
    /// subscript JPEG.Data.Rectangular[x:y:p:] { get set }
    ///     Accesses the sample at the specified pixel location and offset.
    /// - x : Swift.Int 
    ///     The horizontal pixel index of the sample to access.
    /// - y : Swift.Int 
    ///     The vertical pixel index of the sample to access. Index 0 
    ///     corresponds to the visual top of the image.
    /// - p : Swift.Int 
    ///     The interleaved offset of the sample. This offset is analogous to the 
    ///     plane index in the planar image representations.
    /// - ->: Swift.UInt16 
    ///     The sample.
    /// #  [See also](rectangular-accessing-samples)
    /// ## (0:rectangular-accessing-samples)
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
    /// func JPEG.Data.Rectangular.offset(forKey:)
    ///     Returns the interleaved offset of the color channel represented 
    ///     by the given component key, or `nil` if the component key is a 
    ///     non-recognized component.
    /// - ci    : JPEG.Component.Key 
    ///     The component key. 
    /// - ->    : Swift.Int? 
    ///     The interleaved offset of the channel, or `nil`. If not `nil`, this offset 
    ///     can be used as the `p` parameter to the [`[x:y:p:]`] subscript.
    /// #  [See also](rectangular-accessing-samples)
    /// ## (2:rectangular-accessing-samples)
    public 
    func offset(forKey ci:JPEG.Component.Key) -> Int? 
    {
        self.layout.index(ci: ci)
    }
}
// `indices` property for plane types 
extension JPEG.Data.Spectral.Plane 
{
    /// var JPEG.Data.Spectral.Plane.indices    : General.Range2<Swift.Int> { get }
    ///     A two-dimensional index range encompassing the data units in this plane.
    /// 
    ///     This index range is a [`Swift.Sequence`] which can be used to iterate 
    ///     through its index space in row-major order.
    public 
    var indices:General.Range2<Int> 
    {
        (0, 0) ..< self.units 
    }
}
extension JPEG.Data.Planar.Plane 
{
    /// var JPEG.Data.Planar.Plane.indices      : General.Range2<Swift.Int> { get }
    ///     A two-dimensional index range encompassing the data units in this plane.
    /// 
    ///     This index range is a [`Swift.Sequence`] which can be used to iterate 
    ///     through its index space in row-major order.
    public 
    var indices:General.Range2<Int> 
    {
        (0, 0) ..< self.size 
    }
}

// “with” regulated accessors for plane mutation by component index 
extension JPEG.Data.Spectral 
{
    // cannot have both of them named `with(ci:_)` since this leads to ambiguity 
    // at the call site
    
    /// func JPEG.Data.Spectral.read<R>(ci:_:) 
    /// rethrows 
    ///     Calls the given closure on the plane and associated quantization table 
    ///     for the given component key. 
    /// - ci    : JPEG.Component.Key 
    ///     The component key of the plane to access. This component must be a 
    ///     recognized component, or this function will suffer a precondition failure.
    /// - body  : (Plane, JPEG.Table.Quantization) throws -> R 
    ///     The closure to apply to the plane and associated quantization table. 
    ///     Its return value is the return value of the surrounding function.
    /// - ->    : R 
    ///     The return value of the given closure.
    /// #  [See also](spectral-accessing-planes)
    /// ## (4:spectral-accessing-planes)
    public 
    func read<R>(ci:JPEG.Component.Key, 
        _ body:(Plane, JPEG.Table.Quantization) throws -> R) 
        rethrows -> R
    {
        guard let p:Int = self.index(forKey: ci)
        else 
        {
            preconditionFailure("component key out of range")
        }
        return try body(self[p], self.quanta[self[p].q])
    }
    /// mutating func JPEG.Data.Spectral.with<R>(ci:_:) 
    /// rethrows 
    ///     Calls the given closure on the plane and associated quantization table 
    ///     for the given component key. 
    /// 
    ///     The closure passed to this method can mutate the plane in this image 
    ///     specified by the component key. The associated quantization table is still 
    ///     immutable, because editing it would also affect all other planes referencing 
    ///     that table.
    /// - ci    : JPEG.Component.Key 
    ///     The component key of the plane to access. This component must be a 
    ///     recognized component, or this function will suffer a precondition failure.
    /// - body  : (inout Plane, JPEG.Table.Quantization) throws -> R 
    ///     The closure to apply to the plane and associated quantization table. 
    ///     Its return value is the return value of the surrounding function.
    /// - ->    : R 
    ///     The return value of the given closure.
    /// #  [See also](spectral-accessing-planes)
    /// ## (5:spectral-accessing-planes)
    public mutating 
    func with<R>(ci:JPEG.Component.Key, 
        _ body:(inout Plane, JPEG.Table.Quantization) throws -> R) 
        rethrows -> R
    {
        guard let p:Int = self.index(forKey: ci)
        else 
        {
            preconditionFailure("component key out of range")
        }
        return try body(&self[p], self.quanta[self[p].q])
    }
}
extension JPEG.Data.Planar 
{
    /// func JPEG.Data.Planar.read<R>(ci:_:) 
    /// rethrows 
    ///     Calls the given closure on the plane for the given component key. 
    /// - ci    : JPEG.Component.Key 
    ///     The component key of the plane to access. This component must be a 
    ///     recognized component, or this function will suffer a precondition failure.
    /// - body  : (Plane) throws -> R 
    ///     The closure to apply to the plane. 
    ///     Its return value is the return value of the surrounding function.
    /// - ->    : R 
    ///     The return value of the given closure.
    /// #  [See also](planar-accessing-planes)
    /// ## (4:planar-accessing-planes)
    public 
    func read<R>(ci:JPEG.Component.Key, 
        body:(Plane) throws -> R) 
        rethrows -> R
    {
        guard let p:Int = self.index(forKey: ci)
        else 
        {
            preconditionFailure("component key out of range")
        }
        return try body(self[p])
    }
    /// mutating func JPEG.Data.Planar.with<R>(ci:_:) 
    /// rethrows 
    ///     Calls the given closure on the plane for the given component key. 
    /// 
    ///     The closure passed to this method can mutate the plane in this image 
    ///     specified by the component key. 
    /// - ci    : JPEG.Component.Key 
    ///     The component key of the plane to access. This component must be a 
    ///     recognized component, or this function will suffer a precondition failure.
    /// - body  : (inout Plane) throws -> R 
    ///     The closure to apply to the plane. 
    ///     Its return value is the return value of the surrounding function.
    /// - ->    : R 
    ///     The return value of the given closure.
    /// #  [See also](planar-accessing-planes)
    /// ## (5:planar-accessing-planes)
    public mutating 
    func with<R>(ci:JPEG.Component.Key, 
        body:(inout Plane) throws -> R) 
        rethrows -> R
    {
        guard let p:Int = self.index(forKey: ci)
        else 
        {
            preconditionFailure("component key out of range")
        }
        return try body(&self[p])
    }
}

// shared properties needed for initializing planar, spectral, and other layout types 
extension JPEG.Layout 
{
    /// var JPEG.Layout.scale : (x:Swift.Int, y:Swift.Int) { get }
    ///     The size of the minimum-coded unit of the image, in data units. 
    /// 
    ///     This value is the maximum of all the sampling [`(JPEG.Component).factor`]s 
    ///     of the components in the image, including the non-recognized components.
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
    /// var JPEG.Layout.components : [JPEG.Component.Key: (factor:(x:Swift.Int, y:Swift.Int), qi:JPEG.Table.Quantization.Key)] { get }
    ///     A dictionary mapping all of the resident components in the image to 
    ///     their sampling factors and quanta keys. 
    /// 
    ///     This property should be equivalent to the `components` dictionary 
    ///     that would be used to construct this instance using 
    ///     [`init(format:process:components:scans:)`]. As long as the [`Format`] 
    ///     type is properly implemented, this dictionary will always have at 
    ///     least one element.
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
    /// subscript JPEG.Data.Spectral.Plane[x:y:k:h:] { get set }
    /// @inlinable
    ///     Accesses the frequency coefficient at the specified grid index
    ///     in the specified data unit.
    /// 
    ///     The `x` and `y` indices of this subscript have no index bounds. 
    ///     Out-of-bounds reads will return 0; out-of-bounds writes will 
    ///     have no effect. The `k` and `h` indices still have to be within the 
    ///     correct range.
    ///
    ///     Using this subscript is equivalent to using [`[x:y:z:]`] with the `z` 
    ///     index set to the output of [`Table.Quantization.z(k:h:)`].
    /// - x : Swift.Int 
    ///     The horizontal index of the data unit to access.
    /// - y : Swift.Int 
    ///     The vertical index of the data unit to access. Index 0 
    ///     corresponds to the visual top of the image.
    /// - k     : Swift.Int
    ///     The horizontal frequency index of the coefficient to access. 
    ///     This value must be in the range `0 ..< 8`.
    /// - h     : Swift.Int
    ///     The vertical frequency index of the coefficient to access. 
    ///     This value must be in the range `0 ..< 8`.
    /// - ->: Swift.Int16 
    ///     The frequency coefficient.
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
    /// init JPEG.Data.Spectral.init(size:layout:metadata:quanta:)
    ///     Creates a blank spectral image with the given image parameters and quanta.
    /// 
    ///     This initializer will initialize all frequency coefficients in the image to zero.
    /// - size      : (x:Swift.Int, y:Swift.Int) 
    ///     The size of the image, in pixels. Passing a negative or zero width, or 
    ///     a negative height, will result in a precondition failure.
    /// - layout    : JPEG.Layout<Format>
    ///     The layout of the image.
    /// - metadata  : [JPEG.Metadata]
    ///     The metadata records in the image.
    /// - quanta    : [JPEG.Table.Quantization.Key: [Swift.UInt16]]
    ///     The quantum values for each quanta key used by the given `layout`, 
    ///     including quanta keys used only by non-recognized components. Each 
    ///     array of quantum values must have exactly 64 elements. The quantization 
    ///     tables created from these values will be encoded using integers with a bit width
    ///     determined by the [`(JPEG.Format).precision`] of the color [`(Layout).format`] 
    ///     of the given layout, and all the values must be in the correct range 
    ///     for that bit width.
    /// 
    ///     Passing an invalid quanta dictionary will result in a precondition failure.
    /// #  [See also](spectral-create-image)
    /// ## (0:spectral-create-image)
    public 
    init(size:(x:Int, y:Int), layout:JPEG.Layout<Format>, 
        metadata:[JPEG.Metadata], 
        quanta:[JPEG.Table.Quantization.Key: [UInt16]])
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
    
    /// mutating func JPEG.Data.Spectral.set(width:)
    ///     Sets the width of this image, in pixels.
    /// 
    ///     Existing data in this image will either be preserved, or cropped. 
    ///     Any additional data units created by this function will have all coefficients 
    ///     initialized to zero.
    /// - x : Swift.Int 
    ///     The new width of this image, in pixels. This width is measured from the 
    ///     left side of the image. Passing a negative or zero value will result 
    ///     in a precondition failure.
    /// #  [See also](spectral-edit-image)
    /// ## (spectral-edit-image)
    public mutating 
    func set(width x:Int) 
    {
        precondition(x > 0, "width must be set to a positive value.")
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
    /// mutating func JPEG.Data.Spectral.set(height:)
    ///     Sets the height of this image, in pixels.
    /// 
    ///     Existing data in this image will either be preserved, or cropped. 
    ///     Any additional data units created by this function will have all coefficients 
    ///     initialized to zero.
    /// - y : Swift.Int 
    ///     The new height of this image, in pixels. This height is measured from the 
    ///     top of the image. Passing a negative value will result 
    ///     in a precondition failure.
    /// #  [See also](spectral-edit-image)
    /// ## (spectral-edit-image)
    public mutating 
    func set(height y:Int) 
    {
        precondition(y >= 0, "height must be set to zero or a positive value.")
        let scale:Int = self.layout.scale.y
        self.blocks.y   = JPEG.Data.units(y, stride: 8 * scale)
        self.size.y     = y
        for p:Int in self.indices
        {
            let u:Int = JPEG.Data.units(y * self[p].factor.y, stride: 8 * scale)
            self[p].set(height: u)
        }
    }
    /// mutating func JPEG.Data.Spectral.set(quanta:)
    ///     Replaces the quantization tables in this image.
    /// 
    ///     This function will invalidate all existing quantization table indices.
    /// - quanta    : [JPEG.Table.Quantization.Key: [Swift.UInt16]]
    ///     The quantum values for each quanta key used by this image’s [`layout`], 
    ///     including quanta keys used only by non-recognized components. Each 
    ///     array of quantum values must have exactly 64 elements. The quantization 
    ///     tables created from these values will be encoded using integers with a bit width
    ///     determined by this image’s [`layout``(Layout).format``(JPEG.Format).precision`],
    ///     and all the values must be in the correct range for that bit width.
    /// #  [See also](spectral-edit-image)
    /// ## (spectral-edit-image)
    public mutating 
    func set(quanta:[JPEG.Table.Quantization.Key: [UInt16]])
    {
        self.quanta.removeAll()
        for (ci, c):(JPEG.Component.Key, Int) in self.layout.residents
        {
            let qi:JPEG.Table.Quantization.Key = self.layout.planes[c].qi
            let q:Int 
            if let index:Int = self.quanta.contains(key: qi)
            {
                q = index 
            }
            else 
            {
                guard let values:[UInt16] = quanta[qi]
                else 
                {
                    preconditionFailure("missing quantization table for component \(ci)")
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
    /// init JPEG.Data.Planar.init(size:layout:metadata:initializingWith:)
    /// rethrows 
    ///     Creates a planar image with the given image parameters and generator.
    /// - size          : (x:Swift.Int, y:Swift.Int) 
    ///     The size of the image, in pixels. Both dimensions must be positive, 
    ///     or this initializer will suffer a precondition failure.
    /// - layout        : JPEG.Layout<Format>
    ///     The layout of the image.
    /// - metadata      : [JPEG.Metadata]
    ///     The metadata records in the image.
    /// - initializer   : (Swift.Int, (x:Swift.Int, y:Swift.Int), (x:Swift.Int, y:Swift.Int), Swift.UnsafeMutableBufferPointer<Swift.UInt16>) throws -> ()
    ///     A closure called by this function to initialize the contents of each 
    ///     plane in this image.
    /// 
    ///     The first closure argument is the index of the plane being initialized.
    /// 
    ///     The second closure argument is a tuple containing the size of the 
    ///     plane being initialized, in data units.
    /// 
    ///     The third closure argument is a tuple containing the sampling factors 
    ///     of the plane being initialized. 
    /// 
    ///     The last closure argument is an uninitialized buffer containing the  
    ///     samples in the plane, in row-major order. This buffer contains 
    ///     64\ *x*\ *y* samples, where (*x*,\ *y*) is the size of the plane, 
    ///     in data units.
    /// #  [See also](planar-create-image)
    /// ## (0:planar-create-image)
    public 
    init(size:(x:Int, y:Int), layout:JPEG.Layout<Format>, metadata:[JPEG.Metadata], 
        initializingWith initializer:
        (Int, (x:Int, y:Int), (x:Int, y:Int), UnsafeMutableBufferPointer<UInt16>) throws -> ())
        rethrows 
    {
        precondition(size.x > 0 && size.y > 0, "size must be positive")
        
        self.layout     = layout

        self.size       = size
        self.metadata   = metadata
        
        let scale:(x:Int, y:Int)    = layout.scale
        self.planes                 = try layout.recognized.indices.map 
        {
            (p:Int) -> Plane in
             
            let factor:(x:Int, y:Int) = layout.planes[p].component.factor
            let units:(x:Int, y:Int)  = 
            (
                JPEG.Data.units(size.x * factor.x, stride: 8 * scale.x),
                JPEG.Data.units(size.y * factor.y, stride: 8 * scale.y)
            )
            
            let count:Int       = 64 * units.x * units.y
            let plane:[UInt16]  = try .init(unsafeUninitializedCapacity: count)
            {
                try initializer(p, units, factor, $0)
                $1 = count 
            }
            return .init(plane, units: units, factor: factor)
        }
    }
    /// init JPEG.Data.Planar.init(size:layout:metadata:)
    ///     Creates a planar image with the given image parameters, initializing 
    ///     all image samples to a neutral color.
    /// 
    ///     This initializer will initialize all samples in all planes to the 
    ///     midpoint of this image’s sample range. The midpoint is equal to 
    ///     2^*w*\ –\ 1^, where *w*\ =\ [`layout``(Layout).format``(JPEG.Format).precision`].
    /// - size          : (x:Swift.Int, y:Swift.Int) 
    ///     The size of the image, in pixels. Both dimensions must be positive, 
    ///     or this initializer will suffer a precondition failure.
    /// - layout        : JPEG.Layout<Format>
    ///     The layout of the image.
    /// - metadata      : [JPEG.Metadata]
    ///     The metadata records in the image.
    /// #  [See also](planar-create-image)
    /// ## (1:planar-create-image)
    public 
    init(size:(x:Int, y:Int), layout:JPEG.Layout<Format>, metadata:[JPEG.Metadata])
    {
        let midpoint:UInt16 = 1 << (layout.format.precision - 1 as Int)
        self.init(size: size, layout: layout, metadata: metadata) 
        {
            $3.initialize(repeating: midpoint)
        }
    }
}
extension JPEG.Data.Rectangular 
{
    /// init JPEG.Data.Rectangular.init(size:layout:metadata:)
    ///     Creates a rectangular image with the given image parameters, initializing 
    ///     all image samples to a neutral color.
    /// 
    ///     This initializer will initialize all samples to the 
    ///     midpoint of this image’s sample range. The midpoint is equal to 
    ///     2^*w*\ –\ 1^, where *w*\ =\ [`layout``(Layout).format``(JPEG.Format).precision`].
    /// - size          : (x:Swift.Int, y:Swift.Int) 
    ///     The size of the image, in pixels. Both dimensions must be positive, 
    ///     or this initializer will suffer a precondition failure.
    /// - layout        : JPEG.Layout<Format>
    ///     The layout of the image.
    /// - metadata      : [JPEG.Metadata]
    ///     The metadata records in the image.
    /// #  [See also](rectangular-create-image)
    /// ## (1:rectangular-create-image)
    public 
    init(size:(x:Int, y:Int), layout:JPEG.Layout<Format>, metadata:[JPEG.Metadata])
    {
        precondition(size.x > 0 && size.y > 0, "size must be positive")
        
        let midpoint:UInt16 = 1 << (layout.format.precision - 1 as Int)
        self.init(size: size, layout: layout, metadata: metadata, 
            values: .init(repeating: midpoint, count: layout.recognized.count * size.x * size.y))
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
    enum Composite 
    {
        struct DC 
        {
            let difference:Int16 
            
            init(difference:Int16) 
            {
                self.difference = difference
            }
        }
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
    func decode(_ data:[UInt8], blocks:Range<Int>, component:JPEG.Scan.Component, 
        tables slots:(dc:JPEG.Table.HuffmanDC.Slots, ac:JPEG.Table.HuffmanAC.Slots), 
        extend:Bool) throws 
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
        
        let rows:Range<Int> = 
            (blocks.lowerBound / self.units.x ..< blocks.upperBound / self.units.x)
            .clamped(to: 0 ..< (extend ? .max : self.units.y))
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        var predecessor:Int16   = 0
        row: 
        for y:Int in rows
        {
            if extend 
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
    func decode(_ data:[UInt8], blocks:Range<Int>, bits a:PartialRangeFrom<Int>, 
        component:JPEG.Scan.Component, tables slots:JPEG.Table.HuffmanDC.Slots, 
        extend:Bool) throws 
    {
        guard let table:JPEG.Table.HuffmanDC.Decoder = 
            slots[keyPath: component.selector.dc]?.decoder()
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanDCReference(component.selector.dc)
        }
        
        let rows:Range<Int> = 
            (blocks.lowerBound / self.units.x ..< blocks.upperBound / self.units.x)
            .clamped(to: 0 ..< (extend ? .max : self.units.y))
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        var predecessor:Int16   = 0
        row: 
        for y:Int in rows
        {
            if extend 
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
    func decode(_ data:[UInt8], blocks:Range<Int>, bit a:Int) throws 
    {
        let rows:Range<Int>     = blocks.lowerBound / self.units.x ..< 
                        Swift.min(blocks.upperBound / self.units.x, self.units.y)
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        for (x, y):(Int, Int) in (0, rows.lowerBound) ..< (self.units.x, rows.upperBound)
        {
            let refinement:Int16    = try bits.refinement(&b)
            self[x: x, y: y, z: 0] |= refinement << a
        }
    }
    
    mutating 
    func decode(_ data:[UInt8], blocks:Range<Int>, band:Range<Int>, bits a:PartialRangeFrom<Int>, 
        component:JPEG.Scan.Component, tables slots:JPEG.Table.HuffmanAC.Slots) throws
    {
        guard let table:JPEG.Table.HuffmanAC.Decoder = 
            slots[keyPath: component.selector.ac]?.decoder()
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanACReference(component.selector.ac)
        }
        
        let rows:Range<Int>     = blocks.lowerBound / self.units.x ..< 
                        Swift.min(blocks.upperBound / self.units.x, self.units.y)
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0, 
            skip:Int            = 0
        for (x, y):(Int, Int) in (0, rows.lowerBound) ..< (self.units.x, rows.upperBound)
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
    func decode(_ data:[UInt8], blocks:Range<Int>, band:Range<Int>, bit a:Int, 
        component:JPEG.Scan.Component, tables slots:JPEG.Table.HuffmanAC.Slots) throws
    {
        guard let table:JPEG.Table.HuffmanAC.Decoder = 
            slots[keyPath: component.selector.ac]?.decoder()
        else 
        {
            throw JPEG.DecodingError.undefinedScanHuffmanACReference(component.selector.ac)
        }
        
        let rows:Range<Int>     = blocks.lowerBound / self.units.x ..< 
                        Swift.min(blocks.upperBound / self.units.x, self.units.y)
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0, 
            skip:Int            = 0
        for (x, y):(Int, Int) in (0, rows.lowerBound) ..< (self.units.x, rows.upperBound)
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
    func decode(_ data:[UInt8], blocks:Range<Int>, 
        components:[(c:Int, component:JPEG.Scan.Component)], 
        tables slots:(dc:JPEG.Table.HuffmanDC.Slots, ac:JPEG.Table.HuffmanAC.Slots), 
        extend:Bool) throws 
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
            
            try self[p].decode(data, blocks: blocks, component: component, 
                tables: slots, extend: extend)
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
        
        let rows:Range<Int> = 
            (blocks.lowerBound / self.blocks.x ..< blocks.upperBound / self.blocks.x)
            .clamped(to: 0 ..< (extend ? .max : self.blocks.y))
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        var predecessor:[Int16] = .init(repeating: 0, count: descriptors.count)
        row:
        for my:Int in rows
        {
            if extend 
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
    func decode(_ data:[UInt8], blocks:Range<Int>, bits a:PartialRangeFrom<Int>, 
        components:[(c:Int, component:JPEG.Scan.Component)], 
        tables slots:JPEG.Table.HuffmanDC.Slots, 
        extend:Bool) throws
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
            
            try self[p].decode(data, blocks: blocks, bits: a, component: component, 
                tables: slots, extend: extend)
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
        
        let rows:Range<Int> = 
            (blocks.lowerBound / self.blocks.x ..< blocks.upperBound / self.blocks.x)
            .clamped(to: 0 ..< (extend ? .max : self.blocks.y))
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        var predecessor:[Int16] = .init(repeating: 0, count: descriptors.count)
        row:
        for my:Int in rows
        {
            if extend 
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
    func decode(_ data:[UInt8], blocks:Range<Int>, bit a:Int, 
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
            
            try self[p].decode(data, blocks: blocks, bit: a)
            return 
        }
        
        typealias Descriptor = (p:Int?, factor:(x:Int, y:Int))
        let descriptors:[Descriptor] = components.map 
        {
            let factor:(x:Int, y:Int) = self.layout.planes[$0.c].component.factor
            return (self.indices ~= $0.c ? $0.c : nil, factor)
        }
        
        let rows:Range<Int>     = blocks.lowerBound / self.blocks.x ..< 
                        Swift.min(blocks.upperBound / self.blocks.x, self.blocks.y)
        let bits:JPEG.Bitstream = .init(data)
        var b:Int               = 0
        for (mx, my):(Int, Int) in (0, rows.lowerBound) ..< (self.blocks.x, rows.upperBound)
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
    
    mutating 
    func decode(ecss:[[UInt8]], interval:Int, scan:JPEG.Header.Scan, tables slots:
        (
            dc:JPEG.Table.HuffmanDC.Slots, 
            ac:JPEG.Table.HuffmanAC.Slots, 
            quanta:JPEG.Table.Quantization.Slots
        ), 
        extend:Bool) throws 
    {
        let scan:JPEG.Scan = try self.layout.push(scan: scan)
        switch (initial: scan.bits.upperBound == .max, band: scan.band)
        {
        case (initial: true,  band: 0 ..< 64):
            try self.dequantize(components: scan.components, tables: slots.quanta)
        
        case (initial: true,  band: 0 ..<  1):
            // in a progressive image, the dc scan must be the first scan for a 
            // particular component, so this is when we select and push the 
            // quantization tables
            try self.dequantize(components: scan.components, tables: slots.quanta)
        
        default:
            break
        }
        
        for (start, data):(Int, [UInt8]) in zip(stride(from: 0, to: .max, by: interval), ecss) 
        {
            let blocks:Range<Int> = start ..< start + interval
            switch (initial: scan.bits.upperBound == .max, band: scan.band)
            {
            case (initial: true,  band: 0 ..< 64):
                try self.decode(data, blocks: blocks, components: scan.components, 
                    tables: (slots.dc, slots.ac), extend: extend)
            
            case (initial: false, band: 0 ..< 64):
                // successive approximation cannot happen without spectral selection. 
                // the scan header parser should enforce this 
                fatalError("unreachable")
            
            case (initial: true,  band: 0 ..<  1):
                try self.decode(data, blocks: blocks, bits: scan.bits.lowerBound..., 
                    components: scan.components, tables: slots.dc, extend: extend) 
            
            case (initial: false, band: 0 ..<  1):
                try self.decode(data, blocks: blocks, bit: scan.bits.lowerBound, 
                    components: scan.components)
            
            case (initial: true,  band: let band):
                // scan initializer should have validated this
                assert(scan.components.count == 1)
                
                let (p, component):(Int, JPEG.Scan.Component) = scan.components[0]
                guard self.indices ~= p
                else 
                {
                    return 
                }
                
                try self[p].decode(data, blocks: blocks, band: band, bits: scan.bits.lowerBound..., 
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
                
                try self[p].decode(data, blocks: blocks, band: band, bit: scan.bits.lowerBound, 
                    component: component, tables: slots.ac)
            }
        }
    }
}

extension JPEG 
{
    /// struct JPEG.Context<Format> 
    /// where Format:JPEG.Format 
    ///     A contextual state manager used for manual decoding. 
    /// 
    ///     The main use case for this type is to observe the visual state of a 
    ///     partially-decoded image, for example, when performing 
    ///     [online decoding](https://github.com/kelvin13/jpeg/tree/master/examples#online-decoding).
    /// ##  (manual-decoding)
    public 
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
        var interval:Int?
        
        /// var JPEG.Context.spectral : JPEG.Data.Spectral<Format> { get }
        ///     The spectral image, as currently decoded.
        public private(set)
        var spectral:Data.Spectral<Format>
        private 
        var progression:Layout<Format>.Progression 
        
        private 
        var counter:Int 
    }
}
extension JPEG.Context 
{
    /// init JPEG.Context.init(frame:)
    /// throws 
    ///     Initializes the decoder context from the given frame header.
    /// - frame : JPEG.Header.Frame 
    ///     The frame header of the image. This frame header is used to allocate 
    ///     a [`(Data).Spectral`] image.
    public 
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
        self.interval       = nil
    }
    /// mutating func JPEG.Context.push(height:)
    ///     Updates the decoder state with the given height redefinition.
    /// 
    ///     This method calls [`(Data.Spectral).set(height:)`] on the stored image.
    /// - height : JPEG.Header.HeightRedefinition 
    ///     The height redefinition.
    public mutating 
    func push(height:JPEG.Header.HeightRedefinition) 
    {
        self.spectral.set(height: height.height)
    }
    /// mutating func JPEG.Context.push(interval:)
    ///     Updates the decoder state with the given restart interval definition.
    /// - interval : JPEG.Header.RestartInterval 
    ///     The restart interval definition.
    public mutating 
    func push(interval:JPEG.Header.RestartInterval) 
    {
        self.interval = interval.interval 
    }
    /// mutating func JPEG.Context.push(dc:)
    ///     Updates the decoder state with the given DC huffman table.
    /// 
    ///     This method binds the table to its target [`(Table.HuffmanDC).Selector`] 
    ///     within this instance.
    /// - table     : JPEG.Table.HuffmanDC
    ///     The DC huffman table.
    public mutating 
    func push(dc table:JPEG.Table.HuffmanDC) 
    {
        self.tables.dc[keyPath: table.target] = table
    }
    /// mutating func JPEG.Context.push(ac:)
    ///     Updates the decoder state with the given AC huffman table.
    /// 
    ///     This method binds the table to its target [`(Table.HuffmanAC).Selector`] 
    ///     within this instance.
    /// - table     : JPEG.Table.HuffmanAC
    ///     The AC huffman table.
    public mutating 
    func push(ac table:JPEG.Table.HuffmanAC) 
    {
        self.tables.ac[keyPath: table.target] = table
    }
    /// mutating func JPEG.Context.push(quanta:)
    /// throws 
    ///     Updates the decoder state with the given quantization table.
    /// 
    ///     This method binds the table to its target [`(Table.Quantization).Selector`] 
    ///     within this instance.
    /// - table     : JPEG.Table.Quantization
    ///     The quantization table.
    public mutating 
    func push(quanta table:JPEG.Table.Quantization) throws 
    {
        // generate a new `qi`, and get the corresponding `q` from the 
        // `spectral.push` function
        let qi:JPEG.Table.Quantization.Key          = .init(self.counter)
        let q:Int     = try self.spectral.push(qi: qi, quanta: table)
        self.counter += 1
        self.tables.quanta[keyPath: table.target]   = (q, qi)
    }
    /// mutating func JPEG.Context.push(metadata:)
    ///     Updates the decoder state with the given metadata record.
    /// 
    ///     This method adds the metadata record to the [`(Data.Spectral).metadata`] 
    ///     array in the stored image.
    /// - metadata  : JPEG.Metadata
    ///     The metadata record.
    public mutating 
    func push(metadata:JPEG.Metadata) 
    {
        self.spectral.metadata.append(metadata)
    }
    /// mutating func JPEG.Context.push(scan:ecss:extend:)
    /// throws 
    ///     Updates the decoder state with the given scan header, and decodes the 
    ///     given entropy-coded segment.
    /// 
    ///     This type tracks the scan progression of the stored image, and will 
    ///     validate the newly pushed `scan` header against the stored progressive state.
    /// - scan  : JPEG.Header.Scan 
    ///     The scan header associated with the given entropy-coded segment.
    /// - ecss  : [[Swift.UInt8]]
    ///     The entropy-coded segment. Each sub-array is one restart interval of 
    ///     segment. 
    /// - extend: Swift.Bool 
    ///     Specifies whether or not the decoder is allowed to dynamically extend 
    ///     the height of the image if the entropy-coded segment contains more 
    ///     rows of image data than implied by the frame header [`(Header.Frame).size`].
    ///     
    ///     This argument should be set to `true` for the first scan in the file, 
    ///     to accommodate a possible [`(Header).HeightRedefinition`], and `false` 
    ///     for all other scans.
    public mutating 
    func push(scan:JPEG.Header.Scan, ecss:[[UInt8]], extend:Bool) throws 
    {
        let interval:Int
        if let stride:Int = self.interval 
        {
            interval = stride 
        }
        else if ecss.count == 1
        {
            interval = .max 
        }
        else 
        {
            throw JPEG.DecodingError.missingRestartIntervalSegment
        }
        
        try self.progression.update(scan)
        try self.spectral.decode(ecss: ecss, interval: interval, scan: scan, 
            tables: self.tables, extend: extend)
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
        var metadata:[JPEG.Metadata]    = []
        var seen:(jfif:Bool, exif:Bool) = (false, false)
        marker = try stream.segment()
        preamble: 
        while true 
        {
            switch (seen, marker.type)
            {
            case ((jfif: false, exif: _), .application(0)): // JFIF 
                let jfif:JPEG.JFIF = try .parse(marker.data)
                metadata.append(.jfif(jfif))
                seen.jfif = true
            
            case ((jfif: _, exif: false), .application(1)): // EXIF 
                let exif:JPEG.EXIF = try .parse(marker.data)
                metadata.append(.exif(exif))
                seen.exif = true 
            
            case ((jfif: _, exif: _), .application(let application)):
                metadata.append(.application(application, data: marker.data))
            
            case ((jfif: _, exif: _), .comment):
                metadata.append(.comment(data: marker.data))
            
            default:
                break preamble 
            }
            
            marker = try stream.segment() 
        }
        
        var dc:[JPEG.Table.HuffmanDC]           = [], 
            ac:[JPEG.Table.HuffmanAC]           = [], 
            quanta:[JPEG.Table.Quantization]    = []
        var interval:JPEG.Header.RestartInterval?, 
            frame:JPEG.Header.Frame?
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
                let parsed:[JPEG.Table.Quantization] = 
                    try JPEG.Table.parse(quantization: marker.data)
                quanta.append(contentsOf: parsed)
            
            case .huffman:
                let parsed:(dc:[JPEG.Table.HuffmanDC], ac:[JPEG.Table.HuffmanAC]) = 
                    try JPEG.Table.parse(huffman: marker.data)
                dc.append(contentsOf: parsed.dc)
                ac.append(contentsOf: parsed.ac)
            
            case .interval:
                interval = try .parse(marker.data)
            
            // an APP0 segment after the preamble just gets recorded as an APP0 segment, 
            // not a JFIF record
            case .application(let application):
                metadata.append(.application(application, data: marker.data))
            case .comment:
                metadata.append(.comment(data: marker.data))
            
            case .scan:
                throw JPEG.DecodingError.prematureScanHeaderSegment
            case .height:
                throw JPEG.DecodingError.prematureHeightRedefinitionSegment
            
            case .end:
                throw JPEG.DecodingError.prematureEndOfImage
            case .start:
                throw JPEG.DecodingError.duplicateStartOfImage
            case .restart(_):
                throw JPEG.DecodingError.unexpectedRestart
            
            // unimplemented 
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
        for metadata:JPEG.Metadata in metadata 
        {
            context.push(metadata: metadata)
        }
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
        if let interval:JPEG.Header.RestartInterval = interval 
        {
            context.push(interval: interval)
        }
        
        var first:Bool = true
        scans:
        while true 
        {
            switch marker.type 
            {
            case .frame:
                throw JPEG.DecodingError.duplicateFrameHeaderSegment
            
            case .quantization:
                for table:JPEG.Table.Quantization in 
                    try JPEG.Table.parse(quantization: marker.data)
                {
                    try context.push(quanta: table)
                }
            
            case .huffman:
                let parsed:(dc:[JPEG.Table.HuffmanDC], ac:[JPEG.Table.HuffmanAC]) = 
                    try JPEG.Table.parse(huffman: marker.data)
                for table:JPEG.Table.HuffmanDC in parsed.dc 
                {
                    context.push(dc: table)
                }
                for table:JPEG.Table.HuffmanAC in parsed.ac 
                {
                    context.push(ac: table)
                }
            
            case .application(let application):
                context.push(metadata: .application(application, data: marker.data))
            case .comment:
                context.push(metadata: .comment(data: marker.data))        

            case .scan:
                let scan:JPEG.Header.Scan   = try .parse(marker.data, 
                    process: context.spectral.layout.process)
                var ecss:[[UInt8]] = []
                for index:Int in 0...
                {
                    let ecs:[UInt8]
                    (ecs, marker) = try stream.segment(prefix: true)
                    ecss.append(ecs)
                    guard case .restart(let phase) = marker.type
                    else 
                    {
                        try context.push(scan: scan, ecss: ecss, extend: first)
                        if first 
                        {
                            let height:JPEG.Header.HeightRedefinition
                            if case .height = marker.type 
                            {
                                height = try .parse(marker.data)
                                marker = try stream.segment() 
                            }
                            // same guarantees for `!` as before
                            else if frame!.size.y > 0
                            {
                                height = .init(height: frame!.size.y)
                            }
                            else 
                            {
                                throw JPEG.DecodingError.missingHeightRedefinitionSegment
                            }
                            context.push(height: height)
                            first = false 
                        }
                        continue scans 
                    }
                    
                    guard phase == index % 8 
                    else 
                    {
                        throw JPEG.DecodingError.invalidRestartPhase(phase, expected: index % 8)
                    }
                }
            
            case .interval:
                context.push(interval: try .parse(marker.data))
            
            case .end:
                return context.spectral 
                
            case .start:
                throw JPEG.DecodingError.duplicateStartOfImage
            
            case .restart(_):
                throw JPEG.DecodingError.unexpectedRestart
            case .height:
                throw JPEG.DecodingError.unexpectedHeightRedefinitionSegment
            
            // unimplemented 
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
    /// func JPEG.Data.Spectral.idct()
    ///     Converts this spectral image into its planar, spatial representation. 
    /// - ->    : JPEG.Data.Planar<Format> 
    ///     The output of an inverse discrete cosine transform performed on this image.
    /// #  [See also](spectral-change-representation)
    /// ## (0:spectral-change-representation)
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
    /// func JPEG.Data.Planar.interleaved(cosite:)
    ///     Converts this planar image into its rectangular representation. 
    /// - cosited : Swift.Bool 
    ///     The upsampling method to use. Setting this parameter to `true` co-sites 
    ///     the samples; setting it to `false` centers them instead.
    /// 
    ///     The default value is `false`.
    /// - ->    : JPEG.Data.Rectangular<Format> 
    ///     A rectangular image created by upsampling all planes in the input to 
    ///     the same sampling factor.
    /// #  [See also](planar-change-representation)
    /// ## (0:planar-change-representation)
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
extension JPEG.Data.Rectangular 
{
    /// func JPEG.Data.Rectangular.unpack<Color>(as:)
    /// where Color:JPEG.Color, Color.Format == Format 
    /// @ specialized where Color == JPEG.YCbCr
    /// @ specialized where Color == JPEG.RGB
    ///     Unpacks the data in this image into pixels of the given color target.
    /// - _ : Color.Type 
    ///     The color target.
    /// - ->: [Color]
    ///     A row-major array containing pixels of the image in the specified color space.
    /// #  [See also](rectangular-change-representation)
    /// ## (0:rectangular-change-representation)
    @_specialize(where Color == JPEG.YCbCr, Format == JPEG.Common)
    @_specialize(where Color == JPEG.RGB, Format == JPEG.Common)
    public 
    func unpack<Color>(as _:Color.Type) -> [Color] 
        where Color:JPEG.Color, Color.Format == Format 
    {
        Color.unpack(self.values, of: self.layout.format)
    }
}

// staged APIs 
extension JPEG.Data.Spectral 
{
    /// static func JPEG.Data.Spectral.decompress<Source>(stream:) 
    /// throws 
    /// where Source:JPEG.Bytestream.Source 
    ///     Decompresses a spectral image from the given data source.
    /// - stream    : inout Source 
    ///     A source bytestream.
    /// - ->        : Self
    ///     The decompressed image.
    /// #  [See also](spectral-create-image)
    /// ## (1:spectral-create-image)
    public static 
    func decompress<Source>(stream:inout Source) throws -> Self
        where Source:JPEG.Bytestream.Source 
    {
        return try JPEG.Context.decompress(stream: &stream)
    }
}
extension JPEG.Data.Planar 
{
    /// static func JPEG.Data.Planar.decompress<Source>(stream:) 
    /// throws 
    /// where Source:JPEG.Bytestream.Source 
    ///     Decompresses a planar image from the given data source.
    /// 
    ///     This function is a convenience function which calls [`Spectral.decompress(stream:)`] 
    ///     to obtain a spectral image, and then calls [`(Spectral).idct()`] on the 
    ///     output to return a planar image.
    /// - stream    : inout Source 
    ///     A source bytestream.
    /// - ->        : Self
    ///     The decompressed image.
    /// #  [See also](planar-create-image)
    /// ## (2:planar-create-image)
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
    /// static func JPEG.Data.Rectangular.decompress<Source>(stream:cosite:) 
    /// throws 
    /// where Source:JPEG.Bytestream.Source 
    ///     Decompresses a rectangular image from the given data source.
    /// 
    ///     This function is a convenience function which calls [`Planar.decompress(stream:)`] 
    ///     to obtain a planar image, and then calls [`(Planar).interleaved(cosite:)`] 
    ///     on the output to return a rectangular image.
    /// - stream    : inout Source 
    ///     A source bytestream.
    /// - cosited : Swift.Bool 
    ///     The upsampling method to use. Setting this parameter to `true` co-sites 
    ///     the samples; setting it to `false` centers them instead.
    /// 
    ///     The default value is `false`.
    /// - ->        : Self
    ///     The decompressed image.
    /// #  [See also](rectangular-create-image)
    /// ## (3:rectangular-create-image)
    public static 
    func decompress<Source>(stream:inout Source, cosite cosited:Bool = false) throws -> Self
        where Source:JPEG.Bytestream.Source 
    {
        let planar:JPEG.Data.Planar<Format> = try .decompress(stream: &stream) 
        return planar.interleaved(cosite: cosited)
    }
}
