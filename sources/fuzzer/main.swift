import JPEG 

func fuzz<RNG>(rng:inout RNG, path:String) throws where RNG:RandomNumberGenerator
{
    let jfif:JPEG.JFIF = .init(version: .v1_2, density: (1, 1, .dpcm))
    
    let format:JPEG.JFIF.Format                 = .ycc8
    let Y:JPEG.Frame.Component.Index            = format.components[0],
        Cb:JPEG.Frame.Component.Index           = format.components[1],
        Cr:JPEG.Frame.Component.Index           = format.components[2]
    
    let frame:JPEG.Frame                        = 
        format.frame(process:   .progressive(coding: .huffman, differential: false), 
        size:      (8, 8), 
        selectors: [Y: \.0, Cb: \.0, Cr: \.0])
        
    let quantization:JPEG.Table.Quantization    = 
        .init(precision: .uint8, values: .init(repeating: 1, count: 64), target: \.0)
    
    var spectral:JPEG.Data.Spectral<JPEG.JFIF.Format> = 
        .init(frame: frame, format: format)
    
    spectral.with(ci: Y)
    {
        for (x, y):(Int, Int) in $0.indices
        {
            for z:Int in 0 ..< 64
            {
                $0[x: x, y: y, z: z] = Int32.random(in: -75 ..< 75)
            }
        }
    }
    spectral.with(ci: Cb)
    {
        for (x, y):(Int, Int) in $0.indices
        {
            $0[x: x, y: y, z: 1] = 180
        }
    }
    spectral.with(ci: Cr)
    {
        for (x, y):(Int, Int) in $0.indices
        {
            $0[x: x, y: y, z: 2] = 180
        }
    }
    
    let scans:[JPEG.Scan] = 
    [
        frame.progressive([(Y, \.0), (Cb, \.1), (Cr, \.1)], bits: 2...),
        frame.progressive([ Y,        Cb,        Cr      ], bit:  1   ),
        frame.progressive([ Y,        Cb,        Cr      ], bit:  0   ),
        
        frame.progressive((Y,  \.0),        band: 1 ..< 64, bits: 1...), 
        
        frame.progressive((Cb, \.0),        band: 1 ..<  6, bits: 1...), 
        frame.progressive((Cr, \.0),        band: 1 ..<  6, bits: 1...), 
        
        frame.progressive((Cb, \.0),        band: 6 ..< 64, bits: 1...), 
        frame.progressive((Cr, \.0),        band: 6 ..< 64, bits: 1...), 
        
        frame.progressive((Y,  \.0),        band: 1 ..< 64, bit:  0   ), 
        frame.progressive((Cb, \.0),        band: 1 ..< 64, bit:  0   ), 
        frame.progressive((Cr, \.0),        band: 1 ..< 64, bit:  0   ), 
    ]
    
    guard let _:Void = (try Common.File.Destination.open(path: path) 
    {
        (stream:inout Common.File.Destination) in 
        
        try stream.format(marker: .start)
        try stream.format(marker: .application(0), tail: jfif.serialize())
        try stream.format(marker: .quantization,   tail: JPEG.Table.serialize([quantization]))
        
        try stream.format(marker: .frame(frame.process), tail: frame.serialize())
        
        for scan:JPEG.Scan in scans
        {
            let (ecs, dc, ac):([UInt8], [JPEG.Table.HuffmanDC], [JPEG.Table.HuffmanAC]) = 
                spectral.encode(scan: scan)
            try stream.format(marker: .huffman, tail: JPEG.Table.serialize(dc, ac))
            try stream.format(marker: .scan,    tail: scan.serialize())
            try stream.format(prefix: ecs)
        }
        
        try stream.format(marker: .end)
    })
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
        
        guard let rectangular:JPEG.Data.Rectangular<JPEG.JFIF.Format> = 
            try .decompress(path: path)
        else
        {
            fatalError("failed to open file '\(path)'")
        }
        
        // merge into histogram 
        let ycc:[JPEG.YCbCr<UInt8>] = rectangular.pixels(as: JPEG.YCbCr<UInt8>.self)
        for pixel:JPEG.YCbCr<UInt8> in ycc 
        {
            histogram[.init(pixel.y)] += 1
        }
        
        // terminal output 
        print(path)
        let image:[JPEG.RGB<UInt8>] = rectangular.pixels(as: JPEG.RGB<UInt8>.self)
        for i:Int in 0 ..< rectangular.size.y 
        {
            let line:String = (0 ..< rectangular.size.x).map 
            {
                (j:Int) in 
                
                let c:JPEG.RGB<UInt8> = image[j + i * rectangular.size.x]
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
var prefix:String           = "tests/fuzz/jpeg"
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
