import JPEG

extension String 
{
    static 
    func pad(_ string:String, left count:Int) -> Self 
    {
        .init(repeating: " ", count: count - string.count) + string
    }
    static 
    func pad(_ string:String, right count:Int) -> Self 
    {
        string + .init(repeating: " ", count: count - string.count)
    }
}

let path:String = "examples/decode-advanced/karlie-2019.jpg"
guard let spectral:JPEG.Data.Spectral<JPEG.Common> = try .decompress(path: path)
else 
{
    fatalError("failed to open file '\(path)'")
}

print("""
'\(path)' (\(spectral.layout.format))
{
    size        : (\(spectral.size.x), \(spectral.size.y))
    process     : \(spectral.layout.process)
    precision   : \(spectral.layout.format.precision)
    components  : 
    [
        \(spectral.layout.residents.sorted(by: { $0.key < $1.key }).map 
        {
            let (component, qi):(JPEG.Component, JPEG.Table.Quantization.Key) = 
                spectral.layout.planes[$0.value]
            return "\($0.key): (\(component.factor.x), \(component.factor.y), qi: \(qi))"
        }.joined(separator: "\n        "))
    ]
    scans       : 
    [
        \(spectral.layout.scans.map 
        {
            "[band: \($0.band), bits: \($0.bits)]: \($0.components.map(\.ci))"
        }.joined(separator: "\n        "))
    ]
}
""")

for metadata:JPEG.Metadata in spectral.metadata
{
    switch metadata 
    {
    case .application(let a, data: let data):
        Swift.print("metadata (application \(a), \(data.count) bytes)")
    case .comment(data: let data):
        Swift.print("""
        comment 
        {
            '\(String.init(decoding: data, as: Unicode.UTF8.self))'
        }
        """)
    case .jfif(let jfif):
        Swift.print(jfif)
    case .exif(let exif):
        Swift.print(exif)
        if  let (type, count, box):(JPEG.EXIF.FieldType, Int, JPEG.EXIF.Box) = exif[tag: 315],
            case .ascii = type
        {
            let artist:String = .init(decoding: (0 ..< count).map 
            {
                exif[box.asOffset + $0, as: UInt8.self]
            }, as: Unicode.ASCII.self)
            print("artist: \(artist)")
        }
    }
}

let keys:Set<JPEG.Table.Quantization.Key> = .init(spectral.layout.planes.map(\.qi))
for qi:JPEG.Table.Quantization.Key in keys.sorted() 
{
    let q:Int                           = spectral.quanta.index(forKey: qi) 
    let table:JPEG.Table.Quantization   = spectral.quanta[q]
    print("quantization table \(qi):")
    print("""
    ┌ \(String.init(repeating: " ", count: 4 * 8)) ┐
    \((0 ..< 8).map 
    {
        (h:Int) in 
        """
        │ \((0 ..< 8).map 
        {
            (k:Int) in 
            String.pad("\(table[z: JPEG.Table.Quantization.z(k: k, h: h)]) ", left: 4)
        }.joined()) │
        """
    }.joined(separator: "\n"))
    └ \(String.init(repeating: " ", count: 4 * 8)) ┘
    """)
}


let planar:JPEG.Data.Planar<JPEG.Common> = spectral.idct()
for (p, plane):(Int, JPEG.Data.Planar<JPEG.Common>.Plane) in planar.enumerated()
{
    print("""
    plane \(p) 
    {
        size: (\(plane.size.x), \(plane.size.y))
    }
    """)
    
    let samples:[UInt8] = plane.indices.map 
    {
        (i:(x:Int, y:Int)) in 
        .init(clamping: plane[x: i.x, y: i.y])
    }
    
    let planepath:String = "\(path)-\(p).\(plane.size.x)x\(plane.size.y).gray"
    guard let _:Void = (System.File.Destination.open(path: planepath)
    {
        guard let _:Void = $0.write(samples)
        else 
        {
            fatalError("failed to write to file '\(planepath)'")
        }
    }) 
    else
    {
        fatalError("failed to open file '\(planepath)'")
    }
}

let rectangular:JPEG.Data.Rectangular<JPEG.Common> = planar.interleaved(cosite: false)
let rgb:[JPEG.RGB] = rectangular.unpack(as: JPEG.RGB.self)
guard let _:Void = (System.File.Destination.open(path: "\(path).rgb")
{
    guard let _:Void = $0.write(rgb.flatMap{ [$0.r, $0.g, $0.b] })
    else 
    {
        fatalError("failed to write to file '\(path).rgb'")
    }
}) 
else
{
    fatalError("failed to open file '\(path).rgb'")
} 
