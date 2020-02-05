import Glibc

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
        
        case restart 
        case comment 
        case application(Int)
        
        case frame(Frame.Encoding)
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
                self = .frame(.unsupported)
            
            default:
                return nil
            }
        }
    }
    
    struct Frame 
    {
        enum Encoding 
        {
            case baselineDCT, extendedDCT, progressiveDCT
            case unsupported
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
}

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

extension JPEG
{
    /// A namespace for file IO functionality.
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


func decode(path:String) 
{
    try! JPEG.File.Source.open(path: path) 
    {
        var marker:(type:JPEG.Marker, body:[UInt8]) = try $0.segment()
        loop:
        while true 
        {
            print(marker.type)
            switch marker.type 
            {
            case .end:
                break loop 
            
            case .scan:
                let ecs:[UInt8] 
                (ecs, marker) = try $0.segment(prefix: true)
                print("ecs(\(ecs.count))")
            
            default:
                marker = try $0.segment() 
            }
        }
    }
    
    print()
    print()
    print()
}
