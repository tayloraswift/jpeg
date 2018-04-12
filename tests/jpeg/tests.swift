@testable import JPEG

public
func testHuffmanTable()
{
    //                  ___0___[root]___1___
    //                /                      \
    //         __0__[ ]__1__            __0__[ ]__1__
    //       /              \         /               \
    //      [a]            [b]      [c]            _0_[ ]_1_
    //                                           /           \
    //                                         [d]           [e]

    let leafCounts:[UInt8] = [0, 3, 2, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0],
        leafValues:[UInt8] = [0x61, 0x62, 0x63, 0x64, 0x65]

    guard let table:UnsafeHuffmanTable = .create(leafCounts: leafCounts, leafValues: leafValues, coefficientClass: .AC)
    else 
    {
        fatalError()
    }
    defer 
    {
        table.destroy()
    }
    
    var message:UInt16 = 0b110_111_10_00_01_00_10, // decabac
        shifts:Int     = 0
    while (shifts < 16) 
    {
        let entry:UnsafeHuffmanTable.Entry = table[message]
        print(entry.length, Unicode.Scalar(entry.value))
        message = message &<< Int(entry.length)
        shifts += Int(entry.length)
    }
    
    print(shifts)
}
