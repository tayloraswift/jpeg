import Glibc

func decode(path:String) throws
{
    try JPEG.File.Source.open(path: path) 
    {
        (stream:inout JPEG.File.Source) in 
        
        var marker:(type:JPEG.Marker, data:[UInt8]) 
        
        // start of image 
        marker = try stream.segment()
        guard case .start = marker.type 
        else 
        {
            throw JPEG.Parse.Error.unexpected(.markerSegment(marker.type), expected: .markerSegment(.start))
        }
        
        // jfif header (must immediately follow start of image)
        marker = try stream.segment()
        guard case .application(0) = marker.type 
        else 
        {
            throw JPEG.Parse.Error.unexpected(.markerSegment(marker.type), expected: .markerSegment(.application(0)))
        }
        guard let image:JPEG.JFIF = try .parse(marker.data) 
        else 
        {
            throw JPEG.Parse.Error.invalid(.markerSegment(.application(0)))
        }
        
        print(image)
        
        
        let frame:JPEG.Frame = try
        {
            marker = try stream.segment()
            while true 
            {
                print(marker.type)
                switch marker.type 
                {
                case .frame(.unsupported(let code)):
                    throw JPEG.Parse.Error.unsupported("jpeg encoding mode \(code)")
                
                case .frame(let mode):
                    let frame:JPEG.Frame = try .parse(marker.data, mode: mode)
                    marker               = try stream.segment() 
                    return frame
                
                case .quantization:
                    break 
                case .huffman:
                    break
                
                case .comment, .application:
                    break 
                
                case .scan, .height, .restart, .end:
                    throw JPEG.Parse.Error.premature(marker.type)
                
                case .start:
                    throw JPEG.Parse.Error.duplicate(marker.type)
                }
                
                marker = try stream.segment() 
            }
        }()
        
        print(frame)
        
        scans:
        while true 
        {
            print(marker.type)
            switch marker.type 
            {
            case .start, .frame:
                throw JPEG.Parse.Error.duplicate(marker.type)
            
            case .quantization:
                break 
            case .huffman:
                break
            
            case .comment, .application:
                break 
            
            case .scan:
                let ecs:[UInt8] 
                (ecs, marker) = try stream.segment(prefix: true)
                print("ecs(\(ecs.count))")
                continue scans
            
            case .height, .restart:
                break // TODO: enforce ordering
            case .end:
                break scans 
            }
            
            marker = try stream.segment() 
        }
    }
    
    print()
    print()
    print()
}


protocol _JPEGBytestreamSource 
{
    mutating 
    func read(count:Int) -> [UInt8]?
}

enum JPEG 
{
    enum Bytestream 
    {
        typealias Source = _JPEGBytestreamSource
    }
    
    enum Marker
    {
        case start
        case end
        
        case quantization 
        case huffman 
        
        case height 
        case restart 
        case comment 
        case application(Int)
        
        case frame(Mode)
        case scan 
        
        init?(code:UInt8) 
        {
            switch code 
            {
            case 0xd8:
                self = .start 
            case 0xd9:
                self = .end 
            case 0xdb:
                self = .quantization
            case 0xc4:
                self = .huffman
            case 0xdc:
                self = .height 
            case 0xdd:
                self = .restart 
            case 0xfe:
                self = .comment 
            case 0xe0 ..< 0xf0:
                self = .application(.init(code) - 0xe0)
                
            case 0xda:
                self = .scan 
            
            case 0xc0:
                self = .frame(.baselineDCT)

            case 0xc1:
                self = .frame(.extendedDCT)

            case 0xc2:
                self = .frame(.progressiveDCT)

            case 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf:
                self = .frame(.unsupported(.init(code & 0x0f)))
            
            default:
                return nil
            }
        }
    }
    
    enum Lex
    {
        enum Lexeme 
        {
            case eos 
            
            case byte(UInt8)
            
            case markerSegmentPrefix
            case markerSegmentType 
            case markerSegmentLength
            case markerSegmentBody
            
            case entropyCodedSegment
        }
        
        enum Error:Swift.Error 
        {
            case unexpected(Lexeme, expected:Lexeme)
            case invalid(Lexeme)
        }
    }
    enum Parse 
    {
        enum Entity  
        {
            case signature([UInt8])
            
            case markerSegment(Marker) 
            case markerSegmentLength(Int)
        }
        
        enum Error:Swift.Error 
        {
            case duplicate(Marker)
            case premature(Marker)
            
            case unexpected(Entity, expected:Entity)
            case invalid(Entity)
            
            case unsupported(String)
        }
    }
}

// compound types 
extension JPEG 
{
    enum DensityUnit
    {
        case none
        case dpi 
        case dpcm 
        
        init?(code:UInt8) 
        {
            switch code 
            {
            case 0:
                self = .none 
            case 1:
                self = .dpi 
            case 2:
                self = .dpcm 
            default:
                return nil 
            }
        }
    }
    
    enum Mode 
    {
        case baselineDCT, extendedDCT, progressiveDCT
        case unsupported(Int)
    }
}

// lexing 
extension JPEG.Bytestream.Source 
{
    private mutating 
    func read() -> UInt8?
    {
        return self.read(count: 1)?[0]
    }
    
    // segment lexing 
    private mutating 
    func tail(type:JPEG.Marker) throws -> [UInt8]
    {
        switch type 
        {
        case .start, .end:
            return []
        default:
            guard let header:[UInt8] = self.read(count: 2)
            else 
            {
                throw JPEG.Lex.Error.unexpected(.eos, expected: .markerSegmentLength)
            }
            let length:Int = header.load(bigEndian: UInt16.self, as: Int.self, at: 0)
            
            guard length >= 2
            else 
            {
                throw JPEG.Lex.Error.invalid(.markerSegmentLength)
            }
            guard let data:[UInt8] = self.read(count: length - 2)
            else 
            {
                throw JPEG.Lex.Error.unexpected(.eos, expected: .markerSegmentBody)
            }
            
            return data
        }
    }
    
    public mutating 
    func segment() throws -> (JPEG.Marker, [UInt8])
    {
        try self.segment(prefix: false).1
    }
    public mutating 
    func segment(prefix:Bool) throws -> ([UInt8], (JPEG.Marker, [UInt8]))
    {
        // buffering would help immensely here 
        var ecs:[UInt8] = []
        let append:(_ byte:UInt8) throws -> ()
        
        if prefix 
        {
            append = 
            {
                ecs.append($0)
            }
        } 
        else 
        {
            append = 
            {
                throw JPEG.Lex.Error.unexpected(.byte($0), expected: .markerSegmentPrefix)
            }
        }
        
        outer:
        while var byte:UInt8 = self.read() 
        {
            guard byte == 0xff 
            else 
            {
                try append(byte)
                continue outer
            }
            
            repeat
            {
                guard let next:UInt8 = self.read() 
                else 
                {
                    throw JPEG.Lex.Error.unexpected(.eos, expected: .markerSegmentType)
                }
                
                byte = next
                
                guard byte != 0x00 
                else 
                {
                    try append(0xff)
                    continue outer 
                }
            } 
            while byte == 0xff 
            
            guard let marker:JPEG.Marker = JPEG.Marker.init(code: byte)
            else 
            {
                throw JPEG.Lex.Error.unexpected(.byte(byte), expected: .markerSegmentType)
            }
                
            let data:[UInt8] = try self.tail(type: marker)
            return (ecs, (marker, data))
        }
        
        throw JPEG.Lex.Error.unexpected(.eos, expected: .entropyCodedSegment)
    }
}

// parsing 
extension JPEG 
{
    struct JFIF
    {
        let version:(major:Int, minor:Int),
            density:(x:Int, y:Int, unit:DensityUnit)

        static 
        func parse(_ data:[UInt8]) throws -> Self
        {
            guard data.count >= 14
            else
            {
                throw JPEG.Parse.Error.invalid(.markerSegmentLength(data.count))
            }
            
            // look for 'JFIF' signature
            guard data[0 ..< 5] == [0x4a, 0x46, 0x49, 0x46, 0x00]
            else 
            {
                throw JPEG.Parse.Error.invalid(.signature(.init(data[0 ..< 5])))
            }

            let version:(major:Int, minor:Int)
            version.major = .init(data[5])
            version.minor = .init(data[6])

            guard   1 ... 1 ~= version.major, 
                    0 ... 2 ~= version.minor
            else
            {
                // bad JFIF version number (expected 1.0 ... 1.2)
                throw JPEG.Parse.Error.invalid(.markerSegment(.application(0)))
            }

            guard let unit:DensityUnit = DensityUnit.init(code: data[7])
            else
            {
                // invalid JFIF density unit
                throw JPEG.Parse.Error.invalid(.markerSegment(.application(0)))
            }

            let density:(x:Int, y:Int) = 
            (
                data.load(bigEndian: UInt16.self, as: Int.self, at:  8), 
                data.load(bigEndian: UInt16.self, as: Int.self, at: 10)
            )

            // we ignore the thumbnail data
            return .init(version: version, density: (density.x, density.y, unit))
        }
    }
    
    struct Frame
    {
        struct Component
        {
            let factors:(x:Int, y:Int)
            let qi:Int 
            
            init?(factors:UInt8, qi:UInt8)
            {
                let factors:(x:Int, y:Int)  = (.init(factors >> 4), .init(factors & 0x0f))
                let qi:Int                  = .init(qi)
                guard   1 ... 4 ~= factors.x,
                        1 ... 4 ~= factors.y,
                        0 ... 3 ~= qi
                else
                {
                    return nil
                }

                self.factors = factors 
                self.qi      = qi
            }
        }

        let mode:Mode,
            precision:Int

        internal private(set) // DNL segment may change this later on
        var size:(x:Int, y:Int)

        let components:[Int: Component]

        static
        func parse(_ data:[UInt8], mode:JPEG.Mode) throws -> Self
        {
            guard data.count >= 6
            else
            {
                throw JPEG.Parse.Error.invalid(.markerSegmentLength(data.count))
            }

            let precision:Int = .init(data[0])
            switch (mode, precision) 
            {
            case    (.baselineDCT,      8), 
                    (.extendedDCT,      8), (.extendedDCT,      16), 
                    (.progressiveDCT,   8), (.progressiveDCT,   16):
                break

            default:
                // invalid precision
                throw JPEG.Parse.Error.invalid(.markerSegment(.frame(mode)))
            }
            
            let size:(x:Int, y:Int) = 
            (
                data.load(bigEndian: UInt16.self, as: Int.self, at: 3),
                data.load(bigEndian: UInt16.self, as: Int.self, at: 1)
            )

            let count:Int = .init(data[5])
            switch (mode, count) 
            {
            case    (.baselineDCT,      1 ... .max), 
                    (.extendedDCT,      1 ... .max), 
                    (.progressiveDCT,   1 ... 4   ):
                break

            default:
                // invalid count
                throw JPEG.Parse.Error.invalid(.markerSegment(.frame(mode)))
            }

            guard data.count == 3 * count + 6
            else
            {
                // wrong segment size
                throw JPEG.Parse.Error.unexpected(.markerSegmentLength(data.count), 
                    expected: .markerSegmentLength(3 * count + 6))
            }

            var components:[Int: Component] = [:]
            for i:Int in 0 ..< count
            {
                let base:Int = 3 * i + 6
                let ci:Int = .init(data[base])
                
                guard let component:Component = 
                    Component.init(factors: data[base + 1], qi: data[base + 2])
                else
                {
                    throw JPEG.Parse.Error.invalid(.markerSegment(.frame(mode)))
                }
                
                // make sure no duplicate component indices are used 
                guard components.updateValue(component, forKey: ci) == nil 
                else 
                {
                    throw JPEG.Parse.Error.invalid(.markerSegment(.frame(mode)))
                }
            }

            return .init(mode: mode, precision: precision, size: size, components: components)
        }
        
        // parse DNL segment 
        mutating
        func height(_ data:[UInt8]) throws 
        {
            guard data.count == 2
            else
            {
                throw JPEG.Parse.Error.unexpected(.markerSegmentLength(data.count), 
                    expected: .markerSegmentLength(2))
            }

            self.size.y = data.load(bigEndian: UInt16.self, as: Int.self, at: 0)
        }
    }
}

/// A namespace for file IO functionality.
extension JPEG
{
    public
    enum File
    {
        private
        typealias Descriptor = UnsafeMutablePointer<FILE>

        public
        enum Error:Swift.Error
        {
            /// A file could not be opened.
            ///
            /// This error is not thrown by any `File` methods, but is used by users
            /// of these APIs.
            case couldNotOpen
        }

        /// Read data from files on disk.
        public
        struct Source:JPEG.Bytestream.Source
        {
            private
            let descriptor:Descriptor

            /// Calls a closure with an interface for reading from the specified file.
            /// 
            /// This method automatically closes the file when its function argument returns.
            /// - Parameters:
            ///     - path: A path to the file to open.
            ///     - body: A closure with a `Source` parameter from which data in
            ///         the specified file can be read. This interface is only valid
            ///         for the duration of the method’s execution. The closure is
            ///         only executed if the specified file could be successfully
            ///         opened, otherwise `nil` is returned. If `body` has a return
            ///         value and the specified file could be opened, its return
            ///         value is returned as the return value of the `open(path:body:)`
            ///         method.
            /// - Returns: `nil` if the specified file could not be opened, or the
            ///     return value of the function argument otherwise.
            public static
            func open<Result>(path:String, _ body:(inout Source) throws -> Result)
                rethrows -> Result?
            {
                guard let descriptor:Descriptor = fopen(path, "rb")
                else
                {
                    return nil
                }

                var file:Source = .init(descriptor: descriptor)
                defer
                {
                    fclose(file.descriptor)
                }

                return try body(&file)
            }

            /// Read the specified number of bytes from this file interface.
            /// 
            /// This method only returns an array if the exact number of bytes
            /// specified could be read. This method advances the file pointer.
            /// 
            /// - Parameters:
            ///     - capacity: The number of bytes to read.
            /// - Returns: An array containing the read data, or `nil` if the specified
            ///     number of bytes could not be read.
            public
            func read(count capacity:Int) -> [UInt8]?
            {
                let buffer:[UInt8] = .init(unsafeUninitializedCapacity: capacity)
                {
                    (buffer:inout UnsafeMutableBufferPointer<UInt8>, count:inout Int) in

                    count = fread(buffer.baseAddress, MemoryLayout<UInt8>.stride,
                        capacity, self.descriptor)
                }

                guard buffer.count == capacity
                else
                {
                    return nil
                }

                return buffer
            }
        }
    }
}

fileprivate
extension Array where Element == UInt8
{
    /// Loads a misaligned big-endian integer value from the given byte offset
    /// and casts it to a desired format.
    /// - Parameters:
    ///     - bigEndian: The size and type to interpret the data to load as.
    ///     - type: The type to cast the read integer value to.
    ///     - byte: The byte offset to load the big-endian integer from.
    /// - Returns: The read integer value, cast to `U`.
    func load<T, U>(bigEndian:T.Type, as type:U.Type, at byte:Int) -> U
        where T:FixedWidthInteger, U:BinaryInteger
    {
        return self[byte ..< byte + MemoryLayout<T>.size].load(bigEndian: T.self, as: U.self)
    }
}

fileprivate
extension ArraySlice where Element == UInt8
{
    /// Loads this array slice as a misaligned big-endian integer value,
    /// and casts it to a desired format.
    /// - Parameters:
    ///     - bigEndian: The size and type to interpret this array slice as.
    ///     - type: The type to cast the read integer value to.
    /// - Returns: The read integer value, cast to `U`.
    func load<T, U>(bigEndian:T.Type, as type:U.Type) -> U
        where T:FixedWidthInteger, U:BinaryInteger
    {
        return self.withUnsafeBufferPointer
        {
            (buffer:UnsafeBufferPointer<UInt8>) in

            assert(buffer.count >= MemoryLayout<T>.size,
                "attempt to load \(T.self) from slice of size \(buffer.count)")

            var storage:T = .init()
            let value:T   = withUnsafeMutablePointer(to: &storage)
            {
                $0.deinitialize(count: 1)

                let source:UnsafeRawPointer     = .init(buffer.baseAddress!),
                    raw:UnsafeMutableRawPointer = .init($0)

                raw.copyMemory(from: source, byteCount: MemoryLayout<T>.size)

                return raw.load(as: T.self)
            }

            return U(T(bigEndian: value))
        }
    }
}
