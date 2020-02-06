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
        "{quantization table: \(self.selector), sample factors: (\(self.factor.x), \(self.factor.y))}"
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

extension JPEG.Scan.Component:CustomStringConvertible 
{
    var description:String 
    {
        "[\(self.ci)]: \(self.selector)"
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
            components      : 
            [
                \(self.components.map(String.init(describing:)).joined(separator: ", \n        "))
            ]
        }
        """
    }
}

extension JPEG.HuffmanTable:CustomStringConvertible
{
    var description:String 
    {
        """
        huffman table: \(self.storage.count * MemoryLayout<JPEG.HuffmanTable.Entry>.stride) bytes 
        {
            logical entries (ζ): \(self.ζ)
            level 0 entries (n): \(self.n)
        }
        """
    }
}
