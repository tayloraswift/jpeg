enum JPEG 
{
    enum Symbol 
    {
        struct DC 
        {
            private 
            let value:UInt8 
            
            var binade:Int 
            {
                .init(self.value)
            }
        }
        
        struct AC 
        {
            private 
            let value:UInt8
            
            var zeroes:Int
            {
                .init(self.value >> 4)
            }
            var binade:Int 
            {
                .init(self.value & 0x0f)
            }
        }
    }
    
    enum Composite 
    {
        enum DC 
        {
            struct Initial 
            {
                let difference:Int 
            }
            struct Refining 
            {
                let refinement:Bool 
            }
        }
        enum AC 
        {
            enum Initial 
            {
                case run(Int, value:Int)
                case eob(Int)
            }
            
            enum Refining 
            {
                case run(Int, refinements:[Bool], value:Int)
                case eob(Int, refinements:[Bool])
            }
        }
    }
}

enum Fuzz 
{
    func composites(block:[Int]) 
    {
        let composites:
        (
            dc:(initial:JPEG.Composite.DC.Initial, refining:JPEG.Composite.DC.Refining), 
            ac:(initial:[JPEG.Composite.AC.Initial], refining:[JPEG.Composite.AC.Refining])
        )
        
        composites.dc.initial  = .init(difference: block[0] >> 1)
        composites.dc.refining = .init(refinement: block[0] & 1 != 0)
        
        composites.ac.initial  = []
        composites.ac.refining = []
        var zeroes:(high:Int, low:Int)  = (0, 0)
        var refinements:[Bool]          = 0
        for coefficient:Int in block[1 ..< 64] 
        {
            let sign:Int                    = coefficient < 0 ? -1 : 1
            let value:(high:Int, low:Int)   = 
            (
                sign * abs(coefficient) >> 1, 
                coefficient - high << 1
            )
            
            if value.high == 0 
            {
                if zeroes.high == 15 
                {
                    composites.ac.initial.append(.run(zeroes.high, value: 0))
                    zeroes.high = 0 
                }
                else 
                {
                    zeroes.high += 1 
                }
                
                if value.low == 0 
                {
                    if zeroes.low == 15 
                    {
                        composites.ac.refining.append(.run(zeroes.low, refinements: refinements, value: 0))
                        refinements = []
                        zeroes.low  = 0
                    }
                    else 
                    {
                        zeroes.low += 1
                    }
                }
                else 
                {
                    composites.ac.refining.append(.run(zeroes.low, refinements: refinements, value: value.low))
                    refinements = []
                    zeroes.low  = 0
                }
            }
            else 
            {
                composites.ac.initial.append(.run(zeroes.high, value: value.high))
                zeroes.high = 0
                
                refinements.append(value.low != 0)
            }
        }
        
        if zeroes.high > 0 
        {
            composites.ac.initial.append(.eob(1))
        }
        if zeroes.low > 0 || !refinements.isEmpty 
        {
            composites.ac.refining.append(.eob(1, refinements: refinements))
        }
    }
}
