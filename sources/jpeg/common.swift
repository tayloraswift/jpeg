/* This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/. */

/// enum General 
///     A namespace for general functionality.
/// #  [Range types](general-range-types)
/// #  [Integer storage](general-storage-types)
/// #  [See also](top-level-namespaces)
/// ## (1:top-level-namespaces)
public 
enum General    
{
}

extension General  
{
    /// struct General.Storage<I> 
    /// where I:Swift.FixedWidthInteger & Swift.BinaryInteger 
    /// @propertyWrapper 
    ///     A property wrapper providing an immutable [`Swift.Int`] interface backed 
    ///     by a different integer type.
    /// #  [See also](general-storage-types)
    /// ## (general-storage-types)
    @propertyWrapper 
    public 
    struct Storage<I> where I:FixedWidthInteger & BinaryInteger 
    {
        private 
        var storage:I 
        /// init General.Storage.init(wrappedValue:)
        ///     Creates an instance of this property wrapper, with the given value 
        ///     truncated to the width of the storage type [`I`].
        /// - wrappedValue : Swift.Int 
        ///     The value to wrap.
        public 
        init(wrappedValue:Int) 
        {
            self.storage = .init(truncatingIfNeeded: wrappedValue)
        }
        /// var General.Storage.wrappedValue : Swift.Int { get }
        ///     The value wrapped by this property wrapper, expanded to an [`Swift.Int`].
        public 
        var wrappedValue:Int 
        {
            .init(self.storage)
        }
    }
    /// struct General.Storage2<I> 
    /// where I:Swift.FixedWidthInteger & Swift.BinaryInteger 
    /// @propertyWrapper 
    ///     A property wrapper providing an immutable `(`[`Swift.Int`]`, `[`Swift.Int`]`)` 
    ///     interface backed by a different integer type.
    /// #  [See also](general-storage-types)
    /// ## (general-storage-types)
    @propertyWrapper 
    public 
    struct Storage2<I> where I:FixedWidthInteger & BinaryInteger 
    {
        private 
        var storage:(x:I, y:I) 
        /// init General.Storage2.init(wrappedValue:)
        ///     Creates an instance of this property wrapper, with the given values 
        ///     truncated to the width of the storage type [`I`].
        /// - wrappedValue : (x:Swift.Int, y:Swift.Int)
        ///     The values to wrap.
        public 
        init(wrappedValue:(x:Int, y:Int)) 
        {
            self.storage = 
            (
                .init(truncatingIfNeeded: wrappedValue.x),
                .init(truncatingIfNeeded: wrappedValue.y)
            )
        }
        /// var General.Storage2.wrappedValue : Swift.Int { get }
        ///     The values wrapped by this property wrapper, expanded to an 
        ///     `(`[`Swift.Int`]`, `[`Swift.Int`]`)` tuple.
        public 
        var wrappedValue:(x:Int, y:Int) 
        {
            (.init(self.storage.x), .init(self.storage.y))
        }
    }
    /// struct General.MutableStorage<I> 
    /// where I:Swift.FixedWidthInteger & Swift.BinaryInteger 
    /// @propertyWrapper 
    ///     A property wrapper providing a mutable [`Swift.Int`] interface backed 
    ///     by a different integer type.
    /// #  [See also](general-storage-types)
    /// ## (general-storage-types)
    @propertyWrapper 
    public 
    struct MutableStorage<I> where I:FixedWidthInteger & BinaryInteger 
    {
        private 
        var storage:I 
        /// init General.MutableStorage.init(wrappedValue:)
        ///     Creates an instance of this property wrapper, with the given value 
        ///     truncated to the width of the storage type [`I`].
        /// - wrappedValue : Swift.Int 
        ///     The value to wrap.
        public 
        init(wrappedValue:Int) 
        {
            self.storage = .init(truncatingIfNeeded: wrappedValue)
        }
        /// var General.MutableStorage.wrappedValue : Swift.Int { get set }
        ///     The value wrapped by this property wrapper, expanded to an [`Swift.Int`].
        public 
        var wrappedValue:Int 
        {
            get 
            {
                .init(self.storage)
            }
            set(value)
            {
                self.storage = .init(value)
            }
        }
    }
}

extension General 
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
extension General.Heap
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
extension General.Heap:ExpressibleByArrayLiteral 
{
    init(arrayLiteral:(key:Key, value:Value)...) 
    {
        self.init(arrayLiteral)
    }
} 

// 2d iterators 
extension General 
{
    /// struct General.Range2<Bound> 
    /// where Bound:Swift.Comparable 
    /// :   Swift.Sequence where Bound:Swift.Strideable, Bound.Stride:Swift.SignedInteger
    ///     A two-dimensional open range.
    /// ## (general-range-types)
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

}
func ..< <Bound>(lhs:(x:Bound, y:Bound), rhs:(x:Bound, y:Bound)) -> General.Range2<Bound> 
    where Bound:Comparable
{
    return .init(lowerBound: lhs, upperBound: rhs)
}

extension General.Range2:Sequence where Bound:Strideable, Bound.Stride:SignedInteger
{
    /// typealias General.Range2.Element = (x:Bound, y:Bound) 
    /// ?:  Swift.Sequence where Bound:Swift.Strideable, Bound.Stride:Swift.SignedInteger
    public 
    typealias Element = (x:Bound, y:Bound)
    
    /// struct General.Range2.Iterator 
    /// ?:  Swift.Sequence where Bound:Swift.Strideable, Bound.Stride:Swift.SignedInteger
    /// :   Swift.IteratorProtocol 
    ///     A two-dimensional range iterator.
    /// ## (general-range-types)
    public 
    struct Iterator
    {
        var x:Bound, 
            y:Bound 
        let bound:(x:(Bound, Bound), y:Bound)
    }
    
    /// func General.Range2.makeIterator()
    /// ?:  Swift.Sequence where Bound:Swift.Strideable, Bound.Stride:Swift.SignedInteger
    ///     Creates an iterator for this range instance. 
    /// 
    ///     This iterator will traverse the range space in row-major order. For 
    ///     example, if the bounds are `(x: 0, y: 0)` and `(x: 2, y: 2)`, the iterator 
    ///     will yield the elements `(x: 0, y: 0)`, `(x: 1, y: 0)`, `(x: 0, y: 1)`, 
    ///     and `(x: 1, y: 1)`, in that order.
    /// - -> : Iterator 
    ///     An iterator.
    public 
    func makeIterator() -> Iterator 
    {
        .init(x: self.lowerBound.x, y: self.lowerBound.y, 
            bound: ((self.lowerBound.x, self.upperBound.x), self.upperBound.y))
    }
}
extension General.Range2.Iterator:IteratorProtocol
{
    /// mutating func General.Range2.Iterator.next()
    /// ?:  Swift.IteratorProtocol 
    ///     Advances to the next element and returns it, or `nil` if no next element exists.
    /// - -> : (x:Bound, y:Bound)? 
    ///     The next element in the two-dimensional range sequence, if it exists, 
    ///     otherwise `nil`. If advancing the `x` index would cause it to reach its 
    ///     upper bound, this iterator will advance to the next `y` index and reset 
    ///     the `x` index to its lower bound.
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
    //  Loads this array slice as a misaligned big-endian integer value,
    //  and casts it to a desired format.
    //  - Parameters:
    //      - bigEndian: The size and type to interpret this array slice as.
    //      - type: The type to cast the read integer value to.
    //  - Returns: The read integer value, cast to `U`.
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
    //  Loads a misaligned big-endian integer value from the given byte offset
    //  and casts it to a desired format.
    //  - Parameters:
    //      - bigEndian: The size and type to interpret the data to load as.
    //      - type: The type to cast the read integer value to.
    //      - byte: The byte offset to load the big-endian integer from.
    //  - Returns: The read integer value, cast to `U`.
    func load<T, U>(bigEndian:T.Type, as type:U.Type, at byte:Int) -> U
        where T:FixedWidthInteger, U:BinaryInteger
    {
        return self[byte ..< byte + MemoryLayout<T>.size].load(bigEndian: T.self, as: U.self)
    }
}

extension Array where Element == UInt8
{
    //  Decomposes the given integer value into its constituent bytes, in big-endian order.
    //  - Parameters:
    //      - value: The integer value to decompose.
    //      - type: The big-endian format `T` to store the given `value` as. The given
    //              `value` is truncated to fit in a `T`.
    //  - Returns: An array containing the bytes of the given `value`, in big-endian order.
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
