import JPEG

enum Parameter:String 
{
    case rotation
}
enum Rotation:String
{
    case ii, iii, iv
}

enum Block 
{
    typealias Coefficient = (z:Int, multiplier:Int16)
    
    static 
    func transpose(_ input:[Coefficient]) -> [Coefficient]
    {
        (0 ..< 8).flatMap 
        {
            (y:Int) in 
            (0 ..< 8).map 
            {
                (x:Int) in 
                input[8 * x + y]
            }
        }
    }
    static 
    func reflectVertical(_ input:[Coefficient]) -> [Coefficient]
    {
        (0 ..< 8).flatMap 
        {
            (y:Int) -> [Coefficient] in 
            (0 ..< 8).map 
            {
                (x:Int) -> Coefficient in 
                (
                    input[8 * y + x].z, 
                    input[8 * y + x].multiplier * (1 - 2 * (.init(y) & 1))
                )
            }
        }
    }
    static 
    func reflectHorizontal(_ input:[Coefficient]) -> [Coefficient]
    {
        (0 ..< 8).flatMap 
        {
            (y:Int) -> [Coefficient] in 
            (0 ..< 8).map 
            {
                (x:Int) -> Coefficient in 
                (
                    input[8 * y + x].z, 
                    input[8 * y + x].multiplier * (1 - 2 * (.init(x) & 1))
                )
            }
        }
    }
    
    static 
    func transform(_ body:([Coefficient]) -> [Coefficient]) -> [Coefficient]
    {
        let blank:[Coefficient] = (0 ..< 8).flatMap 
        {
            (y:Int) -> [Coefficient] in 
            (0 ..< 8).map 
            {
                (x:Int) in 
                (JPEG.Table.Quantization.z(k: x, h: y), 1)
            }
        }
        let result:[Coefficient] = body(blank)
        let zigzag:[Coefficient] = .init(unsafeUninitializedCapacity: 64)
        {
            for h:Int in 0 ..< 8
            {
                for k:Int in 0 ..< 8 
                {
                    let z:Int   = JPEG.Table.Quantization.z(k: k, h: h)
                    $0[z]       = result[8 * h + k]
                }
            }
            $1 = 64
        }
        return zigzag
    }
}

func rotate(_ rotation:Rotation, input:String, output:String) throws 
{
    guard var original:JPEG.Data.Spectral<JPEG.Common> = try .decompress(path: input)
    else 
    {
        fatalError("failed to open file '\(input)'")
    } 
    
    let scale:(x:Int, y:Int) = original.layout.scale 
    
    let mapping:[Block.Coefficient]
    let matrix:(x:(x:Int, y:Int), y:(x:Int, y:Int))
    let size:(x:Int, y:Int)
    switch rotation 
    {
    case .ii:
        original.set(width:  original.size.x - original.size.x % (8 * scale.x))
        size = (original.size.y, original.size.x)
        mapping = Block.transform 
        {
            Block.reflectVertical(Block.transpose($0))
        }
        matrix  = 
        (
            ( 0,  1), 
            (-1,  0)
        )
        
    case .iii:
        original.set(width:  original.size.x - original.size.x % (8 * scale.x))
        original.set(height: original.size.y - original.size.y % (8 * scale.y))
        size = original.size 
        mapping = Block.transform 
        {
            Block.reflectVertical(Block.reflectHorizontal($0))
        }
        matrix  = 
        (
            (-1,  0), 
            ( 0, -1)
        )
    case .iv:
        original.set(height: original.size.y - original.size.y % (8 * scale.y))
        size = (original.size.y, original.size.x)
        mapping = Block.transform 
        {
            Block.reflectHorizontal(Block.transpose($0))
        }
        matrix  = 
        (
            ( 0, -1), 
            ( 1,  0)
        )
    }
    
    var rotated:JPEG.Data.Spectral<JPEG.Common> = .init(
        size:       size, 
        layout:     original.layout, 
        metadata:   original.metadata, 
        quanta:     original.quanta.mapValues 
        {
            (old:[UInt16]) in 
            .init(unsafeUninitializedCapacity: 64)
            {
                for z:Int in 0 ..< 64 
                {
                    $0[z] = old[mapping[z].z]
                }
                
                $1 = 64
            }
        }) 
    
    // loop through planes 
    for p:(Int, Int) in zip(original.indices, rotated.indices)
    {
        let period:(x:Int, y:Int) = original[p.0].units
        let offset:(x:Int, y:Int) = 
        (
            (matrix.x.x < 0 ? period.x - 1 : 0) + (matrix.x.y < 0 ? period.y - 1 : 0),
            (matrix.y.x < 0 ? period.x - 1 : 0) + (matrix.y.y < 0 ? period.y - 1 : 0)
        )
        // loop through blocks 
        for s:(x:Int, y:Int) in original[p.0].indices 
        {
            let d:(x:Int, y:Int) = 
            (
                offset.x + matrix.x.x * s.x + matrix.x.y * s.y, 
                offset.y + matrix.y.x * s.x + matrix.y.y * s.y
            )
            
            // loop through coefficients 
            for z:Int in 0 ..< 64 
            {
                rotated[p.1][x: d.x, y: d.y, z: z] = 
                    original[p.0][x: s.x, y: s.y, z: mapping[z].z] * mapping[z].multiplier
            }
        }
    }
    
    guard let _:Void = try rotated.compress(path: output)
    else 
    {
        fatalError("failed to open file '\(output)'")
    } 
}

var parameter:Parameter?    = nil 
var rotation:Rotation       = .ii
var input:String?           = nil, 
    output:String?          = nil 
for argument:String in CommandLine.arguments.dropFirst()
{
    if argument.prefix(2) == "--"
    {
        guard let p:Parameter = Parameter.init(rawValue: .init(argument.dropFirst(2)))
        else 
        {
            fatalError("unrecognized parameter '\(argument)'")
        }
        
        parameter = p 
    }
    else 
    {
        switch parameter 
        {
        case nil:
            if input == nil 
            {
                input  = argument 
            }
            else 
            {
                output = argument 
            }
        
        case .rotation?:
            guard let r:Rotation = Rotation.init(rawValue: argument)
            else 
            {
                fatalError("'\(argument)' is not a valid rotation specifier (must be 'ii', 'iii', or 'iv')")
            }
            
            rotation = r
        }
    }
}

if  let input:String  = input, 
    let output:String = output 
{
    try rotate(rotation, input: input, output: output)
}
