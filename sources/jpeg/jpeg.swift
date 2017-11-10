import Glibc

enum JPEGReadError:Error
{
    case FileError(String),
         FiletypeError,
         MissingJFIFSegment,
         IncompleteMarkerError,
         StructuralError,
         SyntaxError(String)
}

struct JPEGProperties
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
    func read(from stream:UnsafeMutablePointer<FILE>) throws -> JPEGProperties
    {
        return try JPEGProperties(stream: stream)
    }

    private
    init(stream:UnsafeMutablePointer<FILE>) throws
    {
        let length:UInt16 = try readUInt16(from: stream)
        guard length >= 16
        else
        {
            throw JPEGReadError.SyntaxError("JFIF marker length \(length) is less than 16")
        }

        guard match(stream: stream, against: [0x4a, 0x46, 0x49, 0x46, 0x00])
        else
        {
            throw JPEGReadError.SyntaxError("missing 'JFIF\\0' signature")
        }

        self.version = (try readUInt8(from: stream), try readUInt8(from: stream))

        guard version.major == 1, 0 ... 2 ~= version.minor
        else
        {
            throw JPEGReadError.SyntaxError("bad JFIF version number (expected 1.0 ... 1.2, got \(version.major).\(version.minor)")
        }

        guard let densityUnit = DensityUnit(rawValue: try readUInt8(from: stream))
        else
        {
            throw JPEGReadError.SyntaxError("invalid JFIF density unit")
        }

        self.densityUnit = densityUnit
        self.density = (try readUInt16(from: stream), try readUInt16(from: stream))

        // ignore the thumbnail data
        guard fseek(stream, Int(length) - 14, SEEK_CUR) == 0
        else
        {
            throw JPEGReadError.IncompleteMarkerError
        }
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

func match(stream:UnsafeMutablePointer<FILE>, against expected:[UInt8]) -> Bool
{
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: expected.count)
    defer
    {
        buffer.deallocate(capacity: -1)
    }

    guard fread(buffer, 1, expected.count, stream) == expected.count
    else
    {
        return false;
    }

    for i:Int in 0 ..< expected.count
    {
        guard buffer[i] == expected[i]
        else
        {
            return false
        }
    }

    return true
}

func readUInt8(from stream:UnsafeMutablePointer<FILE>) throws -> UInt8
{
    var uint8:UInt8 = 0
    return try withUnsafeMutablePointer(to: &uint8)
    {
        guard fread($0, 1, 1, stream) == 1
        else
        {
            throw JPEGReadError.IncompleteMarkerError
        }

        return $0.pointee
    }
}

func readUInt16(from stream:UnsafeMutablePointer<FILE>) throws -> UInt16
{
    var uint16:UInt16 = 0 // allocate this on the stack why not
    return try withUnsafeMutablePointer(to: &uint16)
    {
        guard fread($0, 2, 1, stream) == 1
        else
        {
            throw JPEGReadError.IncompleteMarkerError
        }

        return UInt16(bigEndian: $0.pointee)
    }
}

// reads length block and allocates output buffer
func readMarkerData(from stream:UnsafeMutablePointer<FILE>)
    throws -> UnsafeRawBufferPointer
{
    let dest =
        UnsafeMutableRawBufferPointer.allocate(count:
            Int(try readUInt16(from: stream)) - 2)

    guard fread(dest.baseAddress, 1, dest.count, stream) == dest.count
    else
    {
        throw JPEGReadError.IncompleteMarkerError
    }

    return UnsafeRawBufferPointer(dest)
}

func findNextMarker(stream:UnsafeMutablePointer<FILE>) throws -> UInt8
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

enum QuantizationTable
{
    case q8 (UnsafeMutablePointer<UInt8>),
         q16(UnsafeMutablePointer<UInt16>)

    static
    func create_q8(data:UnsafeRawPointer) -> QuantizationTable
    {
        let cells = UnsafeMutablePointer<UInt8>.allocate(capacity: 64),
            u8    =
            UnsafePointer<UInt8>(data.bindMemory(to: UInt8.self, capacity: 64))
        cells.initialize(from: u8, count: 64)
        return .q8(cells)
    }

    static
    func create_q16(data:UnsafeRawPointer) -> QuantizationTable
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

struct HuffmanTree
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
        -> HuffmanTree?
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

        return HuffmanTree(coefficientClass: coefficientClass,
            nodes: UnsafeBufferPointer<Node>(start: nodes, count: n))
    }

    func deallocate()
    {
        UnsafeMutablePointer(mutating: self.nodes.baseAddress!)
            .deinitialize(count: self.nodes.count)
        // this will be fixed with SE-0184
        UnsafeMutablePointer(mutating: self.nodes.baseAddress!)
            .deallocate(capacity: -1)
    }
}

struct Tables
{
    // these must be managed manually or they will leak
    private
    var qtables:(QuantizationTable?, QuantizationTable?,
                 QuantizationTable?, QuantizationTable?) = (nil, nil, nil, nil)

    mutating
    func updateQuantizationTables(from stream:UnsafeMutablePointer<FILE>) throws
    {
        let tableData:UnsafeRawBufferPointer = try readMarkerData(from: stream)
        defer
        {
            tableData.deallocate()
        }

        var i:Int = 0
        while (i < tableData.count)
        {
            let bindingIndex:UInt8 = tableData[i] & 0x0f

            guard bindingIndex < 4
            else
            {
                throw JPEGReadError.SyntaxError("quantization table has invalid binding index \(bindingIndex) (index must be in 0 ... 3)")
            }

            let table:QuantizationTable
            switch tableData[i] & 0xf0
            {
            case 0x00:
                table = QuantizationTable.create_q8(data: tableData.baseAddress! + i + 1)
                i += 64 + 1

            case 0x10:
                table = QuantizationTable.create_q16(data: tableData.baseAddress! + i + 1)
                i += 128 + 1

            default:
                throw JPEGReadError.SyntaxError("quantization table has invalid precision (code: \(tableData[i] >> 4))")
            }

            switch bindingIndex
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
                fatalError("unreachable")
            }
        }
    }
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


// internal facing FrameHeader struct
struct FrameHeader
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
        width:Int,
        height:Int,
        components:UnsafeBufferPointer<Component>

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
    func create(data:UnsafeRawBufferPointer, encoding:Encoding) -> FrameHeader?
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

        guard 3 * nf + 8 == data.count
        else
        {
            return nil
        }

        let components = UnsafeMutablePointer<Component>.allocate(capacity: nf),
            indexMap   = UnsafeMutablePointer<Int>.allocate(capacity: 256)
            indexMap.initialize(to: -1, count: 256)
        for i:Int in 0 ..< nf
        {
            let ci = Int(data.load(fromByteOffset: 8 + 3 * i, as: UInt8.self))
            indexMap[ci] = i
            guard let component = Component(
                sampleFactors: data.load(fromByteOffset:  9 + 3 * i, as: UInt8.self),
                qtable:        data.load(fromByteOffset: 10 + 3 * i, as: UInt8.self))
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

        return FrameHeader(encoding: encoding,
            precision:  precision,
            width:      width,
            height:     height,
            components: UnsafeBufferPointer(start: components, count: nf),
            indexMap:   indexMap)
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

    // start of image marker
    guard match(stream: stream, against: [0xff, 0xd8])
    else
    {
        throw JPEGReadError.FiletypeError
    }

    // JFIF marker
    guard match(stream: stream, against: [0xff, 0xe0])
    else
    {
        throw JPEGReadError.MissingJFIFSegment
    }

    let properties = try JPEGProperties.read(from: stream)
    let frameHeader:FrameHeader?

    var tables = Tables()
    outer: while true
    {
        let marker:UInt8 = try findNextMarker(stream: stream)
        switch marker
        {
        case 0xdb: // define quantization table(s)
            try tables.updateQuantizationTables(from: stream)

        case 0xc2: // progressive DCT
            let data:UnsafeRawBufferPointer = try readMarkerData(from: stream)
            defer
            {
                data.deallocate()
            }

            frameHeader = FrameHeader.create(data: data, encoding: .progressiveDCT)
            break outer

        default:
            print("unrecognized: \(String(marker, radix: 16))")
            break outer
        }
    }
}
