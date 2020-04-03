import JPEG

extension Test 
{
    static 
    var cases:[(name:String, function:Function)] 
    {
        [
            ("color-sequential-robustness",         .string(Self.test(_:), 
            [
                "tests/integration/data/color-sequential-1.jpg",
                "tests/integration/data/color-sequential-2.jpg",
                "tests/integration/data/color-sequential-3.jpg",
                "tests/integration/data/color-sequential-4.jpg",
            ])),
            ("grayscale-sequential-robustness",     .string(Self.test(_:), 
            [
                "tests/integration/data/grayscale-sequential-1.jpg",
                "tests/integration/data/grayscale-sequential-2.jpg",
            ])),
            ("color-progressive-robustness",        .string(Self.test(_:), 
            [
                "tests/integration/data/color-progressive-1.jpg",
                "tests/integration/data/color-progressive-2.jpg",
                "tests/integration/data/color-progressive-3.jpg",
                "tests/integration/data/color-progressive-4.jpg",
            ])),
            ("grayscale-progressive-robustness",    .string(Self.test(_:), 
            [
                "tests/integration/data/grayscale-progressive-1.jpg",
                "tests/integration/data/grayscale-progressive-2.jpg",
            ])),
        ]
    }
    
    // this test only tries to decode the image without errors, it does not check 
    // for content accuracy
    static 
    func test(_ path:String) -> Result<Void, Failure> 
    {
        do 
        {
            guard let image:JPEG.Data.Rectangular<JPEG.Common> = try .decompress(path: path)
            else 
            {
                return .failure(.init(message: "failed to open file '\(path)'"))
            }
            
            print(
            """
            
            \(Highlight.bold)\(path)\(Highlight.reset) (\(image.properties.format))
            {
                size        : (\(image.size.x), \(image.size.y))
                process     : \(image.properties.process)
                precision   : \(image.properties.format.precision)
                components  : 
                [
                    \(image.properties.components.sorted(by: { $0.key < $1.key }).map 
                    {
                        "[\($0.key)]: (\($0.value.x), \($0.value.y))"
                    }.joined(separator: "\n        "))
                ]
            }
            """)
            for metadata:JPEG.Metadata in image.properties.metadata
            {
                switch metadata 
                {
                case .jfif(let jfif):
                    print(jfif)
                case .unknown(application: let a, let data):
                    print("metadata (application \(a))")
                    print(data)
                }
            }
            
            // terminal output 
            let rgb:[JPEG.RGB] = image.pixels(as: JPEG.RGB.self)
            for i:Int in stride(from: 0, to: image.size.y, by: 8)
            {
                let line:String = stride(from: 0, to: image.size.x, by: 8).map 
                {
                    (j:Int) in 
                    
                    // downsampling 
                    var r:Int = 0, 
                        g:Int = 0, 
                        b:Int = 0 
                    for y:Int in i ..< min(i + 8, image.size.y) 
                    {
                        for x:Int in j ..< min(j + 8, image.size.x)
                        {
                            let c:JPEG.RGB = rgb[x + y * image.size.x]
                            r += .init(c.r)
                            g += .init(c.g)
                            b += .init(c.b)
                        }
                    }
                    
                    let count:Int = 
                        (min(i + 8, image.size.y) - i) * (min(j + 8, image.size.x) - j)
                    let c:(r:Float, g:Float, b:Float) = 
                    (
                        .init(r) / (255 * .init(count)),
                        .init(g) / (255 * .init(count)),
                        .init(b) / (255 * .init(count))
                    )
                    return Highlight.square(c)
                }.joined(separator: "")
                print(line)
            } 
        }
        catch 
        {
            if let error:JPEG.Error = error as? JPEG.Error 
            {
                return .failure(.init(message: error.message))
            }
            else 
            {
                return .failure(.init(message: "\(error)"))
            }
        }
        
        return .success(())
    }
}
