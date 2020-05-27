extension JPEG 
{
    public 
    struct JFIF
    {
        public 
        enum Unit
        {
            case inches 
            case centimeters
        }
        public 
        enum Version 
        {
            case v1_0, v1_1, v1_2
        }
        
        public 
        let version:Version,
            density:(x:Int, y:Int, unit:Unit?)
        
        // initializer has to live here due to compiler issue
        public  
        init(version:Version, density:(x:Int, y:Int, unit:Unit?))
        {
            self.version = version 
            self.density = density
        }
    }
    
    public 
    struct EXIF 
    {
        public 
        enum Endianness 
        {
            case bigEndian 
            case littleEndian 
        }
        
        public 
        enum FieldType 
        {
            case ascii 
            case uint8
            case uint16 
            case uint32 
            case int32 
            case urational 
            case rational
            case raw
            
            case other(code:UInt16)
        }
        
        public 
        struct Box 
        {
            public
            let contents:(UInt8, UInt8, UInt8, UInt8), 
                endianness:Endianness
            
            public 
            var asOffset:Int 
            {
                switch self.endianness
                {
                case .littleEndian:
                    return  .init(contents.3) << 24 |
                            .init(contents.2) << 24 |
                            .init(contents.1) << 24 |
                            .init(contents.0) 
                case .bigEndian:
                    return  .init(contents.0) << 24 |
                            .init(contents.1) << 24 |
                            .init(contents.2) << 24 |
                            .init(contents.3) 
                }
            }
            
            public 
            init(_ b0:UInt8, _ b1:UInt8, _ b2:UInt8, _ b3:UInt8, endianness:Endianness) 
            {
                self.contents   = (b0, b1, b2, b3)
                self.endianness = endianness
            }
        }
        
        public 
        let endianness:Endianness 
        public private(set)
        var tags:[UInt16: Int], 
            storage:[UInt8] 
    }
}

// jfif segment parsing 
extension JPEG.JFIF.Version  
{
    static 
    func parse(code:(UInt8, UInt8)) -> Self?
    {
        switch (major: code.0, minor: code.1)
        {
        case (major: 1, minor: 0):
            return .v1_0
        case (major: 1, minor: 1):
            return .v1_1
        case (major: 1, minor: 2):
            return .v1_2
        default:
            return nil 
        }
    }
}
extension JPEG.JFIF.Unit 
{
    static 
    func parse(code:UInt8) -> Self??
    {
        switch code 
        {
        case 0:
            return .some(nil) 
        case 1:
            return .inches 
        case 2:
            return .centimeters
        default:
            return nil 
        }
    }
}
extension JPEG.JFIF 
{
    static 
    let signature:[UInt8] = [0x4a, 0x46, 0x49, 0x46, 0x00]
    
    public static 
    func parse(_ data:[UInt8]) throws -> Self
    {
        guard data.count >= 14
        else
        {
            throw JPEG.ParsingError.mismatched(marker: .application(0), 
                count: data.count, minimum: 14)
        }
        
        // look for 'JFIF\0' signature
        guard data[0 ..< 5] == Self.signature[...]
        else 
        {
            throw JPEG.ParsingError.invalidJFIFSignature(.init(data[0 ..< 5]))
        }

        guard let version:Version   = .parse(code: (data[5], data[6]))
        else 
        {
            throw JPEG.ParsingError.invalidJFIFVersionCode((data[5], data[6]))
        }
        guard let unit:Unit?        = Unit.parse(code: data[7])
        else
        {
            // invalid JFIF density unit
            throw JPEG.ParsingError.invalidJFIFDensityUnitCode(data[7])
        }

        let density:(x:Int, y:Int)  = 
        (
            data.load(bigEndian: UInt16.self, as: Int.self, at:  8), 
            data.load(bigEndian: UInt16.self, as: Int.self, at: 10)
        )
        
        // we ignore the thumbnail data
        return .init(version: version, density: (density.x, density.y, unit))
    }
}

extension JPEG.JFIF.Version 
{
    var serialized:(UInt8, UInt8) 
    {
        switch self 
        {
        case .v1_0:
            return (1, 0)
        case .v1_1:
            return (1, 1)
        case .v1_2:
            return (1, 2)
        }
    }
}
extension JPEG.JFIF.Unit 
{
    var serialized:UInt8 
    {
        switch self 
        {
        case .inches:
            return 1
        case .centimeters:
            return 2
        }
    }
}
extension JPEG.JFIF 
{
    public 
    func serialized() -> [UInt8] 
    {
        var bytes:[UInt8] = Self.signature 
        bytes.append(self.version.serialized.0)
        bytes.append(self.version.serialized.1)
        bytes.append(self.density.unit?.serialized ?? 0)
        bytes.append(contentsOf: [UInt8].store(self.density.x, asBigEndian: UInt16.self))
        bytes.append(contentsOf: [UInt8].store(self.density.y, asBigEndian: UInt16.self))
        // no thumbnail 
        bytes.append(0) 
        bytes.append(0)
        return bytes
    }
}


extension JPEG.EXIF.FieldType 
{
    static 
    func parse(code:UInt16) -> Self
    {
        switch code 
        {
        case 1:
            return .uint8 
        case 2:
            return .ascii  
        case 3:
            return .uint16
        case 4:
            return .uint32 
        case 5:
            return .urational 
        case 7:
            return .raw
        case 9:
            return .int32 
        case 10:
            return .rational 
        default:
            return .other(code: code) 
        }
    }
}
extension JPEG.EXIF 
{
    static 
    let signature:[UInt8] = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]
    
    public static 
    func parse(_ data:[UInt8]) throws -> Self 
    {
        guard data.count >= 14 
        else 
        {
            throw JPEG.ParsingError.mismatched(marker: .application(1), 
                count: data.count, minimum: 14)
        }
        
        // look for 'Exif\0\0' signature
        guard data[0 ..< 6] == Self.signature[...] 
        else 
        {
            throw JPEG.ParsingError.invalidEXIFSignature(.init(data[0 ..< 6]))
        }
        
        // determine endianness 
        let endianness:Endianness
        switch (data[6], data[7], data[8], data[9]) 
        {
        case (0x49, 0x49, 0x2a, 0x00):
            endianness = .littleEndian
        case (0x4d, 0x4d, 0x00, 0x2a):
            endianness = .bigEndian
        default:
            throw JPEG.ParsingError.invalidEXIFEndiannessCode(
                (data[6], data[7], data[8], data[9]))
        }
        
        var exif:Self = .init(endianness: endianness, tags: [:], 
            storage: .init(data.dropFirst(6)))
        
        exif.index(ifd: .init(exif[4, as: UInt32.self]))
        // exif ifd 
        if  let (type, count, box):(FieldType, Int, Box) = exif[tag: 34665], 
            case .uint32 = type, count == 1
        {
            exif.index(ifd: box.asOffset)
        }
        // gps ifd 
        if  let (type, count, box):(FieldType, Int, Box) = exif[tag: 34853], 
            case .uint32 = type, count == 1
        {
            exif.index(ifd: box.asOffset)
        }
        
        return exif
    }
    
    private mutating 
    func index(ifd:Int) 
    {
        guard ifd + 2 <= self.storage.count 
        else 
        {
            return 
        }
        
        let count:Int = .init(self[ifd, as: UInt16.self])
        for i:Int in 0 ..< count 
        {
            let offset:Int = ifd + 2 + i * 12
            guard offset + 12 <= self.storage.count 
            else 
            {
                continue 
            }
            
            self.tags[self[offset, as: UInt16.self]] = offset
        }
    }
    
    public 
    subscript(tag tag:UInt16) -> (type:FieldType, count:Int, box:Box)?
    {
        guard let offset:Int = self.tags[tag] 
        else 
        {
            return nil 
        }
        
        let type:FieldType = .parse(code: self[offset + 2, as: UInt16.self])
        
        let count:Int = .init(self[offset + 4, as: UInt32.self])
        let box:Box   = .init(
            self[offset + 8 , as: UInt8.self], 
            self[offset + 9 , as: UInt8.self], 
            self[offset + 10, as: UInt8.self], 
            self[offset + 11, as: UInt8.self], 
            endianness: self.endianness)
        return (type, count, box)
    }
    
    public 
    subscript(offset:Int, as _:UInt8.Type) -> UInt8 
    {
        self.storage[offset]
    }
    public 
    subscript(offset:Int, as _:UInt16.Type) -> UInt16 
    {
        switch self.endianness 
        {
        case .littleEndian:
            return  .init(self[offset + 1, as: UInt8.self]) << 8 | 
                    .init(self[offset    , as: UInt8.self])
        case .bigEndian:
            return  .init(self[offset    , as: UInt8.self]) << 8 | 
                    .init(self[offset + 1, as: UInt8.self])
        }
    }
    public 
    subscript(offset:Int, as _:UInt32.Type) -> UInt32 
    {
        switch self.endianness 
        {
        case .littleEndian:
            return  .init(self[offset + 3, as: UInt8.self]) << 24 | 
                    .init(self[offset + 2, as: UInt8.self]) << 16 |
                    .init(self[offset + 1, as: UInt8.self]) <<  8 |
                    .init(self[offset    , as: UInt8.self])
        case .bigEndian:
            return  .init(self[offset    , as: UInt8.self]) << 24 | 
                    .init(self[offset + 1, as: UInt8.self]) << 16 |
                    .init(self[offset + 2, as: UInt8.self]) <<  8 |
                    .init(self[offset + 3, as: UInt8.self])
        }
    }
}

extension JPEG.EXIF.Endianness 
{
    public 
    func serialized() -> [UInt8] 
    {
        switch self 
        {
        case .littleEndian:
            return [0x49, 0x49, 0x2a, 0x00]
        case .bigEndian:
            return [0x4d, 0x4d, 0x00, 0x2a]
        }
    }
}
extension JPEG.EXIF 
{
    public 
    func serialized() -> [UInt8] 
    {
        var bytes:[UInt8] = Self.signature 
        bytes.append(contentsOf: self.endianness.serialized())
        bytes.append(contentsOf: self.storage.dropFirst(4))
        return bytes
    }
}
