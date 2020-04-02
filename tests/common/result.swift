enum Test 
{
    struct Failure:Swift.Error 
    {
        let message:String 
    }
    
    enum Function 
    {
        case void(  ()         -> Result<Void, Failure>)
        case string((String)   -> Result<Void, Failure>, [String])
    }
}

func test(_ function:Test.Function, name:String)
{
    var successes:Int                               = 0
    var failures:[(name:String?, message:String)]   = []
    switch function 
    {
    case .void(let function):
        switch function()
        {
        case .success:
            successes += 1
        case .failure(let failure):
            failures.append((nil, failure.message))
        }
    case .string(let function, let cases):
        for argument:String in cases 
        {
            switch function(argument)
            {
            case .success:
                successes += 1
            case .failure(let failure):
                failures.append((argument, failure.message))
            }
        }
    }
    
    var width:Int 
    {
        80
    }
    var white:(Double, Double, Double)
    {
        (1, 1, 1)
    }
    var red:(Double, Double, Double)
    {
        (1, 0.4, 0.3)
    }
    switch (successes, failures.count)
    {
    case (1, 0):
        Highlight.print(.pad(" test '\(name)' passed ", right: width), highlight: white)
    case (let succeeded, 0):
        Highlight.print(.pad(" test '\(name)' passed (\(succeeded) cases)", right: width), highlight: white)
    case (0, 1):
        Highlight.print(.pad(" test '\(name)' failed ", right: width), highlight: red)
    case (let succeeded, let failed):
        Highlight.print(.pad(" test '\(name)' failed (\(succeeded + failed) cases, \(failed) failed)", right: width), highlight: red)
    }
    for (i, failure):(Int, (name:String?, message:String)) in failures.enumerated() 
    {
        if let name:String = failure.name 
        {
            Highlight.print(" [\(String.pad("\(i)", left: 2))] case '\(name)' failed: \(failure.message)", color: red)
        }
        else 
        {
            Highlight.print(" [\(String.pad("\(i)", left: 2))]: \(failure.message)", color: red)
        }
    }
}
