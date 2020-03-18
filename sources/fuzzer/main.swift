import JPEG 

extension JPEG.DensityUnit 
{
    var code:UInt8 
    {
        switch self 
        {
        case .none:
            return 0
        case .dpi:
            return 1
        case .dpcm:
            return 2
        }
    }
}
extension JPEG.Marker 
{
    var code:UInt8 
    {
        switch self 
        {
        case .frame(.baseline):
            return 0xc0
        case .frame(.extended   (coding: .huffman, differential: false)):
            return 0xc1
        case .frame(.progressive(coding: .huffman, differential: false)):
            return 0xc2
        
        case .frame(.lossless   (coding: .huffman, differential: false)):
            return 0xc3
        
        case .huffman:
            return 0xc4
        
        case .frame(.extended   (coding: .huffman, differential: true)):
            return 0xc5
        case .frame(.progressive(coding: .huffman, differential: true)):
            return 0xc6
        case .frame(.lossless   (coding: .huffman, differential: true)):
            return 0xc7
        
        case .frame(.extended   (coding: .arithmetic, differential: false)):
            return 0xc9
        case .frame(.progressive(coding: .arithmetic, differential: false)):
            return 0xca
        case .frame(.lossless   (coding: .arithmetic, differential: false)):
            return 0xcb
        
        case .arithmeticCodingCondition:
            return 0xcc
        
        case .frame(.extended   (coding: .arithmetic, differential: true)):
            return 0xcd
        case .frame(.progressive(coding: .arithmetic, differential: true)):
            return 0xce
        case .frame(.lossless   (coding: .arithmetic, differential: true)):
            return 0xcf
        
        case .restart(let n):
            return 0xd0 + .init(n & 0x07)
                
        case .start:
            return 0xd8
        case .end:
            return 0xd9 
        case .scan:
            return 0xda
        case .quantization:
            return 0xdb
        case .height:
            return 0xdc
        case .interval:
            return 0xdd
        case .hierarchical:
            return 0xde
        case .expandReferenceComponents:
            return 0xdf
        
        case .application(let n):
            return 0xe0 + .init(n & 0x0f)
        case .comment:
            return 0xfe
        }
    }
}
extension JPEG.AnyTable 
{
    static 
    func serialize(selector:Self.Selector) -> UInt8 
    {
        switch selector 
        {
        case \.0:
            return 0
        case \.1:
            return 1
        case \.2:
            return 2
        case \.3:
            return 3
        default:
            fatalError("unreachable")
        }
    }
}
extension JPEG.JFIF 
{
    func serialize() -> [UInt8] 
    {
        var bytes:[UInt8] = Self.signature 
        bytes.append(.init(self.version.major))
        bytes.append(.init(self.version.minor))
        bytes.append(self.density.unit.code)
        bytes.append(contentsOf: [UInt8].store(self.density.x, asBigEndian: UInt16.self))
        bytes.append(contentsOf: [UInt8].store(self.density.y, asBigEndian: UInt16.self))
        // no thumbnail 
        bytes.append(0) 
        bytes.append(0)
        return bytes
    }
}
extension JPEG.Frame 
{
    func serialize() -> [UInt8]
    {
        var bytes:[UInt8] = [.init(self.precision)]
        bytes.append(contentsOf: [UInt8].store(self.size.y, asBigEndian: UInt16.self))
        bytes.append(contentsOf: [UInt8].store(self.size.x, asBigEndian: UInt16.self))
        bytes.append(.init(self.components.count))
        
        for (ci, component):(Int, Component) in self.components 
        {
            bytes.append(.init(ci))
            bytes.append(.init(component.factor.x) << 4 | .init(component.factor.y))
            bytes.append(JPEG.Table.Quantization.serialize(selector: component.selector))
        }
        
        return bytes
    }
}

extension JPEG.Bitstream 
{
    static 
    func composites(spectra:JPEG.Data.Spectral.Plane) -> 
        (
            dc:
            (
                initial:[Composite.DC], 
                refining:[Bool]
            ), 
            ac:
            (
                initial:[Composite.AC], 
                refining:[(Composite.AC, [Bool])]
            )
        )
    {
        var dc:(initial:[Composite.DC], refining:[Bool]), 
            ac:(initial:[Composite.AC], refining:[(Composite.AC, [Bool])])
        dc = ([], [])
        ac = ([], [])
        var predecessor:Int = 0
        for y:Int in 0 ..< spectra.units.y
        {
            for x:Int in 0 ..< spectra.units.x 
            {
                let coefficient:Int = spectra[x: x, y: y, z: 0]
                let high:Int = coefficient >> 1,
                    low:Int  = coefficient &  1
                dc.initial.append(.init(difference: high - predecessor))
                dc.refining.append(low != 0)
                predecessor  = high 
                
                
                var zeroes:(high:Int, low:Int)  = (0, 0)
                var refinements:[Bool]          = []
                for z:Int in 1 ..< 64
                {
                    let coefficient:Int = spectra[x: x, y: y, z: z]
                    
                    let sign:Int = coefficient < 0 ? -1 : 1
                    let high:Int = sign * abs(coefficient) >> 1,  
                        low:Int  = coefficient - high << 1
                    
                    if high == 0 
                    {
                        if zeroes.high == 15 
                        {
                            ac.initial.append(.run(zeroes.high, value: 0))
                            zeroes.high = 0 
                        }
                        else 
                        {
                            zeroes.high += 1 
                        }
                        
                        if low == 0 
                        {
                            if zeroes.low == 15 
                            {
                                ac.refining.append((.run(zeroes.low, value: 0), refinements))
                                refinements = []
                                zeroes.low  = 0
                            }
                            else 
                            {
                                zeroes.low += 1
                            }
                        }
                        else 
                        {
                            ac.refining.append((.run(zeroes.low, value: low), refinements))
                            refinements = []
                            zeroes.low  = 0
                        }
                    }
                    else 
                    {
                        ac.initial.append(.run(zeroes.high, value: high))
                        zeroes.high = 0
                        
                        refinements.append(low != 0)
                    }
                }
                
                if zeroes.high > 0 
                {
                    ac.initial.append(.eob(1))
                }
                if zeroes.low > 0 || !refinements.isEmpty 
                {
                    ac.refining.append((.eob(1), refinements))
                }
            }
        }
        
        return (dc, ac)
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
    fileprivate static
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
