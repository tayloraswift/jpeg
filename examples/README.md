# swift jpeg tutorials

* [basic decoding](#basic-decoding) ([sources](decode-basic/))
* [basic encoding](#basic-encoding) ([sources](encode-basic/))
* [lossless rotations](#lossless-rotations) ([sources](rotate/))
* [increasing a file’s compression level](#increasing-a-files-compression-level) ([sources](recompress/))

## basic decoding

On platforms with built-in file system support (MacOS, Linux), decoding a JPEG file to a pixel array takes just two function calls.

```swift 
guard let image:JPEG.Data.Rectangular<JPEG.Common> = 
    try .decompress(path: "examples/decode-basic/karlie-kwk-2019.jpg")
else 
{
    fatalError("failed to open file '\(path)'")
}

let rgb:[JPEG.RGB] = image.unpack(as: JPEG.RGB.self)
```

The pixel unpacking can also be done with the `JPEG.YCbCr` built-in target, to obtain an image in its native [YCbCr](https://en.wikipedia.org/wiki/YCbCr) color space.

The `unpack(as:)` method is non-mutating, so you can unpack the same image to multiple color targets without having to re-decode the file each time.

> *Karlie Kloss at Kode With Klossy 2019 (photo by Shantell Martin)*

<img src="decode-basic/karlie-kwk-2019.jpg" alt="output (as png)" width=512/>
> original jpeg file 

<img src="decode-basic/karlie-kwk-2019.jpg.rgb.png" alt="output (as png)" width=512/>
> decoded jpeg image, saved in png format
