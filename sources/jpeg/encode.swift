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

// forward dct 
extension JPEG.Data.Planar.Plane 
{
    fileprivate 
    func load(x:Int, y:Int, limit:SIMD8<Float>) 
        -> JPEG.Data.Spectral<Format>.Plane.Block8x8<Float>
    {
        @inline(__always)
        func row(_ h:Int) -> SIMD8<Float> 
        {
            pointwiseMin(limit, .init(.init(
                self[x: 8 * x + 0, y: 8 * y + h],
                self[x: 8 * x + 1, y: 8 * y + h],
                self[x: 8 * x + 2, y: 8 * y + h],
                self[x: 8 * x + 3, y: 8 * y + h],
                
                self[x: 8 * x + 4, y: 8 * y + h],
                self[x: 8 * x + 5, y: 8 * y + h],
                self[x: 8 * x + 6, y: 8 * y + h],
                self[x: 8 * x + 7, y: 8 * y + h])))
        }
        
        return (row(0), row(1), row(2), row(3), row(4), row(5), row(6), row(7))
    }
}
extension JPEG.Data.Spectral.Plane 
{
    private static 
    var zigzag:Block8x8<Int> 
    {
        @inline(__always)
        func row(_ h:Int) -> SIMD8<Int> 
        {
            .init(
                JPEG.Table.Quantization.z(k: 0, h: h),
                JPEG.Table.Quantization.z(k: 1, h: h),
                JPEG.Table.Quantization.z(k: 2, h: h),
                JPEG.Table.Quantization.z(k: 3, h: h),
                JPEG.Table.Quantization.z(k: 4, h: h),
                JPEG.Table.Quantization.z(k: 5, h: h),
                JPEG.Table.Quantization.z(k: 6, h: h),
                JPEG.Table.Quantization.z(k: 7, h: h)
                )
        }
        return (row(0), row(1), row(2), row(3), row(4), row(5), row(6), row(7))
    }
    private static 
    func fdct8(_ g:Block8x8<Float>, shift:Float) -> Block8x8<Float>
    {
        // even rows 
        let a:(SIMD8<Float>, SIMD8<Float>, SIMD8<Float>, SIMD8<Float>) = 
        (
            g.0 + g.7,
            g.1 + g.6, 
            g.2 + g.5, 
            g.3 + g.4
        )
        let b:(SIMD8<Float>, SIMD8<Float>, SIMD8<Float>, SIMD8<Float>) = 
        (
            a.0     +     a.3, 
                a.1 + a.2    , 
                a.1 - a.2    , 
            a.0     -     a.3
        )
        let c:SIMD8<Float> = 0.707106781 * (b.2 + b.3)
        let r:(SIMD8<Float>, SIMD8<Float>, SIMD8<Float>, SIMD8<Float>) = 
        (
            b.0     +     b.1 - shift,
                b.3 + c                  , 
            b.0     -     b.1            , 
                b.3 - c
        )
        // odd rows 
        let d:(SIMD8<Float>, SIMD8<Float>, SIMD8<Float>, SIMD8<Float>) = 
        (
            g.3 - g.4,
            g.2 - g.5,
            g.1 - g.6,
            g.0 - g.7
        )
        let f:(SIMD8<Float>, SIMD8<Float>, SIMD8<Float>) = 
        (
            d.0 + d.1, 
            d.1 + d.2, 
            d.2 + d.3
        )
        let k:SIMD8<Float> = 0.707106781 *  f.1, 
            l:SIMD8<Float> = 0.382683433 * (f.0 - f.2)
        let m:(SIMD8<Float>, SIMD8<Float>) = 
        (
            l + f.0 * 0.541196100, 
            l + f.2 * 1.306562965
        )
        let n:(SIMD8<Float>, SIMD8<Float>) = 
        (
            d.3 + k, 
            d.3 - k
        )
        let s:(SIMD8<Float>, SIMD8<Float>, SIMD8<Float>, SIMD8<Float>) = 
        (
            n.0     +     m.1, 
                n.1 - m.0    , 
                n.1 + m.0    , 
            n.0     -     m.1
        )
        return 
            (
            r.0, s.0, 
            r.1, s.1, 
            r.2, s.2, 
            r.3, s.3
            )
    }
    
    private static 
    func fdct8x8(_ g:Block8x8<Float>, shift:Float) -> Block8x8<Float>
    {
        let f:Block8x8<Float>   = Self.fdct8(Self.transpose(g), shift: shift), 
            h:Block8x8<Float>   = Self.fdct8(Self.transpose(f), shift: 0)
        return h
    }
    
    mutating 
    func fdct(_ plane:JPEG.Data.Planar<Format>.Plane, 
        quanta table:JPEG.Table.Quantization, precision:Int) 
    {
        let count:Int               = 64 * plane.units.x * plane.units.y
        let values:[Int16]          = .init(unsafeUninitializedCapacity: count)
        {
            var scale:Float 
            {
                0x1p3
            }
            let q:Block8x8<Float>   = Self.modulate(quanta: table, scale: scale)
            let z:Block8x8<Int>     = Self.zigzag
            
            let stride:Int          = 64 * plane.units.x
            // dont’s add 0.5 to the level shift, since the 0.5 is simply to 
            // emulate nearest-integer rounding 
            let level:Float         = 
                .init(sign: .plus, exponent: precision - 1, significand: 1) * scale
            let limit:SIMD8<Float>  = .init(repeating: 
                .init(sign: .plus, exponent: precision    , significand: 1)) - 1
            for (x, y):(Int, Int) in (0, 0) ..< plane.units 
            {
                let g:Block8x8<Float> = plane.load(x: x, y: y, limit: limit), 
                    h:Block8x8<Float> = Self.fdct8x8(g, shift: level)
                for (z, v):(SIMD8<Int>, SIMD8<Float>) in 
                [
                    (z.0, h.0 / q.0), 
                    (z.1, h.1 / q.1), 
                    (z.2, h.2 / q.2), 
                    (z.3, h.3 / q.3), 
                    (z.4, h.4 / q.4), 
                    (z.5, h.5 / q.5), 
                    (z.6, h.6 / q.6), 
                    (z.7, h.7 / q.7)
                ]
                {
                    let w:SIMD8<Int16> = .init(v, rounding: .toNearestOrAwayFromZero)
                    for j:Int in 0 ..< 8 
                    {
                        $0[y * stride + 64 * x + z[j]] = w[j]
                    }
                }
            }
            
            $1 = count
        }
        
        self.set(values: values, units: plane.units)
    }
}
extension JPEG.Data.Planar 
{
    public 
    func fdct(quanta:[JPEG.Table.Quantization.Key: [UInt16]]) 
        -> JPEG.Data.Spectral<Format>
    {
        let precision:Int                       = self.layout.format.precision
        var spectral:JPEG.Data.Spectral<Format> = .init(layout: self.layout)
        spectral.set(quanta: quanta)
        for (p, plane):(Int, JPEG.Data.Planar<Format>.Plane) in 
            zip(spectral.indices, self)
        {
            spectral[p].fdct(plane, quanta: spectral.quanta[spectral[p].q], 
                precision: precision)
        }
        spectral.set(width:  self.size.x)
        spectral.set(height: self.size.y)
        spectral.metadata.append(contentsOf: self.metadata)
        
        return spectral
    }
}

// strict constructors 
extension JPEG.JFIF 
{
    // due to a compiler issue, this initializer has to live in `decode.swift`
}
extension JPEG.Data.Spectral   
{
    // this property is not to be used within the library, it is used for encoding 
    // to obtain a valid frame header from a `Spectral` struct
    public 
    func encode() -> JPEG.Header.Frame 
    {
        do 
        {
            // strip the resident components
            return try .validate(
                process:    self.layout.process, 
                precision:  self.layout.format.precision, 
                size:       self.size, 
                components: .init(uniqueKeysWithValues: zip(self.layout.recognized, 
                    self.layout.planes[self.layout.recognized.indices].map(\.component))))
        }
        catch 
        {
            // there are only a few ways validation can fail, and all of them 
            // are programmer errors (zero width, broken `Format` implementation)
            fatalError((error as? JPEG.Error)?.message ?? "\(error)")
        }
    }
}

extension JPEG.Table.Huffman 
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
extension JPEG.Table.Huffman.Subtree 
{
    private 
    var children:[JPEG.Table.Huffman<Symbol>.Subtree<Element>] 
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
        var levels:[Int]                                        = []
        var queue:[JPEG.Table.Huffman<Symbol>.Subtree<Element>] = [self]
        while !queue.isEmpty  
        {
            var leaves:Int = 0 
            for subtree:JPEG.Table.Huffman<Symbol>.Subtree<Element> in queue 
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
extension JPEG.Table.Huffman 
{
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
    func assign(_ symbols:Int, levels:[Int]) -> [Encoder.Codeword]
    {
        var codewords:[Encoder.Codeword]    = []
        var counter:UInt16                  = 0
        for (length, leaves):(Int, Int) in zip(1 ... 16, levels) 
        {
            for _ in 0 ..< leaves 
            {
                codewords.append(.init(bits: counter, length: length))
                counter        += 1
            }
            
            counter <<= 1
        }
        
        return codewords
    }
    
    // `frequencies` must always contain 256 entries 
    public 
    init(frequencies:[Int], target:Selector)  
    {
        precondition(!frequencies.allSatisfy{ $0 <= 0 }, 
            "at least one symbol must have non-zero frequency")
        
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
                // drop the first level, since it corresponds to the tree root 
                let levels:ArraySlice<Int> = first.value.levels().dropFirst()
                assert(!levels.isEmpty)
                
                // convert level counts to codeword assignments 
                let limited:[Int]        = Self.limit(height: 16, of: levels)
                
                // split symbols list into levels 
                var base:Int            = 0, 
                    symbols:[[Symbol]]  = []
                    symbols.reserveCapacity(limited.count)
                for leaves:Int in limited 
                {
                    symbols.append(sorted[base ..< base + leaves].map(\.symbol))
                    base += leaves 
                }
                // symbols array must have length exactly equal to 16
                symbols.append(contentsOf: repeatElement([], count: 16 - symbols.count))
                
                self.init(validated: symbols, target: target)
                return 
            }
            
            let merged:Subtree<Void> = .init(.interior(left: first.value, right: second.value))
            let weight:Int           = first.key + second.key 
            
            heap.enqueue(key: weight, value: merged)
        }
        
        fatalError("unreachable")
    }
}

// inverse huffman tables 
extension JPEG.Table.Huffman 
{
    struct Encoder
    {
        struct Codeword  
        {
            // the inhabited bits are in the most significant end of the `UInt16`
            let bits:UInt16
            @Common.Storage<UInt16> 
            var length:Int 
        }
        
        private 
        let storage:[Codeword]
        
        init(_ storage:[Codeword]) 
        {
            self.storage = storage 
        }
    }
}
extension JPEG.Table.Huffman 
{
    func encoder() -> Encoder 
    {
        var storage:[Encoder.Codeword] = 
            .init(repeating: .init(bits: 0, length: 0), count: 256)
        
        let levels:[Int]                    = self.symbols.map(\.count), 
            count:Int                       = levels.reduce(0, +)
        let codewords:[Encoder.Codeword]    = Self.assign(count, levels: levels)
        
        var base:Int = 0
        for symbols:[Symbol] in self.symbols  
        {
            for (i, symbol):(Int, Symbol) in zip(base ..< base + symbols.count, symbols)
            {
                storage[.init(symbol.value)] = codewords[i]
            }
            
            base += symbols.count  
        }
        
        return .init(storage)
    }
}
// table accessors 
extension JPEG.Table.Huffman.Encoder 
{
    subscript(symbol:Symbol) -> Codeword 
    {
        self.storage[.init(symbol.value)]
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
    func append(composite:Composite.DC, table:JPEG.Table.HuffmanDC.Encoder) 
    {
        let (symbol, tail, length):(JPEG.Bitstream.Symbol.DC, UInt16, Int) = 
            composite.decomposed 
        
        let codeword:JPEG.Table.HuffmanDC.Encoder.Codeword = table[symbol]
        self.append(codeword.bits, count: codeword.length)
        self.append(tail, count: length)
    } 
    mutating 
    func append(composite:Composite.AC, table:JPEG.Table.HuffmanAC.Encoder) 
    {
        let (symbol, tail, length):(JPEG.Bitstream.Symbol.AC, UInt16, Int) = 
            composite.decomposed 
            
        let codeword:JPEG.Table.HuffmanAC.Encoder.Codeword = table[symbol]
        self.append(codeword.bits, count: codeword.length)
        self.append(tail, count: length)
    } 
}
extension JPEG.Bitstream.AnySymbol
{
    static 
    func frequencies<S>(of path:KeyPath<S.Element, Self>, in sequence:S) -> [Int]
        where S:Sequence
    {
        var frequencies:[Int] = .init(repeating: 0, count: 256)
        for element:S.Element in sequence  
        {
            frequencies[.init(element[keyPath: path].value)] += 1
        }
        return frequencies
    }
}
extension JPEG.Data.Spectral.Plane  
{
    func encode(x:Int, y:Int, predecessor:inout Int16)
        -> (JPEG.Bitstream.Composite.DC, [JPEG.Bitstream.Composite.AC])
    {
        // dc coefficient
        let coefficient:Int16   = self[x: x, y: y, z: 0] 
        let composite:JPEG.Bitstream.Composite.DC   = 
            .init(difference: coefficient &- predecessor)
        
        predecessor                                 = coefficient 
        // ac coefficients
        var composites:[JPEG.Bitstream.Composite.AC] = []
        var zeroes = 0
        for z:Int in 1 ..< 64
        {
            let coefficient:Int16 = self[x: x, y: y, z: z]
            if coefficient == 0 
            {
                if zeroes == 15 
                {
                    composites.append(.run(zeroes, value: 0))
                    zeroes  = 0 
                }
                else 
                {
                    zeroes += 1 
                }
            }
            else 
            {
                composites.append(.run(zeroes, value: coefficient))
                zeroes      = 0
            }
        }
        
        if zeroes > 0 
        {
            composites.append(.eob(1))
        }
        
        return (composite, composites)
    }
    
    // sequential mode 
    func encode(component:JPEG.Scan.Component) 
        -> ([UInt8], JPEG.Table.HuffmanDC, JPEG.Table.HuffmanAC)
    {
        let count:Int = self.units.x * self.units.y
        let composites:[(JPEG.Bitstream.Composite.DC, [JPEG.Bitstream.Composite.AC])] = 
            .init(unsafeUninitializedCapacity: count) 
        {
            var predecessor:Int16 = 0
            for (x, y):(Int, Int) in (0, 0) ..< self.units
            {
                // can use `!` here because loop execution implies `count > 0`
                ($0.baseAddress! + y * self.units.x + x).initialize(to:
                    self.encode(x: x, y: y, predecessor: &predecessor))
            }
            
            $1 = count 
        }
        
        let frequencies:(dc:[Int], ac:[Int]) =
        (
            JPEG.Bitstream.Symbol.DC.frequencies(of: \.0.decomposed.symbol, 
                in: composites),
            JPEG.Bitstream.Symbol.AC.frequencies(of: \.decomposed.symbol, 
                in: composites.flatMap(\.1))
        )
        
        let table:(dc:JPEG.Table.HuffmanDC, ac:JPEG.Table.HuffmanAC) =
        (
            .init(frequencies: frequencies.dc, target: component.selector.dc),
            .init(frequencies: frequencies.ac, target: component.selector.ac) 
        )
        let encoder:(dc:JPEG.Table.HuffmanDC.Encoder, ac:JPEG.Table.HuffmanAC.Encoder) = 
        (
            table.dc.encoder(),
            table.ac.encoder()
        )
        
        var bits:JPEG.Bitstream                     = []
        for (composite, ac):(JPEG.Bitstream.Composite.DC, [JPEG.Bitstream.Composite.AC]) in 
            composites 
        {
            bits.append(composite: composite, table: encoder.dc)
            for composite:JPEG.Bitstream.Composite.AC in ac 
            {
                bits.append(composite: composite, table: encoder.ac)
            }
        }
        return (bits.bytes(escaping: 0xff, with: (0xff, 0x00)), table.dc, table.ac)
    }
    
    // progressive
    func encode(bits a:PartialRangeFrom<Int>, component:JPEG.Scan.Component) 
        -> ([UInt8], JPEG.Table.HuffmanDC)
    {
        let count:Int = self.units.x * self.units.y
        let composites:[JPEG.Bitstream.Composite.DC] = 
            .init(unsafeUninitializedCapacity: count) 
        {
            var predecessor:Int16 = 0
            for (x, y):(Int, Int) in (0, 0) ..< self.units
            {
                let high:Int16              = self[x: x, y: y, z: 0] >> a.lowerBound
                $0[y * self.units.x + x]    = .init(difference: high &- predecessor)
                predecessor                 = high 
            }
            
            $1 = count 
        }
        
        let frequencies:[Int]                       = 
            JPEG.Bitstream.Symbol.DC.frequencies(of: \.decomposed.symbol, in: composites)
        
        let table:JPEG.Table.HuffmanDC              = 
            .init(frequencies: frequencies, target: component.selector.dc)  
        let encoder:JPEG.Table.HuffmanDC.Encoder    = table.encoder()
        
        var bits:JPEG.Bitstream                     = []
        for composite:JPEG.Bitstream.Composite.DC in composites 
        {
            bits.append(composite: composite, table: encoder)
        }
        return (bits.bytes(escaping: 0xff, with: (0xff, 0x00)), table)
    }
    
    func encode(bit a:Int) 
        ->  [UInt8]
    {
        var bits:JPEG.Bitstream = []
        for y:Int in 0 ..< self.units.y
        {
            for x:Int in 0 ..< self.units.x 
            {
                bits.append(bit: self[x: x, y: y, z: 0] >> a & 1)
            }
        }
        return bits.bytes(escaping: 0xff, with: (0xff, 0x00))
    } 
    
    func encode(band:Range<Int>, bits a:PartialRangeFrom<Int>, component:JPEG.Scan.Component) 
        -> ([UInt8], JPEG.Table.HuffmanAC)
    {
        assert(band.lowerBound >   0)
        assert(band.upperBound <= 64)
         
        var composites:[JPEG.Bitstream.Composite.AC] = []
        for y:Int in 0 ..< self.units.y
        {
            for x:Int in 0 ..< self.units.x 
            {
                var zeroes = 0
                for z:Int in band
                {
                    let coefficient:Int16 = self[x: x, y: y, z: z]
                    // TODO: overflow probably possible here
                    let sign:Int16 = coefficient < 0 ? -1 : 1
                    let high:Int16 = sign * abs(coefficient) >> a.lowerBound 
                    
                    if high == 0 
                    {
                        if zeroes == 15 
                        {
                            composites.append(.run(zeroes, value: 0))
                            zeroes  = 0 
                        }
                        else 
                        {
                            zeroes += 1 
                        }
                    }
                    else 
                    {
                        composites.append(.run(zeroes, value: high))
                        zeroes      = 0
                    }
                }
                
                if zeroes > 0 
                {
                    composites.append(.eob(1))
                }
            }
        }
        
        let frequencies:[Int]                       = 
            JPEG.Bitstream.Symbol.AC.frequencies(of: \.decomposed.symbol, in: composites)
        
        let table:JPEG.Table.HuffmanAC              = 
            .init(frequencies: frequencies, target: component.selector.ac)
        let encoder:JPEG.Table.HuffmanAC.Encoder    = table.encoder()
        
        var bits:JPEG.Bitstream                     = []
        for composite:JPEG.Bitstream.Composite.AC in composites 
        {
            bits.append(composite: composite, table: encoder)
        }
        
        return (bits.bytes(escaping: 0xff, with: (0xff, 0x00)), table)
    }
    
    func encode(band:Range<Int>, bit a:Int, component:JPEG.Scan.Component) 
        -> ([UInt8], JPEG.Table.HuffmanAC)
    {
        assert(band.lowerBound >   0)
        assert(band.upperBound <= 64)
        
        var pairs:[(JPEG.Bitstream.Composite.AC, [Bool])] = []
        for y:Int in 0 ..< self.units.y
        {
            for x:Int in 0 ..< self.units.x 
            {
                var zeroes              = 0
                var refinements:[Bool]  = []
                for z:Int in band
                {
                    let coefficient:Int16 = self[x: x, y: y, z: z]
                    
                    // TODO: overflow probably possible here
                    let sign:Int16 = coefficient < 0 ? -1 : 1
                    let high:Int16 = sign *         abs(coefficient) >> (a + 1) 
                    let low:Int16  = (coefficient - high << (a + 1)) >>  a
                    
                    if high == 0 
                    {
                        if low == 0 
                        {
                            if zeroes == 15 
                            {
                                pairs.append((.run(zeroes, value: 0), refinements))
                                refinements = []
                                zeroes      = 0
                            }
                            else 
                            {
                                zeroes     += 1
                            }
                        }
                        else 
                        {
                            pairs.append((.run(zeroes, value: low), refinements))
                            refinements     = []
                            zeroes          = 0
                        } 
                    }
                    else 
                    {
                        refinements.append(low != 0)
                    }
                }
                
                if zeroes > 0 || !refinements.isEmpty 
                {
                    pairs.append((.eob(1), refinements))
                }
            }
        }
        
        let frequencies:[Int]                       = 
            JPEG.Bitstream.Symbol.AC.frequencies(of: \.0.decomposed.symbol, in: pairs)
        
        let table:JPEG.Table.HuffmanAC              = 
            .init(frequencies: frequencies, target: component.selector.ac)
        let encoder:JPEG.Table.HuffmanAC.Encoder    = table.encoder()
        
        var bits:JPEG.Bitstream                     = []
        for (composite, refinements):(JPEG.Bitstream.Composite.AC, [Bool]) in pairs 
        {
            bits.append(composite: composite, table: encoder)
            for refinement:Bool in refinements 
            {
                bits.append(bit: refinement ? 1 : 0)
            }
        }
        return (bits.bytes(escaping: 0xff, with: (0xff, 0x00)), table)
    }
}
extension JPEG.Data.Spectral 
{
    // sequential mode 
    private 
    func encode(components:[(c:Int, component:JPEG.Scan.Component)]) 
        -> ([UInt8], [JPEG.Table.HuffmanDC], [JPEG.Table.HuffmanAC])
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
                fatalError("scan component not a member of this spectral image")
            }
            
            let (bytes, dc, ac):([UInt8], JPEG.Table.HuffmanDC, JPEG.Table.HuffmanAC) = 
                self[p].encode(component: component)
            return (bytes, [dc], [ac])
        }
        
        let factors:[(x:Int, y:Int)] = components.map 
        {
            guard self.indices ~= $0.c
            else 
            {
                // unlike in the decoder, we don’t have a good reason to allow scans to 
                // reference components which have not been included in the spectral image, 
                // so every component must be linked to an existing plane index (non-optional `p`)
                fatalError("scan component not a member of this spectral image")
            }
            return self.layout.planes[$0.c].component.factor
        }
        
        let stride:Int = factors.reduce(0){ $0 + $1.x * $1.y } 
        // some components may specify the same table selectors, which means 
        // those components are sharing the same huffman table.
        var globals:
        (
            dc:[JPEG.Table.HuffmanDC.Selector: [Int]], 
            ac:[JPEG.Table.HuffmanAC.Selector: [Int]]
        ) = 
        ([:], [:])
        
        let count:Int  = self.blocks.x * self.blocks.y * stride
        let composites:[(JPEG.Bitstream.Composite.DC, [JPEG.Bitstream.Composite.AC])] = 
            .init(unsafeUninitializedCapacity: count)
        {
            var offset:Int = 0
            for ((p, component), factor):((Int, JPEG.Scan.Component), (x:Int, y:Int)) in 
                zip(components, factors) 
            {
                // to avoid doing tons of dictionary lookups, maintain a local 
                // frequency count, and then merge it into the dictionary one 
                var frequencies:(dc:[Int], ac:[Int])    = 
                (
                    .init(repeating: 0, count: 256),
                    .init(repeating: 0, count: 256)
                )
                var predecessor:Int16 = 0
                for (mx, my):(Int, Int) in (0, 0) ..< self.blocks 
                {
                    let start:(x:Int, y:Int) = (     mx * factor.x,      my * factor.y), 
                        end:(x:Int, y:Int)   = (start.x + factor.x, start.y + factor.y) 
                    for (i, (x, y)):(Int, (x:Int, y:Int)) in (start ..< end).enumerated() 
                    {
                        let composite:JPEG.Bitstream.Composite.DC, 
                            ac:[JPEG.Bitstream.Composite.AC]
                        
                        (composite, ac) = self[p].encode(x: x, y: y, predecessor: &predecessor)
                        
                        frequencies.dc[.init(composite.decomposed.symbol.value)] += 1
                        for composite:JPEG.Bitstream.Composite.AC in ac 
                        {
                            frequencies.ac[.init(composite.decomposed.symbol.value)] += 1
                        }
                        
                        let index:Int = (my * self.blocks.x + mx) * stride + offset + i
                        // can use `!` here because this loop never runs unless 
                        // `self.blocks` and at least one of the `factor`s is nonzero
                        ($0.baseAddress! + index).initialize(to: (composite, ac))
                    }
                }
                
                // merge frequency counts 
                if let global:[Int] = globals.dc[component.selector.dc] 
                {
                    globals.dc[component.selector.dc] = zip(global, frequencies.dc).map
                    { 
                        $0.0 + $0.1 
                    }
                }
                else 
                {
                    globals.dc[component.selector.dc] = frequencies.dc
                }
                if let global:[Int] = globals.ac[component.selector.ac] 
                {
                    globals.ac[component.selector.ac] = zip(global, frequencies.ac).map
                    { 
                        $0.0 + $0.1 
                    }
                }
                else 
                {
                    globals.ac[component.selector.ac] = frequencies.ac
                }
                
                offset += factor.x * factor.y
            } 
            
            $1 = count 
        }
        
        // construct tables 
        let tables:(dc:[JPEG.Table.HuffmanDC], ac:[JPEG.Table.HuffmanAC]) = 
        (
            globals.dc.map{ .init(frequencies: $0.value, target: $0.key) },
            globals.ac.map{ .init(frequencies: $0.value, target: $0.key) }
        )
        
        typealias Descriptor = 
            (offset:Int, volume:Int, table:
            (
                dc:JPEG.Table.HuffmanDC.Encoder,
                ac:JPEG.Table.HuffmanAC.Encoder
            ))
        let dc:[JPEG.Table.HuffmanDC.Selector: JPEG.Table.HuffmanDC.Encoder] = 
            .init(uniqueKeysWithValues: tables.dc.map 
        {
            ($0.target, $0.encoder())
        })
        let ac:[JPEG.Table.HuffmanAC.Selector: JPEG.Table.HuffmanAC.Encoder] = 
            .init(uniqueKeysWithValues: tables.ac.map 
        {
            ($0.target, $0.encoder())
        })
        var offset:Int                  = 0
        var descriptors:[Descriptor]    = [] 
            descriptors.reserveCapacity(components.count)
        for ((_, component), factor):((Int, JPEG.Scan.Component), (x:Int, y:Int)) in 
            zip(components, factors) 
        {
            let volume:Int = factor.x * factor.y
            descriptors.append((
                    offset: offset, 
                    volume: volume, // `!` is unreachable
                    table: (dc[component.selector.dc]!, ac[component.selector.ac]!)
                ))
            offset += volume
        }
        
        var bits:JPEG.Bitstream = []
        for base:Int in 
            Swift.stride(from: composites.startIndex, to: composites.endIndex, by: stride)
        {
            for descriptor:Descriptor in descriptors 
            {
                let start:Int = base  + descriptor.offset, 
                    end:Int   = start + descriptor.volume
                for (composite, ac):(JPEG.Bitstream.Composite.DC, [JPEG.Bitstream.Composite.AC]) in 
                    composites[start ..< end]
                {
                    bits.append(composite: composite, table: descriptor.table.dc)
                    for composite:JPEG.Bitstream.Composite.AC in ac 
                    {
                        bits.append(composite: composite, table: descriptor.table.ac)
                    }
                }
            }
        }
        
        return (bits.bytes(escaping: 0xff, with: (0xff, 0x00)), tables.dc, tables.ac)
    }
    // progressive mode 
    private 
    func encode(bits a:PartialRangeFrom<Int>, 
        components:[(c:Int, component:JPEG.Scan.Component)]) 
        -> ([UInt8], [JPEG.Table.HuffmanDC])
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
                fatalError("scan component not a member of this spectral image")
            }
            let (bytes, table):([UInt8], JPEG.Table.HuffmanDC) = 
                self[p].encode(bits: a, component: component)
            return (bytes, [table])
        }
        
        let factors:[(x:Int, y:Int)] = components.map 
        {
            guard self.indices ~= $0.c
            else 
            {
                fatalError("scan component not a member of this spectral image")
            }
            return self.layout.planes[$0.c].component.factor
        }

        let stride:Int = factors.reduce(0){ $0 + $1.x * $1.y } 
        // some components may specify the same table selectors, which means 
        // those components are sharing the same huffman table.
        var globals:[JPEG.Table.HuffmanDC.Selector: [Int]] = [:]
        
        let count:Int  = self.blocks.x * self.blocks.y * stride
        let composites:[JPEG.Bitstream.Composite.DC] = 
            .init(unsafeUninitializedCapacity: count)
        {
            var offset:Int = 0
            for ((p, component), factor):((Int, JPEG.Scan.Component), (x:Int, y:Int)) in 
                zip(components, factors) 
            {
                var frequencies:[Int]   = .init(repeating: 0, count: 256)
                var predecessor:Int16   = 0
                for (mx, my):(Int, Int) in (0, 0) ..< self.blocks 
                {
                    let start:(x:Int, y:Int) = (     mx * factor.x,      my * factor.y), 
                        end:(x:Int, y:Int)   = (start.x + factor.x, start.y + factor.y) 
                    for (i, (x, y)):(Int, (x:Int, y:Int)) in (start ..< end).enumerated() 
                    {
                        let high:Int16  = self[p][x: x, y: y, z: 0] >> a.lowerBound
                        let composite:JPEG.Bitstream.Composite.DC   = 
                            .init(difference: high &- predecessor)
                        predecessor                                 = high 
                        
                        frequencies[.init(composite.decomposed.symbol.value)] += 1
                        let index:Int = (my * self.blocks.x + mx) * stride + offset + i
                        $0[index]     = composite 
                    }
                }
                
                // merge frequency counts 
                if let global:[Int] = globals[component.selector.dc] 
                {
                    globals[component.selector.dc] = zip(global, frequencies).map
                    { 
                        $0.0 + $0.1 
                    }
                }
                else 
                {
                    globals[component.selector.dc] = frequencies
                }
                
                offset += factor.x * factor.y
            } 
            
            $1 = count 
        }
        
        // construct tables 
        let tables:[JPEG.Table.HuffmanDC] = globals.map 
        {
            .init(frequencies: $0.value, target: $0.key)
        }
        
        typealias Descriptor = (offset:Int, volume:Int, table:JPEG.Table.HuffmanDC.Encoder)
        let encoders:[JPEG.Table.HuffmanDC.Selector: JPEG.Table.HuffmanDC.Encoder] = 
            .init(uniqueKeysWithValues: tables.map 
        {
            ($0.target, $0.encoder())
        })
        var offset:Int                  = 0
        var descriptors:[Descriptor]    = []
            descriptors.reserveCapacity(components.count)
        for ((_, component), factor):((Int, JPEG.Scan.Component), (x:Int, y:Int)) in 
            zip(components, factors) 
        {
            let volume:Int = factor.x * factor.y
            descriptors.append((
                    offset: offset, 
                    volume: volume, // `!` is unreachable
                    table: encoders[component.selector.dc]!
                ))
            offset += volume
        }
        
        var bits:JPEG.Bitstream = []
        for base:Int in 
            Swift.stride(from: composites.startIndex, to: composites.endIndex, by: stride)
        {
            for descriptor:Descriptor in descriptors 
            {
                let start:Int = base  + descriptor.offset, 
                    end:Int   = start + descriptor.volume
                for composite:JPEG.Bitstream.Composite.DC in composites[start ..< end]
                {
                    bits.append(composite: composite, table: descriptor.table)
                }
            }
        }
        
        return (bits.bytes(escaping: 0xff, with: (0xff, 0x00)), tables)
    } 
    
    private 
    func encode(bit a:Int, components:[(c:Int, component:JPEG.Scan.Component)]) 
        ->  [UInt8]
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
                fatalError("scan component not a member of this spectral image")
            }
            
            return self[p].encode(bit: a)
        }
        
        typealias Descriptor = (p:Int, factor:(x:Int, y:Int)) 
        let descriptors:[Descriptor] = components.map 
        {
            guard self.indices ~= $0.c
            else 
            {
                fatalError("scan component not a member of this spectral image")
            }
            
            return ($0.c, self.layout.planes[$0.c].component.factor)
        }
        
        var bits:JPEG.Bitstream = []
        for (mx, my):(Int, Int) in (0, 0) ..< self.blocks 
        {
            for (p, factor):Descriptor in descriptors 
            {
                let start:(x:Int, y:Int) = (     mx * factor.x,      my * factor.y), 
                    end:(x:Int, y:Int)   = (start.x + factor.x, start.y + factor.y) 
                for (x, y):(x:Int, y:Int) in start ..< end
                {
                    bits.append(bit: self[p][x: x, y: y, z: 0] >> a & 1)
                }
            }
        }
        return bits.bytes(escaping: 0xff, with: (0xff, 0x00))
    } 
    
    public 
    func encode(scan:JPEG.Scan) 
        -> 
        (
            dc:[JPEG.Table.HuffmanDC], 
            ac:[JPEG.Table.HuffmanAC],
            header:JPEG.Header.Scan, 
            ecs:[UInt8]
        )
    {
        // “unresolve” the component keys 
        let header:JPEG.Header.Scan = 
            .init(band: scan.band, bits: scan.bits, components: 
                scan.components.map(\.component))
        
        switch (initial: scan.bits.upperBound == .max, band: scan.band)
        {
        case (initial: true,  band: 0 ..< 64):
            // sequential mode jpeg
            let (data, dc, ac):([UInt8], [JPEG.Table.HuffmanDC], [JPEG.Table.HuffmanAC]) = 
                self.encode(components: scan.components) 
            return (dc, ac, header, data)
        
        case (initial: false, band: 0 ..< 64):
            fatalError("unreachable")
        
        case (initial: true,  band: 0 ..<  1):
            let (data, dc):([UInt8], [JPEG.Table.HuffmanDC]) = 
                self.encode(bits: scan.bits.lowerBound..., components: scan.components) 
            return (dc, [], header, data)
        
        case (initial: false, band: 0 ..<  1):
            let data:[UInt8] = 
                self.encode(bit: scan.bits.lowerBound, components: scan.components)
            return ([], [], header, data)
        
        case (initial: true,  band: let band):
            precondition(scan.components.count == 1, "progressive ac scan cannot be interleaved")
            let (p, component):(Int, JPEG.Scan.Component) = scan.components[0]
            guard self.indices ~= p
            else 
            {
                fatalError("scan component not a member of this spectral image") 
            }
            
            let (data, ac):([UInt8], JPEG.Table.HuffmanAC) = self[p].encode(
                band: band, bits: scan.bits.lowerBound..., component: component)
            return ([], [ac], header, data)
        
        case (initial: false, band: let band):
            precondition(scan.components.count == 1, "progressive ac scan cannot be interleaved")
            let (p, component):(Int, JPEG.Scan.Component) = scan.components[0]
            guard self.indices ~= p
            else 
            {
                fatalError("scan component not a member of this spectral image") 
            }
            
            let (data, ac):([UInt8], JPEG.Table.HuffmanAC) = self[p].encode(
                band: band, bit: scan.bits.lowerBound, component: component)
            return ([], [ac], header, data)
        }
    }
}

// serializers (opposite of parsers)
extension JPEG.JFIF.Version 
{
    var serialized:(UInt8, UInt8) 
    {
        switch self 
        {
        case .v1_0:
            return (1, 0)
        case .v1_1:
            return (1, 1)
        case .v1_2:
            return (1, 2)
        }
    }
}
extension JPEG.JFIF.Unit 
{
    var serialized:UInt8 
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
extension JPEG.JFIF 
{
    public 
    func serialized() -> [UInt8] 
    {
        var bytes:[UInt8] = Self.signature 
        bytes.append(self.version.serialized.0)
        bytes.append(self.version.serialized.1)
        bytes.append(self.density.unit.serialized)
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
extension JPEG.Table.Huffman 
{
    // bytes 1 ..< 17 + count (does not include selector byte)
    func serialized() -> [UInt8]
    {
        return self.symbols.map{ .init($0.count) } + self.symbols.flatMap{ $0.map(\.value) }
    }
}
extension JPEG.Table.Quantization 
{
    // bytes 1 ..< 1 + 64 * stride (does not include selector byte)
    func serialized() -> [UInt8]
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
    func serialize(_ dc:[HuffmanDC], _ ac:[HuffmanAC]) -> [UInt8]
    {
        var bytes:[UInt8] = []
        for table:HuffmanDC in dc 
        {
            bytes.append(0x00 | HuffmanDC.serialize(selector: table.target))
            bytes.append(contentsOf: table.serialized())
        }
        for table:HuffmanAC in ac 
        {
            bytes.append(0x10 | HuffmanAC.serialize(selector: table.target))
            bytes.append(contentsOf: table.serialized())
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
                bytes.append(contentsOf: table.serialized())
            case .uint16:
                bytes.append(0x10 | Quantization.serialize(selector: table.target))
                bytes.append(contentsOf: table.serialized())
            }
        }
        
        return bytes 
    }
}

extension JPEG.Header.Frame 
{
    public 
    func serialized() -> [UInt8]
    {
        var bytes:[UInt8] = [.init(self.precision)]
        bytes.append(contentsOf: [UInt8].store(self.size.y, asBigEndian: UInt16.self))
        bytes.append(contentsOf: [UInt8].store(self.size.x, asBigEndian: UInt16.self))
        bytes.append(.init(self.components.count))
        
        // must be sorted, as ordering in scan header must match ordering in frame header
        for (ci, component):(JPEG.Component.Key, JPEG.Component) in 
            self.components.sorted(by: { $0.key < $1.key })
        {
            bytes.append(.init(ci.value))
            bytes.append(.init(component.factor.x) << 4 | .init(component.factor.y))
            bytes.append(JPEG.Table.Quantization.serialize(selector: component.selector))
        }
        
        return bytes
    }
}
extension JPEG.Header.Scan 
{
    public 
    func serialized() -> [UInt8] 
    {
        var bytes:[UInt8] = [.init(self.components.count)]
        for component:JPEG.Scan.Component in self.components 
        {
            let dc:UInt8 = JPEG.Table.HuffmanDC.serialize(selector: component.selector.dc),
                ac:UInt8 = JPEG.Table.HuffmanAC.serialize(selector: component.selector.ac)
            bytes.append(.init(component.ci.value))
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
    func format(marker:JPEG.Marker) throws 
    {
        guard let _:Void    = self.write([0xff, marker.code])
        else 
        {
            throw JPEG.FormattingError.invalidDestination 
        }
    }
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

// staged APIs
extension JPEG.Data.Spectral 
{
    public 
    func compress<Destination>(stream:inout Destination) throws 
        where Destination:JPEG.Bytestream.Destination
    {
        try stream.format(marker: .start)
        for metadata:JPEG.Metadata in self.metadata 
        {
            switch metadata 
            {
            case .jfif(let jfif):
                try stream.format(marker: .application(0), tail: jfif.serialized())
            case .unknown(application: let a, let serialized):
                try stream.format(marker: .application(a), tail: serialized)
            }
        }
        
        let frame:JPEG.Header.Frame = self.encode() 
        try stream.format(marker: .frame(frame.process), tail: frame.serialized())
        for (qi, scans):([JPEG.Table.Quantization.Key], [JPEG.Scan]) in 
            self.layout.definitions 
        {
            let quanta:[JPEG.Table.Quantization] = qi.compactMap
            { 
                self.quanta.index(forKey: $0).map{ self.quanta[$0] }
            }
            
            if !quanta.isEmpty
            {
                try stream.format(marker: .quantization, tail: JPEG.Table.serialize(quanta))
            }
            
            for scan:JPEG.Scan in scans 
            {
                let dc:[JPEG.Table.HuffmanDC],
                    ac:[JPEG.Table.HuffmanAC],
                    header:JPEG.Header.Scan, 
                    ecs:[UInt8]
                
                (dc, ac, header, ecs) = self.encode(scan: scan)
                
                if !dc.isEmpty || !ac.isEmpty 
                {
                    try stream.format(marker: .huffman, tail: JPEG.Table.serialize(dc, ac))
                }
                
                try stream.format(marker: .scan, tail: header.serialized())
                try stream.format(prefix: ecs)
            }
        }
        
        try stream.format(marker: .end)
    }
}
