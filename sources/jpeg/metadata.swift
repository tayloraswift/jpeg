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
        enum Endianness 
        {
            case bigEndian 
            case littleEndian 
        }
        
        let endianness:Endianness 
        var storage:[UInt8]
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
        
        return .init(endianness: endianness, storage: .init(data.dropFirst(6)))
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
