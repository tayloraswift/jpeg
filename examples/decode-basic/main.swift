import JPEG

do 
{
    guard let image:JPEG.Data.Rectangular<JPEG.Common> = 
        try .decompress(path: "examples/decode-basic/karlie-kwk-2019.jpg")
    else 
    {
        fatalError("failed to open file")
    }
    
    print(image)
}
catch let error 
{
    print(error)
}
