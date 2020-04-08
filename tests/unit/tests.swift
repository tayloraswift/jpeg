@testable import JPEG 

extension JPEG.Bitstream.Symbol.DC:ExpressibleByIntegerLiteral
{
    public 
    init(integerLiteral:UInt8) 
    {
        self.init(integerLiteral)
    }
}
extension JPEG.Bitstream.Symbol.AC:ExpressibleByIntegerLiteral
{
    public 
    init(integerLiteral:UInt8) 
    {
        self.init(integerLiteral)
    }
}

extension Test 
{
    static 
    var cases:[(name:String, function:Function)] 
    {
        [
            ("zigzag-ordering",                 .void(Self.zigzagOrdering)),
            ("amplitude-coding-asymmetric",     .void(Self.amplitudeCoding)),
            ("amplitude-coding-symmetric",      .void(Self.amplitudeCodingSymmetric)),
            ("huffman-table-building",          .void(Self.huffmanBuilding)),
            ("huffman-table-coding-asymmetric", .void(Self.huffmanCoding)),
            ("huffman-table-coding-symmetric",  .int (Self.huffmanCodingSymmetric(_:), [16, 256, 4096, 65536])),
        ]
    }
    
    static 
    func zigzagOrdering() -> Result<Void, Failure> 
    {
        let indices:[[Int]] = 
        [
            [ 0,  1,  5,  6, 14, 15, 27, 28],
            [ 2,  4,  7, 13, 16, 26, 29, 42],
            [ 3,  8, 12, 17, 25, 30, 41, 43],
            [ 9, 11, 18, 24, 31, 40, 44, 53],
            [10, 19, 23, 32, 39, 45, 52, 54], 
            [20, 22, 33, 38, 46, 51, 55, 60], 
            [21, 34, 37, 47, 50, 56, 59, 61], 
            [35, 36, 48, 49, 57, 58, 62, 63]
        ]
        for (y, row):(Int, [Int]) in indices.enumerated() 
        {
            for (x, expected):(Int, Int) in row.enumerated() 
            {
                let z:Int = JPEG.Table.Quantization.z(k: x, h: y)
                guard z == expected 
                else 
                {
                    return .failure(.init(message: 
                        "zig-zag transform mapped index (\(x), \(y)) to zig-zag index \(z) (expected \(expected))"))
                }
            }
        }
        
        return .success(())
    }
    
    // tests a few “known” cases in one direction 
    static 
    func amplitudeCoding() -> Result<Void, Failure> 
    {
        for (binade, tail, expected):(Int, UInt16, Int32) in 
        [
            (1,      0,         -1),
            (1,      1,          1), 
            
            (2,      0,         -3), 
            (2,      1,         -2), 
            (2,      2,          2), 
            (2,      3,          3),
            
            (5,      0,        -31), 
            (5,      1,        -30), 
            (5,     14,        -17), 
            (5,     15,        -16), 
            (5,     16,         16), 
            (5,     17,         17), 
            (5,     30,         30), 
            (5,     31,         31), 
            
            (11,     0,      -2047), 
            (11,     1,      -2046), 
            (11,  1023,      -1024), 
            (11,  1024,       1024), 
            (11,  2046,       2046), 
            (11,  2047,       2047), 
            
            (15,     0,     -32767), 
            (15,     1,     -32766), 
            (15, 16383,     -16384), 
            (15, 16384,      16384), 
            (15, 32766,      32766), 
            (15, 32767,      32767), 
        ]
        {
            let result:Int32 = JPEG.Bitstream.extend(binade: binade, tail, as: Int32.self)
            guard result == expected 
            else 
            {
                return .failure(.init(message: 
                    "amplitude decoder mapped composite bits {\(binade); \(tail)} incorrectly (expected \(expected), got \(result))"))
            }
        }
        
        return .success(())
    }
    
    // exhaustively tests reversibility of extend and compact
    static 
    func amplitudeCodingSymmetric() -> Result<Void, Failure> 
    {
        // JPEG.Bitstream.extend(binade:_:as:) not defined for x = 0
        // JPEG.Bitstream.compact(_:) not defined for x = Int16.min 
        for x:Int32 in -1 << 15 + 1 ..< 1 >> 15 where x != 0
        {
            let (binade, tail):(Int, UInt16) = JPEG.Bitstream.compact(x)
            let xp:Int32 = JPEG.Bitstream.extend(binade: binade, tail, as: Int32.self)
            
            guard x == xp 
            else 
            {
                return .failure(.init(message: 
                    "amplitude coder failed to round-trip value {\(x)} -> {\(binade); \(tail)} -> {\(xp)}"))
            }
        }
        
        return .success(())
    }
    
    // tries to construct the example AC huffman table from the JPEG standard annex, 
    // and decode individual codewords 
    static 
    func huffmanBuilding() -> Result<Void, Failure>
    {
        let counts:[Int] = 
        [
            0x00, 0x02, 0x01, 0x03,
            0x03, 0x02, 0x04, 0x03,
            0x05, 0x05, 0x04, 0x04,
            0x00, 0x00, 0x01, 0x7D,
        ]
        let values:[UInt8] = 
        [
            0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07,
            0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0,
            0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28,
            0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
            0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
            0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
            0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
            0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5,
            0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2,
            0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8,
            0xF9, 0xFA
        ]
        
        guard let table:JPEG.Table.HuffmanAC = 
            JPEG.Table.HuffmanAC.init(counts: counts, values: values, target: \.0)
        else 
        {
            return .failure(.init(message: "failed to initialize huffman table"))
        }
        
        let decoder:JPEG.Table.HuffmanAC.Decoder = table.decoder()
        var expected:UInt8 = 0
        for (length, codeword):(Int, UInt16) in 
        [
            (4,     0b1010), 
            (2,     0b00), 
            (2,     0b01), 
            (3,     0b100), 
            (4,     0b1011), 
            (5,     0b11010), 
            (7,     0b1111000), 
            (8,     0b11111000), 
            (10,    0b1111110110), 
            (16,    0b1111111110000010), 
            (16,    0b1111111110000011), 
            (4,     0b1100), 
            (5,     0b11011), 
            (7,     0b1111001), 
            (9,     0b111110110), 
            (11,    0b11111110110), 
            (16,    0b1111111110000100), 
            (16,    0b1111111110000101), 
            (16,    0b1111111110000110), 
            (16,    0b1111111110000111), 
            (16,    0b1111111110001000), 
            (5,     0b11100), 
            (8,     0b11111001), 
            (10,    0b1111110111), 
            (12,    0b111111110100), 
            (16,    0b1111111110001001), 
            (16,    0b1111111110001010), 
            (16,    0b1111111110001011), 
            (16,    0b1111111110001100), 
            (16,    0b1111111110001101), 
            (16,    0b1111111110001110), 
            (6,     0b111010), 
            (9,     0b111110111), 
            (12,    0b111111110101), 
            (16,    0b1111111110001111), 
            (16,    0b1111111110010000), 
            (16,    0b1111111110010001), 
            (16,    0b1111111110010010), 
            (16,    0b1111111110010011), 
            (16,    0b1111111110010100), 
            (16,    0b1111111110010101), 
            (6,     0b111011), 
            (10,    0b1111111000), 
            (16,    0b1111111110010110), 
            (16,    0b1111111110010111), 
            (16,    0b1111111110011000), 
            (16,    0b1111111110011001), 
            (16,    0b1111111110011010), 
            (16,    0b1111111110011011), 
            (16,    0b1111111110011100), 
            (16,    0b1111111110011101), 
            (7,     0b1111010), 
            (11,    0b11111110111), 
            (16,    0b1111111110011110), 
            (16,    0b1111111110011111), 
            (16,    0b1111111110100000), 
            (16,    0b1111111110100001), 
            (16,    0b1111111110100010), 
            (16,    0b1111111110100011), 
            (16,    0b1111111110100100), 
            (16,    0b1111111110100101), 
            (7,     0b1111011), 
            (12,    0b111111110110), 
            (16,    0b1111111110100110), 
            (16,    0b1111111110100111), 
            (16,    0b1111111110101000), 
            (16,    0b1111111110101001), 
            (16,    0b1111111110101010), 
            (16,    0b1111111110101011), 
            (16,    0b1111111110101100), 
            (16,    0b1111111110101101), 
            (8,     0b11111010), 
            (12,    0b111111110111), 
            (16,    0b1111111110101110), 
            (16,    0b1111111110101111), 
            (16,    0b1111111110110000), 
            (16,    0b1111111110110001), 
            (16,    0b1111111110110010), 
            (16,    0b1111111110110011), 
            (16,    0b1111111110110100), 
            (16,    0b1111111110110101), 
            (9,     0b111111000), 
            (15,    0b111111111000000), 
            (16,    0b1111111110110110), 
            (16,    0b1111111110110111), 
            (16,    0b1111111110111000), 
            (16,    0b1111111110111001), 
            (16,    0b1111111110111010), 
            (16,    0b1111111110111011), 
            (16,    0b1111111110111100), 
            (16,    0b1111111110111101), 
            (9,     0b111111001), 
            (16,    0b1111111110111110), 
            (16,    0b1111111110111111), 
            (16,    0b1111111111000000), 
            (16,    0b1111111111000001), 
            (16,    0b1111111111000010), 
            (16,    0b1111111111000011), 
            (16,    0b1111111111000100), 
            (16,    0b1111111111000101), 
            (16,    0b1111111111000110), 
            (9,     0b111111010), 
            (16,    0b1111111111000111), 
            (16,    0b1111111111001000), 
            (16,    0b1111111111001001), 
            (16,    0b1111111111001010), 
            (16,    0b1111111111001011), 
            (16,    0b1111111111001100), 
            (16,    0b1111111111001101), 
            (16,    0b1111111111001110), 
            (16,    0b1111111111001111), 
            (10,    0b1111111001), 
            (16,    0b1111111111010000), 
            (16,    0b1111111111010001), 
            (16,    0b1111111111010010), 
            (16,    0b1111111111010011), 
            (16,    0b1111111111010100), 
            (16,    0b1111111111010101), 
            (16,    0b1111111111010110), 
            (16,    0b1111111111010111), 
            (16,    0b1111111111011000), 
            (10,    0b1111111010), 
            (16,    0b1111111111011001), 
            (16,    0b1111111111011010), 
            (16,    0b1111111111011011), 
            (16,    0b1111111111011100), 
            (16,    0b1111111111011101), 
            (16,    0b1111111111011110), 
            (16,    0b1111111111011111), 
            (16,    0b1111111111100000), 
            (16,    0b1111111111100001), 
            (11,    0b11111111000), 
            (16,    0b1111111111100010), 
            (16,    0b1111111111100011), 
            (16,    0b1111111111100100), 
            (16,    0b1111111111100101), 
            (16,    0b1111111111100110), 
            (16,    0b1111111111100111), 
            (16,    0b1111111111101000), 
            (16,    0b1111111111101001), 
            (16,    0b1111111111101010), 
            (16,    0b1111111111101011), 
            (16,    0b1111111111101100), 
            (16,    0b1111111111101101), 
            (16,    0b1111111111101110), 
            (16,    0b1111111111101111), 
            (16,    0b1111111111110000), 
            (16,    0b1111111111110001), 
            (16,    0b1111111111110010), 
            (16,    0b1111111111110011), 
            (16,    0b1111111111110100), 
            (11,    0b11111111001), 
            (16,    0b1111111111110101), 
            (16,    0b1111111111110110), 
            (16,    0b1111111111110111), 
            (16,    0b1111111111111000), 
            (16,    0b1111111111111001), 
            (16,    0b1111111111111010), 
            (16,    0b1111111111111011), 
            (16,    0b1111111111111100), 
            (16,    0b1111111111111101), 
            (16,    0b1111111111111110)
        ]
        {
            let entry:JPEG.Table.HuffmanAC.Decoder.Entry = decoder[codeword << (16 - length)]
            
            guard   entry.symbol.value == expected, 
                    entry.length == length
            else 
            {
                return .failure(.init(message: 
                    "codeword decoded incorrectly (\(entry.symbol.value), expected \(expected))"))
            }
            
            if expected & 0x0f < 0x0a 
            {
                expected =  expected & 0xf0          | (expected & 0x0f &+ 1)
            }
            else 
            {
                expected = (expected & 0xf0 &+ 0x10) | (expected & 0xf0 == 0xe0 ? 0 : 1)
            }
        }
        
        return .success(())
    }
    
    // tries to decode bitstreams into byte arrays using simple known huffman trees
    static 
    func huffmanCoding() -> Result<Void, Failure>
    {
        let trees:[[[JPEG.Bitstream.Symbol.DC]]] =
        [
            // 4-height single-layered tree
            //
            // 00   -> 0x61
            // 01   -> 0x62
            // 10   -> 0x63
            // 110  -> 0x64
            // 1110 -> 0x65
            [
                [    ], 
                [0x61, 0x62, 0x63],
                [0x64],
                [0x65],
                
                [    ], [    ], [    ], [    ],
                [    ], [    ], [    ], [    ],
                [    ], [    ], [    ], [    ],
            ],
            // 16-height degenerate, double-layered tree 
            //
            // 0                   -> 0x61
            // 10                  -> 0x62
            // 110                 -> 0x63
            // 1110                -> 0x64
            // 11110               -> 0x65
            // ...
            // 1111_1111_1111_1110 -> 0x70
            [
                [0x61], [0x62], [0x63], [0x64],
                [0x65], [0x66], [0x67], [0x68],
                [0x69], [0x6a], [0x6b], [0x6c],
                [0x6d], [0x6e], [0x6f], [0x70],
            ],
            // 4-height degenerate, single-layered tree 
            //
            // 0                   -> 0x61
            // 10                  -> 0x62
            // 110                 -> 0x63
            // 1110                -> 0x64
            [
                [0x61], [0x62], [0x63], [0x64],
                [    ], [    ], [    ], [    ],
                [    ], [    ], [    ], [    ],
                [    ], [    ], [    ], [    ],
            ],
        ]
        let pairs:[(encoded:JPEG.Bitstream, decoded:[UInt8])] = 
        [
            (
                [0b110_1110__0,0b0_01____10____110 ], 
                [0x64, 0x65, 0x61, 0x62, 0x63, 0x64]
            ),
            (
                [0b11111111,0b110_0_____1111,0b11111111,0b1110_1110], 
                [0x6b,            0x61, 0x70,                  0x64]
            ),
            (
                // test codewords that do not correspond to encoded symbols
                // (decoder should return a null byte rather than crashing, and 
                // skip 16 bits)
                [0b11110110,0b11111110, 0b10__10____1110, 0b11111111,0b11111110], 
                [0x00,                  0x62, 0x62, 0x64, 0x00]
            ),
        ]
        for (symbols, (encoded, expected)):
            ([[JPEG.Bitstream.Symbol.DC]], (JPEG.Bitstream, [UInt8])) in zip(trees, pairs)
        {
            guard let table:JPEG.Table.HuffmanDC = 
                JPEG.Table.HuffmanDC.init(symbols, target: \.0)
            else 
            {
                return .failure(.init(message: "failed to initialize huffman table"))
            }
            
            let decoder:JPEG.Table.HuffmanDC.Decoder    = table.decoder()
            var decoded:[UInt8]                         = []
            var b:Int                                   = 0
            while b < encoded.count 
            {
                let entry:JPEG.Table.HuffmanDC.Decoder.Entry = decoder[encoded[b, count: 16]]
                decoded.append(entry.symbol.value)
                b += entry.length
            }
            
            guard decoded == expected 
            else 
            {
                return .failure(.init(message: 
                    "message decoded incorrectly (expected \(expected), got \(decoded))"))
            }
        }
        
        return .success(())
    }
    
    static 
    func huffmanCodingSymmetric(_ count:Int) -> Result<Void, Failure>
    {
        let symbols:[JPEG.Bitstream.Symbol.AC] = (0 ..< count).map 
        {
            _ in
            // biases the distribution so that values around 128 are more common 
            .init(UInt8.random(in: 0 ..< 128) + UInt8.random(in: 0 ... 128))
        }
        
        let frequencies:[Int] = JPEG.Bitstream.Symbol.AC.frequencies(of: \.self, in: symbols)
        let table:JPEG.Table.HuffmanAC = .init(frequencies: frequencies, target: \.0)
        let encoder:JPEG.Table.HuffmanAC.Encoder = table.encoder()
        
        var bits:JPEG.Bitstream = []
        for symbol:JPEG.Bitstream.Symbol.AC in symbols 
        {
            let codeword:JPEG.Table.HuffmanAC.Encoder.Codeword = encoder[symbol]
            bits.append(codeword.bits, count: codeword.length)
        }
        
        let decoder:JPEG.Table.HuffmanAC.Decoder = table.decoder()
        
        var b:Int = 0
        var decoded:[JPEG.Bitstream.Symbol.AC] = []
        while b < bits.count 
        {
            let entry:JPEG.Table.Huffman.Decoder.Entry = decoder[bits[b, count: 16]]
            decoded.append(entry.symbol)
            b += entry.length 
        }
        
        guard symbols == decoded 
        else 
        {
            return .failure(.init(message: 
                "huffman coder failed to round-trip symbolic sequence (\(symbols.count) symbols)"))
        }
        
        return .success(())
    }
}
