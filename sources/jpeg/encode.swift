import Glibc

extension JPEG.DensityUnit 
{
    var code:UInt8 
    {
        switch self 
        {
        case .none:
            return 0
        case .dpi:
            return 1
        case .dpcm:
            return 2
        }
    }
}
extension JPEG.Marker 
{
    var code:UInt8 
    {
        switch self 
        {
        case .frame(.baseline):
            return 0xc0
        case .frame(.extended   (coding: .huffman, differential: false)):
            return 0xc1
        case .frame(.progressive(coding: .huffman, differential: false)):
            return 0xc2
        
        case .frame(.lossless   (coding: .huffman, differential: false)):
            return 0xc3
        
        case .huffman:
            return 0xc4
        
        case .frame(.extended   (coding: .huffman, differential: true)):
            return 0xc5
        case .frame(.progressive(coding: .huffman, differential: true)):
            return 0xc6
        case .frame(.lossless   (coding: .huffman, differential: true)):
            return 0xc7
        
        case .frame(.extended   (coding: .arithmetic, differential: false)):
            return 0xc9
        case .frame(.progressive(coding: .arithmetic, differential: false)):
            return 0xca
        case .frame(.lossless   (coding: .arithmetic, differential: false)):
            return 0xcb
        
        case .arithmeticCodingCondition:
            return 0xcc
        
        case .frame(.extended   (coding: .arithmetic, differential: true)):
            return 0xcd
        case .frame(.progressive(coding: .arithmetic, differential: true)):
            return 0xce
        case .frame(.lossless   (coding: .arithmetic, differential: true)):
            return 0xcf
        
        case .restart(let n):
            return 0xd0 + .init(n & 0x07)
                
        case .start:
            return 0xd8
        case .end:
            return 0xd9 
        case .scan:
            return 0xda
        case .quantization:
            return 0xdb
        case .height:
            return 0xdc
        case .interval:
            return 0xdd
        case .hierarchical:
            return 0xde
        case .expandReferenceComponents:
            return 0xdf
        
        case .application(let n):
            return 0xe0 + .init(n & 0x0f)
        case .comment:
            return 0xfe
        }
    }
}

// error types 
extension JPEG 
{
    public 
    enum FormattingError:JPEG.Error 
    {
        case invalidDestination
        
        public static 
        var namespace:String 
        {
            "formatting error"
        }
        
        public 
        var message:String 
        {
            switch self 
            {
            case .invalidDestination:
                return "failed to write to destination"
            } 
        }
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
    public 
    enum SerializingError:JPEG.Error 
    {
        public static 
        var namespace:String 
        {
            "serializing error"
        }
        
        public 
        var message:String 
        {
            switch self 
            {
            } 
        }
        public 
        var details:String? 
        {
            switch self 
            {
            } 
        }
    }
    public 
    enum EncodingError:JPEG.Error 
    {
        public static 
        var namespace:String 
        {
            "encoding error"
        }
        
        public 
        var message:String 
        {
            switch self 
            {
            } 
        }
        public 
        var details:String? 
        {
            switch self 
            {
            } 
        }
    }
}

// inverse huffman tables 
extension JPEG.Table 
{
    public 
    typealias InverseHuffmanDC = InverseHuffman<JPEG.Bitstream.Symbol.DC>
    public 
    typealias InverseHuffmanAC = InverseHuffman<JPEG.Bitstream.Symbol.AC>
    public 
    struct InverseHuffman<Symbol>:JPEG.AnyTable where Symbol:JPEG.Bitstream.AnySymbol  
    {
        struct Codeword  
        {
            // the inhabited bits are in the most significant end of the `UInt16`
            let bits:UInt16
            @JPEG.Storage<UInt16> 
            var length:Int 
        }
        
        let storage:[Codeword]
        let symbols:[[Symbol]]
        
        let target:Selector
        
        subscript(symbol:Symbol) -> Codeword 
        {
            self.storage[.init(symbol.value)]
        }
    }
}
extension JPEG.Table.InverseHuffman 
{
    // indirect enum would entail too much copying 
    final    
    class Subtree<Element>
    {
        enum Node 
        {
            case leaf(Element)
            case interior(left:Subtree, right:Subtree)
        }
        
        let node:Node
        
        init(_ node:Node) 
        {
            self.node = node 
        }
    }
}
extension JPEG.Table.InverseHuffman.Subtree 
{
    private 
    var children:[JPEG.Table.InverseHuffman<Symbol>.Subtree<Element>] 
    {
        switch self.node  
        {
        case .leaf:
            return [] 
        case .interior(left: let left, right: let right):
            return [left, right]
        }
    }
    func levels() -> [Int] 
    {
        var levels:[Int]                                                = []
        var queue:[JPEG.Table.InverseHuffman<Symbol>.Subtree<Element>]  = [self]
        while !queue.isEmpty  
        {
            var leaves:Int = 0 
            for subtree:JPEG.Table.InverseHuffman<Symbol>.Subtree<Element> in queue 
            {
                if case .leaf = subtree.node 
                {
                    leaves += 1
                }
            }
            levels.append(leaves)
            queue = queue.flatMap(\.children)
        }
        
        return levels 
    }
}
extension JPEG.Table.InverseHuffman 
{
    // `frequencies` must always contain 256 entries 
    public static 
    func build(frequencies:[Int], target:Selector) -> Self 
    {
        // sort non-zero symbols by (decreasing) frequency
        // this is nlog(n), but so is the heap stuff later on
        let sorted:[(frequency:Int, symbol:Symbol)] = (UInt8.min ... UInt8.max).compactMap 
        {
            (value:UInt8) -> (Int, Symbol)? in 
            
            let frequency:Int = frequencies[.init(value)]
            guard frequency > 0 
            else 
            {
                return nil 
            }
            
            return (frequency, .init(value))
        }.sorted
        {
            $0.frequency > $1.frequency
        }
        
        // reversing (to get canonically sorted array) gets the heapify below 
        // to its best-case O(n) time, not that O matters for n = 256 
        var heap:Common.Heap<Int, Subtree<Void>> = .init(sorted.reversed().map  
        {
            ($0.frequency, .init(.leaf(())))
        })
        // insert dummy value with frequency 0 to occupy the all-ones codeword 
        heap.enqueue(key: 0, value: .init(.leaf(())))
        
        // standard huffman tree construction algorithm
        while let first:(key:Int, value:Subtree<Void>) = heap.dequeue() 
        {
            guard let second:(key:Int, value:Subtree<Void>) = heap.dequeue() 
            else 
            {
                var storage:[Codeword] = .init(repeating: .init(bits: 0, length: 0), count: 256)
                
                // drop the first level, since it corresponds to the tree root 
                let levels:ArraySlice<Int> = first.value.levels().dropFirst()
                guard !levels.isEmpty
                else 
                {
                    // happens in the (almost unreachable) situation where there 
                    // are no codewords with non-zero frequency 
                    let symbols:[[Symbol]] = .init(repeating: [], count: 16)
                    return .init(storage: storage, symbols: symbols, target: target) 
                }
                
                // convert level counts to codeword assignments 
                let limited:[Int]        = Self.limit(height: 16, of: levels)
                let codewords:[Codeword] = Self.assign(sorted.count, levels: limited)
                
                // for codeword:Codeword in codewords 
                // {
                //     print((0 ..< codeword.length).map
                //     { 
                //         (codeword.bits >> (UInt16.bitWidth - $0 - 1)) & 1 != 0 ? "1" : "0" 
                //     }.joined(separator: " "))
                // }
                
                // split symbols list into levels 
                var base:Int            = 0, 
                    symbols:[[Symbol]]  = []
                for leaves:Int in limited 
                {
                    var level:[Symbol] = []
                        level.reserveCapacity(leaves)
                    for i:Int in base ..< base + leaves 
                    {
                        let symbol:Symbol               = sorted[i].symbol, 
                            codeword:Codeword           = codewords[i]
                        storage[.init(symbol.value)]    = codeword 
                        level.append(symbol)
                    }
                    
                    symbols.append(level)
                    base += leaves 
                }
                
                return .init(storage: storage, symbols: symbols, target: target)
            }
            
            let merged:Subtree<Void> = .init(.interior(left: first.value, right: second.value))
            let weight:Int           = first.key + second.key 
            
            heap.enqueue(key: weight, value: merged)
        }
        
        fatalError("unreachable")
    }
    
    // limit the height of the generated tree to the given height, and also 
    // removes the slot corresponding to the all-ones code at the end 
    private static 
    func limit(height:Int, of uncompacted:ArraySlice<Int>) -> [Int]
    {
        var levels:[Int] = .init(uncompacted)
        guard levels.count > height
        else 
        {
            // remove the all-ones code 
            levels[levels.endIndex - 1] -= 1
            return levels 
        }
        
        // collect unhoused nodes: from the bottom to level 17, we gather up 
        // node pairs (since huffman trees are always full trees). one of the 
        // child nodes gets promoted to the level above, the other node goes 
        // into a pool of unhoused nodes 
        var unhoused:Int = 0 
        for l:Int in (height ..< levels.endIndex).reversed() 
        {
            assert(levels[l] & 1 == 0)
            
            let pairs:Int  = levels[l] >> 1
            unhoused      += pairs 
            levels[l - 1] += pairs 
        }
        levels.removeLast(levels.count - height)
        
        // for the remaining unhoused nodes, our strategy is to look for a level 
        // at least 1 step above the bottom (meaning, indices 0 ..< 15) and split 
        // one of its leaves, reducing the leaf count of that level by 1, and 
        // increasing the leaf count of the level below it by 2
        var split:Int = height - 2
        while unhoused > 0 
        {
            guard levels[split] > 0 
            else 
            {
                split -= 1
                // traversal pattern should make it impossible to go below 0 so 
                // long as total leaf population is less than 2^16 (it can never 
                // be greater than 257 anyway)
                assert(split > 0)
                continue 
            }
            
            let resettled:Int  = min(levels[split], unhoused)
            unhoused          -=     resettled 
            levels[split]     -=     resettled 
            levels[split + 1] += 2 * resettled 
            
            if split < height - 2 
            {
                // since we have added new leaves to this level
                split += 1
            } 
        }
        
        // remove the all-ones code 
        levels[height - 1] -= 1
        return levels
    }
    
    private static 
    func assign(_ symbols:Int, levels:[Int]) -> [Codeword]
    {
        var codewords:[Codeword] = []
        var counter:UInt16       = 0
        for (length, leaves):(Int, Int) in zip(1 ... 16, levels) 
        {
            for _ in 0 ..< leaves 
            {
                let bits:UInt16 = counter &<< (UInt16.bitWidth &- length)
                counter        += 1
                codewords.append(.init(bits: bits, length: length))
            }
            
            counter <<= 1
        }
        
        return codewords
    }
}

// encoders (opposite of decoders)
extension JPEG.Bitstream.Symbol.DC
{
    init(binade:Int) 
    {
        assert(0 ..< 16 ~= binade)
        self.value = .init(binade)
    }
}
extension JPEG.Bitstream.Symbol.AC 
{
    init(zeroes:Int, binade:Int) 
    {
        assert(0 ..< 16 ~= zeroes)
        assert(0 ..< 16 ~= binade)
        self.value = .init(zeroes << 4 | binade)
    }
}
extension JPEG.Bitstream.Composite.DC
{
    var decomposed:(symbol:JPEG.Bitstream.Symbol.DC, tail:UInt16, length:Int)
    {
        let (binade, tail):(Int, UInt16)    = JPEG.Bitstream.compact(self.difference)
        let symbol:JPEG.Bitstream.Symbol.DC = .init(binade: binade)
        return (symbol, tail, binade)
    }
}
extension JPEG.Bitstream.Composite.AC
{
    var decomposed:(symbol:JPEG.Bitstream.Symbol.AC, tail:UInt16, length:Int)
    {
        switch self 
        {
        case .run(let zeroes, value: let value):
            let (binade, tail):(Int, UInt16)    = JPEG.Bitstream.compact(value)
            let symbol:JPEG.Bitstream.Symbol.AC = .init(zeroes: zeroes, binade: binade)
            return (symbol, tail, binade)
        
        case .eob(let run):
            assert(run > 0)
            let binade:Int  = Int.bitWidth - run.leadingZeroBitCount - 1
            let tail:UInt16 = .init(~(1 &<< binade) & run)
            
            let symbol:JPEG.Bitstream.Symbol.AC = .init(zeroes: binade, binade: 0)
            return (symbol, tail, binade)
        }
    }
}
extension JPEG.Bitstream 
{ 
    mutating 
    func append(composite:Composite.DC, table:JPEG.Table.InverseHuffmanDC) 
    {
        let (symbol, tail, length):(JPEG.Bitstream.Symbol.DC, UInt16, Int) = 
            composite.decomposed 
        
        let codeword:JPEG.Table.InverseHuffmanDC.Codeword = table[symbol]
        self.append(codeword.bits, count: codeword.length)
        self.append(tail, count: length)
    } 
    mutating 
    func append(composite:Composite.AC, table:JPEG.Table.InverseHuffmanAC) 
    {
        let (symbol, tail, length):(JPEG.Bitstream.Symbol.AC, UInt16, Int) = 
            composite.decomposed 
            
        let codeword:JPEG.Table.InverseHuffmanAC.Codeword = table[symbol]
        self.append(codeword.bits, count: codeword.length)
        self.append(tail, count: length)
    } 
    
    static 
    func initial(dc composites:[Composite.DC], table:JPEG.Table.InverseHuffmanDC) 
        -> Self 
    {
        var bits:Self = []
        for composite:Composite.DC in composites 
        {
            bits.append(composite: composite, table: table)
        }
        return bits 
    }
    static 
    func refining(dc refinements:[Bool]) 
        -> Self 
    {
        var bits:Self = []
        for refinement:Bool in refinements 
        {
            bits.append(bit: refinement ? 1 : 0)
        }
        return bits 
    }
    static 
    func initial(ac composites:[Composite.AC], table:JPEG.Table.InverseHuffmanAC) 
        -> Self 
    {
        var bits:Self = []
        for composite:Composite.AC in composites 
        {
            bits.append(composite: composite, table: table)
        }
        return bits 
    }
    static 
    func refining(ac pairs:[(Composite.AC, [Bool])], table:JPEG.Table.InverseHuffmanAC) 
        -> Self 
    {
        var bits:Self = []
        for (composite, refinements):(Composite.AC, [Bool]) in pairs 
        {
            bits.append(composite: composite, table: table)
            for refinement:Bool in refinements 
            {
                bits.append(bit: refinement ? 1 : 0)
            }
        }
        return bits 
    }
}

// serializers (opposite of parsers)
extension JPEG.JFIF 
{
    public 
    func serialize() -> [UInt8] 
    {
        var bytes:[UInt8] = Self.signature 
        bytes.append(.init(self.version.major))
        bytes.append(.init(self.version.minor))
        bytes.append(self.density.unit.code)
        bytes.append(contentsOf: [UInt8].store(self.density.x, asBigEndian: UInt16.self))
        bytes.append(contentsOf: [UInt8].store(self.density.y, asBigEndian: UInt16.self))
        // no thumbnail 
        bytes.append(0) 
        bytes.append(0)
        return bytes
    }
}

extension JPEG.AnyTable 
{
    static 
    func serialize(selector:Self.Selector) -> UInt8 
    {
        switch selector 
        {
        case \.0:
            return 0
        case \.1:
            return 1
        case \.2:
            return 2
        case \.3:
            return 3
        default:
            fatalError("unreachable")
        }
    }
}
extension JPEG.Table.InverseHuffman 
{
    // bytes 1 ..< 17 + count (does not include selector byte)
    func serialize() -> [UInt8]
    {
        return self.symbols.map{ .init($0.count) } + self.symbols.flatMap{ $0.map(\.value) }
    }
}
extension JPEG.Table.Quantization 
{
    // bytes 1 ..< 1 + 64 * stride (does not include selector byte)
    func serialize() -> [UInt8]
    {
        switch self.precision 
        {
        case .uint8:
            return self.storage.map(UInt8.init(_:))
        case .uint16:
            return self.storage.flatMap{ [UInt8].store($0, asBigEndian: UInt16.self) }
        }
    } 
}
extension JPEG.Table 
{
    public static 
    func serialize(_ dc:[InverseHuffmanDC], _ ac:[InverseHuffmanAC]) -> [UInt8]
    {
        var bytes:[UInt8] = []
        for table:InverseHuffmanDC in dc 
        {
            bytes.append(0x00 | InverseHuffmanDC.serialize(selector: table.target))
            bytes.append(contentsOf: table.serialize())
        }
        for table:InverseHuffmanAC in ac 
        {
            bytes.append(0x10 | InverseHuffmanAC.serialize(selector: table.target))
            bytes.append(contentsOf: table.serialize())
        }
        
        return bytes 
    }
    
    public static 
    func serialize(_ tables:[Quantization]) -> [UInt8] 
    {
        var bytes:[UInt8] = []
        for table:Quantization in tables 
        {
            // yes all the information needed to encode the sigil byte is in the 
            // table data structure itself, but for consistency with the huffman 
            // table serializers, we encode it in the caller body
            switch table.precision 
            {
            case .uint8:
                bytes.append(0x00 | Quantization.serialize(selector: table.target))
                bytes.append(contentsOf: table.serialize())
            case .uint16:
                bytes.append(0x10 | Quantization.serialize(selector: table.target))
                bytes.append(contentsOf: table.serialize())
            }
        }
        
        return bytes 
    }
}

extension JPEG.Frame 
{
    public 
    func serialize() -> [UInt8]
    {
        var bytes:[UInt8] = [.init(self.precision)]
        bytes.append(contentsOf: [UInt8].store(self.size.y, asBigEndian: UInt16.self))
        bytes.append(contentsOf: [UInt8].store(self.size.x, asBigEndian: UInt16.self))
        bytes.append(.init(self.components.count))
        
        for (ci, component):(Int, Component) in self.components 
        {
            bytes.append(.init(ci))
            bytes.append(.init(component.factor.x) << 4 | .init(component.factor.y))
            bytes.append(JPEG.Table.Quantization.serialize(selector: component.selector))
        }
        
        return bytes
    }
}
extension JPEG.Scan 
{
    public 
    func serialize() -> [UInt8] 
    {
        var bytes:[UInt8] = [.init(self.components.count)]
        for component:Component in self.components 
        {
            let dc:UInt8 = JPEG.Table.HuffmanDC.serialize(selector: component.selectors.huffman.dc),
                ac:UInt8 = JPEG.Table.HuffmanAC.serialize(selector: component.selectors.huffman.ac)
            bytes.append(.init(component.ci))
            bytes.append(dc << 4 | ac)
        }
        
        bytes.append(.init(self.band.lowerBound))
        bytes.append(.init(self.band.upperBound - 1))
        
        let pt:(UInt8, UInt8) = 
        (
                                                .init(self.bits.lowerBound), 
            self.bits.upperBound == .max ? 0 :  .init(self.bits.upperBound)
        )
        bytes.append(pt.1 << 4 | pt.0)
        return bytes 
    }
}

// formatters (opposite of lexers)
public 
protocol _JPEGBytestreamDestination 
{
    mutating 
    func write(_ bytes:[UInt8]) -> Void?
}
extension JPEG.Bytestream 
{
    public 
    typealias Destination = _JPEGBytestreamDestination
}
extension JPEG.Bytestream.Destination 
{
    public mutating 
    func format(marker:JPEG.Marker, tail:[UInt8]) throws 
    {
        let length:Int      = tail.count + 2
        let bytes:[UInt8]   = 
            [0xff, marker.code] + [UInt8].store(length, asBigEndian: UInt16.self) + tail
        guard let _:Void    = self.write(bytes)
        else 
        {
            throw JPEG.FormattingError.invalidDestination 
        }
    }
    public mutating 
    func format(prefix:[UInt8]) throws 
    {
        guard let _:Void = self.write(prefix) 
        else 
        {
            throw JPEG.FormattingError.invalidDestination 
        }
    }
}

/// file IO functionality
extension JPEG.File 
{
    public 
    struct Destination 
    {
        private 
        let descriptor:Descriptor
    }
}
extension JPEG.File.Destination:JPEG.Bytestream.Destination 
{
    /// Calls a closure with an interface for writing to the specified file.
    /// 
    /// This method automatically closes the file when its function argument returns.
    /// - Parameters:
    ///     - path: A path to the file to open.
    ///     - body: A closure with a `Destination` parameter representing
    ///         the specified file to which data can be written to. This
    ///         interface is only valid for the duration of the method’s
    ///         execution. The closure is only executed if the specified
    ///         file could be successfully opened, otherwise `nil` is returned.
    ///         If `body` has a return value and the specified file could
    ///         be opened, its return value is returned as the return value
    ///         of the `open(path:body:)` method.
    /// - Returns: `nil` if the specified file could not be opened, or the
    ///     return value of the function argument otherwise.
    public static
    func open<Result>(path:String, body:(inout Self) throws -> Result)
        rethrows -> Result?
    {
        guard let descriptor:JPEG.File.Descriptor = fopen(path, "wb")
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

    /// Write the bytes in the given array to this file interface.
    /// 
    /// This method only returns `()` if the entire array argument could
    /// be written. This method advances the file pointer.
    /// 
    /// - Parameters:
    ///     - buffer: The data to write.
    /// - Returns: `()` if the entire array argument could be written, or
    ///     `nil` otherwise.
    public
    func write(_ buffer:[UInt8]) -> Void?
    {
        let count:Int = buffer.withUnsafeBufferPointer
        {
            fwrite($0.baseAddress, MemoryLayout<UInt8>.stride,
                $0.count, self.descriptor)
        }

        guard count == buffer.count
        else
        {
            return nil
        }

        return ()
    }
}

extension Array where Element == UInt8
{
    /// Decomposes the given integer value into its constituent bytes, in big-endian order.
    /// - Parameters:
    ///     - value: The integer value to decompose.
    ///     - type: The big-endian format `T` to store the given `value` as. The given
    ///             `value` is truncated to fit in a `T`.
    /// - Returns: An array containing the bytes of the given `value`, in big-endian order.
    fileprivate static
    func store<U, T>(_ value:U, asBigEndian type:T.Type) -> [UInt8]
        where U:BinaryInteger, T:FixedWidthInteger
    {
        return .init(unsafeUninitializedCapacity: MemoryLayout<T>.size)
        {
            (buffer:inout UnsafeMutableBufferPointer<UInt8>, count:inout Int) in

            let bigEndian:T = T.init(truncatingIfNeeded: value).bigEndian,
                destination:UnsafeMutableRawBufferPointer = .init(buffer)
            Swift.withUnsafeBytes(of: bigEndian)
            {
                destination.copyMemory(from: $0)
                count = $0.count
            }
        }
    }
}
