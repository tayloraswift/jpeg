import JPEG

extension Test 
{
    static 
    var cases:[(name:String, function:Function)] 
    {
        [
            ("color-sequential-regression",         .string(Self.test(_:), 
            [
                "tests/regression/gold/color-sequential-1.jpg",
                "tests/regression/gold/color-sequential-2.jpg",
                "tests/regression/gold/color-sequential-3.jpg",
                "tests/regression/gold/color-sequential-4.jpg",
            ])),
            ("grayscale-sequential-regression",     .string(Self.test(_:), 
            [
                "tests/regression/gold/grayscale-sequential-1.jpg",
                "tests/regression/gold/grayscale-sequential-2.jpg",
            ])),
            ("color-progressive-regression",        .string(Self.test(_:), 
            [
                "tests/regression/gold/color-progressive-1.jpg",
                "tests/regression/gold/color-progressive-2.jpg",
                "tests/regression/gold/color-progressive-3.jpg",
                "tests/regression/gold/color-progressive-4.jpg",
            ])),
            ("grayscale-progressive-regression",    .string(Self.test(_:), 
            [
                "tests/regression/gold/grayscale-progressive-1.jpg",
                "tests/regression/gold/grayscale-progressive-2.jpg",
            ])),
        ]
    }
    
    // this test attempts to decode the given image, and compares it to the golden 
    // outputs in the same directory
    static 
    func test(_ path:String) -> Result<Void, Failure> 
    {
        do 
        {
            guard let image:JPEG.Data.Rectangular<JPEG.Common> = try .decompress(path: path)
            else 
            {
                throw Failure.init(message: "failed to open file '\(path)'")
            }
            
            let ycc:[JPEG.YCbCr]        = image.pixels(as: JPEG.YCbCr.self)
            guard let gold:[JPEG.YCbCr] = try (Common.File.Source.open(path: "\(path).ycc")
            {
                guard let data:[UInt8] = $0.read(count: 3 * ycc.count)
                else
                {
                    throw Failure.init(message: "failed to read from file '\(path).ycc'")
                }

                return (0 ..< ycc.count).map
                {
                    let y:UInt8  = data[$0 * 3    ],
                        cb:UInt8 = data[$0 * 3 + 1],
                        cr:UInt8 = data[$0 * 3 + 2]
                    return .init(y: y, cb: cb, cr: cr)
                }
            }) 
            else
            {
                // write new golden output if there is none at the given location 
                guard let _:Void = try (Common.File.Destination.open(path: "\(path).ycc")
                {
                    guard let _:Void = $0.write(ycc.flatMap{ [$0.y, $0.cb, $0.cr] })
                    else 
                    {
                        throw Failure.init(message: "failed to write to file '\(path).ycc'")
                    }
                }) 
                else
                {
                    throw Failure.init(message: "failed to open file '\(path).ycc'")
                }
                
                throw Failure.init(message: 
                    "no golden output for '\(path)' (new golden output written to '\(path).ycc')")
            }
            
            guard ycc == gold 
            else 
            {
                throw Failure.init(message: "decoded output does not match golden output")
            }
            
            return .success(())
        }
        catch 
        {
            if      let error:Failure    = error as? Failure  
            {
                return .failure(error)
            }
            else if let error:JPEG.Error = error as? JPEG.Error 
            {
                return .failure(.init(message: error.message))
            }
            else 
            {
                return .failure(.init(message: "\(error)"))
            }
        }
    }
}
