import JPEG 

extension System 
{
    struct Blob 
    {
        private(set)
        var data:[UInt8], 
            position:Int 
    }
}
extension System.Blob:JPEG.Bytestream.Source, JPEG.Bytestream.Destination 
{
    init(_ data:[UInt8]) 
    {
        self.data       = data 
        self.position   = data.startIndex
    }
    
    mutating 
    func read(count:Int) -> [UInt8]? 
    {
        guard self.position + count <= data.endIndex 
        else 
        {
            return nil 
        }
        
        defer 
        {
            self.position += count 
        }
        
        return .init(self.data[self.position ..< self.position + count])
    }
    
    mutating 
    func write(_ bytes:[UInt8]) -> Void? 
    {
        self.data.append(contentsOf: bytes) 
        return ()
    }
}

let path:String         = "examples/in-memory/karlie-2011.jpg"
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

var blob:System.Blob = .init(data)
// read from blob 
let spectral:JPEG.Data.Spectral<JPEG.Common>    = try .decompress(stream: &blob)
let image:JPEG.Data.Rectangular<JPEG.Common>    = spectral.idct().interleaved()
let rgb:[JPEG.RGB]                              = image.unpack(as: JPEG.RGB.self)
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

// write to blob 
blob = .init([])
try spectral.compress(stream: &blob)
guard let _:Void = (System.File.Destination.open(path: "\(path).jpg")
{
    guard let _:Void = $0.write(blob.data)
    else 
    {
        fatalError("failed to write to file '\(path).jpg'")
    }
}) 
else
{
    fatalError("failed to open file '\(path).jpg'")
} 
