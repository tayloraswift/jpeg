// literal forms 
extension JPEG.Frame.Component.Index:ExpressibleByIntegerLiteral 
{
    public 
    init(integerLiteral:UInt8) 
    {
        self.init(integerLiteral)
    }
}

// print descriptions
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
extension JPEG.Scan.Component:CustomStringConvertible 
{
    public 
    var description:String 
    {
        "{dc huffman table: \(String.init(selector: self.selectors.huffman.dc)), ac huffman table: \(String.init(selector: self.selectors.huffman.ac))}"
    }
}
extension JPEG.Frame.Component.Index:CustomStringConvertible 
{
    public 
    var description:String 
    {
        "\(self.value)"
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
                \(self.components.sorted(by: { $0.key < $1.key }).map
                {
                    return "[\($0.key)]: \($0.value)"
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
        scan header (\(Self.self)):
        {
            band            : \(self.band.lowerBound) ..< \(self.band.upperBound), 
            bits            : \(self.bits.lowerBound) ..< \(self.bits.upperBound), 
            components      : 
            [
                \(self.components.map
                { 
                    "[\($0.ci)]: \($0)" 
                }.joined(separator: ", \n        "))
            ]
        }
        """
    }
}

extension JPEG.Table.Huffman:CustomStringConvertible
{
    public 
    var description:String 
    {
        """
        huffman table (\(Self.self))
        {
            target  : \(String.init(selector: self.target))
        }
        """
    }
}

extension JPEG.Table.Quantization:CustomStringConvertible
{
    public 
    var description:String 
    {
        """
        quantization table (\(Self.self))
        {
            target  : \(String.init(selector: self.target))
        }
        """
    }
}
