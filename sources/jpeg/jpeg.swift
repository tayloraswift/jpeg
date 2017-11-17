import Glibc

enum JPEGReadError:Error
{
    case FileError(String),
         FiletypeError,
         FilestreamError,
         MissingJFIFHeader,
         InvalidJFIFHeader,
         MissingFrameHeader,
         InvalidFrameHeader,
         MissingScanHeader,
         InvalidScanHeader,

         InvalidQuantizationTable,
         InvalidHuffmanTable,

         InvalidDNLSegment,

         StructuralError,
         SyntaxError(String),

         Unsupported(String)
}

struct UnsafeRawVector
{
    private
    var buffer = UnsafeMutableRawBufferPointer(start: nil, count: 0)

    internal private(set)
    var count:Int = 0

    private
    var capacity:Int
    {
        return self.buffer.count
    }

    // don’t try to call `deallocate()` on this, it will work (after SE-0184), but
    // it is not well-defined. keep the original UnsafeRawVector object around
    // and call `deallocate()` on that instead.
    var dataView:UnsafeRawBufferPointer
    {
        return UnsafeRawBufferPointer(start: self.buffer.baseAddress, count: self.count)
    }

    subscript(i:Int) -> UInt8
    {
        get
        {
            return self.buffer[i]
        }
        set(v)
        {
            self.buffer[i] = v
        }
    }

    func deallocate()
    {
        self.buffer.deallocate()
    }

    mutating
    func append(_ byte:UInt8)
    {
        if self.count == self.capacity
        {
            let newCapacity:Int = max(1, self.capacity << 1)
            let newBuffer = UnsafeMutableRawBufferPointer.allocate(count: newCapacity)
            newBuffer.copyBytes(from: self.buffer)
            self.buffer.deallocate()
            self.buffer = newBuffer
        }

        self.buffer[self.count] = byte
        self.count += 1
    }
}

func resolve_path(_ path:String) -> String
{
    guard let first:Character = path.first
    else
    {
        return path
    }

    if first == "~"
    {
        let expanded:String.SubSequence = path.dropFirst()
        if  expanded.isEmpty ||
            expanded.first == "/"
        {
            return String(cString: getenv("HOME")) + expanded
        }

        return path
    }

    return path
}

extension UnsafeRawBufferPointer
{
    func loadBigEndian<I>(fromByteOffset offset:Int, as _:I.Type)
        -> I where I:FixedWidthInteger
    {
        var i = I()
        withUnsafeMutablePointer(to: &i)
        {
            UnsafeMutableRawPointer($0).copyBytes(from: self.baseAddress! + offset,
                count: MemoryLayout<I>.size)
        }

        return I(bigEndian: i)
    }
}

func readUInt8(from stream:UnsafeMutablePointer<FILE>) throws -> UInt8
{
    var uint8:UInt8 = 0
    return try withUnsafeMutablePointer(to: &uint8)
    {
        guard fread($0, 1, 1, stream) == 1
        else
        {
            throw JPEGReadError.FilestreamError
        }

        return $0.pointee
    }
}

func readBigEndian<I>(from stream:UnsafeMutablePointer<FILE>, as:I.Type) throws
    -> I where I:FixedWidthInteger
{
    var i:I = I()
    return try withUnsafeMutablePointer(to: &i)
    {
        guard fread($0, MemoryLayout<I>.size, 1, stream) == 1
        else
        {
            throw JPEGReadError.FilestreamError
        }

        return I(bigEndian: $0.pointee)
    }
}

// reads length block and allocates output buffer
func readMarkerData(from stream:UnsafeMutablePointer<FILE>)
    throws -> UnsafeRawBufferPointer
{
    let length:Int = Int(try readBigEndian(from: stream, as: UInt16.self)) - 2
    let dest = UnsafeMutableRawBufferPointer.allocate(count: length)

    guard fread(dest.baseAddress, 1, length, stream) == length
    else
    {
        throw JPEGReadError.FilestreamError
    }

    return UnsafeRawBufferPointer(dest)
}

func readNextMarker(from stream:UnsafeMutablePointer<FILE>) throws -> UInt8
{
    guard try readUInt8(from: stream) == 0xff
    else
    {
        throw JPEGReadError.StructuralError
    }

    while true
    {
        let marker:UInt8 = try readUInt8(from: stream)
        if marker != 0xff
        {
            return marker
        }
    }
}

enum UnsafeQuantizationTable
{
    case q8 (UnsafeMutablePointer<UInt8>),
         q16(UnsafeMutablePointer<UInt16>)

    static
    func create_q8(data:UnsafeRawPointer) -> UnsafeQuantizationTable
    {
        let cells = UnsafeMutablePointer<UInt8>.allocate(capacity: 64),
            u8    =
            UnsafePointer<UInt8>(data.bindMemory(to: UInt8.self, capacity: 64))
        cells.initialize(from: u8, count: 64)
        return .q8(cells)
    }

    static
    func create_q16(data:UnsafeRawPointer) -> UnsafeQuantizationTable
    {
        let cells = UnsafeMutablePointer<UInt16>.allocate(capacity: 64),
            u16   =
            UnsafePointer<UInt16>(data.bindMemory(to: UInt16.self, capacity: 64))

        for cell:Int in 0 ..< 64
        {
            (cells + cell).initialize(to: UInt16(bigEndian: u16[cell]))
        }

        return .q16(cells)
    }

    func deallocate()
    {
        switch self
        {
        case .q8(let buffer):
            buffer.deinitialize(count: 64)
            buffer.deallocate(capacity: -1)

        case .q16(let buffer):
            buffer.deinitialize(count: 64)
            buffer.deallocate(capacity: -1)
        }
    }
}

struct UnsafeHuffmanTree
{
    enum CoefficientClass
    {
        case DC, AC
    }

    // storage *could* be optimized to 16 bytes instead of 24
    enum Node
    {
        case leafNode(UInt8),
             internalNode(UnsafePointer<Node>, UnsafePointer<Node>)
    }

    let coefficientClass:CoefficientClass

    private
    let nodes:UnsafeBufferPointer<Node> // count ~= 0 ... 4080

    var root:UnsafePointer<Node>
    {
        return nodes.baseAddress!
    }

    /*
    static
    func assignEntropyCoding<Element>(_ elements:[Element])
        -> ([Int], [Element]) where Element:Hashable
    {
        var occurrences:[Element: Int] = [:]
        for element:Element in elements
        {
            occurrences[element, default: 0] += 1
        }
    }
    */

    func deallocate()
    {
        UnsafeMutablePointer(mutating: self.nodes.baseAddress!)
            .deinitialize(count: self.nodes.count)
        // this will be fixed with SE-0184
        UnsafeMutablePointer(mutating: self.nodes.baseAddress!)
            .deallocate(capacity: -1)
    }

    private static
    func precalculateTreeSize(leavesPerLevel:UnsafePointer<UInt8>)
        -> (leaves:Int, n:Int)?
    {
        var leaves:Int        = 0,
            n:Int             = 1,
            internalNodes:Int = 1 // count the root

        for level:Int in 0 ..< 16
        {
            guard internalNodes > 0
            else
            {
                break
            }

            leaves       += Int(leavesPerLevel[level])
            n            += internalNodes << 1
            internalNodes = internalNodes << 1 - Int(leavesPerLevel[level])
        }

        guard internalNodes == 0
        else
        {
            // invalid huffman tree (h ≤ 16)
            return nil
        }

        return (leaves, n)
    }

    static
    func create(data:UnsafeRawPointer, coefficientClass:CoefficientClass)
        -> UnsafeHuffmanTree?
    {
        let leavesPerLevel:UnsafePointer<UInt8> =
            data.bindMemory(to: UInt8.self, capacity: 16)
        guard let (leaves, n):(Int, Int) =
            precalculateTreeSize(leavesPerLevel: leavesPerLevel)
        else
        {
            return nil
        }

        let nodes = UnsafeMutablePointer<Node>.allocate(capacity: n),
            leafValues:UnsafePointer<UInt8> =
            (data + 16).bindMemory(to: UInt8.self, capacity: leaves)

        // algorithm:   keep a list (range) of all the nodes in the previous level,
        //              append leaf nodes into the buffer, then append internal
        //              nodes into the buffer.
        //
        //          Given: leavesPerLevel = [0, 3, 2, ... ]
        //
        //                  ___0___[root]___1___
        //                /                      \
        //         __0__[A]__1__            __0__[B]__1__
        //       /              \         /               \
        //      [C]            [D]      [E]            _0_[F]_1_
        //                                           /           \
        //                                         [G]           [H]
        //
        //                                          [root]
        //          the root counts as 1 internal node (huffman trees always
        //          have a height > 0), so we expect 2 nodes in the next level.
        //          these two nodes will come immediately after the root, so
        //          their positions in the array are already known.
        //
        //      (        0 leaf nodes added)        [root]
        //      (2 - 0 = 2 internal nodes added)    [root, A, B]
        //          2 internal nodes were added, so we expect 4 nodes in the
        //          next level (huffman trees are always full). As before, the
        //          4 children come immediately after in the array.
        //
        //      (        3 leaf nodes added)        [root, A, B, C, D, E]
        //      (4 - 3 = 1 internal node added)     [root, A, B, C, D, E, F]
        //          1 internal node was added, so we expect 2 nodes in the
        //          next level
        //      (        2 leaf nodes added)        [root, A, B, C, D, E, F, G, H]
        //          0 internal nodes were added, so we are finished.

        typealias UnsafeMutablePointerRange<T> =
            (lowerBound:UnsafeMutablePointer<T>, upperBound:UnsafeMutablePointer<T>)

        nodes.initialize(to: .internalNode(nodes + 1, nodes + 2))
        var internalNodes:UnsafeMutablePointerRange<Node> = (nodes, nodes + 1),
            leavesGenerated:Int = 0

        for level:Int in 0 ..< 16
        {
            guard internalNodes.lowerBound < internalNodes.upperBound
            else
            {
                break
            }
            // `nodes`            `internalNodes`
            //    |                   |     |
            //  [root, A, B, C, D, E, F] + [G, H] ← new leaf nodes
            for leafIndex:Int in 0 ..< Int(leavesPerLevel[level])
            {
                (internalNodes.upperBound + leafIndex)
                    .initialize(to: .leafNode(leafValues[leavesGenerated]))
                leavesGenerated += 1
            }

            let expectedNodes:Int =
                (internalNodes.upperBound - internalNodes.lowerBound) << 1
            let newInternalNodes:UnsafeMutablePointerRange<Node> =
                (internalNodes.upperBound + Int(leavesPerLevel[level]),
                 internalNodes.upperBound + expectedNodes)
            // `nodes`     `internalNodes` `newInternalNodes`
            //    |                   |  |       ||
            //  [root, A, B, C, D, E, F, G, H] + []
            var leftChild:UnsafeMutablePointer<Node> = newInternalNodes.upperBound

            for internalIndex:Int in Int(leavesPerLevel[level]) ..< expectedNodes
            {
                (internalNodes.upperBound + internalIndex)
                    .initialize(to: .internalNode(leftChild, leftChild + 1))
                leftChild += 2
            }

            internalNodes = newInternalNodes
        }

        return UnsafeHuffmanTree(coefficientClass: coefficientClass,
            nodes: UnsafeBufferPointer<Node>(start: nodes, count: n))
    }
}

struct JFIF
{
    enum DensityUnit:UInt8
    {
        case none = 0,
             dpi  = 1,
             dpcm = 2
    }

    let version:(major:UInt8, minor:UInt8),
        densityUnit:DensityUnit,
        density:(x:UInt16, y:UInt16)

    static
    func read(from stream:UnsafeMutablePointer<FILE>, marker:inout UInt8)
        throws -> JFIF?
    {
        guard marker == 0xe0
        else
        {
            throw JPEGReadError.MissingJFIFHeader
        }

        let data:UnsafeRawBufferPointer = try readMarkerData(from: stream)
        marker  = try readNextMarker(from: stream)
        return JFIF.create(from: data)
    }

    private static //todo: rewrite this with buffers and without throws
    func create(from data:UnsafeRawBufferPointer) -> JFIF?
    {
        guard data.count >= 14
        else
        {
            return nil
        }

        for (b1, b2):(UInt8, UInt8) in zip(data[0 ..< 5], [0x4a, 0x46, 0x49, 0x46, 0x00])
        {
            guard b1 == b2
            else
            {
                // missing 'JFIF' signature"
                return nil
            }
        }

        let version:(major:UInt8, minor:UInt8) =
            (data.load(fromByteOffset: 5, as: UInt8.self),
             data.load(fromByteOffset: 6, as: UInt8.self))

        guard version.major == 1, 0 ... 2 ~= version.minor
        else
        {
            // bad JFIF version number (expected 1.0 ... 1.2)
            return nil
        }

        guard let densityUnit =
            DensityUnit(rawValue: data.load(fromByteOffset: 7, as: UInt8.self))
        else
        {
            // invalid JFIF density unit
            return nil
        }

        let density:(x:UInt16, y:UInt16) =
            (data.loadBigEndian(fromByteOffset:  8, as: UInt16.self),
             data.loadBigEndian(fromByteOffset: 10, as: UInt16.self))

        // we ignore the thumbnail data

        return JFIF(version: version, densityUnit: densityUnit, density: density)
    }
}

struct UnsafeFrameHeader
{
    enum Encoding
    {
        case baselineDCT,
             extendedDCT,
             progressiveDCT
    }

    struct Component
    {
        private
        let _sampleFactors:UInt8

        let qtable:UInt8

        var sampleFactors:(x:UInt8, y:UInt8)
        {
            return (_sampleFactors >> 4, _sampleFactors & 0x0f)
        }

        init?(sampleFactors:UInt8, qtable:UInt8)
        {
            guard 1 ... 4 ~= sampleFactors >> 4,
                  1 ... 4 ~= sampleFactors & 0x0f,
                  0 ... 3 ~= qtable
            else
            {
                return nil
            }

            self._sampleFactors = sampleFactors
            self.qtable = qtable
        }
    }

    let encoding:Encoding,
        precision:Int,
        width:Int

    internal private(set)
    var height:Int

    let components:UnsafeBufferPointer<Component>

    let indexMap:UnsafePointer<Int> // always 256 Ints long, -1 signifies hole

    func deallocate()
    {
        UnsafeMutablePointer(mutating: self.components.baseAddress!)
            .deinitialize(count: self.components.count)
        UnsafeMutablePointer(mutating: self.components.baseAddress!)
            .deallocate(capacity: -1)
        UnsafeMutablePointer(mutating: self.indexMap)
            .deinitialize(count: 256)
        UnsafeMutablePointer(mutating: self.indexMap)
            .deallocate(capacity: -1)
    }

    static
    func read(from stream:UnsafeMutablePointer<FILE>, marker:inout UInt8) throws
        -> UnsafeFrameHeader?
    {
        let data:UnsafeRawBufferPointer,
            encoding:Encoding

        switch marker
        {
        case 0xc0:
            data     = try readMarkerData(from: stream)
            encoding = .baselineDCT

        case 0xc1:
            data     = try readMarkerData(from: stream)
            encoding = .extendedDCT

        case 0xc2:
            data     = try readMarkerData(from: stream)
            encoding = .progressiveDCT

        case 0xc3:
            throw JPEGReadError.Unsupported("hierarchical jpegs are unsupported")

        default:
            throw JPEGReadError.MissingFrameHeader
        }

        defer
        {
            data.deallocate()
        }

        marker = try readNextMarker(from: stream)
        return create(from: data, encoding: encoding)
    }

    private static
    func create(from data:UnsafeRawBufferPointer, encoding:Encoding)
        -> UnsafeFrameHeader?
    {
        guard data.count >= 8
        else
        {
            return nil
        }

        let precision = Int(data.load(fromByteOffset: 0, as: UInt8.self))
        switch encoding
        {
        case .baselineDCT:
            guard precision == 8
            else
            {
                return nil
            }

        case .extendedDCT, .progressiveDCT:
            guard precision == 8 || precision == 12
            else
            {
                return nil
            }
        }

        let width  = Int(data.loadBigEndian(fromByteOffset: 1, as: UInt16.self)),
            height = Int(data.loadBigEndian(fromByteOffset: 3, as: UInt16.self))

        let nf     = Int(data.load(fromByteOffset: 5, as: UInt8.self))

        if encoding == .progressiveDCT
        {
            guard 1 ... 4 ~= nf
            else
            {
                return nil
            }
        }

        guard 3 * nf + 6 == data.count
        else
        {
            return nil
        }

        let components = UnsafeMutablePointer<Component>.allocate(capacity: nf),
            indexMap   = UnsafeMutablePointer<Int>.allocate(capacity: 256)
            indexMap.initialize(to: -1, count: 256)
        for i:Int in 0 ..< nf
        {
            let ci = Int(data.load(fromByteOffset: 6 + 3 * i, as: UInt8.self))
            indexMap[ci] = i
            guard let component = Component(
                sampleFactors: data.load(fromByteOffset: 7 + 3 * i, as: UInt8.self),
                qtable:        data.load(fromByteOffset: 8 + 3 * i, as: UInt8.self))
            else
            {
                components.deinitialize(count: i)
                components.deallocate(capacity: -1)
                indexMap.deinitialize(count: 256)
                indexMap.deallocate(capacity: -1)
                return nil
            }

            (components + i).initialize(to: component)
        }

        return UnsafeFrameHeader(encoding: encoding,
            precision:  precision,
            width:      width,
            height:     height,
            components: UnsafeBufferPointer(start: components, count: nf),
            indexMap:   indexMap)
    }

    mutating
    func updateHeight(from stream:UnsafeMutablePointer<FILE>, marker:inout UInt8)
        throws
    {
        guard marker == 0xdc
        else
        {
            return
        }

        let data:UnsafeRawBufferPointer = try readMarkerData(from: stream)
        defer
        {
            data.deallocate()
        }

        guard data.count == 2
        else
        {
            throw JPEGReadError.InvalidDNLSegment
        }

        self.height = Int(data.loadBigEndian(fromByteOffset: 0, as: UInt16.self))
    }
}

struct ScanHeader
{
    // the marker parameter is not a reference because this function does not
    // update the `marker` variable because scan headers are followed by MCU data
    static
    func read(from stream:UnsafeMutablePointer<FILE>, marker:UInt8) throws
        -> ScanHeader?
    {
        guard marker == 0xda
        else
        {
            throw JPEGReadError.MissingScanHeader
        }

        let data:UnsafeRawBufferPointer = try readMarkerData(from: stream)
        defer
        {
            data.deallocate()
        }

        return create(from: data)
    }

    private static
    func create(from _:UnsafeRawBufferPointer) -> ScanHeader?
    {
        return ScanHeader()
    }
}

struct UnsafeContext
{
    internal private(set)
    var restartInterval:Int = 0

    // these must be managed manually or they will leak
    private
    var qtables:(UnsafeQuantizationTable?, UnsafeQuantizationTable?,
                 UnsafeQuantizationTable?, UnsafeQuantizationTable?) =
        (nil, nil, nil, nil)

    func deallocate()
    {
        qtables.0?.deallocate()
        qtables.1?.deallocate()
        qtables.2?.deallocate()
        qtables.3?.deallocate()
    }

    // restart is a naked marker so it takes no `stream` parameter. just like
    // ScanHeader.read(from:marker:) this function does not update the `marker`
    // variable because restart markers are followed by MCU data
    func restart(marker:UInt8) -> Bool
    {
        return 0xd0 ... 0xd7 ~= marker
    }

    mutating // todo: rewrite with buffers and no throws
    func update(from stream:UnsafeMutablePointer<FILE>, marker:inout UInt8) throws
    {
        while true
        {
            let data:UnsafeRawBufferPointer
            switch marker
            {
            case 0xdb: // define quantization table(s)
                print("quantization table")
                data = try readMarkerData(from: stream)
                guard let _:Void = self.updateQuantizationTables(from: data)
                else
                {
                    throw JPEGReadError.InvalidQuantizationTable
                }

            case 0xc4: // define huffman table(s)
                print("huffman table")
                data = try readMarkerData(from: stream)
                guard let _:Void = self.updateHuffmanTrees(from: data)
                else
                {
                    throw JPEGReadError.InvalidHuffmanTable
                }

            case 0xdd: // define restart interval
                print("DRI")
                data = try readMarkerData(from: stream)

            case 0xfe: // comment
                print("comment")
                data = try readMarkerData(from: stream)

            default:
                return
            }

            defer
            {
                data.deallocate()
            }

            marker = try readNextMarker(from: stream)
        }
    }

    private mutating
    func updateQuantizationTables(from data:UnsafeRawBufferPointer) -> Void?
    {
        var i:Int = 0
        while (i < data.count)
        {
            let table:UnsafeQuantizationTable,
                flags:UInt8 = data[i]
            // `i` gets incremented halfway through so it’s easier to just store
            // the `flags` byte
            switch flags & 0xf0
            {
            case 0x00:
                guard i + 64 + 1 <= data.count
                else
                {
                    return nil
                }

                table = UnsafeQuantizationTable.create_q8(data: data.baseAddress! + i + 1)
                i += 64 + 1

            case 0x10:
                guard i + 128 + 1 <= data.count
                else
                {
                    return nil
                }

                table = UnsafeQuantizationTable.create_q16(data: data.baseAddress! + i + 1)
                i += 128 + 1

            default:
                // quantization table has invalid precision
                return nil
            }

            switch flags & 0x0f
            {
            case 0:
                qtables.0?.deallocate()
                qtables.0 = table

            case 1:
                qtables.1?.deallocate()
                qtables.1 = table

            case 2:
                qtables.2?.deallocate()
                qtables.2 = table

            case 3:
                qtables.3?.deallocate()
                qtables.3 = table

            default:
                // quantization table has invalid binding index (index must be in 0 ... 3)
                table.deallocate()
                return nil
            }
        }

        return ()
    }

    private mutating
    func updateHuffmanTrees(from data:UnsafeRawBufferPointer) -> Void?
    {
        // todo
        return ()
    }
}

func readMCUs(from stream:UnsafeMutablePointer<FILE>, marker:inout UInt8) throws
    -> UnsafeRawVector
{
    var vector     = UnsafeRawVector(),
        byte:UInt8 = try readUInt8(from: stream)
    while true
    {
        if byte == 0xff
        {
            // this is the only exit point from this function so we can just
            // reuse the `inout marker` variable
            marker = try readUInt8(from: stream)
            if marker != 0x00
            {
                while marker == 0xff
                {
                    marker = try readUInt8(from: stream)
                }

                return vector
            }
        }

        vector.append(byte)
        byte = try readUInt8(from: stream)
    }
}

func decode(path:String) throws
{
    guard let stream:UnsafeMutablePointer<FILE> = fopen(resolve_path(path), "rb")
    else
    {
        throw JPEGReadError.FileError(resolve_path(path))
    }
    defer
    {
        fclose(stream)
    }

    var marker:UInt8 = try readNextMarker(from: stream)
    // start of image marker
    guard marker == 0xd8
    else
    {
        throw JPEGReadError.FiletypeError
    }

    marker = try readNextMarker(from: stream)

    guard let jfif:JFIF = try JFIF.read(from: stream, marker: &marker)
    else
    {
        throw JPEGReadError.InvalidJFIFHeader
    }

    var context = UnsafeContext()
    defer
    {
        context.deallocate()
    }
    try context.update(from: stream, marker: &marker)

    guard var frameHeader:UnsafeFrameHeader =
        try UnsafeFrameHeader.read(from: stream, marker: &marker)
    else
    {
        throw JPEGReadError.InvalidFrameHeader
    }

    var firstScan:Bool = true
    while marker != 0xd9 // end of image
    {
        try context.update(from: stream, marker: &marker)
        guard let scanHeader = try ScanHeader.read(from: stream, marker: marker)
        else
        {
            throw JPEGReadError.InvalidScanHeader
        }

        let mcuVector:UnsafeRawVector = try readMCUs(from: stream, marker: &marker)
        defer
        {
            mcuVector.deallocate()
        }

        if context.restartInterval > 0
        {
            while context.restart(marker: marker)
            {
                let mcuVector:UnsafeRawVector =
                    try readMCUs(from: stream, marker: &marker)
                defer
                {
                    mcuVector.deallocate()
                }
            }
        }

        if firstScan
        {
            try frameHeader.updateHeight(from: stream, marker: &marker)
            firstScan = false
        }
    }
    // the while loop already scanned the EOI marker
}
