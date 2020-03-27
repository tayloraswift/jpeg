import JPEG 

func fuzz() throws
{
    let format:JPEG.JFIF.Format                 = .ycc8
    let Y:JPEG.Frame.Component.Index            = format.components[0],
        Cb:JPEG.Frame.Component.Index           = format.components[1],
        Cr:JPEG.Frame.Component.Index           = format.components[2]
    
    let frame:JPEG.Frame                        = 
        format.frame(process:   .progressive(coding: .huffman, differential: false), 
        size:      (12, 6), 
        selectors: [Y: \.0, Cb: \.0, Cr: \.0])
        
    let quantization:JPEG.Table.Quantization    = 
        .init(precision: .uint8, values: .init(repeating: 1, count: 64), target: \.0)
    
    var spectral:JPEG.Data.Spectral<JPEG.JFIF.Format> = 
        .init(frame: frame, format: format)
    
    spectral.with(ci: Y)
    {
        for (x, y):(Int, Int) in $0.indices
        {
            $0[x: x, y: y, z: 0] = 50 
            $0[x: x, y: y, z: 2] = 255 
            $0[x: x, y: y, z: 7] = 50 
        }
    }
    spectral.with(ci: Cb)
    {
        for (x, y):(Int, Int) in $0.indices
        {
            $0[x: x, y: y, z: 0] = 255 
        }
    }
    spectral.with(ci: Cr)
    {
        for (x, y):(Int, Int) in $0.indices
        {
            $0[x: x, y: y, z: 0] = 128 
        }
    }
    
    let scans:[JPEG.Scan] = 
    [
        frame.progressive([(Y, \.0), (Cb, \.1), (Cr, \.1)], bits: 2...),
        frame.progressive([Y, Cb, Cr],                      bit:  1   ),
        frame.progressive([Y, Cb, Cr],                      bit:  0   ),
        
        frame.progressive((Y,  \.0),        band: 1 ..< 64, bits: 1...), 
        
        frame.progressive((Cb, \.0),        band: 1 ..<  6, bits: 1...), 
        frame.progressive((Cr, \.0),        band: 1 ..<  6, bits: 1...), 
        
        frame.progressive((Cb, \.0),        band: 6 ..< 64, bits: 1...), 
        frame.progressive((Cr, \.0),        band: 6 ..< 64, bits: 1...), 
        
        frame.progressive((Y,  \.0),        band: 1 ..< 64, bit:  0   ), 
        frame.progressive((Cb, \.0),        band: 1 ..< 64, bit:  0   ), 
        frame.progressive((Cr, \.0),        band: 1 ..< 64, bit:  0   ), 
    ]
    
    guard let _:Void = (try Common.File.Destination.open(path: "test") 
    {
        (stream:inout Common.File.Destination) in 
        
        try stream.format(marker: .start)
        
        let jfif:JPEG.JFIF = .init(version: .v1_2, density: (1, 1, .dpcm))
        try stream.format(marker: .application(0), tail: jfif.serialize())
        
        try stream.format(marker: .quantization, tail: JPEG.Table.serialize([quantization]))
        
        print(frame)
        try stream.format(marker: .frame(frame.process), tail: frame.serialize())
        
        for scan:JPEG.Scan in scans
        {
            print(scan)
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
        fatalError("failed to open file")
    }
}

try fuzz()
/* var heap:Common.Heap<Int, Void> = 
[
    (  3, ()), 
    (  2, ()), 
    (  6, ()), 
    (  9, ()), 
    (  0, ()), 
    ( -1, ()), 
    ( 45, ()), 
    (  0, ()), 
    ( 61, ()), 
    (-55, ()), 
    ( 34, ()), 
    ( 35, ()), 
]
for v:Int in [-66, 4, -11, 60, 135, -9]
{
    heap.enqueue(key: v, value: ())
}

while let (v, _):(Int, Void) = heap.dequeue()
{
    print(v)
}  */

/* var frequencies:[Int] = .init(repeatElement(1, count: 256))
frequencies[16] = 5
frequencies[17] = 3
frequencies[18] = 10
frequencies[19] = 200
frequencies[20] = 2
frequencies[21] = 60

let table:JPEG.Table.HuffmanDC = .init(frequencies: frequencies, target: \.0) */
