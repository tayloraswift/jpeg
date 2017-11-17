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

    let table:[UInt8] = [0, 3, 2, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
                         0x61, 0x62, 0x63, 0x64, 0x65]

    let tree = UnsafeHuffmanTree.create(data: table, coefficientClass: .AC)!
    printHuffmanTree(root: tree.root)

    tree.deallocate()
}

func printHuffmanTree(root:UnsafePointer<UnsafeHuffmanTree.Node>, path:String = "")
{
    switch root.pointee
    {
    case .leafNode(let value):
        print("'\(Unicode.Scalar(value))': \(path)")

    case .internalNode(let left, let right):
        printHuffmanTree(root: left,  path: path + "0")
        printHuffmanTree(root: right, path: path + "1")
    }
}
