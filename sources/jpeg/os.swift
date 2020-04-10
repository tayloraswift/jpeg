#if os(macOS)
    import func     Darwin.fopen
    import func     Darwin.fread
    import func     Darwin.fwrite
    import func     Darwin.fclose
    import struct   Darwin.FILE
#elseif os(Linux)
    import func     Glibc.fopen
    import func     Glibc.fread
    import func     Glibc.fwrite
    import func     Glibc.fclose
    import struct   Glibc.FILE
#else
    #warning("unsupported or untested platform (please open an issue at https://github.com/kelvin13/jpeg/issues)")
#endif

#if os(macOS) || os(Linux)

/// A namespace for file IO functionality.
extension Common 
{
    public
    enum File
    {
        typealias Descriptor = UnsafeMutablePointer<FILE>
        
        /// Read data from files on disk.
        public
        struct Source
        {
            private
            let descriptor:Descriptor
        }
        
        /// Write data to files on disk.
        public 
        struct Destination 
        {
            private 
            let descriptor:Descriptor
        }
    }
}
extension Common.File.Source
{
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
    func open<Result>(path:String, _ body:(inout Self) throws -> Result)
        rethrows -> Result?
    {
        guard let descriptor:Common.File.Descriptor = fopen(path, "rb")
        else
        {
            return nil
        }

        var file:Self = .init(descriptor: descriptor)
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
extension Common.File.Destination
{
    /// Calls a closure with an interface for writing to the specified file.
    /// 
    /// This method automatically closes the file when its function argument returns.
    /// - Parameters:
    ///     - path: A path to the file to open.
    ///     - body: A closure with a `Destination` parameter representing
    ///         the specified file to which data can be written to. This
    ///         interface is only valid for the duration of the method’s
    ///         execution. The closure is only executed if the specified
    ///         file could be successfully opened, otherwise `nil` is returned.
    ///         If `body` has a return value and the specified file could
    ///         be opened, its return value is returned as the return value
    ///         of the `open(path:body:)` method.
    /// - Returns: `nil` if the specified file could not be opened, or the
    ///     return value of the function argument otherwise.
    public static
    func open<Result>(path:String, _ body:(inout Self) throws -> Result)
        rethrows -> Result?
    {
        guard let descriptor:Common.File.Descriptor = fopen(path, "wb")
        else
        {
            return nil
        }

        var file:Self = .init(descriptor: descriptor)
        defer
        {
            fclose(file.descriptor)
        }

        return try body(&file)
    }

    /// Write the bytes in the given array to this file interface.
    /// 
    /// This method only returns `()` if the entire array argument could
    /// be written. This method advances the file pointer.
    /// 
    /// - Parameters:
    ///     - buffer: The data to write.
    /// - Returns: `()` if the entire array argument could be written, or
    ///     `nil` otherwise.
    public
    func write(_ buffer:[UInt8]) -> Void?
    {
        let count:Int = buffer.withUnsafeBufferPointer
        {
            fwrite($0.baseAddress, MemoryLayout<UInt8>.stride,
                $0.count, self.descriptor)
        }

        guard count == buffer.count
        else
        {
            return nil
        }

        return ()
    }
}

// declare conformance (as a formality)
extension Common.File.Source:JPEG.Bytestream.Source 
{
}
extension Common.File.Destination:JPEG.Bytestream.Destination 
{
}
// file-based encoding and decoding apis
extension JPEG.Data.Spectral 
{
    public static 
    func decompress(path:String) throws -> Self? 
    {
        return try Common.File.Source.open(path: path, Self.decompress(stream:))
    }
    public 
    func compress(path:String) throws -> Void?
    {
        return try Common.File.Destination.open(path: path, self.compress(stream:))
    }
}
extension JPEG.Data.Planar 
{
    public static 
    func decompress(path:String) throws -> Self?
    {
        guard let spectral:JPEG.Data.Spectral<Format> = try .decompress(path: path)
        else 
        {
            return nil 
        }
        return spectral.idct()
    }
}
extension JPEG.Data.Rectangular 
{
    public static 
    func decompress(path:String) throws -> Self? 
    {
        guard let planar:JPEG.Data.Planar<Format> = try .decompress(path: path) 
        else 
        {
            return nil 
        }
        
        return planar.interleave()
    }
}

#endif
