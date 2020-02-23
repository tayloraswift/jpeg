extension String 
{
    init(selector:JPEG.HuffmanTable.Selector) 
    {
        switch selector
        {
        case \.dc.0:
            self = "DC 0"
        case \.dc.1:
            self = "DC 1"
        case \.dc.2:
            self = "DC 2"
        case \.dc.3:
            self = "DC 3"
        
        case \.ac.0:
            self = "AC 0"
        case \.ac.1:
            self = "AC 1"
        case \.ac.2:
            self = "AC 2"
        case \.ac.3:
            self = "AC 3"
        
        default:
            self = "<unavailable>"
        }
    }
    init(selector:JPEG.QuantizationTable.Selector) 
    {
        switch selector
        {
        case \.0:
            self = "0"
        case \.1:
            self = "1"
        case \.2:
            self = "2"
        case \.3:
            self = "3"
        
        default:
            self = "<unavailable>"
        }
    }
}

extension JPEG.Mode:CustomStringConvertible
{
    var description:String 
    {
        switch self 
        {
        case .baselineDCT:
            return "baseline sequential DCT"
        case .extendedDCT:
            return "extended sequential DCT"
        case .progressiveDCT:
            return "progressive DCT"
        case .unsupported(let code):
            return "unsupported mode (code \(code))"
        }
    }
}

extension JPEG.Frame.Component:CustomStringConvertible 
{
    var description:String 
    {
        "{quantization table: \(String.init(selector: self.selector)), sample factors: (\(self.factor.x), \(self.factor.y))}"
    }
}

extension JPEG.Frame:CustomStringConvertible 
{
    var description:String 
    {
        """
        frame header: 
        {
            mode            : \(self.mode), 
            precision       : \(self.precision), 
            initial size    : (\(self.size.x), \(self.size.y)), 
            components      : 
            [
                \(self.components.keys.sorted().map
                {
                    guard let component:JPEG.Frame.Component = self.components[$0]
                    else 
                    {
                        return "[\($0)]: "
                    }
                    
                    return "[\($0)]: \(component)"
                }.joined(separator: ", \n        "))
            ]
        }
        """
    }
}

extension JPEG.Scan:CustomStringConvertible
{
    var description:String 
    {
        """
        scan header:
        {
            band            : \(self.band.lowerBound) ..< \(self.band.upperBound), 
            bits            : \(self.bits.lowerBound) ..< \(self.bits.upperBound), 
            components      : \(self.components.map(\.ci))
        }
        """
    }
}

extension JPEG.HuffmanTable:CustomStringConvertible
{
    var description:String 
    {
        return """
        huffman table: \(self.storage.count * MemoryLayout<JPEG.HuffmanTable.Entry>.stride) bytes 
        {
            target             : \(String.init(selector: self.target))
            logical entries (ζ): \(self.ζ)
            level 0 entries (n): \(self.n)
        }
        """
    }
}

extension JPEG.QuantizationTable:CustomStringConvertible
{
    var description:String 
    {
        return """
        quantization table
        {
            target  : \(String.init(selector: self.target))
        }
        """
    }
}

// color printing 
extension String 
{
    static 
    func pad(_ string:String, left count:Int) -> Self 
    {
        .init(repeating: " ", count: count - string.count) + string
    }
}
enum Highlight 
{
    static 
    var bold:String     = "\u{1B}[1m"
    static 
    var reset:String    = "\u{1B}[0m"
    
    static 
    func fg(_ color:(r:UInt8, g:UInt8, b:UInt8)?) -> String 
    {
        if let color:(r:UInt8, g:UInt8, b:UInt8) = color
        {
            return "\u{1B}[38;2;\(color.r);\(color.g);\(color.b)m"
        }
        else 
        {
            return "\u{1B}[39m"
        }
    }
    static 
    func bg(_ color:(r:UInt8, g:UInt8, b:UInt8)?) -> String 
    {
        if let color:(r:UInt8, g:UInt8, b:UInt8) = color
        {
            return "\u{1B}[48;2;\(color.r);\(color.g);\(color.b)m"
        }
        else 
        {
            return "\u{1B}[49m"
        }
    }
    
    static 
    func quantize<F>(_ color:(r:F, g:F, b:F)) -> (r:UInt8, g:UInt8, b:UInt8) 
        where F:BinaryFloatingPoint 
    {
        let r:UInt8 = .init((.init(UInt8.max) * max(0, min(color.r, 1))).rounded()),
            g:UInt8 = .init((.init(UInt8.max) * max(0, min(color.g, 1))).rounded()),
            b:UInt8 = .init((.init(UInt8.max) * max(0, min(color.b, 1))).rounded())
        return (r, g, b)
    }
    static 
    func highlight<F>(_ string:String, _ color:(r:F, g:F, b:F)) -> String 
        where F:BinaryFloatingPoint 
    {
        let c:
        (
            bg:(r:UInt8, g:UInt8, b:UInt8), 
            fg:(r:UInt8, g:UInt8, b:UInt8)
        )
        c.bg = Self.quantize(color)
        c.fg = (color.r + color.g + color.b) / 3 < 0.5 ? (.max, .max, .max) : (0, 0, 0)
        
        return "\(Self.bg(c.bg))\(Self.fg(c.fg))\(string)\(Self.fg(nil))\(Self.bg(nil))"
    }
    static 
    func swatch<F>(_ color:(r:F, g:F, b:F)) -> String 
        where F:BinaryFloatingPoint 
    {
        let v:(String, String, String) = 
        (
            String.pad("\(color.r)", left: 3),
            String.pad("\(color.g)", left: 3),
            String.pad("\(color.b)", left: 3)
        )
        return Self.highlight(" \(v.0)\(v.1)\(v.2) ", color)
    }
    static 
    func square<F>(_ color:(r:F, g:F, b:F)) -> String 
        where F:BinaryFloatingPoint 
    {
        return Self.highlight("  ", color)
    }
    
    static 
    func bits<I>(_ x:I) -> String where I:FixedWidthInteger 
    {
        return (0 ..< I.bitWidth).reversed().map
        { 
            (x >> $0) & 1 == 0 ? Self.highlight("0", (0.2, 0.2, 0.2)) : Self.highlight("1", (1, 1, 1))
        }.joined(separator: "")
    }
}
