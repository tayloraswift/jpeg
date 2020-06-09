import JPEG

let path:String          = "examples/encode-basic/karlie-milan-sp12-2011", 
    size:(x:Int, y:Int)  = (400, 665)
guard let rgb:[JPEG.RGB] = (System.File.Source.open(path: "\(path).rgb")
{
    guard let data:[UInt8] = $0.read(count: 3 * size.x * size.y)
    else 
    {
        fatalError("failed to read from file '\(path).rgb'")
    }
    
    return (0 ..< size.x * size.y).map 
    {
        (i:Int) -> JPEG.RGB in
        .init(data[3 * i], data[3 * i + 1], data[3 * i + 2])
    }
}) 
else
{
    fatalError("failed to open file '\(path).rgb'")
}

for factor:(luminance:(x:Int, y:Int), chrominance:(x:Int, y:Int), name:String) in 
[
    ((1, 1), (1, 1), "4:4:4"),
    ((1, 2), (1, 1), "4:4:0"),
    ((2, 1), (1, 1), "4:2:2"),
    ((2, 2), (1, 1), "4:2:0"),
]
{
    let layout:JPEG.Layout<JPEG.Common> = .init(
        format:     .ycc8,
        process:    .baseline, 
        components: 
        [
            1: (factor: factor.luminance,   qi: 0 as JPEG.Table.Quantization.Key), 
            2: (factor: factor.chrominance, qi: 1 as JPEG.Table.Quantization.Key), 
            3: (factor: factor.chrominance, qi: 1 as JPEG.Table.Quantization.Key),
        ], 
        scans: 
        [
            .sequential((1, \.0, \.0)),
            .sequential((2, \.1, \.1), (3, \.1, \.1))
        ])
    let jfif:JPEG.JFIF = .init(version: .v1_2, density: (1, 1, .centimeters))
    let image:JPEG.Data.Rectangular<JPEG.Common> = 
        .pack(size: size, layout: layout, metadata: [.jfif(jfif)], pixels: rgb)
    
    for level:Double in [0.0, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0] 
    {
        try image.compress(path: "\(path)-\(factor.name)-\(level).jpg", quanta: 
        [
            0: JPEG.CompressionLevel.luminance(  level).quanta,
            1: JPEG.CompressionLevel.chrominance(level).quanta
        ])
    }
}
