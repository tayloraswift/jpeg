#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

var succeeded:Bool = true  
for group:Group in 
[
    .init(name: "decode", expectation: true, functions: .string(Test.decode(_:), 
    [
        ("karlie (99 @ 4:4:4 progressive)", "karlie-kloss-diane-von-fürstenberg-99-4-4-4-p")
    ]))
]
{
    succeeded = group.run(filter: []) && succeeded 
}

exit(succeeded ? 0 : -1)
