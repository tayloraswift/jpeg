@testable import JPEG

#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

public 
func testDecode() -> String? 
{
    do 
    {
        try decode(path: "tests/oscardelarenta.jpg")
    }
    catch 
    {
        return .init(describing: error)
    }
    
    return nil
}
 
func testHuffmanTable(leafCounts:[UInt8], leafValues:[UInt8], message:[UInt8], key:String) -> String?
{
    guard let table:HuffmanTable = 
        .create(leafCounts: leafCounts, leafValues: leafValues, coefficient: .AC)
    else 
    {
        return "failed to generate huffman table"
    }
    
    var bitstream:Bitstream = .init(message), 
        decoded:String = ""
    while let path:UInt16 = bitstream.front
    {
        let entry:HuffmanTable.Entry = table[path]
        bitstream.pop(entry.length)
        decoded.append(Character(Unicode.Scalar(entry.value)))
    }

    guard decoded == key
    else 
    {
        return "message decoded incorrectly (expected '\(key)', got '\(decoded)')"
    }
    
    return nil
}

public
func testHuffmanTableSingle() -> String?
{
    //                  ___0___[root]___1___
    //                /                      \
    //         __0__[ ]__1__            __0__[ ]__1__
    //       /              \         /               \
    //      [a]            [b]      [c]            _0_[ ]_1_
    //                                           /           \
    //                                         [d]        _0_[ ]_1_
    //                                                  /           \
    //                                                [e]        reserved
    
    return testHuffmanTable(leafCounts: [0, 3, 1, 1,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0], 
        leafValues  : .init(0x61 ..< 0x61 + 5), 
        message     : [0b110_1110_0, 0b0_01_10_110], 
        key         : "deabcd")
}

public 
func testHuffmanTableDouble() -> String?
{
    // test really skewed tree 
    return testHuffmanTable(leafCounts: [1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1], 
        leafValues  : .init(0x61 ..< 0x61 + 16), 
        message     : [0b1111_1111, 0b1100__1111, 0b1111_1111, 0b1110__1110],
        key         : "kapd")
}

public 
func testHuffmanTableUndefined() -> String?
{
    // test codewords that do not correspond to encoded leaf nodes
    return testHuffmanTable(leafCounts: [1, 1, 1, 1,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0], 
        leafValues  : .init(0x61 ..< 0x61 + 4), 
        message     : [0b11110_110, 0b11111110, 0b10_10_1110, 0b11111111, 0b11111111], 
        key         : "\0bbd\0")
}

public 
typealias Case = (expectation:Bool, name:String, f:() -> String?)
public 
func runTests(_ cases:[(group:String, cases:[Case])]) -> Never
{
    var passed:Int   = 0, 
        failed:Int   = 0, 
        expected:Int = 0, 
        number:Int   = 0

    let count:Int    = cases.reduce(0){ $0 + $1.cases.count }

    printTestHeader(0, of: count)
    print()
    printProgress(0)
    for (group, cases):(String, [Case]) in cases
    {
        for (i, (expectation, name, testfunc)):(Int, Case) in cases.enumerated() 
        {
            number += 1
            
            let label:String = "(\(group):\(i)) test '\(name)'", 
                output:String
            expected += expectation ? 1 : 0
            if let message:String = testfunc()
            {
                failed += 1
                output  = "\(Colors.red.1)\(label) failed\(Colors.off.0)"
                
                upline(3) 
                print(output)
                print("\(Colors.red.0)\(indent(message, by: 4))\(Colors.off.0)\n")
            }
            else 
            {
                passed += 1
                output  = "\(Colors.green.1)\(label) passed\(Colors.off.0)"
                
                upline(3) 
            }
            
            printTestHeader(number, of: count)
            printCentered(output)
            printProgress(Double(number) / Double(count))
        }
    }

    upline()
    upline()
    printCentered("\(Colors.lightCyan.1)\(passed) passed, \(failed) failed\(Colors.off.0)")
    printProgress(1)
    
    print()
    if passed == expected
    {
        printCentered("\(Colors.pink.1)<3\(Colors.off.0)")
        exit(0)
    }
    else 
    {
        printCentered("\(Colors.pink.1)</3\(Colors.off.0)")
        exit(-1)
    }
}
