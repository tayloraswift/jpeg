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
            
            let output:(ycc:[JPEG.YCbCr], rgb:[JPEG.RGB]) = 
            (
                image.unpack(as: JPEG.YCbCr.self), 
                image.unpack(as: JPEG.RGB.self)
            )
            guard   let ycc:[JPEG.YCbCr] = try (System.File.Source.open(path: "\(path).ycc")
            {
                guard let data:[UInt8] = $0.read(count: 3 * output.ycc.count)
                else
                {
                    throw Failure.init(message: "failed to read from file '\(path).ycc'")
                }

                return (0 ..< output.ycc.count).map
                {
                    (i:Int) -> JPEG.YCbCr in 
                    .init(y: data[i * 3], cb: data[i * 3 + 1], cr: data[i * 3 + 2])
                }
            }), 
                    let rgb:[JPEG.RGB]   = try (System.File.Source.open(path: "\(path).rgb")
            {
                guard let data:[UInt8] = $0.read(count: 3 * output.rgb.count)
                else
                {
                    throw Failure.init(message: "failed to read from file '\(path).rgb'")
                }

                return (0 ..< output.rgb.count).map
                {
                    (i:Int) -> JPEG.RGB in 
                    .init(data[i * 3], data[i * 3 + 1], data[i * 3 + 2])
                }
            })
            else
            {
                // write new golden output if there is none at the given location 
                guard let _:Void = try (System.File.Destination.open(path: "\(path).ycc")
                {
                    guard let _:Void = $0.write(output.ycc.flatMap{ [$0.y, $0.cb, $0.cr] })
                    else 
                    {
                        throw Failure.init(message: "failed to write to file '\(path).ycc'")
                    }
                }) 
                else
                {
                    throw Failure.init(message: "failed to open file '\(path).ycc'")
                }
                
                guard let _:Void = try (System.File.Destination.open(path: "\(path).rgb")
                {
                    guard let _:Void = $0.write(output.rgb.flatMap{ [$0.r, $0.g, $0.b] })
                    else 
                    {
                        throw Failure.init(message: "failed to write to file '\(path).rgb'")
                    }
                }) 
                else
                {
                    throw Failure.init(message: "failed to open file '\(path).rgb'")
                }
                
                throw Failure.init(message: 
                    "no golden output for '\(path)' (new golden output written to '\(path).ycc', '\(path).rgb')")
            }
            
            guard output.ycc == ycc, output.rgb == rgb
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
