import Glibc

public 
enum Common   
{
}

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
    func open<Result>(path:String, body:(inout Self) throws -> Result)
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

extension Common  
{
    @propertyWrapper 
    public 
    struct Storage<I> where I:FixedWidthInteger & BinaryInteger 
    {
        private 
        var storage:I 
        
        public 
        init(wrappedValue:Int) 
        {
            self.storage = .init(truncatingIfNeeded: wrappedValue)
        }
        
        public 
        var wrappedValue:Int 
        {
            get 
            {
                .init(self.storage)
            }
        }
    }
    @propertyWrapper 
    public 
    struct Storage2<I> where I:FixedWidthInteger & BinaryInteger 
    {
        private 
        var storage:(x:I, y:I) 
        
        public 
        init(wrappedValue:(x:Int, y:Int)) 
        {
            self.storage = 
            (
                .init(truncatingIfNeeded: wrappedValue.x),
                .init(truncatingIfNeeded: wrappedValue.y)
            )
        }
        
        public 
        var wrappedValue:(x:Int, y:Int) 
        {
            get 
            {
                (.init(self.storage.x), .init(self.storage.y))
            }
        }
    }
}

extension Common 
{    
    struct Heap<Key, Value> where Key:Comparable 
    {
        private 
        var storage:[(Key, Value)]
        
        // support 1-based indexing
        private
        subscript(index:Int) -> (key:Key, value:Value)
        {
            get
            {
                self.storage[index - 1]
            }
            set(item)
            {
                self.storage[index - 1] = item
            }
        }

        var count:Int
        {
            self.storage.count
        }
        var first:(key:Key, value:Value)?
        {
            self.storage.first
        }
        var isEmpty:Bool 
        {
            self.storage.isEmpty 
        }
        
        private 
        var startIndex:Int 
        {
            1
        }
        private 
        var endIndex:Int 
        {
            1 + self.count
        }
    }
}
extension Common.Heap
{
    @inline(__always)
    private static 
    func left(index:Int) -> Int
    {
        return index << 1
    }
    @inline(__always)
    private static 
    func right(index:Int) -> Int
    {
        return index << 1 + 1
    }
    @inline(__always)
    private static 
    func parent(index:Int) -> Int
    {
        return index >> 1
    }
    
    private
    func highest(above child:Int) -> Int?
    {
        let p:Int = Self.parent(index: child)
        // make sure it’s not the root
        guard p >= self.startIndex 
        else 
        {
            return nil 
        }
                
        // and the element is higher than the parent
        return self[child].key < self[p].key ? p : nil
    }
    private
    func lowest(below parent:Int) -> Int?
    {
        let r:Int = Self.right(index: parent),
            l:Int = Self.left (index: parent)

        guard l < self.endIndex
        else
        {
            return nil
        }

        guard r < self.endIndex
        else
        {
            return  self[l].key < self[parent].key ? l : nil 
        }
        
        let c:Int = self[r].key < self[l].key      ? r : l
        return      self[c].key < self[parent].key ? c : nil 
    }
    

    @inline(__always)
    private mutating
    func swapAt(_ i:Int, _ j:Int)
    {
        self.storage.swapAt(i - 1, j - 1)
    }
    private mutating
    func siftUp(index:Int)
    {
        guard let parent:Int = self.highest(above: index)
        else
        {
            return
        }

        self.swapAt(index, parent)
        self.siftUp(index: parent)
    }
    private mutating
    func siftDown(index:Int)
    {
        guard let child:Int = self.lowest(below: index)
        else
        {
            return
        }
        
        self.swapAt  (index, child)
        self.siftDown(index: child)
    }

    mutating
    func enqueue(key:Key, value:Value)
    {
        self.storage.append((key, value))
        self.siftUp(index: self.endIndex - 1)
    }
    
    mutating
    func dequeue() -> (key:Key, value:Value)?
    {
        switch self.count 
        {
        case 0:
            return nil 
        case 1:
            return self.storage.removeLast()
        default:
            self.swapAt(self.startIndex, self.endIndex - 1)
            defer 
            {
                self.siftDown(index: self.startIndex)
            }
            return self.storage.removeLast()
        }
    }
    
    init<S>(_ sequence:S) where S:Sequence, S.Element == (Key, Value) 
    {
        self.storage    = .init(sequence)
        // heapify 
        let halfway:Int = Self.parent(index: self.endIndex - 1) + 1
        for i:Int in (self.startIndex ..< halfway).reversed()
        {
            self.siftDown(index: i)
        }
    }
}
extension Common.Heap:ExpressibleByArrayLiteral 
{
    init(arrayLiteral:(key:Key, value:Value)...) 
    {
        self.init(arrayLiteral)
    }
} 

// 2d iterators 
extension Common 
{
    public 
    struct Range2<Bound> where Bound:Comparable 
    {
        let lowerBound:(x:Bound, y:Bound)
        let upperBound:(x:Bound, y:Bound)
        
        init(lowerBound:(x:Bound, y:Bound), upperBound:(x:Bound, y:Bound))
        {
            precondition(lowerBound.x <= upperBound.x, "x lower bound cannot be greater than upper bound")
            precondition(lowerBound.y <= upperBound.y, "y lower bound cannot be greater than upper bound")
            
            self.lowerBound = lowerBound
            self.upperBound = upperBound
        }
    }
    
    public 
    struct Range2Iterator<Bound> where Bound:Strideable, Bound.Stride:SignedInteger
    {
        var x:Bound, 
            y:Bound 
        let bound:(x:(Bound, Bound), y:Bound)
    }
}
func ..< <Bound>(lhs:(x:Bound, y:Bound), rhs:(x:Bound, y:Bound)) -> Common.Range2<Bound> 
    where Bound:Comparable
{
    return .init(lowerBound: lhs, upperBound: rhs)
}

extension Common.Range2:Sequence where Bound:Strideable, Bound.Stride:SignedInteger
{
    public 
    typealias Element = (x:Bound, y:Bound)
    public 
    func makeIterator() -> Common.Range2Iterator<Bound> 
    {
        .init(x: self.lowerBound.x, y: self.lowerBound.y, 
            bound: ((self.lowerBound.x, self.upperBound.x), self.upperBound.y))
    }
}
extension Common.Range2Iterator:IteratorProtocol
{
    public mutating 
    func next() -> (x:Bound, y:Bound)? 
    {
        if self.x < self.bound.x.1 
        {
            defer 
            {
                self.x = self.x.advanced(by: 1)
            }
            
            return (self.x, self.y)
        }
        else 
        {
            self.y = self.y.advanced(by: 1)
            
            if self.y < self.bound.y 
            {
                self.x = self.bound.x.0 
                return self.next()
            }
            else 
            {
                return nil 
            }
        }
    }
}

// raw buffer utilities 
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

extension Array where Element == UInt8
{
    /// Decomposes the given integer value into its constituent bytes, in big-endian order.
    /// - Parameters:
    ///     - value: The integer value to decompose.
    ///     - type: The big-endian format `T` to store the given `value` as. The given
    ///             `value` is truncated to fit in a `T`.
    /// - Returns: An array containing the bytes of the given `value`, in big-endian order.
    static
    func store<U, T>(_ value:U, asBigEndian type:T.Type) -> [UInt8]
        where U:BinaryInteger, T:FixedWidthInteger
    {
        return .init(unsafeUninitializedCapacity: MemoryLayout<T>.size)
        {
            (buffer:inout UnsafeMutableBufferPointer<UInt8>, count:inout Int) in

            let bigEndian:T = T.init(truncatingIfNeeded: value).bigEndian,
                destination:UnsafeMutableRawBufferPointer = .init(buffer)
            Swift.withUnsafeBytes(of: bigEndian)
            {
                destination.copyMemory(from: $0)
                count = $0.count
            }
        }
    }
}
