enum Common   
{
    struct Heap<Element> where Element:Comparable 
    {
        private 
        var storage:[Element]
        
        // support 1-based indexing
        private
        subscript(index:Int) -> Element
        {
            get
            {
                self.storage[index - 1]
            }
            set(value)
            {
                self.storage[index - 1] = value
            }
        }

        var count:Int
        {
            self.storage.count
        }
        var first:Element?
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
    func lowestPriority(above child:Int) -> Int?
    {
        let p:Int = Self.parent(index: child)
        // make sure it’s not the root
        guard p >= self.startIndex 
        else 
        {
            return nil 
        }
                
        // and the element is higher than the parent
        return self[p] < self[child] ? p : nil
    }
    private
    func highestPriority(below parent:Int) -> Int?
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
            return self[parent] < self[l] ? l : nil 
        }
        
        let c:Int = self[l] < self[r] ? r : l
        return self[parent] < self[c] ? c : nil 
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
        guard let parent:Int = self.lowestPriority(above: index)
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
        guard let child:Int = self.highestPriority(below: index)
        else
        {
            return
        }
        
        self.swapAt  (index, child)
        self.siftDown(index: child)
    }

    mutating
    func enqueue(_ element:Element)
    {
        self.storage.append(element)
        self.siftUp(index: self.endIndex - 1)
    }
    
    mutating
    func dequeue() -> Element?
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
    
    init<S>(_ sequence:S) where S:Sequence, S.Element == Element 
    {
        self.storage = .init(sequence)
        // heapify 
        let perfect:ClosedRange<Int> = 
            self.startIndex ... Self.parent(index: self.endIndex - 1)
        for i:Int in perfect.reversed()
        {
            self.siftDown(index: i)
        }
    }
}
extension Common.Heap:ExpressibleByArrayLiteral 
{
    init(arrayLiteral:Element...) 
    {
        self.init(arrayLiteral)
    }
}
