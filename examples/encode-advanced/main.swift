import JPEG

let path:String          = "examples/encode-advanced/karlie-cfdas-2011.png.rgb",
    size:(x:Int, y:Int)  = (600, 900)
guard let rgb:[JPEG.RGB] = (System.File.Source.open(path: path)
{
    guard let data:[UInt8] = $0.read(count: 3 * size.x * size.y)
    else 
    {
        fatalError("failed to read from file '\(path)'")
    }

    return (0 ..< size.x * size.y).map 
    {
        (i:Int) -> JPEG.RGB in
        .init(data[3 * i], data[3 * i + 1], data[3 * i + 2])
    }
}) 
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
    components: 
    [
        Y:  (factor: (2, 1), qi: 0), // 4:2:2 subsampling
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

for (tables, scans):([JPEG.Table.Quantization.Key], [JPEG.Scan]) in layout.definitions 
{
    print("""
    define quantization tables: 
    [
        \(tables.map(String.init(describing:)).joined(separator: "\n    "))
    ]
    """)
    print("""
    scans: \(scans.count) scans 
    """)
}

for (c, (component, qi)):(Int, (component:JPEG.Component, qi:JPEG.Table.Quantization.Key)) in layout.planes.enumerated() 
{
    print("""
    plane \(c)
    {
        sampling factor         : (\(component.factor.x), \(component.factor.y))
        quantization table      : \(qi)
        quantization selector   : \\.\(String.init(selector: component.selector))
    }
    """)
}

let comment:[UInt8] = .init("the way u say ‘important’ is important".utf8)
let rectangular:JPEG.Data.Rectangular<JPEG.Common>  = 
    .pack(size: size, layout: layout, metadata: [.comment(data: comment)], pixels: rgb)

let planar:JPEG.Data.Planar<JPEG.Common>            = rectangular.decomposed()
let spectral:JPEG.Data.Spectral<JPEG.Common>        = planar.fdct(quanta:     
    [
        0: [1, 2, 2, 3, 3, 3] + .init(repeating:  4, count: 58),
        1: [1, 2, 2, 5, 5, 5] + .init(repeating: 30, count: 58),
    ])

guard let _:Void = try spectral.compress(path: "\(path).jpg")
else 
{
    fatalError("failed to open file '\(path).jpg'")
}
