extension FrameHeader.Component:CustomStringConvertible 
{
    var description:String 
    {
        return "{q: \(self.q), sample factors: \(self.sampleFactors)}"
    }
}

extension FrameHeader:CustomStringConvertible 
{
    var description:String 
    {
        return """
        frame header: 
        {
            encoding      : \(self.encoding), 
            precision     : \(self.precision), 
            width         : \(self.width), 
            initial height: \(self.height), 
            components    : 
            [
                \(self.components.enumerated().filter{ $0.1 != nil }
                .map{ "[\($0.0)]: \($0.1!)"}.joined(separator: ", \n        "))
            ]
        }
        """
    }
}

extension ScanHeader.Component:CustomStringConvertible 
{
    var description:String 
    {
        return "[\(self.component)]: \(self.selectors)"
    }
}

extension ScanHeader:CustomStringConvertible
{
    var description:String 
    {
        return """
        scan header:
        {
            spectral band: \(self.band.lowerBound) ..< \(self.band.upperBound), 
            exponent     : \(self.exponent), 
            components   : 
            [
                \(self.components.map(String.init(describing:)).joined(separator: ", \n        "))
            ]
        }
        """
    }
}
