import JPEG

let path:String = "examples/recompress/original.jpg"
guard let original:JPEG.Data.Spectral<JPEG.Common> = try .decompress(path: path)
else 
{
    fatalError("failed to open file '\(path)'")
}

let format:JPEG.Common              = .ycc8
let Y:JPEG.Component.Key            = format.components[0],
    Cb:JPEG.Component.Key           = format.components[1],
    Cr:JPEG.Component.Key           = format.components[2]

let layout:JPEG.Layout<JPEG.Common> = .init(
    format:     format,
    process:    .progressive(coding: .huffman, differential: false), 
    components: original.layout.components, 
    scans: 
    [
        .progressive((Y,  \.0), (Cb, \.1), (Cr, \.1),  bits: 0...),
        
        .progressive((Y,  \.0),        band: 1 ..< 64, bits: 0...), 
        .progressive((Cb, \.0),        band: 1 ..< 64, bits: 0...), 
        .progressive((Cr, \.0),        band: 1 ..< 64, bits: 0...)
    ])

var recompressed:JPEG.Data.Spectral<JPEG.Common> = .init(
    size:       original.size, 
    layout:     layout, 
    metadata:   
    [
        .jfif(.init(version: .v1_2, density: (1, 1, .centimeters))),
    ], 
    quanta: original.quanta.mapValues
    {
        [$0[0]] + $0.dropFirst().map{ min($0 * 3 as UInt16, 255) }
    })

for ci:JPEG.Component.Key in recompressed.layout.recognized 
{
    original.read(ci: ci)
    {
        (plane:JPEG.Data.Spectral<JPEG.Common>.Plane, quanta:JPEG.Table.Quantization) in 
        
        recompressed.with(ci: ci) 
        {
            for b:((x:Int, y:Int), (x:Int, y:Int)) in zip(plane.indices, $0.indices)
            {
                for z:Int in 0 ..< 64 
                {
                    let coefficient:Int16 = .init(quanta[z: z]) * plane[x: b.0.x, y: b.0.y, z: z]
                    let rescaled:Double   = .init(coefficient) / .init($1[z: z])
                    $0[x: b.1.x, y: b.1.y, z: z] = .init(rescaled + (0.3 * (rescaled < 0 ? -1 : 1)))
                }
            }
        }
    }
} 
    
try recompressed.compress(path: "examples/recompress/recompressed-requantized.jpg")
