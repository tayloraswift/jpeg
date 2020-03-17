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

extension JPEG.Process:CustomStringConvertible
{
    var description:String 
    {
        switch self 
        {
        case .baseline:
            return "baseline sequential DCT"
        case .extended(coding: let coding, differential: let differential):
            return "extended sequential DCT (\(coding), \(differential ? "differential" : "non-differential"))"
        case .progressive(coding: let coding, differential: let differential):
            return "progressive DCT (\(coding), \(differential ? "differential" : "non-differential"))"
        case .lossless(coding: let coding, differential: let differential):
            return "lossless process (\(coding), \(differential ? "differential" : "non-differential"))"
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
            mode            : \(self.process), 
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
