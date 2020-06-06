#if os(macOS)
    import Darwin
#elseif os(Linux)
    import Glibc
#else
    #error("unsupported platform")
#endif

enum File 
{
    typealias Descriptor = UnsafeMutablePointer<FILE>
    
    private static 
    func count(descriptor:Descriptor) -> Int? 
    {
        let descriptor:Int32 = fileno(descriptor)
        guard descriptor != -1 
        else 
        {
            return nil 
        }
        
        guard let status:stat = 
        ({
            var status:stat = .init()
            guard fstat(descriptor, &status) == 0 
            else 
            {
                return nil 
            }
            return status 
        }())
        else 
        {
            return nil 
        }
        
        switch status.st_mode & S_IFMT 
        {
        case S_IFREG, S_IFLNK:
            break 
        default:
            return nil 
        }
        
        return Int.init(status.st_size)
    }
    
    static 
    func source(path:String) -> String? 
    {
        guard   let descriptor:Descriptor   = fopen(path, "rb"), 
                let count:Int               = Self.count(descriptor: descriptor)
        else
        {
            return nil
        }
        
        let buffer:[UInt8] = .init(unsafeUninitializedCapacity: count)
        {
            $1 = fread($0.baseAddress, MemoryLayout<UInt8>.stride, count, descriptor)
        }
        guard buffer.count == count 
        else
        {
            return nil
        }
        
        fclose(descriptor)
        
        return .init(decoding: buffer, as: Unicode.UTF8.self)
    }
    
    static 
    func save(_ buffer:[UInt8], path:String)
    {
        guard let descriptor:Descriptor   = fopen(path, "wb")
        else
        {
            print("failed to open file '\(path)'")
            return
        }
        
        let count:Int = buffer.withUnsafeBufferPointer
        {
            fwrite($0.baseAddress, MemoryLayout<UInt8>.stride, $0.count, descriptor)
        }

        guard count == buffer.count
        else
        {
            print("failed to write to file '\(path)'")
            return 
        }
        
        fclose(descriptor)
    }
    
    // creates directories 
    static 
    func pave(_ directories:[String]) 
    {
        // scan directory paths 
        for path:String in ((1 ... directories.count).map{ directories.prefix($0).joined(separator: "/") })
        {
            mkdir("\(path)/", 0o0755)
        }
    }
}
