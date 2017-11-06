import Glibc 

enum JPEGReadError:Error
{
    case FileError(String), 
         FiletypeError, 
         MissingJFIFSegment, 
         IncompleteMarkerError, 
         SyntaxError(String)
}

struct JPEGProperties 
{
    enum DensityUnit:UInt8 
    {
        case none = 0,
             dpi  = 1, 
             dpcm = 2
    }
    
    let version:(major:UInt8, minor:UInt8), 
        densityUnit:DensityUnit, 
        density:(x:UInt16, y:UInt16) 
    
    static 
    func read(from stream:UnsafeMutablePointer<FILE>) throws -> JPEGProperties 
    {
        return try JPEGProperties(stream: stream)
    }
    
    private 
    init(stream:UnsafeMutablePointer<FILE>) throws 
    {
        let length:UInt16 = try readUInt16(from: stream) 
        guard length >= 16 
        else 
        {
            throw JPEGReadError.SyntaxError("JFIF marker length \(length) is less than 16")
        }
        
        guard match(stream: stream, against: [0x4a, 0x46, 0x49, 0x46, 0x00]) 
        else 
        {
            throw JPEGReadError.SyntaxError("missing 'JFIF\\0' signature")
        }
        
        self.version = (try readUInt8(from: stream), try readUInt8(from: stream))
        
        guard version.major == 1, 0 ... 2 ~= version.minor
        else 
        {
            throw JPEGReadError.SyntaxError("bad JFIF version number (expected 1.0 ... 1.2, got \(version.major).\(version.minor)")
        }
        
        guard let densityUnit = DensityUnit(rawValue: try readUInt8(from: stream)) 
        else 
        {
            throw JPEGReadError.SyntaxError("invalid JFIF density unit")
        }
        
        self.densityUnit = densityUnit
        self.density = (try readUInt16(from: stream), try readUInt16(from: stream))
        
        // ignore the thumbnail data
        guard fseek(stream, Int(length) - 14, SEEK_CUR) == 0
        else 
        {
            throw JPEGReadError.IncompleteMarkerError
        }
    }
}

func resolve_path(_ path:String) -> String
{
    guard let first:Character = path.first
    else
    {
        return path
    }
    
    if first == "~"
    {
        let expanded:String.SubSequence = path.dropFirst()
        if  expanded.isEmpty || 
            expanded.first == "/"
        {
            return String(cString: getenv("HOME")) + expanded
        }
        
        return path
    }
    
    return path
}

func match(stream:UnsafeMutablePointer<FILE>, against expected:[UInt8]) -> Bool 
{
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: expected.count) 
    defer 
    {
        buffer.deallocate(capacity: -1)
    }
    
    guard fread(buffer, 1, expected.count, stream) == expected.count 
    else 
    {
        return false;
    }
    
    for i:Int in 0 ..< expected.count
    {
        guard buffer[i] == expected[i] 
        else 
        {
            return false
        }
    }
    
    return true
} 

func readUInt8(from stream:UnsafeMutablePointer<FILE>) throws -> UInt8 
{
    var uint8:UInt8 = 0 
    return try withUnsafeMutablePointer(to: &uint8) 
    {
        guard fread($0, 1, 1, stream) == 1 
        else 
        {
            throw JPEGReadError.IncompleteMarkerError
        }
        
        return $0.pointee
    }
}

func readUInt16(from stream:UnsafeMutablePointer<FILE>) throws -> UInt16 
{
    var uint16:UInt16 = 0 // allocate this on the stack why not
    return try withUnsafeMutablePointer(to: &uint16) 
    {
        guard fread($0, 2, 1, stream) == 1 
        else 
        {
            throw JPEGReadError.IncompleteMarkerError
        }
        
        return UInt16(bigEndian: $0.pointee)
    }
}

// reads length block and allocates output buffer
func readMarkerData(from stream:UnsafeMutablePointer<FILE>) 
    throws -> UnsafeMutableRawBufferPointer
{
    let dest = 
        UnsafeMutableRawBufferPointer.allocate(count: Int(try readUInt16(from: stream)))
    
    guard fread(dest.baseAddress, 1, dest.count, stream) == dest.count 
    else 
    {
        throw JPEGReadError.IncompleteMarkerError
    } 
    
    return dest
}

private 
struct Decoder 
{
    private 
    enum QuantizationTable 
    {
        case q8 (UnsafeMutablePointer<UInt8>), 
             q16(UnsafeMutablePointer<UInt16>) 
        
        func deallocate() 
        {
            switch self 
            {
            case .q8(let buffer):
                buffer.deinitialize(count: 64)
                buffer.deallocate(capacity: 64)
            
            case .q16(let buffer):
                buffer.deinitialize(count: 64)
                buffer.deallocate(capacity: 64)
            }
        }
    }
    
    // these must be managed manually or they will leak
    private 
    var qtables:(QuantizationTable?, QuantizationTable?, 
                 QuantizationTable?, QuantizationTable?) = (nil, nil, nil, nil)
    
    private mutating 
    func updateQuantizationTables(from stream:UnsafeMutablePointer<FILE>) throws 
    {
        let tableData:UnsafeMutableRawBufferPointer = try readMarkerData(from: stream) 
        defer 
        {
            tableData.deallocate()
        }
        
        var i:Int = 0
        while (i < tableData.count) 
        {
            let table:QuantizationTable, 
                bindingIndex:UInt8 = tableData[i] & 0x0f 
            
            guard bindingIndex < 4 
            else 
            {
                throw JPEGReadError.SyntaxError("quantization table has invalid binding index \(bindingIndex) (index must be in 0 ... 3)")
            }
            
            switch tableData[i] & 0xf0 
            {
            case 0x00:
                let cells = UnsafeMutablePointer<UInt8>.allocate(capacity: 64), 
                    u8    = UnsafePointer<UInt8>((tableData.baseAddress! + 1)
                            .bindMemory(to: UInt8.self, capacity: 64))
                cells.initialize(from: u8, count: 64)
                table = .q8(cells)
            
                i += 64 + 1
            
            case 0x10: 
                let cells = UnsafeMutablePointer<UInt16>.allocate(capacity: 64), 
                    u16   = UnsafePointer<UInt16>((tableData.baseAddress! + 1)
                            .bindMemory(to: UInt16.self, capacity: 64))
                for cell:Int in 0 ..< 64 
                {
                    (cells + cell).initialize(to: UInt16(bigEndian: u16[cell]))
                }
                
                table = .q16(cells) 
                
                i += 128 + 1
            
            default:
                throw JPEGReadError.SyntaxError("quantization table has invalid precision (code: \(tableData[i] >> 4))")
            }
            
            switch bindingIndex 
            {
            case 0:
                qtables.0?.deallocate()
                qtables.0 = table
                
            case 1:
                qtables.1?.deallocate()
                qtables.1 = table
                
            case 2:
                qtables.2?.deallocate()
                qtables.2 = table
                
            case 3:
                qtables.3?.deallocate()
                qtables.3 = table 
            
            default: 
                fatalError("unreachable")
            }
        }
    }
}

func decode(path:String) throws
{
    guard let stream:UnsafeMutablePointer<FILE> = fopen(resolve_path(path), "rb") 
    else 
    {
        throw JPEGReadError.FileError(resolve_path(path))
    }
    
    guard match(stream: stream, against: [0xff, 0xd8]) 
    else 
    {
        throw JPEGReadError.FiletypeError
    } 
    
    guard match(stream: stream, against: [0xff, 0xe0]) 
    else 
    {
        throw JPEGReadError.MissingJFIFSegment
    } 
    
    let properties = try JPEGProperties.read(from: stream) 
    print(properties)
}

do 
{
    try decode(path: "../../tests/oscardelarenta.jpg")
}
catch 
{
    print(error)
}
