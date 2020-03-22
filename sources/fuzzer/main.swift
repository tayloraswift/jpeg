import JPEG 

extension JPEG.Bitstream 
{
    static 
    func composites(spectra:JPEG.Data.Spectral.Plane) -> 
        (
            dc:
            (
                initial:[Composite.DC], 
                refining:[Bool]
            ), 
            ac:
            (
                initial:[Composite.AC], 
                refining:[(Composite.AC, [Bool])]
            )
        )
    {
        var dc:(initial:[Composite.DC], refining:[Bool]), 
            ac:(initial:[Composite.AC], refining:[(Composite.AC, [Bool])])
        dc = ([], [])
        ac = ([], [])
        var predecessor:Int = 0
        for y:Int in 0 ..< spectra.units.y
        {
            for x:Int in 0 ..< spectra.units.x 
            {
                let coefficient:Int = spectra[x: x, y: y, z: 0]
                let high:Int = coefficient >> 1,
                    low:Int  = coefficient &  1
                dc.initial.append(.init(difference: high - predecessor))
                dc.refining.append(low != 0)
                predecessor  = high 
                
                
                var zeroes:(high:Int, low:Int)  = (0, 0)
                var refinements:[Bool]          = []
                for z:Int in 1 ..< 64
                {
                    let coefficient:Int = spectra[x: x, y: y, z: z]
                    
                    let sign:Int = coefficient < 0 ? -1 : 1
                    let high:Int = sign * abs(coefficient) >> 1,  
                        low:Int  = coefficient - high << 1
                    
                    if high == 0 
                    {
                        if zeroes.high == 15 
                        {
                            ac.initial.append(.run(zeroes.high, value: 0))
                            zeroes.high = 0 
                        }
                        else 
                        {
                            zeroes.high += 1 
                        }
                        
                        if low == 0 
                        {
                            if zeroes.low == 15 
                            {
                                ac.refining.append((.run(zeroes.low, value: 0), refinements))
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
                            ac.refining.append((.run(zeroes.low, value: low), refinements))
                            refinements = []
                            zeroes.low  = 0
                        }
                    }
                    else 
                    {
                        ac.initial.append(.run(zeroes.high, value: high))
                        zeroes.high = 0
                        
                        refinements.append(low != 0)
                    }
                }
                
                if zeroes.high > 0 
                {
                    ac.initial.append(.eob(1))
                }
                if zeroes.low > 0 || !refinements.isEmpty 
                {
                    ac.refining.append((.eob(1), refinements))
                }
            }
        }
        
        return (dc, ac)
    }
}

func fuzz()
{
    
}

 
/* var heap:Common.Heap<Int, Void> = 
[
    (  3, ()), 
    (  2, ()), 
    (  6, ()), 
    (  9, ()), 
    (  0, ()), 
    ( -1, ()), 
    ( 45, ()), 
    (  0, ()), 
    ( 61, ()), 
    (-55, ()), 
    ( 34, ()), 
    ( 35, ()), 
]
for v:Int in [-66, 4, -11, 60, 135, -9]
{
    heap.enqueue(key: v, value: ())
}

while let (v, _):(Int, Void) = heap.dequeue()
{
    print(v)
}  */

var frequencies:[Int] = .init(repeatElement(1, count: 256))
frequencies[16] = 5
frequencies[17] = 3
frequencies[18] = 10
frequencies[19] = 200
frequencies[20] = 2
frequencies[21] = 60

let table:JPEG.Table.InverseHuffmanDC = .build(frequencies: frequencies, target: \.0)
