import JPEGTests

let cases:[(group:String, cases:[Case])] = 
[
    (
        "amplitude coding", 
        [            
            (true, "amplitude level coding (1–15)", testAmplitudeDecoding)
        ]
    ), 
    (
        "zig-zag transform", 
        [            
            (true, "zig-zag mapping", testZigZagOrdering)
        ]
    ), 
    (
        "huffman", 
        [            
            (true, "table construction", testHuffmanTableBuilding), 
            (true, "single-level table", testHuffmanTableSingle), 
            (true, "double-level table", testHuffmanTableDouble), 
            (true, "undefined codewords", testHuffmanTableUndefined)
        ]
    ), 
    (
        "decode",
        [
            (true, "oscardelarenta.jpg", testDecode)
        ]
    )
]

runTests(cases)
