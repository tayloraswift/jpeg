import JPEG

extension Test 
{
    static 
    var cases:[(name:String, function:Function)] 
    {
        [
            ("color-sequential-robustness",         .string(Self.decode(_:), 
            [
                "tests/integration/decode/color-sequential-1.jpg",
                "tests/integration/decode/color-sequential-2.jpg",
                "tests/integration/decode/color-sequential-3.jpg",
                "tests/integration/decode/color-sequential-4.jpg",
            ])),
            ("grayscale-sequential-robustness",     .string(Self.decode(_:), 
            [
                "tests/integration/decode/grayscale-sequential-1.jpg",
                "tests/integration/decode/grayscale-sequential-2.jpg",
            ])),
            ("color-progressive-robustness",        .string(Self.decode(_:), 
            [
                "tests/integration/decode/color-progressive-1.jpg",
                "tests/integration/decode/color-progressive-2.jpg",
                "tests/integration/decode/color-progressive-3.jpg",
                "tests/integration/decode/color-progressive-4.jpg",
            ])),
            ("grayscale-progressive-robustness",    .string(Self.decode(_:), 
            [
                "tests/integration/decode/grayscale-progressive-1.jpg",
                "tests/integration/decode/grayscale-progressive-2.jpg",
            ])),
            ("restart-interval-robustness",    .string(Self.decode(_:), 
            [
                "tests/integration/decode/color-sequential-restart.jpg",
                "tests/integration/decode/color-progressive-restart.jpg",
                "tests/integration/decode/grayscale-sequential-restart.jpg",
                "tests/integration/decode/grayscale-progressive-restart.jpg",
            ])),
            
            ("color-sequential-encoding-robustness", .string_int2(Self.encodeColorSequential(_:_:), 
            [
                ("tests/integration/encode/karlie-kloss-1", (640, 320))
            ])),
            ("grayscale-sequential-encoding-robustness", .string_int2(Self.encodeGrayscaleSequential(_:_:), 
            [
                ("tests/integration/encode/karlie-kloss-1", (640, 320))
            ])),
            ("color-progressive-encoding-robustness", .string_int2(Self.encodeColorProgressive(_:_:), 
            [
                ("tests/integration/encode/karlie-kloss-1", (640, 320))
            ])),
            ("grayscale-progressive-encoding-robustness", .string_int2(Self.encodeGrayscaleProgressive(_:_:), 
            [
                ("tests/integration/encode/karlie-kloss-1", (640, 320))
            ])),
        ]
    }
    
    private static 
    func print(image rgb:[JPEG.RGB], size:(x:Int, y:Int)) 
    {
        for i:Int in stride(from: 0, to: size.y, by: 8)
        {
            let line:String = stride(from: 0, to: size.x, by: 8).map 
            {
                (j:Int) in 
                
                // downsampling 
                var r:Int = 0, 
                    g:Int = 0, 
                    b:Int = 0 
                for y:Int in i ..< min(i + 8, size.y) 
                {
                    for x:Int in j ..< min(j + 8, size.x)
                    {
                        let c:JPEG.RGB = rgb[x + y * size.x]
                        r += .init(c.r)
                        g += .init(c.g)
                        b += .init(c.b)
                    }
                }
                
                let count:Int = (min(i + 8, size.y) - i) * (min(j + 8, size.x) - j)
                let c:(r:Float, g:Float, b:Float) = 
                (
                    .init(r) / (255 * .init(count)),
                    .init(g) / (255 * .init(count)),
                    .init(b) / (255 * .init(count))
                )
                return Highlight.square(c)
            }.joined(separator: "")
            Swift.print(line)
        } 
    }
    
    // this test only tries to decode the image without errors, it does not check 
    // for content accuracy
    static 
    func decode(_ path:String) -> Result<Void, Failure> 
    {
        do 
        {
            guard let image:JPEG.Data.Rectangular<JPEG.Common> = try .decompress(path: path)
            else 
            {
                return .failure(.init(message: "failed to open file '\(path)'"))
            }
            
            Swift.print(
            """
            
            \(Highlight.bold)\(path)\(Highlight.reset) (\(image.layout.format))
            {
                size        : (\(image.size.x), \(image.size.y))
                process     : \(image.layout.process)
                precision   : \(image.layout.format.precision)
                components  : 
                [
                    \(image.layout.residents.sorted(by: { $0.key < $1.key }).map 
                    {
                        let (x, y):(Int, Int) = 
                            image.layout.planes[$0.value].component.factor
                        return "\($0.key): (\(x), \(y))"
                    }.joined(separator: "\n        "))
                ]
                scans       : 
                [
                    \(image.layout.scans.map 
                    {
                        "[band: \(String.pad("\($0.band.lowerBound)", left: 2)) ..< \(String.pad("\($0.band.upperBound)", left: 2)), bits: \(String.pad("\($0.bits.lowerBound)", left: 2)) \(String.pad($0.bits.upperBound == .max ? "..." : "..< \("\(String.pad("\($0.bits.upperBound)", left: 2))")", right: 6))]: \($0.components.map(\.ci))"
                    }.joined(separator: "\n        "))
                ]
            }
            """)
            for metadata:JPEG.Metadata in image.metadata
            {
                switch metadata 
                {
                case .jfif(let jfif):
                    Swift.print(jfif)
                case .exif(let exif):
                    Swift.print(exif)
                case .application(let a, data: let data):
                    Swift.print("metadata (application \(a), \(data.count) bytes)")
                case .comment(data: let data):
                    Swift.print("""
                    comment 
                    {
                        '\(String.init(decoding: data, as: Unicode.UTF8.self))'
                    }
                    """)
                }
            }
            
            let rgb:[JPEG.RGB] = image.unpack(as: JPEG.RGB.self)
            // write to rgb file 
            guard let _:Void = try (System.File.Destination.open(path: "\(path).rgb")
            {
                guard let _:Void = $0.write(rgb.flatMap{ [$0.r, $0.g, $0.b] })
                else 
                {
                    throw Failure.init(message: "failed to write to file '\(path).rgb'")
                }
            }) 
            else
            {
                throw Failure.init(message: "failed to open file '\(path).rgb'")
            }
            
            // terminal output 
            Self.print(image: rgb, size: image.size)
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
    
    static 
    func encodeColorSequential(_ path:String, _ size:(x:Int, y:Int)) 
        -> Result<Void, Failure> 
    {
        let format:JPEG.Common              = .ycc8
        let Y:JPEG.Component.Key            = format.components[0],
            Cb:JPEG.Component.Key           = format.components[1],
            Cr:JPEG.Component.Key           = format.components[2]
        let layout:JPEG.Layout<JPEG.Common> = .init(
            format:     format,
            process:    .baseline, 
            components: 
            [
                Y:  (factor: (1, 1), qi: 0), 
                Cb: (factor: (1, 1), qi: 1), 
                Cr: (factor: (1, 1), qi: 1),
            ], 
            scans: 
            [
                .sequential((Y,  \.0, \.0), (Cb, \.1, \.1), (Cr, \.1, \.1))
            ])
        return Self.encode(path, suffix: "-color-sequential", size: size, layout: layout)
    }
    static 
    func encodeGrayscaleSequential(_ path:String, _ size:(x:Int, y:Int)) 
        -> Result<Void, Failure> 
    {
        let format:JPEG.Common              = .y8
        let Y:JPEG.Component.Key            = format.components[0]
        let layout:JPEG.Layout<JPEG.Common> = .init(
            format:     format,
            process:    .baseline, 
            components: 
            [
                Y:  (factor: (1, 1), qi: 0), 
            ], 
            scans: 
            [
                .sequential((Y,  \.0, \.0))
            ])
        return Self.encode(path, suffix: "-grayscale-sequential", size: size, layout: layout)
    }
    static 
    func encodeColorProgressive(_ path:String, _ size:(x:Int, y:Int)) 
        -> Result<Void, Failure> 
    {
        let format:JPEG.Common              = .ycc8
        let Y:JPEG.Component.Key            = format.components[0],
            Cb:JPEG.Component.Key           = format.components[1],
            Cr:JPEG.Component.Key           = format.components[2]
        let layout:JPEG.Layout<JPEG.Common> = .init(
            format:     format,
            process:    .progressive(coding: .huffman, differential: false), 
            components: 
            [
                Y:  (factor: (1, 1), qi: 0), 
                Cb: (factor: (1, 1), qi: 1), 
                Cr: (factor: (1, 1), qi: 1),
            ], 
            scans: 
            [
                .progressive((Y,  \.0), (Cb, \.1), (Cr, \.2),  bits: 2...),
                .progressive( Y,         Cb,        Cr      ,  bit:  1   ),
                .progressive( Y,         Cb,        Cr      ,  bit:  0   ),
                
                .progressive((Y,  \.0),        band: 1 ..< 64, bits: 2...), 
                
                .progressive((Cb, \.0),        band: 1 ..<  6, bits: 1...), 
                .progressive((Cr, \.0),        band: 1 ..<  6, bits: 1...), 
                
                .progressive((Cb, \.0),        band: 6 ..< 64, bits: 1...), 
                .progressive((Cr, \.0),        band: 6 ..< 64, bits: 1...), 
                
                .progressive((Y,  \.0),        band: 1 ..< 64, bit:  1   ), 
                .progressive((Y,  \.0),        band: 1 ..< 64, bit:  0   ), 
                .progressive((Cb, \.0),        band: 1 ..< 64, bit:  0   ), 
                .progressive((Cr, \.0),        band: 1 ..< 64, bit:  0   ), 
            ])
        return Self.encode(path, suffix: "-color-progressive", size: size, layout: layout)
    }
    static 
    func encodeGrayscaleProgressive(_ path:String, _ size:(x:Int, y:Int)) 
        -> Result<Void, Failure> 
    {
        let format:JPEG.Common              = .y8
        let Y:JPEG.Component.Key            = format.components[0]
        let layout:JPEG.Layout<JPEG.Common> = .init(
            format:     format,
            process:    .progressive(coding: .huffman, differential: false), 
            components: 
            [
                Y:  (factor: (1, 1), qi: 0)
            ], 
            scans: 
            [
                .progressive((Y,  \.0),                        bits: 2...),
                .progressive( Y,                               bit:  1   ),
                .progressive( Y,                               bit:  0   ),
                
                .progressive((Y,  \.0),        band: 1 ..<  6, bits: 2...), 
                .progressive((Y,  \.0),        band: 6 ..< 64, bits: 2...), 
                .progressive((Y,  \.0),        band: 1 ..< 64, bit:  1   ), 
                .progressive((Y,  \.0),        band: 1 ..< 64, bit:  0   ), 
            ])
        return Self.encode(path, suffix: "-grayscale-progressive", size: size, layout: layout)
    }
    private static 
    func encode(_ path:String, suffix:String, size:(x:Int, y:Int), layout:JPEG.Layout<JPEG.Common>) 
        -> Result<Void, Failure> 
    {
        do 
        {
            guard let rgb:[JPEG.RGB]    = try (System.File.Source.open(path: "\(path).rgb")
            {
                guard let data:[UInt8]  = $0.read(count: 3 * size.x * size.y)
                else
                {
                    throw Failure.init(message: "failed to read from file '\(path).rgb'")
                }

                return (0 ..< size.x * size.y).map
                {
                    (i:Int) -> JPEG.RGB in 
                    .init(data[i * 3], data[i * 3 + 1], data[i * 3 + 2])
                }
            })
            else 
            {
                throw Failure.init(message: "failed to open file '\(path).rgb'")
            }
            
            var planar:JPEG.Data.Planar<JPEG.Common> = .init(
                size:       size, 
                layout:     layout, 
                metadata:   
                [
                    .jfif(.init(version: .v1_2, density: (1, 1, .centimeters))),
                ])
            
            let ycc:[JPEG.YCbCr] = rgb.map(\.ycc)
            for (ci, p):(JPEG.Component.Key, KeyPath<JPEG.YCbCr, UInt8>) in 
                zip(layout.format.components, [\.y, \.cb, \.cr])
            {
                guard planar.index(forKey: ci) != nil 
                else 
                {
                    continue 
                }
                
                planar.with(ci: ci) 
                {
                    for (x, y):(Int, Int) in $0.indices
                    {
                        $0[x: x, y: y] = .init(ycc[x + y * size.x][keyPath: p])
                    }
                }
            }
            
            let quanta:([UInt16], [UInt16]) = 
            (
                (1 ... 64).map{ 1 +      $0 >> 1      },
                (1 ... 64).map{ 1 + 2 * ($0 & 0xfffe) }
            )
            
            let spectral:JPEG.Data.Spectral<JPEG.Common> = planar.fdct(
                quanta: 
                [
                    0: quanta.0,
                    1: quanta.1,
                ])
            
            guard let _:Void = try spectral.compress(path: "\(path)\(suffix).jpg")
            else 
            {
                fatalError("failed to open file '\(path)\(suffix).jpg'")
            } 
            
            // terminal output 
            let rectangular:JPEG.Data.Rectangular<JPEG.Common> = 
                spectral.idct().interleaved()
            Self.print(image: rectangular.unpack(as: JPEG.RGB.self), size: size)
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
