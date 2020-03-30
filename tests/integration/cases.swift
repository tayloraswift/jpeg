struct Filter:Hashable
{
    let group:String?
    let test:String? 
    
    static 
    func ~= (lhs:Self, rhs:(group:String, test:String)) -> Bool 
    {
        if let group:String = lhs.group, group != rhs.group 
        {
            return false 
        }
        if let test:String = lhs.test, test != rhs.test 
        {
            return false 
        }
        return true 
    }
}

struct Group 
{
    enum Functions 
    {
        case void(  ()         -> String?, [(name:String, argument:Void)])
        case string((String)   -> String?, [(name:String, argument:String)])
    }
    
    let name:String 
    let expectation:Bool 
    let functions:Functions 
    
    func run(filter _:Set<Filter>) -> Bool 
    {
        var successes:Int                            = 0, 
            failures:[(name:String, message:String)] = []
        switch self.functions 
        {
        case .void(let function, let cases):
            for (name, _):(String, Void) in cases 
            {
                if let message:String = function() 
                {
                    failures.append((name, message))
                }
                else 
                {
                    successes += 1
                }
            }
        case .string(let function, let cases):
            for (name, argument):(String, String) in cases 
            {
                if let message:String = function(argument) 
                {
                    failures.append((name, message))
                }
                else 
                {
                    successes += 1
                }
            }
        }
        
        Highlight.print(" test group '\(self.name)' completed with \(successes) \(successes == 1 ? "success" : "successes") and \(failures.count) \(failures.count == 1 ? "failure" : "failures") ", (1, 1, 1))
        for (name, message):(String, String) in failures 
        {
            Swift.print("    test '\(self.name):\(name)' failed: \(message)")
        }
        
        return failures.count == 0 || !self.expectation
    }
}
