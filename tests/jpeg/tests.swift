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
