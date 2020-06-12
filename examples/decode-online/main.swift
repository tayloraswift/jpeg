import JPEG 

struct Stream  
{
    private(set)
    var data:[UInt8], 
        position:Int, 
        available:Int 
}
extension Stream:JPEG.Bytestream.Source
{
    init(_ data:[UInt8]) 
    {
        self.data       = data 
        self.position   = data.startIndex
        self.available  = data.startIndex
    }
    
    mutating 
    func read(count:Int) -> [UInt8]? 
    {
        guard self.position + count <= data.endIndex 
        else 
        {
            return nil 
        }
        guard self.position + count < self.available 
        else 
        {
            self.available += 4096
            return nil 
        }
        
        defer 
        {
            self.position += count 
        }
        
        return .init(self.data[self.position ..< self.position + count])
    }
    
    mutating 
    func reset(position:Int) 
    {
        precondition(self.data.indices ~= position)
        self.position = position
    }
}

let path:String         = "examples/decode-online/karlie-oscars-2017.jpg"
guard let data:[UInt8]  = (System.File.Source.open(path: path) 
{
    (source:inout System.File.Source) -> [UInt8]? in
    
    guard let count:Int = source.count
    else 
    {
        return nil 
    }
    return source.read(count: count)
} ?? nil)
else 
{
    fatalError("failed to open or read file '\(path)'")
}

var stream:Stream = .init(data)

func waitSegment(stream:inout Stream) throws -> (JPEG.Marker, [UInt8]) 
{
    let position:Int = stream.position
    while true 
    {
        do 
        {
            return try stream.segment()
        }
        catch JPEG.LexingError.truncatedMarkerSegmentType 
        {
            stream.reset(position: position)
            continue 
        }
        catch JPEG.LexingError.truncatedMarkerSegmentHeader 
        {
            stream.reset(position: position)
            continue 
        }
        catch JPEG.LexingError.truncatedMarkerSegmentBody 
        {
            stream.reset(position: position)
            continue 
        }
        catch JPEG.LexingError.truncatedEntropyCodedSegment 
        {
            stream.reset(position: position)
            continue 
        }
    }
}
func waitSegmentPrefix(stream:inout Stream) throws -> ([UInt8], (JPEG.Marker, [UInt8]))
{
    let position:Int = stream.position
    while true 
    {
        do 
        {
            return try stream.segment(prefix: true)
        }
        catch JPEG.LexingError.truncatedMarkerSegmentType 
        {
            stream.reset(position: position)
            continue 
        }
        catch JPEG.LexingError.truncatedMarkerSegmentHeader 
        {
            stream.reset(position: position)
            continue 
        }
        catch JPEG.LexingError.truncatedMarkerSegmentBody 
        {
            stream.reset(position: position)
            continue 
        }
        catch JPEG.LexingError.truncatedEntropyCodedSegment 
        {
            stream.reset(position: position)
            continue 
        }
    }
}

func decodeOnline(stream:inout Stream, _ capture:(JPEG.Data.Spectral<JPEG.Common>) throws -> ()) 
    throws
{
    var marker:(type:JPEG.Marker, data:[UInt8]) 

    // start of image 
    marker = try waitSegment(stream: &stream)
    guard case .start = marker.type 
    else 
    {
        fatalError()
    }
    marker = try waitSegment(stream: &stream)

    var dc:[JPEG.Table.HuffmanDC]           = [], 
        ac:[JPEG.Table.HuffmanAC]           = [], 
        quanta:[JPEG.Table.Quantization]    = []
    var interval:JPEG.Header.RestartInterval?, 
        frame:JPEG.Header.Frame?
    definitions:
    while true 
    {
        switch marker.type 
        {
        case .frame(let process):
            frame   = try .parse(marker.data, process: process)
            marker  = try waitSegment(stream: &stream)
            break definitions
        
        case .quantization:
            let parsed:[JPEG.Table.Quantization] = 
                try JPEG.Table.parse(quantization: marker.data)
            quanta.append(contentsOf: parsed)
        
        case .huffman:
            let parsed:(dc:[JPEG.Table.HuffmanDC], ac:[JPEG.Table.HuffmanAC]) = 
                try JPEG.Table.parse(huffman: marker.data)
            dc.append(contentsOf: parsed.dc)
            ac.append(contentsOf: parsed.ac)
        
        case .interval:
            interval = try .parse(marker.data)
        
        // ignore 
        case .application, .comment:
            break 
        
        // unexpected 
        case .scan, .height, .end, .start, .restart:
            fatalError()
        
        // unsupported  
        case .arithmeticCodingCondition, .hierarchical, .expandReferenceComponents:
            break 
        }
        
        marker = try waitSegment(stream: &stream)
    }

    // can use `!` here, previous loop cannot exit without initializing `frame`
    var context:JPEG.Context<JPEG.Common> = try .init(frame: frame!)
    for table:JPEG.Table.HuffmanDC in dc 
    {
        context.push(dc: table)
    }
    for table:JPEG.Table.HuffmanAC in ac 
    {
        context.push(ac: table)
    }
    for table:JPEG.Table.Quantization in quanta 
    {
        try context.push(quanta: table)
    }
    if let interval:JPEG.Header.RestartInterval = interval 
    {
        context.push(interval: interval)
    }

    var first:Bool = true
    scans:
    while true 
    {
        switch marker.type 
        {
        // ignore 
        case .application, .comment:
            break 
        // unexpected
        case .frame, .start, .restart, .height:
            fatalError()
        // unsupported  
        case .arithmeticCodingCondition, .hierarchical, .expandReferenceComponents:
            break 
        
        case .quantization:
            for table:JPEG.Table.Quantization in 
                try JPEG.Table.parse(quantization: marker.data)
            {
                try context.push(quanta: table)
            }
        
        case .huffman:
            let parsed:(dc:[JPEG.Table.HuffmanDC], ac:[JPEG.Table.HuffmanAC]) = 
                try JPEG.Table.parse(huffman: marker.data)
            for table:JPEG.Table.HuffmanDC in parsed.dc 
            {
                context.push(dc: table)
            }
            for table:JPEG.Table.HuffmanAC in parsed.ac 
            {
                context.push(ac: table)
            }
        
        case .interval:
            context.push(interval: try .parse(marker.data))
        
        case .scan:
            let scan:JPEG.Header.Scan   = try .parse(marker.data, 
                process: context.spectral.layout.process)
            var ecss:[[UInt8]] = []
            for index:Int in 0...
            {
                let ecs:[UInt8]
                (ecs, marker) = try waitSegmentPrefix(stream: &stream)
                ecss.append(ecs)
                guard case .restart(let phase) = marker.type
                else 
                {
                    try context.push(scan: scan, ecss: ecss, extend: first)
                    if first 
                    {
                        let height:JPEG.Header.HeightRedefinition
                        if case .height = marker.type 
                        {
                            height = try .parse(marker.data)
                            marker = try waitSegment(stream: &stream)
                        }
                        // same guarantees for `!` as before
                        else if frame!.size.y > 0
                        {
                            height = .init(height: frame!.size.y)
                        }
                        else 
                        {
                            fatalError()
                        }
                        context.push(height: height)
                        first = false 
                    }
                    
                    print("band: \(scan.band), bits: \(scan.bits), components: \(scan.components.map(\.ci))")
                    try capture(context.spectral)
                    continue scans 
                }
                
                guard phase == index % 8 
                else 
                {
                    fatalError()
                }
            }

        case .end:
            return
        }
        
        marker = try waitSegment(stream: &stream)
    }
}

var counter:Int = 0
var last:[JPEG.RGB] = []
try decodeOnline(stream: &stream) 
{
    let image:JPEG.Data.Rectangular<JPEG.Common>    = $0.idct().interleaved()
    let rgb:[JPEG.RGB]                              = image.unpack(as: JPEG.RGB.self)
    let difference:[JPEG.RGB] = 
        zip(last + .init(repeating: .init(0, 0, 0), count: rgb.count - last.count), rgb).map 
    {
        let d:(r:Int, g:Int, b:Int) = 
        (
            abs(.init($1.r) - .init($0.r)),
            abs(.init($1.g) - .init($0.g)),
            abs(.init($1.b) - .init($0.b))
        )
        return .init(.init(clamping: 50 * d.r), .init(clamping: 50 * d.g), .init(clamping: 50 * d.b))
    }
    
    last = rgb
    
    guard let _:Void = (System.File.Destination.open(path: "\(path)-\(counter).rgb")
    {
        guard let _:Void = $0.write(rgb.flatMap{ [$0.r, $0.g, $0.b] })
        else 
        {
            fatalError("failed to write to file '\(path)-\(counter).rgb'")
        }
    }) 
    else
    {
        fatalError("failed to open file '\(path)-\(counter).rgb'")
    } 
    
    guard let _:Void = (System.File.Destination.open(path: "\(path)-difference-\(counter).rgb")
    {
        guard let _:Void = $0.write(difference.flatMap{ [$0.r, $0.g, $0.b] })
        else 
        {
            fatalError("failed to write to file '\(path)-difference-\(counter).rgb'")
        }
    }) 
    else
    {
        fatalError("failed to open file '\(path)-difference-\(counter).rgb'")
    } 
    
    counter += 1
}
