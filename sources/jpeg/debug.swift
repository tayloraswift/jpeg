/* This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/. */

// literal forms 
extension JPEG.Component.Key:ExpressibleByIntegerLiteral 
{
    /// init JPEG.Component.Key.init(integerLiteral:)
    /// ?:  Swift.ExpressibleByIntegerLiteral 
    /// - integerLiteral    : Swift.UInt8
    public 
    init(integerLiteral:UInt8) 
    {
        self.init(integerLiteral)
    }
}
extension JPEG.Table.Quantization.Key:ExpressibleByIntegerLiteral 
{
    /// init JPEG.Table.Quantization.Key.init(integerLiteral:)
    /// ?:  Swift.ExpressibleByIntegerLiteral 
    /// - integerLiteral    : Swift.Int
    public 
    init(integerLiteral:Int) 
    {
        self.init(integerLiteral)
    }
}

// print descriptions
extension String 
{
    public 
    init<Delegate>(selector:WritableKeyPath<(Delegate?, Delegate?, Delegate?, Delegate?), Delegate?>)  
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

extension JPEG.Component:CustomStringConvertible 
{
    public 
    var description:String 
    {
        return "{quantization table: \(String.init(selector: self.selector)), sample factors: (\(self.factor.x), \(self.factor.y))}"
    }
}
extension JPEG.Scan.Component:CustomStringConvertible 
{
    public 
    var description:String 
    {
        "{dc huffman table: \(String.init(selector: self.selector.dc)), ac huffman table: \(String.init(selector: self.selector.ac))}"
    }
}
extension JPEG.Component.Key:CustomStringConvertible 
{
    public 
    var description:String 
    {
        "[\(self.value)]"
    }
}
extension JPEG.Table.Quantization.Key:CustomStringConvertible 
{
    public 
    var description:String 
    {
        "[\(self.value)]"
    }
}

extension JPEG.Header.Frame:CustomStringConvertible 
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

extension JPEG.Header.Scan:CustomStringConvertible
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

extension JPEG.JFIF:CustomStringConvertible
{
    public 
    var description:String 
    {
        """
        metadata (\(Self.self))
        {
            version  : \(self.version)
            unit     : \(self.density.unit.map(String.init(describing:)) ?? "none")
            density  : (\(self.density.x), \(self.density.y))
        }
        """
    }
}
extension JPEG.EXIF:CustomStringConvertible
{
    public 
    var description:String 
    {
        """
        metadata (\(Self.self))
        {
            endianness  : \(self.endianness)
            storage     : \(self.storage.count) bytes 
        }
        """
    }
}
