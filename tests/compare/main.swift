import JPEG 

func discrepancy(jpeg:String, reference:String) 
    throws -> (average:Double, max:Double)
{
    guard let rectangular:JPEG.Data.Rectangular<JPEG.Common> = 
        try .decompress(path: jpeg)
    else
    {
        fatalError("failed to open file '\(jpeg)'")
    }
    
    let output:[JPEG.YCbCr]         =  rectangular.unpack(as: JPEG.YCbCr.self)
    guard let expected:[JPEG.YCbCr] = (System.File.Source.open(path: reference)
    {
        guard let data:[UInt8] = $0.read(count: 3 * output.count)
        else
        {
            fatalError("failed to read file '\(reference)'")
        }

        return (0 ..< output.count).map
        {
            let y:UInt8  = data[$0 * 3    ],
                cb:UInt8 = data[$0 * 3 + 1],
                cr:UInt8 = data[$0 * 3 + 2]
            return .init(y: y, cb: cb, cr: cr)
        }
    }) 
    else
    {
        fatalError("failed to open file '\(reference)'")
    }
    
    // terminal output 
    for i:Int in 0 ..< rectangular.size.y 
    {
        func gradientRed(_ x:Double) -> (r:Double, g:Double, b:Double) 
        {
            (x, 2 * (x - 0.5), 1 * (x - 0.4))
        }
        func gradientBlue(_ x:Double) -> (r:Double, g:Double, b:Double) 
        {
            (0.8 * (x - 0.4), 0, x)
        }
        
        let line1:String = (0 ..< rectangular.size.x).map 
        {
            (j:Int) in 
            
            let c:JPEG.RGB = output[j + i * rectangular.size.x].rgb
            return Highlight.square((c.r, c.g, c.b))
        }.joined(separator: "")
        let line2:String = (0 ..< rectangular.size.x).map 
        {
            (j:Int) in 
            
            let c:JPEG.RGB = expected[j + i * rectangular.size.x].rgb
            return Highlight.square((c.r, c.g, c.b))
        }.joined(separator: "")
        let line3:String = (0 ..< rectangular.size.x).map 
        {
            (j:Int) in 
            
            let y:(UInt8, UInt8) = 
            (
                output[j + i * rectangular.size.x].y,
                expected[j + i * rectangular.size.x].y
            )
            
            let d:Int = Int.init(y.0) - Int.init(y.1)
            if d < 0 
            {
                return Highlight.square(gradientBlue(.init(-d) / 10))
            }
            else 
            {
                return Highlight.square(gradientRed(.init(d) / 10))
            }
        }.joined(separator: "")
        print("\(line1) \(line2) \(line3)")
    } 
    for i:Int in 0 ..< rectangular.size.y
    {
        for j:Int in 0 ..< rectangular.size.x 
        {
            let y:(UInt8, UInt8) = 
            (
                output[j + i * rectangular.size.x].y,
                expected[j + i * rectangular.size.x].y
            )
            
            if abs(Int.init(y.0) - Int.init(y.1)) > 1 
            {
                print("output = \(y.0), expected = \(y.1)")
            }
        }
    }
    
    var total:Int   = 0, 
        max:Int     = 0
    
    for (a, b):(JPEG.YCbCr, JPEG.YCbCr) in zip(output, expected) 
    {
        let difference:Int = abs(.init(a.y) - .init(b.y))
        
        total += difference 
        max    = Swift.max(max, difference)
    }
    
    return (average: .init(total) / .init(output.count), max: .init(max))
}

func bin(_ value:Double, into histogram:inout [Int], range:Range<Int>)
{
    let u:Double  = (value - .init(range.lowerBound)) / 
        .init(range.count) * .init(histogram.count)
    let b:Int     = max(histogram.startIndex, min(.init(u), histogram.endIndex - 1))
    histogram[b] += 1
}

func print(histogram:[Int], range:Range<Int>, width:Int) 
{
    func gradient(_ x:Double) -> (r:Double, g:Double, b:Double) 
    {
        (1, 1 - 1.5 * (x - 0.4), 1 - x)
    } 
    
    let max:Int = histogram.max() ?? 1
    for (i, count):(Int, Int) in zip(histogram.indices, histogram)
    {
        let a:(Double, Double)  = 
        (
            .init(range.lowerBound), 
            .init(range.upperBound)
        )
        let u:(Double, Double)  = 
        (
            .init(i    ) / .init(histogram.count), 
            .init(i + 1) / .init(histogram.count)
        )
        let x:(Double, Double)  = 
        (
            a.0 * (1 - u.0) + a.1 * u.0,
            a.0 * (1 - u.1) + a.1 * u.1
        )
        
        let rgb:(r:Double, g:Double, b:Double) = gradient(u.0)
        
        let left:String     = Highlight.highlight(
            " \(String.pad("\(x.0)", left: 8)) ..< \(String.pad("\(x.1)", left: 8))", rgb)
        let label:String    = .pad("\(count)", left: 5)
        let right:String    = .init(repeating: "█", count: width * count / max)
        
        print("\(left) \(label) \(right)")
    }
}

let range:(average:Range<Int>, max:Range<Int>) = 
(
    0 ..< 1,
    0 ..< 32
)
var histogram:(average:[Int], max:[Int]) = 
(
    .init(repeating: 0, count: 64),
    .init(repeating: 0, count: 32)
)
for argument:String in CommandLine.arguments.dropFirst()
{
    let (average, max):(Double, Double) = 
        try discrepancy(jpeg: argument, reference: "\(argument).ycc")
    bin(average, into: &histogram.average, range: range.average)
    bin(max,     into: &histogram.max,     range: range.max)
}
print("average discrepancy")
print(histogram: histogram.average, range: range.average, width: 80)
print("maximum discrepancy")
print(histogram: histogram.max,     range: range.max,     width: 80)
