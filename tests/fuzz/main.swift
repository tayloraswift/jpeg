import JPEG 

func fuzz<RNG>(rng:inout RNG, path:String) throws where RNG:RandomNumberGenerator
{
    let format:JPEG.Common              = .ycc8
    let Y:JPEG.Component.Key            = format.components[0],
        Cb:JPEG.Component.Key           = format.components[1],
        Cr:JPEG.Component.Key           = format.components[2]
    
    let layout:JPEG.Layout<JPEG.Common> = .init(
        format:     format,
        process:    .progressive(coding: .huffman, differential: false), 
        components: 
        [
            Y:  (factor: (1, 1), qi: 0), 
            Cb: (factor: (1, 1), qi: 1), 
            Cr: (factor: (1, 1), qi: 1),
        ], 
        scans: 
        [
            .progressive((Y,  \.0), (Cb, \.1), (Cr, \.1),  bits: 2...),
            .progressive( Y,         Cb,        Cr      ,  bit:  1   ),
            .progressive( Y,         Cb,        Cr      ,  bit:  0   ),
            
            .progressive((Y,  \.0),        band: 1 ..< 64, bits: 1...), 
            
            .progressive((Cb, \.0),        band: 1 ..<  6, bits: 1...), 
            .progressive((Cr, \.0),        band: 1 ..<  6, bits: 1...), 
            
            .progressive((Cb, \.0),        band: 6 ..< 64, bits: 1...), 
            .progressive((Cr, \.0),        band: 6 ..< 64, bits: 1...), 
            
            .progressive((Y,  \.0),        band: 1 ..< 64, bit:  0   ), 
            .progressive((Cb, \.0),        band: 1 ..< 64, bit:  0   ), 
            .progressive((Cr, \.0),        band: 1 ..< 64, bit:  0   ), 
        ])

    let quanta:([UInt16], [UInt16]) = 
    (
        .init(repeating: 1, count: 64),
        .init(repeating: 1, count: 64)
    )
    
    var planar:JPEG.Data.Planar<JPEG.Common> = .init(
        size:       (8, 8), 
        layout:     layout, 
        metadata:   
        [
            .jfif(.init(version: .v1_2, density: (1, 1, .centimeters))),
        ])
    
    let colors:[JPEG.YCbCr] = ((0 as UInt8) ..< (8 * 8 as UInt8)).map 
    {
        let rgb:JPEG.RGB = .init(
            UInt8.random(in: 5 ... 250), 
            128 + ($0      & 0x38) - 32,
            128 + ($0 << 3 & 0x38) - 32)
        return rgb.ycc 
    }
    planar.with(ci: Y)
    {
        for (x, y):(Int, Int) in $0.indices
        {
            $0[x: x, y: y] = .init(colors[8 * y + x].y)
        }
    }
    planar.with(ci: Cb)
    {
        for (x, y):(Int, Int) in $0.indices
        {
            $0[x: x, y: y] = .init(colors[8 * y + x].cb)
        }
    }
    planar.with(ci: Cr)
    {
        for (x, y):(Int, Int) in $0.indices
        {
            $0[x: x, y: y] = .init(colors[8 * y + x].cr)
        }
    }
    
    let spectral:JPEG.Data.Spectral<JPEG.Common> = planar.fdct(quanta:     
        [
            0: quanta.0,
            1: quanta.1,
        ])
    
    guard let _:Void = try spectral.compress(path: path)
    else 
    {
        fatalError("failed to open file '\(path)'")
    } 
}

func print(histogram:[Int], width:Int) 
{
    // print histogram 
    let max:Int = histogram.max() ?? 1
    for (y, count):(Int, Int) in zip(histogram.indices, histogram)
    {
        let value:UInt8                 = .init(y), 
            rgb:(UInt8, UInt8, UInt8)   = (value, value, value)
        let left:String     = Highlight.highlight(" y = \(String.pad("\(y)", left: 3)) ", rgb)
        let label:String    = .pad("\(count)", left: 5)
        let right:String    = .init(repeating: "█", count: width * count / max)
        
        print("\(left) \(label) \(right)")
    }
}

func generate(count:Int, prefix:String) throws
{
    var rng:SystemRandomNumberGenerator = .init()
    var histogram:[Int]                 = .init(repeating: 0, count: 256)
    for i:Int in 0 ..< count 
    {
        let path:String = "\(prefix)/\(i).jpg"
        try fuzz(rng: &rng, path: path)
        
        guard let rectangular:JPEG.Data.Rectangular<JPEG.Common> = 
            try .decompress(path: path)
        else
        {
            fatalError("failed to open file '\(path)'")
        }
        
        // merge into histogram 
        let ycc:[JPEG.YCbCr] = rectangular.unpack(as: JPEG.YCbCr.self)
        for pixel:JPEG.YCbCr in ycc 
        {
            histogram[.init(pixel.y)] += 1
        }
        
        // terminal output 
        print(path)
        let image:[JPEG.RGB] = rectangular.unpack(as: JPEG.RGB.self)
        for i:Int in 0 ..< rectangular.size.y 
        {
            let line:String = (0 ..< rectangular.size.x).map 
            {
                (j:Int) in 
                
                let c:JPEG.RGB = image[j + i * rectangular.size.x]
                return Highlight.square((c.r, c.g, c.b))
            }.joined(separator: "")
            print(line)
        } 
    }
    print(histogram: histogram, width: 80)
}

enum Parameter:String 
{
    case count
    case path 
}

var parameter:Parameter?    = nil 
var count:Int               = 16 
var prefix:String           = "tests/fuzz/data/jpeg"
for argument:String in CommandLine.arguments.dropFirst()
{
    if argument.prefix(2) == "--"
    {
        guard let p:Parameter = Parameter.init(rawValue: .init(argument.dropFirst(2)))
        else 
        {
            fatalError("unrecognized parameter '\(argument)'")
        }
        
        parameter = p 
    }
    else 
    {
        switch parameter 
        {
        case nil:
            fatalError("no parameter name given before argument value '\(argument)'")
        
        case .count?:
            guard let n:Int = Int.init(argument) 
            else 
            {
                fatalError("could not convert argument '\(argument)' to Int")
            }
            count   = n
        
        case .path:
            prefix  = argument 
        }
    }
}

try generate(count: count, prefix: prefix)
