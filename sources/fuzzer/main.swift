import JPEG 

func fuzz(z:Int, n:Int, path:String) throws
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
        let u:Int = 127 / n
        for (x, y):(Int, Int) in $0.indices
        {
            for z:Int in z ..< z + n 
            {
                $0[x: x, y: y, z: z & 63] = u
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

for n:Int in 1 ... 1
{
    for z:Int in 0 ..< 64 
    {
        let path:String = "\(z)-\(n).jpg"
        try fuzz(z: z, n: 1, path: path)
        
        guard let rectangular:JPEG.Data.Rectangular<JPEG.RGB<UInt8>> = 
            try .decompress(path: path)
        else
        {
            fatalError("failed to open file '\(path)'")
        }
        
        print(path)
        let image:[JPEG.RGB<UInt8>] = rectangular.pixels()
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
}
