extension String 
{
    public 
    init<Table>(selector:Table.Selector) where Table:JPEG.AnyTable  
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
    public 
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
    public 
    var description:String 
    {
        "{quantization table: \(String.init(selector: self.selector)), sample factors: (\(self.factor.x), \(self.factor.y))}"
    }
}

extension JPEG.Frame:CustomStringConvertible 
{
    public 
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
                    guard let component:Component = self.components[$0]
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
    public 
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

extension JPEG.Table.Huffman:CustomStringConvertible
{
    public 
    var description:String 
    {
        return """
        huffman table: \(self.storage.count * MemoryLayout<Entry>.stride) bytes 
        {
            target             : \(String.init(selector: self.target))
            logical entries (ζ): \(self.ζ)
            level 0 entries (n): \(self.n)
        }
        """
    }
}

extension JPEG.Table.Quantization:CustomStringConvertible
{
    public 
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
