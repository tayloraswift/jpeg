import JPEG 

extension JPEG.Table 
{
    typealias InverseHuffmanDC = InverseHuffman<JPEG.Bitstream.Symbol.DC>
    typealias InverseHuffmanAC = InverseHuffman<JPEG.Bitstream.Symbol.AC>
    struct InverseHuffman<Symbol> where Symbol:JPEG.Bitstream.AnySymbol  
    {
        struct Codeword  
        {
            // the inhabited bits are in the most significant end of the `UInt16`
            let bits:UInt16
            @JPEG.Storage<UInt16> 
            var length:Int 
        }
        
        private 
        let storage:[Codeword]
        
        subscript(symbol:Symbol) -> Codeword 
        {
            self.storage[.init(symbol.value)]
        }
    }
}

extension JPEG.Table.InverseHuffman 
{
    // indirect enum would entail too much copying 
    final fileprivate  
    class Subtree<Element>
    {
        enum Node 
        {
            case leaf(Element)
            case interior(left:Subtree, right:Subtree)
        }
        
        let node:Node
        
        init(_ node:Node) 
        {
            self.node = node 
        }
    }
}
extension JPEG.Table.InverseHuffman.Subtree 
{
    var children:[JPEG.Table.InverseHuffman<Symbol>.Subtree<Element>] 
    {
        switch self.node  
        {
        case .leaf:
            return [] 
        case .interior(left: let left, right: let right):
            return [left, right]
        }
    }
    func levels() -> [Int] 
    {
        var levels:[Int]                                                = []
        var queue:[JPEG.Table.InverseHuffman<Symbol>.Subtree<Element>]  = [self]
        while !queue.isEmpty  
        {
            var leaves:Int = 0 
            for subtree:JPEG.Table.InverseHuffman<Symbol>.Subtree<Element> in queue 
            {
                if case .leaf = subtree.node 
                {
                    leaves += 1
                }
            }
            levels.append(leaves)
            queue = queue.flatMap(\.children)
        }
        
        return levels 
    }
}
extension JPEG.Table.InverseHuffman 
{
    // `frequencies` must always contain 256 entries 
    static 
    func construct(frequencies:[Int]) -> Self 
    {
        // sort non-zero symbols by (decreasing) frequency
        // this is nlog(n), but so is the heap stuff later on
        let sorted:[(Int, UInt8)] = (UInt8.min ... UInt8.max).compactMap 
        {
            (value:UInt8) -> (Int, UInt8)? in 
            
            let frequency:Int = frequencies[.init(value)]
            guard frequency > 0 
            else 
            {
                return nil 
            }
            
            return (frequency, value)
        }.sorted
        {
            $0.0 > $1.0
        }
        
        // reversing (to get canonically sorted array) gets the heapify below 
        // to its best-case O(n) time, not that O matters for n = 256 
        let units:[(Int, Subtree<Void>)] = sorted.reversed().map  
        {
            ($0.0, .init(.leaf(())))
        }
        
        var heap:Common.Heap<Int, Subtree<Void>> = .init(units)
        // insert dummy value with frequency 0 to occupy the all-ones codeword 
        heap.enqueue(key: 0, value: .init(.leaf(())))
        // standard huffman tree construction algorithm
        while let first:(key:Int, value:Subtree<Void>) = heap.dequeue() 
        {
            guard let second:(key:Int, value:Subtree<Void>) = heap.dequeue() 
            else 
            {
                var storage:[Codeword] = .init(repeating: .init(bits: 0, length: 0), count: 256)
                
                let levels:ArraySlice<Int> = first.value.levels().dropFirst()
                guard !levels.isEmpty
                else 
                {
                    // happens in the (almost unreachable) situation where there 
                    // are no codewords with non-zero frequency 
                    return .init(storage: storage) 
                }
                
                // convert level counts to codeword assignments 
                let limited:[Int] = Self.limit(height: 16, of: levels)
                for ((_, value), codeword):((Int, UInt8), Codeword) in 
                    zip(sorted, Self.assign(sorted.count, levels: limited)) 
                {
                    storage[.init(value)] = codeword 
                }
                
                return .init(storage: storage)
            }
            
            let merged:Subtree<Void> = .init(.interior(left: first.value, right: second.value))
            let weight:Int           = first.key + second.key 
            
            heap.enqueue(key: weight, value: merged)
        }
        
        fatalError("unreachable")
    }
    
    // limit the height of the generated tree to the given height
    private static 
    func limit(height:Int, of uncompacted:ArraySlice<Int>) -> [Int]
    {
        var levels:[Int] = .init(uncompacted)
        guard levels.count > height
        else 
        {
            return levels 
        }
        
        // collect unhoused nodes: from the bottom to level 17, we gather up 
        // node pairs (since huffman trees are always full trees). one of the 
        // child nodes gets promoted to the level above, the other node goes 
        // into a pool of unhoused nodes 
        var unhoused:Int = 0 
        for l:Int in (height ..< levels.endIndex).reversed() 
        {
            assert(levels[l] & 1 == 0)
            
            let pairs:Int  = levels[l] >> 1
            unhoused      += pairs 
            levels[l - 1] += pairs 
        }
        levels.removeLast(levels.count - height)
        
        // for the remaining unhoused nodes, our strategy is to look for a level 
        // at least 1 step above the bottom (meaning, indices 0 ..< 15) and split 
        // one of its leaves, reducing the leaf count of that level by 1, and 
        // increasing the leaf count of the level below it by 2
        var split:Int = height - 2
        while unhoused > 0 
        {
            guard levels[split] > 0 
            else 
            {
                split -= 1
                // traversal pattern should make it impossible to go below 0 so 
                // long as total leaf population is less than 2^16 (it can never 
                // be greater than 257 anyway)
                assert(split > 0)
                continue 
            }
            
            let resettled:Int  = min(levels[split], unhoused)
            unhoused          -=     resettled 
            levels[split]     -=     resettled 
            levels[split + 1] += 2 * resettled 
            
            if split < height - 2 
            {
                // since we have added new leaves to this level
                split += 1
            } 
        }
        
        return levels
    }
    
    private static 
    func assign(_ symbols:Int, levels:[Int]) -> [Codeword]
    {
        var codewords:[Codeword] = []
        var counter:UInt16      = 0
        for (length, leaves):(Int, Int) in zip(1 ... 16, levels) 
        {
            for _ in 0 ..< leaves 
            {
                let bits:UInt16 = counter &<< (UInt16.bitWidth &- length)
                counter        += 1
                codewords.append(.init(bits: bits, length: length))
            }
            
            counter <<= 1
        }
        
        return codewords
    }
}
