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

    let leafCounts:[UInt8] = [0, 3, 1, 1,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0],
        leafValues:[UInt8] = [0x61, 0x62, 0x63, 0x64, 0x65]
    guard let table:UnsafeHuffmanTable = .create(leafCounts: leafCounts, leafValues: leafValues, coefficientClass: .AC)
    else 
    {
        return "failed to generate huffman table"
    }
    defer 
    {
        table.destroy()
    }
    
    var message:UInt16 = 0b110_1110_00_01_10_110, // deabcd
        shifts:Int     = 0, 
        decoded:String = ""
    while (shifts < 16) 
    {
        let entry:UnsafeHuffmanTable.Entry = table[message]
        decoded.append(Character(Unicode.Scalar(entry.value)))
        message = message &<< Int(entry.length)
        shifts += Int(entry.length)
    }
    
    let key:String = "deabcd"
    guard decoded == key, 
          shifts == 16 
    else 
    {
        return "message decoded incorrectly (expected '\(key)', got '\(decoded)')"
    }
    
    return nil
}

public 
func testHuffmanTableDouble() -> String?
{
    // test really skewed tree 
    
    let leafCounts:[UInt8] = [1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1,  1, 1, 1, 1], 
        leafValues:[UInt8] = .init(0x61 ..< 0x61 + 16)
        
    guard let table:UnsafeHuffmanTable = .create(leafCounts: leafCounts, leafValues: leafValues, coefficientClass: .AC)
    else 
    {
        return "failed to generate huffman table"
    }
    defer 
    {
        table.destroy()
    }
    
    var message:UInt32 = 0b1111_1111_1100__1111_1111_1111_1110__1110,
        shifts:Int     = 0, 
        decoded:String = ""
    while (shifts < 32) 
    {
        let entry:UnsafeHuffmanTable.Entry = table[UInt16(truncatingIfNeeded: message >> 16)]
        decoded.append(Character(Unicode.Scalar(entry.value)))
        message = message &<< Int(entry.length)
        shifts += Int(entry.length)
    }

    let key:String = "kapd"
    guard decoded == key, 
          shifts == 32 
    else 
    {
        return "message decoded incorrectly (expected '\(key)', got '\(decoded)')"
    }
    
    return nil
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
