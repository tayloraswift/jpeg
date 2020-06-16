import JPEG 

extension JPEG 
{
    enum Deep 
    {
        case rgba12
    }
    
    struct RGB12 
    {
        var r:UInt16
        var g:UInt16
        var b:UInt16
        
        init(_ r:UInt16, _ g:UInt16, _ b:UInt16)
        {
            self.r = r
            self.g = g
            self.b = b
        }
    }
    
    struct RGBA12 
    {
        var r:UInt16
        var g:UInt16
        var b:UInt16
        var a:UInt16
        
        init(_ r:UInt16, _ g:UInt16, _ b:UInt16, _ a:UInt16)
        {
            self.r = r
            self.g = g
            self.b = b
            self.a = a
        }
    }
}

extension JPEG.Deep:JPEG.Format 
{
    static 
    func recognize(_ components:Set<JPEG.Component.Key>, precision:Int) -> Self?
    {
        switch (components.sorted(), precision)
        {
        case ([4, 5, 6, 7], 12):
            return .rgba12 
        default:
            return nil 
        }
    }
    
    // the ordering here is used to determine planar indices 
    var components:[JPEG.Component.Key]
    {
        [4, 5, 6, 7]
    }
    var precision:Int 
    {
        12 
    }
}
extension JPEG.RGB12:JPEG.Color 
{
    static 
    func unpack(_ interleaved:[UInt16], of format:JPEG.Deep) -> [Self]
    {
        switch format 
        {
        case .rgba12:
            return stride(from: interleaved.startIndex, to: interleaved.endIndex, by: 4).map 
            {
                (base:Int) -> Self in 
                .init(
                    interleaved[base    ], 
                    interleaved[base + 1], 
                    interleaved[base + 2])
            }
        }
    }
    static 
    func pack(_ pixels:[Self], as format:JPEG.Deep) -> [UInt16]
    {
        switch format 
        {
        case .rgba12:
            return pixels.flatMap
            {
                [min($0.r, 0x0fff), min($0.g, 0x0fff), min($0.b, 0x0fff), 0x0fff]
            }
        }
    }
}
extension JPEG.RGBA12:JPEG.Color 
{
    static 
    func unpack(_ interleaved:[UInt16], of format:JPEG.Deep) -> [Self]
    {
        switch format 
        {
        case .rgba12:
            return stride(from: interleaved.startIndex, to: interleaved.endIndex, by: 4).map 
            {
                (base:Int) -> Self in 
                .init(
                    interleaved[base    ], 
                    interleaved[base + 1], 
                    interleaved[base + 2], 
                    interleaved[base + 3])
            }
        }
    }
    static 
    func pack(_ pixels:[Self], as format:JPEG.Deep) -> [UInt16]
    {
        switch format 
        {
        case .rgba12:
            return pixels.flatMap
            {
                [min($0.r, 0x0fff), min($0.g, 0x0fff), min($0.b, 0x0fff), min($0.a, 0x0fff)]
            }
        }
    }
}


func sin(_ x:Double) -> UInt16 
{
    .init(0x0fff * (_sin(2.0 * .pi * x) * 0.5 + 0.5))
} 
let gradient:[JPEG.RGBA12] = stride(from: 0.0, to: 1.0, by: 0.005).flatMap 
{
    (phase:Double) -> [JPEG.RGBA12] in 
    stride(from: 0.0, to: 1.0, by: 0.001).map
    {
        .init(sin(phase + $0 - 0.15), sin(phase + $0), sin(phase + $0 + 0.15), 0x0fff)
    }
}

let format:JPEG.Deep     = .rgba12 
let R:JPEG.Component.Key = format.components[0],
    G:JPEG.Component.Key = format.components[1],
    B:JPEG.Component.Key = format.components[2],
    A:JPEG.Component.Key = format.components[3]

let layout:JPEG.Layout<JPEG.Deep> = .init(
    format:     format, 
    process:    .progressive(coding: .huffman, differential: false), 
    components: 
    [
        R: (factor: (2, 2), qi: 0),
        G: (factor: (2, 2), qi: 0),
        B: (factor: (2, 2), qi: 0),
        A: (factor: (1, 1), qi: 1),
    ], 
    scans: 
    [
        .progressive((G, \.0), (A, \.1),       bits: 0...),
        .progressive((R, \.0), (B, \.1),       bits: 0...),
        
        .progressive((R, \.0), band: 1 ..< 64, bits: 1...),
        .progressive((G, \.0), band: 1 ..< 64, bits: 1...),
        .progressive((B, \.0), band: 1 ..< 64, bits: 1...),
        .progressive((A, \.0), band: 1 ..< 64, bits: 1...),
        
        .progressive((R, \.0), band: 1 ..< 64, bit:  0),
        .progressive((G, \.0), band: 1 ..< 64, bit:  0),
        .progressive((B, \.0), band: 1 ..< 64, bit:  0),
        .progressive((A, \.0), band: 1 ..< 64, bit:  0),
    ])

let path:String                             = "examples/custom-color/output.jpg"
let image:JPEG.Data.Rectangular<JPEG.Deep>  = 
    .pack(size: (1000, 200), layout: layout, metadata: [], pixels: gradient)
try image.compress(path: path, quanta: 
[
    0: [1, 2, 2, 3, 3, 3] + .init(repeating:  10, count: 58),
    1: [1]                + .init(repeating: 100, count: 63),
])

guard let saved:JPEG.Data.Rectangular<JPEG.Deep> = try .decompress(path: path)
else 
{
    fatalError("failed to open file '\(path)'")
}

let rgb12:[JPEG.RGB12] = image.unpack(as: JPEG.RGB12.self)
guard let _:Void = (System.File.Destination.open(path: "\(path).rgb")
{
    guard let _:Void = $0.write(rgb12.flatMap
    { 
        [
            .init($0.r >> 4 as UInt16), .init(($0.r << 4 as UInt16) & 0xff), 
            .init($0.g >> 4 as UInt16), .init(($0.g << 4 as UInt16) & 0xff), 
            .init($0.b >> 4 as UInt16), .init(($0.b << 4 as UInt16) & 0xff), 
        ] 
    })
    else 
    {
        fatalError("failed to write to file '\(path).rgb'")
    }
}) 
else
{
    fatalError("failed to open file '\(path).rgb'")
}
