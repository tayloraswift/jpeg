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
            throw JPEG.Parse.Error.unexpected(.markerSegment(marker.type), expected: .markerSegment(.start))
        }
        
        // jfif header (must immediately follow start of image)
        marker = try stream.segment()
        guard case .application(0) = marker.type 
        else 
        {
            throw JPEG.Parse.Error.unexpected(.markerSegment(marker.type), expected: .markerSegment(.application(0)))
        }
        guard let image:JPEG.JFIF = try .parse(marker.data) 
        else 
        {
            throw JPEG.Parse.Error.invalid(.markerSegment(.application(0)))
        }
        
        print(image)
        
        
        let frame:JPEG.Frame = try
        {
            marker = try stream.segment()
            while true 
            {
                print(marker.type)
                switch marker.type 
                {
                case .frame(.unsupported(let code)):
                    throw JPEG.Parse.Error.unsupported("jpeg encoding mode \(code)")
                
                case .frame(let mode):
                    let frame:JPEG.Frame = try .parse(marker.data, mode: mode)
                    marker               = try stream.segment() 
                    return frame
                
                case .quantization:
                    break 
                case .huffman:
                    break
                
                case .comment, .application:
                    break 
                
                case .scan, .height, .restart, .end:
                    throw JPEG.Parse.Error.premature(marker.type)
                
                case .start:
                    throw JPEG.Parse.Error.duplicate(marker.type)
                }
                
                marker = try stream.segment() 
            }
        }()
        
        print(frame)
        
        scans:
        while true 
        {
            print(marker.type)
            switch marker.type 
            {
            case .start, .frame:
                throw JPEG.Parse.Error.duplicate(marker.type)
            
            case .quantization:
                break 
            case .huffman:
                let tables:[JPEG.HuffmanTable] = try JPEG.HuffmanTable.parse(marker.data)
                print("[")
                for table:JPEG.HuffmanTable in tables 
                {
                    print(table.description.split(separator: "\n", omittingEmptySubsequences: false).map{ "    \($0)" }.joined(separator: "\n"))
                }
                print("]")
            
            case .comment, .application:
                break 
            
            case .scan:
                let scan:JPEG.Scan = try .parse(marker.data, frame: frame)
                let ecs:[UInt8] 
                (ecs, marker) = try stream.segment(prefix: true)
                print(scan)
                print("ecs(\(ecs.count))")
                continue scans
            
            case .height, .restart:
                break // TODO: enforce ordering
            case .end:
                break scans 
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
        let atoms:[UInt16]
        var byte:Int    = 0, 
            bit:UInt8   = 0
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
    
    enum Lex
    {
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
        
        enum Error:Swift.Error 
        {
            case unexpected(Lexeme, expected:Lexeme)
            case invalid(Lexeme)
        }
    }
    enum Parse 
    {
        enum Entity  
        {
            case signature([UInt8])
            
            case component(Int)
            
            case markerSegment(Marker) 
            case markerSegmentLength(Int)
        }
        
        enum Error:Swift.Error 
        {
            case missing(Entity)
            case duplicate(Marker)
            case premature(Marker)
            
            case unexpected(Entity, expected:Entity)
            case invalid(Entity)
            
            case unsupported(String)
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
                throw JPEG.Lex.Error.unexpected(.eos, expected: .markerSegmentLength)
            }
            let length:Int = header.load(bigEndian: UInt16.self, as: Int.self, at: 0)
            
            guard length >= 2
            else 
            {
                throw JPEG.Lex.Error.invalid(.markerSegmentLength)
            }
            guard let data:[UInt8] = self.read(count: length - 2)
            else 
            {
                throw JPEG.Lex.Error.unexpected(.eos, expected: .markerSegmentBody)
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
                throw JPEG.Lex.Error.unexpected(.byte($0), expected: .markerSegmentPrefix)
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
                    throw JPEG.Lex.Error.unexpected(.eos, expected: .markerSegmentType)
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
                throw JPEG.Lex.Error.unexpected(.byte(byte), expected: .markerSegmentType)
            }
                
            let data:[UInt8] = try self.tail(type: marker)
            return (ecs, (marker, data))
        }
        
        throw JPEG.Lex.Error.unexpected(.eos, expected: .entropyCodedSegment)
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
                throw JPEG.Parse.Error.invalid(.markerSegmentLength(data.count))
            }
            
            // look for 'JFIF' signature
            guard data[0 ..< 5] == [0x4a, 0x46, 0x49, 0x46, 0x00]
            else 
            {
                throw JPEG.Parse.Error.invalid(.signature(.init(data[0 ..< 5])))
            }

            let version:(major:Int, minor:Int)
            version.major = .init(data[5])
            version.minor = .init(data[6])

            guard   1 ... 1 ~= version.major, 
                    0 ... 2 ~= version.minor
            else
            {
                // bad JFIF version number (expected 1.0 ... 1.2)
                throw JPEG.Parse.Error.invalid(.markerSegment(.application(0)))
            }

            guard let unit:DensityUnit = DensityUnit.init(code: data[7])
            else
            {
                // invalid JFIF density unit
                throw JPEG.Parse.Error.invalid(.markerSegment(.application(0)))
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
            let selector:Int 
        }

        let mode:Mode,
            precision:Int

        private(set) // DNL segment may change this later on
        var size:(x:Int, y:Int)

        let components:[Int: Component]

        static
        func parse(_ data:[UInt8], mode:JPEG.Mode) throws -> Self
        {
            guard data.count >= 6
            else
            {
                throw JPEG.Parse.Error.invalid(.markerSegmentLength(data.count))
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
                throw JPEG.Parse.Error.invalid(.markerSegment(.frame(mode)))
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
                throw JPEG.Parse.Error.invalid(.markerSegment(.frame(mode)))
            }

            guard data.count == 3 * count + 6
            else
            {
                // wrong segment size
                throw JPEG.Parse.Error.unexpected(.markerSegmentLength(data.count), 
                    expected: .markerSegmentLength(3 * count + 6))
            }

            var components:[Int: Component] = [:]
            for i:Int in 0 ..< count
            {
                let base:Int = 3 * i + 6
                let byte:(UInt8, UInt8, UInt8) = (data[base], data[base + 1], data[base + 2])
                
                let factor:(x:Int, y:Int)  = (.init(byte.1 >> 4), .init(byte.1 & 0x0f))
                let ci:Int                  = .init(byte.0), 
                    selector:Int            = .init(byte.2)
                
                guard   1 ... 4 ~= factor.x,
                        1 ... 4 ~= factor.y,
                        0 ... 3 ~= selector
                else
                {
                    throw JPEG.Parse.Error.invalid(.markerSegment(.frame(mode)))
                }
                
                let component:Component = .init(factor: factor, selector: selector)
                // make sure no duplicate component indices are used 
                guard components.updateValue(component, forKey: ci) == nil 
                else 
                {
                    throw JPEG.Parse.Error.invalid(.markerSegment(.frame(mode)))
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
                throw JPEG.Parse.Error.unexpected(.markerSegmentLength(data.count), 
                    expected: .markerSegmentLength(2))
            }

            self.size.y = data.load(bigEndian: UInt16.self, as: Int.self, at: 0)
        }
    }
    
    struct Scan
    {
        struct Component 
        {
            let ci:Int, 
                selector:(dc:Int, ac:Int)
        }
        
        let band:Range<Int>, 
            bits:Range<Int>, 
            components:[Component] 
        
        static 
        func parse(_ data:[UInt8], frame:JPEG.Frame) throws -> Self
        {
            guard data.count >= 4 
            else 
            {
                throw JPEG.Parse.Error.invalid(.markerSegmentLength(data.count))
            }
            
            let count:Int = .init(data[0])
            guard 1 ... 4 ~= count
            else 
            {
                throw JPEG.Parse.Error.invalid(.markerSegment(.scan))
            } 
            
            guard data.count == 2 * count + 4
            else 
            {
                // wrong segment size
                throw JPEG.Parse.Error.unexpected(.markerSegmentLength(data.count), 
                    expected: .markerSegmentLength(2 * count + 4))
            }
            
            let components:[Component] = try (0 ..< count).map 
            {
                let base:Int            = 2 * $0 + 1
                let byte:(UInt8, UInt8) = (data[base], data[base + 1])
                
                let ci:Int = .init(byte.0)
                let selector:(dc:Int, ac:Int) = 
                (
                    dc: .init(byte.1 >> 4), 
                    ac: .init(byte.1 & 0xf)
                )
                
                switch (frame.mode, selector.dc, selector.ac) 
                {
                case    (.baselineDCT,      0 ... 1, 0 ... 1), 
                        (.extendedDCT,      0 ... 3, 0 ... 3), 
                        (.progressiveDCT,   0 ... 3, 0 ... 3):
                    break 
                
                default:
                    throw JPEG.Parse.Error.invalid(.markerSegment(.scan))
                }
                
                return .init(ci: ci, selector: selector)
            }
            
            // validate sampling factor sum 
            let sampling:Int = try components.map 
            {
                guard let component:Frame.Component = frame.components[$0.ci]
                else 
                {
                    throw JPEG.Parse.Error.missing(.component($0.ci))
                }
                
                return component.factor.x * component.factor.y
            }.reduce(0, +)
            
            guard 0 ... 10 ~= sampling 
            else 
            {
                throw JPEG.Parse.Error.invalid(.markerSegment(.scan))
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
                    bits.0 <= bits.1, 
                    band == (0, 0) || count == 1 // only DC scans can contain multiple components 
            else 
            {
                throw JPEG.Parse.Error.invalid(.markerSegment(.scan))
            }
            
            switch (frame.mode, band.0, band.1, bits.0, bits.1) 
            {
            case    (.baselineDCT,      0,        63,                0,                     frame.precision), 
                    (.extendedDCT,      0,        63,                0,                     frame.precision),
                    (.progressiveDCT,   0,        0,                 0 ..< frame.precision, bits.0 + 1 ... frame.precision),
                    (.progressiveDCT,   1 ..< 64, band.0 + 1 ..< 64, 0 ..< frame.precision, bits.0 + 1 ... frame.precision):
                break 
            
            default:
                throw JPEG.Parse.Error.invalid(.markerSegment(.scan))
            }
            
            return .init(band: band.0 ..< band.1 + 1, bits: bits.0 ..< bits.1, components: components)
        }
    }
    
    struct HuffmanTable 
    {
        typealias Entry = (value:UInt8, length:UInt8)
        
        let storage:[Entry], 
            n:Int, // number of level 0 entries
            ζ:Int  // logical size of the table (where the n level 0 entries are each 256 units big)
        
        static 
        func parse(_ data:[UInt8]) throws -> [Self] 
        {
            var tables:[Self] = []
            
            var base:Int = 0
            while (base < data.count)
            {
                guard base + 17 < data.count
                else
                {
                    // data buffer does not contain enough data
                    throw JPEG.Parse.Error.invalid(.markerSegmentLength(data.count))
                }
                
                // huffman tables have variable length that can only be determined
                // by examining the first 17 bytes of each table which means checks
                // have to be done midway through the parsing
                let leaf:(counts:[Int], values:[UInt8])
                leaf.counts = data[base + 1 ..< base + 17].map(Int.init(_:))
                
                // count the number of expected leaves 
                let count:Int = leaf.counts.reduce(0, +)
                guard base + 17 + count <= data.count 
                else 
                {
                    throw JPEG.Parse.Error.invalid(.markerSegmentLength(data.count))
                }
                
                leaf.values = .init(data[base + 17 ..< base + 17 + count])
                
                let destination:WritableKeyPath<(dc:(Self, Self, Self, Self), ac:(Self, Self, Self, Self)), Self>
                switch data[base] 
                {
                case 0x00:
                    destination = \.dc.0
                
                case 0x01:
                    destination = \.dc.1

                case 0x02:
                    destination = \.dc.2

                case 0x03:
                    destination = \.dc.3
                
                case 0x10:
                    destination = \.ac.0
                
                case 0x11:
                    destination = \.ac.1

                case 0x12:
                    destination = \.ac.2

                case 0x13:
                    destination = \.ac.3

                default:
                    // huffman table has invalid binding index
                    throw JPEG.Parse.Error.invalid(.markerSegment(.huffman))
                }
                
                guard let table:Self = .build(counts: leaf.counts, values: leaf.values)
                else 
                {
                    throw JPEG.Parse.Error.invalid(.markerSegment(.huffman))
                }
                
                tables.append(table)
                
                base += 17 + count
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
    func build(counts:[Int], values:[UInt8]) -> Self?
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
        
        return .init(storage: storage, n: n, ζ: z + n * 255)
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
    }
    
    var front:UInt16?
    {
        // can optimize with two shifts and &>> ?
        let atom:UInt16 = self.atoms[self.byte] << self.bit | self.atoms[self.byte + 1] >> (16 - self.bit)
        
        // entropy coded segments may not have a whole number of bytes, so they 
        // get padded with 1 bits. so the only way to know when the stream really 
        // ends is to wait for a `0xffff` word to appear
        guard atom != 0xffff 
        else 
        {
            return nil
        }
        
        return atom
    }
    
    mutating 
    func pop(_ bits:UInt8)
    {
        self.bit += bits 
        if self.bit > 15 
        {
            self.bit  &= 0x0f
            self.byte += 1
        }
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
