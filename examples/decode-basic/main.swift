import JPEG

let path:String = "examples/decode-basic/karlie-kwk-2019.jpg"

guard let image:JPEG.Data.Rectangular<JPEG.Common> = try .decompress(path: path)
else 
{
    fatalError("failed to open file '\(path)'")
}

let rgb:[JPEG.RGB] = image.unpack(as: JPEG.RGB.self)
guard let _:Void = (System.File.Destination.open(path: "\(path).rgb")
{
    guard let _:Void = $0.write(rgb.flatMap{ [$0.r, $0.g, $0.b] })
    else 
    {
        fatalError("failed to write to file '\(path).rgb'")
    }
}) 
else
{
    fatalError("failed to open file '\(path).rgb'")
}
