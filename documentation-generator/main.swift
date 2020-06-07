enum ParsingError:Swift.Error 
{
    case unexpectedEOS(expected:Parseable.Type)
    case unexpected(String, expected:Parseable.Type)
    
    static 
    func unexpected(_ tokens:[Character], _ position:Int, expected:Parseable.Type) -> Self 
    {
        if tokens.indices ~= position 
        {
            return .unexpected(.init(tokens[position]), expected: expected)
        }
        else 
        {
            return .unexpectedEOS(expected: expected)
        }
    }
}

protocol Parseable 
{
    typealias TerminalClass = _ParseableTerminalClass
    typealias Terminal      = _ParseableTerminal
    static 
    func parse(_:[Character], position:inout Int) throws -> Self 
}
protocol _ParseableTerminalClass:Parseable
{
    init(character:Character)
    
    static 
    func test(_ character:Character) -> Bool 
}
extension Parseable.TerminalClass 
{
    static 
    func parse(_ tokens:[Character], position:inout Int) throws -> Self
    {
        guard tokens.indices ~= position 
        else 
        {
            throw ParsingError.unexpectedEOS(expected: Self.self)
        }
        if Self.test(tokens[position]) 
        {
            defer 
            {
                position += 1
            }
            return .init(character: tokens[position])
        }
        else 
        {
            throw ParsingError.unexpected(tokens, position, expected: Self.self)
        }
    }
}
protocol _ParseableTerminal:Parseable
{
    init()
    
    static 
    var token:String 
    {
        get 
    }
}
extension Parseable.Terminal
{
    static 
    func parse(_ tokens:[Character], position:inout Int) throws -> Self
    {
        let count:Int = Self.token.count
        guard position + count <= tokens.endIndex 
        else 
        {
            throw ParsingError.unexpectedEOS(expected: Self.self)
        }
        let characters:[Character] = .init(tokens[position ..< position + count])
        if characters == .init(Self.token)
        {
            position += count 
            return .init()
        }
        else 
        {
            throw ParsingError.unexpected(.init(characters), expected: Self.self)
        }
    }
}

enum Token 
{
    struct Wildcard:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            return !character.isNewline
        }
    } 
    struct BalancedContent:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            return !character.isNewline && 
                character != "(" && 
                character != ")" &&
                character != "[" &&
                character != "]" &&
                character != "{" &&
                character != "}"
        }
    } 
    struct ASCIIDigit:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            return character.isWholeNumber && character.isASCII
        }
    } 
    struct Darkspace:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            return !character.isWhitespace
        }
    } 
    struct Newline:Parseable.TerminalClass 
    {
        init(character _:Character) 
        {
        }
        
        static 
        func test(_ character:Character) -> Bool 
        {
            character.isNewline
        }
    }
    // does not include newlines 
    struct Space:Parseable.TerminalClass
    {
        init(character _:Character) 
        {
        }
        
        static 
        func test(_ character:Character) -> Bool 
        {
            character.isWhitespace && !character.isNewline
        }
    }
    enum Parenthesis 
    {
        struct Left:Parseable.Terminal
        {
            static 
            let token:String = "("
        }
        struct Right:Parseable.Terminal
        {
            static 
            let token:String = ")"
        }
    }
    enum Bracket 
    {
        struct Left:Parseable.Terminal
        {
            static 
            let token:String = "["
        }
        struct Right:Parseable.Terminal
        {
            static 
            let token:String = "]"
        }
    }
    enum Brace 
    {
        struct Left:Parseable.Terminal
        {
            static 
            let token:String = "{"
        }
        struct Right:Parseable.Terminal
        {
            static 
            let token:String = "}"
        }
    }
    enum Angle 
    {
        struct Left:Parseable.Terminal
        {
            static 
            let token:String = "<"
        }
        struct Right:Parseable.Terminal
        {
            static 
            let token:String = ">"
        }
    }
    struct Question:Parseable.Terminal
    {
        static 
        let token:String = "?"
    }
    struct Comma:Parseable.Terminal
    {
        static 
        let token:String = ","
    }
    struct Period:Parseable.Terminal
    {
        static 
        let token:String = "."
    }
    struct Colon:Parseable.Terminal
    {
        static 
        let token:String = ":"
    } 
    struct Equals:Parseable.Terminal
    {
        static 
        let token:String = "="
    } 
    struct At:Parseable.Terminal
    {
        static 
        let token:String = "@"
    } 
    struct Ampersand:Parseable.Terminal
    {
        static 
        let token:String = "&"
    } 
    struct Hyphen:Parseable.Terminal
    {
        static 
        let token:String = "-"
    } 
    struct Hashtag:Parseable.Terminal
    {
        static 
        let token:String = "#"
    } 
    struct EqualsEquals:Parseable.Terminal
    {
        static 
        let token:String = "=="
    } 
    struct Arrow:Parseable.Terminal
    {
        static 
        let token:String = "->"
    } 
    struct Ellipsis:Parseable.Terminal
    {
        static 
        let token:String = "..."
    } 
    
    struct Throws:Parseable.Terminal
    {
        static 
        let token:String = "throws"
    } 
    struct Rethrows:Parseable.Terminal
    {
        static 
        let token:String = "rethrows"
    } 
    struct Final:Parseable.Terminal
    {
        static 
        let token:String = "final"
    } 
    struct Static:Parseable.Terminal 
    {
        static 
        let token:String = "static"
    }
    /* struct Override:Parseable.Terminal
    {
        static 
        let token:String = "override"
    }  */
    
    static 
    func isIdentifierHead(_ scalar:Unicode.Scalar) -> Bool 
    {
        switch scalar 
        {
        case    "a" ... "z", 
                "A" ... "Z",
                "_", 
                
                "\u{00A8}", "\u{00AA}", "\u{00AD}", "\u{00AF}", 
                "\u{00B2}" ... "\u{00B5}", "\u{00B7}" ... "\u{00BA}",
                
                "\u{00BC}" ... "\u{00BE}", "\u{00C0}" ... "\u{00D6}", 
                "\u{00D8}" ... "\u{00F6}", "\u{00F8}" ... "\u{00FF}",
                
                "\u{0100}" ... "\u{02FF}", "\u{0370}" ... "\u{167F}", "\u{1681}" ... "\u{180D}", "\u{180F}" ... "\u{1DBF}", 
                
                "\u{1E00}" ... "\u{1FFF}", 
                
                "\u{200B}" ... "\u{200D}", "\u{202A}" ... "\u{202E}", "\u{203F}" ... "\u{2040}", "\u{2054}", "\u{2060}" ... "\u{206F}",
                
                "\u{2070}" ... "\u{20CF}", "\u{2100}" ... "\u{218F}", "\u{2460}" ... "\u{24FF}", "\u{2776}" ... "\u{2793}",
                
                "\u{2C00}" ... "\u{2DFF}", "\u{2E80}" ... "\u{2FFF}",
                
                "\u{3004}" ... "\u{3007}", "\u{3021}" ... "\u{302F}", "\u{3031}" ... "\u{303F}", "\u{3040}" ... "\u{D7FF}",
                
                "\u{F900}" ... "\u{FD3D}", "\u{FD40}" ... "\u{FDCF}", "\u{FDF0}" ... "\u{FE1F}", "\u{FE30}" ... "\u{FE44}", 
                
                "\u{FE47}" ... "\u{FFFD}", 
                
                "\u{10000}" ... "\u{1FFFD}", "\u{20000}" ... "\u{2FFFD}", "\u{30000}" ... "\u{3FFFD}", "\u{40000}" ... "\u{4FFFD}", 
                
                "\u{50000}" ... "\u{5FFFD}", "\u{60000}" ... "\u{6FFFD}", "\u{70000}" ... "\u{7FFFD}", "\u{80000}" ... "\u{8FFFD}", 
                
                "\u{90000}" ... "\u{9FFFD}", "\u{A0000}" ... "\u{AFFFD}", "\u{B0000}" ... "\u{BFFFD}", "\u{C0000}" ... "\u{CFFFD}", 
                
                "\u{D0000}" ... "\u{DFFFD}", "\u{E0000}" ... "\u{EFFFD}"
                :
            return true 
        default:
            return false
        }
    }
    static 
    func isIdentifierScalar(_ scalar:Unicode.Scalar) -> Bool 
    {
        if Self.isIdentifierHead(scalar) 
        {
            return true 
        }
        switch scalar 
        {
        case    "0" ... "9", 
                "\u{0300}" ... "\u{036F}", 
                "\u{1DC0}" ... "\u{1DFF}", 
                "\u{20D0}" ... "\u{20FF}", 
                "\u{FE20}" ... "\u{FE2F}"
                :
            return true 
        default:
            return false
        }
    }
    
    struct IdentifierHead:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            guard   let first:Unicode.Scalar = character.unicodeScalars.first, 
                    Token.isIdentifierHead(first)
            else 
            {
                return false 
            }
            
            return character.unicodeScalars.dropFirst().allSatisfy(Token.isIdentifierScalar(_:))
        }
    } 
    struct Identifier:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            return character.unicodeScalars.allSatisfy(Token.isIdentifierScalar(_:))
        }
    } 
}

extension Optional:Parseable where Wrapped:Parseable 
{
    static 
    func parse(_ tokens:[Character], position:inout Int) -> Self 
    {
        let reset:Int = position 
        do 
        {
            return .some(try .parse(tokens, position: &position))
        }
        catch 
        {
            position = reset 
            return nil 
        }
    }
    
    // can’t be declared as protocol extension because then it would have to 
    // be marked `throws`
    static 
    func parse(_ string:String) -> Self 
    {
        Self.parse([Character].init(string))
    }
    static 
    func parse(_ tokens:[Character]) -> Self 
    {
        var c:Int = tokens.startIndex
        return Self.parse(tokens, position: &c)
    }
}
extension Array:Parseable where Element:Parseable
{
    static 
    func parse(_ tokens:[Character], position:inout Int) -> Self
    {
        var array:[Element] = []
        while let next:Element = .parse(tokens, position: &position) 
        {
            array.append(next)
        }
        
        return array
    }
    
    static 
    func parse(_ string:String) -> Self 
    {
        Self.parse([Character].init(string))
    }
    static 
    func parse(_ tokens:[Character]) -> Self 
    {
        var c:Int = tokens.startIndex
        return Self.parse(tokens, position: &c)
    }
}
struct List<Head, Body>:Parseable where Head:Parseable, Body:Parseable
{
    let head:Head,
        body:Body
    
    static 
    func parse(_ tokens:[Character], position:inout Int) throws -> Self
    {
        let head:Head = try .parse(tokens, position: &position),
            body:Body = try .parse(tokens, position: &position)
        return .init(head: head, body: body)
    }
}

enum Symbol 
{
    // Whitespace ::= ' ' ' ' *
    struct Whitespace:Parseable 
    {
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Space   = try .parse(tokens, position: &position),
                _:[Token.Space] =     .parse(tokens, position: &position)
            return .init()
        }
    }
    // Endline ::= ' ' * '\n'
    struct Endline:Parseable 
    {
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:[Token.Space] =     .parse(tokens, position: &position),
                _:Token.Newline = try .parse(tokens, position: &position)
            return .init()
        }
    }
    // Identifier ::= <Swift Identifier Head> <Swift Identifier Character> *
    struct Identifier:Parseable, CustomStringConvertible
    {
        let string:String 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let head:Token.IdentifierHead   = try .parse(tokens, position: &position),
                body:[Token.Identifier]     =     .parse(tokens, position: &position)
            return .init(string: "\(head.character)" + .init(body.map(\.character)))
        }
        
        var description:String 
        {
            self.string
        }
    }
    
    // FunctionField       ::= <FunctionKeyword> <Whitespace> <Identifiers> <TypeParameters> ? '?' ? '(' ( <FunctionLabel> ':' ) * ')' <Endline>
    //                       | 'case' <Whitespace> <Identifiers> <Endline>
    // FunctionKeyword     ::= 'init'
    //                       | 'func'
    //                       | 'mutating' <Whitespace> 'func'
    //                       | 'static' <Whitespace> 'func'
    //                       | 'case' 
    //                       | 'indirect' <Whitespace> 'case' 
    // FunctionLabel       ::= <Identifier> 
    //                       | <Identifier> ? '...'
    // Identifiers         ::= <Identifier> ( '.' <Identifier> ) *
    // TypeParameters      ::= '<' <Whitespace> ? <Identifier> <Whitespace> ? ( ',' <Whitespace> ? <Identifier> <Whitespace> ? ) * '>'
    struct FunctionField:Parseable, CustomStringConvertible
    {
        struct FunctionFieldNormal:Parseable
        {
            let keyword:Symbol.FunctionKeyword
            let identifiers:[String]
            let generics:[String] 
            let failable:Bool
            let labels:[(name:String, variadic:Bool)]
            
            static 
            func parse(_ tokens:[Character], position:inout Int) throws -> Self
            {
                let keyword:Symbol.FunctionKeyword          = try .parse(tokens, position: &position), 
                    _:Symbol.Whitespace                     = try .parse(tokens, position: &position),
                    identifiers:Symbol.Identifiers          = try .parse(tokens, position: &position),
                    generics:Symbol.TypeParameters?         =     .parse(tokens, position: &position),
                    failable:Token.Question?                =     .parse(tokens, position: &position),
                    _:Token.Parenthesis.Left                = try .parse(tokens, position: &position),
                    labels:[List<Symbol.FunctionLabel, Token.Colon>] = .parse(tokens, position: &position),
                    _:Token.Parenthesis.Right               = try .parse(tokens, position: &position),
                    _:Symbol.Endline                        = try .parse(tokens, position: &position)
                return .init(keyword: keyword, 
                    identifiers:    identifiers.identifiers, 
                    generics:       generics?.identifiers ?? [], 
                    failable:       failable != nil, 
                    labels:         labels.map{ ($0.head.string, $0.head.variadic) })
            }
        }
        struct FunctionFieldUninhabitedCase:Parseable
        {
            let identifiers:[String]
            
            static 
            func parse(_ tokens:[Character], position:inout Int) throws -> Self
            {
                let _:Symbol.FunctionKeyword.Case           = try .parse(tokens, position: &position), 
                    _:Symbol.Whitespace                     = try .parse(tokens, position: &position),
                    identifiers:Symbol.Identifiers          = try .parse(tokens, position: &position),
                    _:Symbol.Endline                        = try .parse(tokens, position: &position)
                return .init(identifiers: identifiers.identifiers)
            }
        }
        
        let keyword:Symbol.FunctionKeyword
        let identifiers:[String]
        let generics:[String] 
        let failable:Bool
        let labels:[(name:String, variadic:Bool)]
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if let normal:FunctionFieldNormal = .parse(tokens, position: &position) 
            {
                return .init(keyword: normal.keyword, identifiers: normal.identifiers, 
                    generics: normal.generics, failable: normal.failable, labels: normal.labels)
            }
            else if let `case`:FunctionFieldUninhabitedCase = .parse(tokens, position: &position) 
            {
                return .init(keyword: .case, identifiers: `case`.identifiers, 
                    generics: [], failable: false, labels: [])
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
        
        var description:String 
        {
            """
            FunctionField
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                generics    : \(self.generics)
                failable    : \(self.failable)
                labels      : \(self.labels)
            }
            """
        }
    }

    enum FunctionKeyword:Parseable 
    {
        struct Init:Parseable.Terminal 
        {
            static 
            let token:String = "init"
        }
        struct Func:Parseable.Terminal 
        {
            static 
            let token:String = "func"
        }
        struct Mutating:Parseable.Terminal 
        {
            static 
            let token:String = "mutating"
        }
        struct Case:Parseable.Terminal 
        {
            static 
            let token:String = "case"
        }
        struct Indirect:Parseable.Terminal 
        {
            static 
            let token:String = "indirect"
        }
        
        case `init` 
        case `func` 
        case mutatingFunc
        case staticFunc
        case `case`
        case indirectCase
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:Init = .parse(tokens, position: &position)
            {
                return .`init`
            }
            else if let _:Func = .parse(tokens, position: &position)
            {
                return .func
            }
            else if let _:List<Mutating, List<Symbol.Whitespace, Func>> = 
                .parse(tokens, position: &position)
            {
                return .mutatingFunc
            }
            else if let _:List<Token.Static, List<Symbol.Whitespace, Func>> = 
                .parse(tokens, position: &position)
            {
                return .staticFunc
            }
            else if let _:Case = .parse(tokens, position: &position)
            {
                return .case
            }
            else if let _:List<Indirect, List<Symbol.Whitespace, Case>> = 
                .parse(tokens, position: &position)
            {
                return .indirectCase
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    struct FunctionLabel:Parseable, CustomStringConvertible
    {
        let string:String, 
            variadic:Bool 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let variadic:List<Symbol.Identifier?, Token.Ellipsis> = 
                .parse(tokens, position: &position)
            {
                return .init(string: variadic.head?.string ?? "_", variadic: true)
            }
            else if let singular:Symbol.Identifier = 
                .parse(tokens, position: &position)
            {
                return .init(string: singular.string, variadic: false)
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
        
        var description:String 
        {
            "\(self.variadic && self.string == "_" ? "" : self.string)\(self.variadic ? "..." : ""):"
        }
    }
    struct Identifiers:Parseable, CustomStringConvertible
    {
        let identifiers:[String]
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let head:Symbol.Identifier = try .parse(tokens, position: &position)
            let body:[List<Token.Period, Symbol.Identifier>] = .parse(tokens, position: &position)
            return .init(identifiers: ([head] + body.map(\.body)).map(\.string))
        }
        
        var description:String 
        {
            "\(self.identifiers.joined(separator: "."))"
        }
    }
    struct TypeParameters:Parseable, CustomStringConvertible
    {
        let identifiers:[String]
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Angle.Left          = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position),
                head:Symbol.Identifier      = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position),
                body:[List<Token.Comma, List<Symbol.Whitespace?, List<Symbol.Identifier, Symbol.Whitespace?>>>] = 
                .parse(tokens, position: &position),
                _:Token.Angle.Right         = try .parse(tokens, position: &position)
            return .init(identifiers: ([head] + body.map(\.body.body.head)).map(\.string))
        }
        
        var description:String 
        {
            "<\(self.identifiers.joined(separator: ", "))>"
        }
    }
    
    // SubscriptField      ::= 'subscript' <Whitespace> <Identifiers> '[' ( <Identifier> ':' ) * ']' <Endline> 
    struct SubscriptField:Parseable, CustomStringConvertible
    {
        struct Subscript:Parseable.Terminal 
        {
            static 
            let token:String = "subscript"
        }
        
        let identifiers:[String],
            labels:[String]
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Subscript                     = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace             = try .parse(tokens, position: &position),
                identifiers:Symbol.Identifiers  = try .parse(tokens, position: &position),
                _:Token.Bracket.Left            = try .parse(tokens, position: &position),
                labels:[List<Symbol.Identifier, Token.Colon>] = .parse(tokens, position: &position),
                _:Token.Bracket.Right           = try .parse(tokens, position: &position),
                _:Symbol.Endline                = try .parse(tokens, position: &position)
            return .init(identifiers: identifiers.identifiers, labels: labels.map(\.head.string))
        }
        
        var description:String 
        {
            """
            SubscriptField 
            {
                identifiers     : \(self.identifiers)
                labels          : \(self.labels)
            }
            """
        }
    }
    
    // MemberField         ::= <MemberKeyword> <Whitespace> <Identifiers> <Whitespace> ? ':' <Whitespace> ? <Type> <Whitespace> ? <MemberMutability> ? <Endline> 
    // MemberKeyword       ::= 'let'
    //                       | 'var'
    //                       | 'static' <Whitespace> 'let'
    //                       | 'static' <Whitespace> 'var'
    //                       | 'associatedtype'
    // MemberMutability    ::= '{' <Whitespace> ? 'get' ( <Whitespace> 'set' ) ? <Whitespace> ? '}'
    struct MemberField:Parseable, CustomStringConvertible
    {
        let keyword:Symbol.MemberKeyword
        let identifiers:[String]
        let type:Symbol.SwiftType
        let mutability:Symbol.MemberMutability?
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let keyword:Symbol.MemberKeyword            = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace                     = try .parse(tokens, position: &position),
                identifiers:Symbol.Identifiers          = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?                    =     .parse(tokens, position: &position),
                _:Token.Colon                           = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?                    =     .parse(tokens, position: &position),
                type:Symbol.SwiftType                   = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?                    =     .parse(tokens, position: &position),
                mutability:Symbol.MemberMutability?     =     .parse(tokens, position: &position),
                _:Symbol.Endline                        = try .parse(tokens, position: &position)
            return .init(keyword: keyword, 
                identifiers:    identifiers.identifiers, 
                type:           type,
                mutability:     mutability)
        }
        
        var description:String 
        {
            """
            MemberField 
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                type        : \(self.type)
                mutability  : \(self.mutability.map(String.init(describing:)) ?? "")
            }
            """
        }
    }
    enum MemberKeyword:Parseable 
    {
        struct Let:Parseable.Terminal 
        {
            static 
            let token:String = "let"
        }
        struct Var:Parseable.Terminal 
        {
            static 
            let token:String = "var"
        }
        struct Associatedtype:Parseable.Terminal 
        {
            static 
            let token:String = "associatedtype"
        }
        
        case `let` 
        case `var` 
        case staticLet 
        case staticVar
        case `associatedtype`
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:Let = .parse(tokens, position: &position)
            {
                return .let
            }
            else if let _:Var = .parse(tokens, position: &position)
            {
                return .var 
            }
            else if let _:List<Token.Static, List<Symbol.Whitespace, Let>> = 
                .parse(tokens, position: &position)
            {
                return .staticLet 
            }
            else if let _:List<Token.Static, List<Symbol.Whitespace, Var>> = 
                .parse(tokens, position: &position)
            {
                return .staticVar
            }
            else if let _:Associatedtype = .parse(tokens, position: &position)
            {
                return .associatedtype
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    enum MemberMutability:Parseable 
    {
        struct Get:Parseable.Terminal 
        {
            static 
            let token:String = "get"
        }
        struct Set:Parseable.Terminal 
        {
            static 
            let token:String = "set"
        }
        
        case get 
        case getset
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Brace.Left                  = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?                =     .parse(tokens, position: &position),
                _:Get                               = try .parse(tokens, position: &position),
                set:List<Symbol.Whitespace, Set>?   =     .parse(tokens, position: &position),
                _:Symbol.Whitespace?                =     .parse(tokens, position: &position),
                _:Token.Brace.Right                 = try .parse(tokens, position: &position)
            return set == nil ? .get : .getset
        }
    }
    
    // Type                ::= <UnwrappedType> '?' *
    // UnwrappedType       ::= <NamedType>
    //                       | <CompoundType>
    //                       | <FunctionType>
    //                       | <CollectionType>
    // NamedType           ::= <TypeIdentifier> ( '.' <TypeIdentifier> ) *
    // TypeIdentifier      ::= <Identifier> <TypeArguments> ?
    // TypeArguments       ::= '<' <Whitespace> ? <Type> <Whitespace> ? ( ',' <Whitespace> ? <Type> <Whitespace> ? ) * '>'
    // CompoundType        ::= '(' <Whitespace> ? ( <LabeledType> <Whitespace> ? ( ',' <Whitespace> ? <LabeledType> <Whitespace> ? ) * ) ? ')'
    // LabeledType         ::= ( <Identifier> <Whitespace> ? ':' <Whitespace> ? ) ? <Type> 
    // FunctionType        ::= ( <Attribute> <Whitespace> ) * <FunctionParameters> <Whitespace> ? ( 'throws' <Whitespace> ? ) ? '->' <Whitespace> ? <Type>
    // FunctionParameters  ::= '(' <Whitespace> ? ( <FunctionParameter> <Whitespace> ? ( ',' <Whitespace> ? <FunctionParameter> <Whitespace> ? ) * ) ? ')'
    // FunctionParameter   ::= ( <Attribute> <Whitespace> ) ? ( 'inout' <Whitespace> ) ? <Type>
    // Attribute           ::= '@' <Identifier>
    // CollectionType      ::= '[' <Whitespace> ? <Type> <Whitespace> ? ( ':' <Whitespace> ? <Type> <Whitespace> ? ) ? ']'
    enum SwiftType:Parseable, CustomStringConvertible
    {
        indirect
        case named([Symbol.TypeIdentifier])
        indirect 
        case compound([Symbol.LabeledType])
        indirect 
        case function(Symbol.FunctionType)
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let unwrapped:Symbol.UnwrappedType  = try .parse(tokens, position: &position), 
                optionals:[Token.Question]      =     .parse(tokens, position: &position)
            var inner:Self 
            switch unwrapped 
            {
            case .named(let type):
                inner = .named(type.identifiers)
            case .compound(let type):
                inner = .compound(type.elements)
            case .function(let type):
                inner = .function(type)
            case .collection(let type):
                if let value:Self = type.value 
                {
                    inner = .named(
                        [
                            .init(identifier: "Swift",      generics: []), 
                            .init(identifier: "Dictionary", generics: [type.key, value])
                        ])
                }
                else 
                {
                    inner = .named(
                        [
                            .init(identifier: "Swift", generics: []), 
                            .init(identifier: "Array", generics: [type.key])
                        ])
                }
            }
            for _ in optionals 
            {
                inner = .named(
                    [
                        .init(identifier: "Swift",    generics: []), 
                        .init(identifier: "Optional", generics: [inner])
                    ])
            }
            return inner
        }
        
        
        var description:String 
        {
            switch self 
            {
            case .named(let identifiers):
                return "\(identifiers.map(String.init(describing:)).joined(separator: "."))"
            case .compound(let elements):
                return "(\(elements.map(String.init(describing:)).joined(separator: ", ")))"
            case .function(let type):
                return "\(type.attributes.map{ "\($0) " }.joined())(\(type.parameters.map(String.init(describing:)).joined(separator: ", ")))\(type.throws ? " throws" : "") -> \(type.return)"
            }
        }
    }
    enum UnwrappedType:Parseable 
    {
        case named(Symbol.NamedType)
        case compound(Symbol.CompoundType)
        case function(Symbol.FunctionType)
        case collection(Symbol.CollectionType)
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let type:Symbol.NamedType = .parse(tokens, position: &position)
            {
                return .named(type)
            }
            else if let type:Symbol.CompoundType = .parse(tokens, position: &position)
            {
                return .compound(type)
            }
            else if let type:Symbol.FunctionType = .parse(tokens, position: &position)
            {
                return .function(type)
            }
            else if let type:Symbol.CollectionType = .parse(tokens, position: &position)
            {
                return .collection(type)
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    struct NamedType:Parseable
    {
        let identifiers:[Symbol.TypeIdentifier]
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let head:Symbol.TypeIdentifier = try .parse(tokens, position: &position)
            let body:[List<Token.Period, Symbol.TypeIdentifier>] = .parse(tokens, position: &position)
            return .init(identifiers: [head] + body.map(\.body))
        }
        
    }
    struct TypeIdentifier:Parseable, CustomStringConvertible
    {
        let identifier:String
        let generics:[Symbol.SwiftType]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let identifier:Symbol.Identifier    = try .parse(tokens, position: &position), 
                generics:Symbol.TypeArguments?  =     .parse(tokens, position: &position)
            return .init(identifier: identifier.string, generics: generics?.types ?? [])
        }
        
        var description:String 
        {
            "\(self.identifier)\(self.generics.isEmpty ? "" : "<\(self.generics.map(String.init(describing:)).joined(separator: ", "))>")"
        }
    }
    struct TypeArguments:Parseable
    {
        let types:[Symbol.SwiftType]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Angle.Left          = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position),
                head:Symbol.SwiftType       = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position),
                body:[List<Token.Comma, List<Symbol.Whitespace?, List<Symbol.SwiftType, Symbol.Whitespace?>>>] = 
                                                  .parse(tokens, position: &position),
                _:Token.Angle.Right         = try .parse(tokens, position: &position)
            return .init(types: [head] + body.map(\.body.body.head))
        }
    }
    struct CompoundType:Parseable
    {
        let elements:[Symbol.LabeledType]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Parenthesis.Left        = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                types:List<Symbol.LabeledType, List<Symbol.Whitespace?, [List<Token.Comma, List<Symbol.Whitespace?, List<Symbol.LabeledType, Symbol.Whitespace?>>>]>>? = 
                                                      .parse(tokens, position: &position), 
                _:Token.Parenthesis.Right       = try .parse(tokens, position: &position)
            return .init(elements: types.map{ [$0.head] + $0.body.body.map(\.body.body.head) } ?? [])
        }
    }
    struct LabeledType:Parseable, CustomStringConvertible
    {
        let label:String?
        let type:Symbol.SwiftType
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let label:List<Symbol.Identifier, List<Symbol.Whitespace?, List<Token.Colon, Symbol.Whitespace?>>>? = 
                                            .parse(tokens, position: &position), 
                type:Symbol.SwiftType = try .parse(tokens, position: &position)
            return .init(label: label?.head.string, type: type)
        }
        
        var description:String 
        {
            "\(self.label.map{ "\($0):" } ?? "")\(self.type)"
        }
    }
    struct FunctionType:Parseable
    {
        let attributes:[Symbol.Attribute]
        let parameters:[Symbol.FunctionParameter]
        let `throws`:Bool
        let `return`:Symbol.SwiftType
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let attributes:[List<Symbol.Attribute, Symbol.Whitespace>] = 
                                                      .parse(tokens, position: &position), 
                _:Token.Parenthesis.Left        = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                parameters:List<Symbol.FunctionParameter, List<Symbol.Whitespace?, [List<Token.Comma, List<Symbol.Whitespace?, List<Symbol.FunctionParameter, Symbol.Whitespace?>>>]>>? = 
                                                      .parse(tokens, position: &position), 
                _:Token.Parenthesis.Right       = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                `throws`:List<Token.Throws, Symbol.Whitespace?>? = 
                                                      .parse(tokens, position: &position), 
                _:Token.Arrow                   = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                `return`:Symbol.SwiftType       = try .parse(tokens, position: &position)
            return .init(attributes: attributes.map(\.head), 
                parameters: parameters.map{ [$0.head] + $0.body.body.map(\.body.body.head) } ?? [], 
                throws:     `throws` != nil, 
                return:     `return`)
        }
    }
    struct FunctionParameter:Parseable, CustomStringConvertible
    {
        struct Inout:Parseable.Terminal 
        {
            static 
            let token:String = "inout"
        }
        
        let attributes:[Symbol.Attribute]
        let `inout`:Bool
        let type:Symbol.SwiftType
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let attributes:[List<Symbol.Attribute, Symbol.Whitespace>] = 
                                                              .parse(tokens, position: &position), 
                `inout`:List<Inout, Symbol.Whitespace>? =     .parse(tokens, position: &position), 
                type:Symbol.SwiftType                   = try .parse(tokens, position: &position)
            return .init(attributes: attributes.map(\.head), `inout`: `inout` != nil, type: type)
        }
        
        var description:String 
        {
            "\(self.attributes.map{ "\($0) " }.joined())\(self.inout ? "inout " : "")\(self.type)"
        }
    }
    struct Attribute:Parseable, CustomStringConvertible
    {
        let identifier:String
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.At                      = try .parse(tokens, position: &position),
                identifier:Symbol.Identifier    = try .parse(tokens, position: &position)
            return .init(identifier: identifier.string)
        }
        
        var description:String 
        {
            "@\(self.identifier)"
        }
    }
    struct CollectionType:Parseable 
    {
        let key:Symbol.SwiftType, 
            value:Symbol.SwiftType?
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Bracket.Left    = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?    =     .parse(tokens, position: &position),
                key:Symbol.SwiftType    = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?    =     .parse(tokens, position: &position),
                value:List<Token.Colon, List<Symbol.Whitespace?, List<Symbol.SwiftType, Symbol.Whitespace?>>>? =
                                              .parse(tokens, position: &position), 
                _:Token.Bracket.Right   = try .parse(tokens, position: &position)
            return .init(key: key, value: value?.body.body.head)
        }
    }
    
    // TypeField           ::= <TypeKeyword> <Whitespace> <Identifiers> <TypeParameters> ? <Endline>
    // TypeKeyword         ::= 'protocol'
    //                       | 'class'
    //                       | 'final' <Whitespace> 'class'
    //                       | 'struct'
    //                       | 'enum'
    struct TypeField:Parseable, CustomStringConvertible
    {
        let keyword:TypeKeyword 
        let identifiers:[String]
        let generics:[String]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let keyword:Symbol.TypeKeyword          = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace                 = try .parse(tokens, position: &position), 
                identifiers:Symbol.Identifiers      = try .parse(tokens, position: &position), 
                generics:Symbol.TypeParameters?     =     .parse(tokens, position: &position), 
                _:Symbol.Endline                    = try .parse(tokens, position: &position)
            return .init(keyword: keyword, identifiers: identifiers.identifiers, generics: generics?.identifiers ?? [])
        }
        
        var description:String 
        {
            """
            TypeField 
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                generics    : \(self.generics)
            }
            """
        }
    }
    enum TypeKeyword:Parseable 
    {
        struct `Protocol`:Parseable.Terminal 
        {
            static 
            let token:String = "protocol"
        }
        struct Class:Parseable.Terminal 
        {
            static 
            let token:String = "class"
        }
        struct Struct:Parseable.Terminal 
        {
            static 
            let token:String = "struct"
        }
        struct Enum:Parseable.Terminal 
        {
            static 
            let token:String = "enum"
        }
        
        case `protocol` 
        case `class` 
        case finalClass 
        case `struct` 
        case `enum`
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:Protocol = .parse(tokens, position: &position)
            {
                return .protocol
            }
            else if let _:Class = .parse(tokens, position: &position)
            {
                return .class 
            }
            else if let _:List<Token.Final, List<Symbol.Whitespace, Class>> = 
                .parse(tokens, position: &position)
            {
                return .finalClass 
            }
            else if let _:Struct = .parse(tokens, position: &position)
            {
                return .struct
            }
            else if let _:Enum = .parse(tokens, position: &position)
            {
                return .enum 
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // TypealiasField      ::= 'typealias' <Whitespace> <Identifiers> <Whitespace> ? '=' <Whitespace> ? <Type> <Endline>
    struct TypealiasField:Parseable, CustomStringConvertible
    {
        struct Typealias:Parseable.Terminal 
        {
            static 
            let token:String = "typealias"
        }
        
        let identifiers:[String]
        let target:Symbol.SwiftType
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Typealias                     = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace             = try .parse(tokens, position: &position), 
                identifiers:Symbol.Identifiers  = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                _:Token.Equals                  = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                target:Symbol.SwiftType         = try .parse(tokens, position: &position), 
                _:Symbol.Endline                = try .parse(tokens, position: &position)
            return .init(identifiers: identifiers.identifiers, target: target)
        }
        
        var description:String 
        {
            """
            TypealiasField 
            {
                identifiers : \(self.identifiers)
                target      : \(self.target)
            }
            """
        }
    }
    // AssociatedtypeField ::= 'associatedtype' <Whitespace> <Identifiers> <Endline>
    struct AssociatedtypeField:Parseable, CustomStringConvertible
    {
        struct Associatedtype:Parseable.Terminal 
        {
            static 
            let token:String = "associatedtype"
        }
        
        let identifiers:[String]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Associatedtype                = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace             = try .parse(tokens, position: &position), 
                identifiers:Symbol.Identifiers  = try .parse(tokens, position: &position), 
                _:Symbol.Endline                = try .parse(tokens, position: &position)
            return .init(identifiers: identifiers.identifiers)
        }
        
        var description:String 
        {
            """
            AssociatedtypeField 
            {
                identifiers  : \(self.identifiers)
            }
            """
        }
    }
    // AnnotationField     ::= ':' <Whitespace> ? <Identifiers> <Whitespace> ? ( '&' <Whitespace> ? <Identifiers> <Whitespace> ? ) * '\n'
    struct AnnotationField:Parseable, CustomStringConvertible
    {
        let annotations:[[String]]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Colon               = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                head:Symbol.Identifiers     = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                body:[List<Token.Ampersand, List<Symbol.Whitespace?, List<Symbol.Identifiers, Symbol.Whitespace?>>>] =
                                                  .parse(tokens, position: &position),
                _:Token.Newline             = try .parse(tokens, position: &position)
            return .init(annotations: ([head] + body.map(\.body.body.head)).map(\.identifiers))
        }
        
        var description:String 
        {
            """
            AnnotationField 
            {
                annotations  : \(self.annotations)
            }
            """
        }
    }
    
    // WhereField          ::= 'where' <Whitespace> <Identifiers> <Whitespace> ? <WhereRelation> <Whitespace> ? <Identifiers> <Endline>
    // WhereRelation       ::= ':' 
    //                       | '=='
    struct WhereField:Parseable, CustomStringConvertible
    {
        struct Where:Parseable.Terminal 
        {
            static 
            let token:String = "where"
        }
        
        let lhs:[String], 
            rhs:[String], 
            relation:Symbol.WhereRelation 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Where                 = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace     = try .parse(tokens, position: &position), 
                lhs:Symbol.Identifiers  = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?    =     .parse(tokens, position: &position), 
                relation:Symbol.WhereRelation = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?    =     .parse(tokens, position: &position), 
                rhs:Symbol.Identifiers  = try .parse(tokens, position: &position),
                _:Symbol.Endline        = try .parse(tokens, position: &position)
            return .init(lhs: lhs.identifiers, rhs: rhs.identifiers, relation: relation)
        }
        
        var description:String 
        {
            """
            WhereField 
            {
                constraint  : \(self.lhs) \(self.relation) \(self.rhs)
            }
            """
        }
    }
    enum WhereRelation:Parseable
    {
        case conforms 
        case equals 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:Token.Colon = .parse(tokens, position: &position) 
            {
                return .conforms 
            }
            else if let _:Token.EqualsEquals = .parse(tokens, position: &position) 
            {
                return .equals 
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // AttributeField      ::= '@' <Whitespace> ? <DeclarationAttribute> 
    // DeclarationAttribute::= 'frozen' <Endline>
    //                       | 'inlinable' <Endline>
    //                       | 'propertyWrapper' <Endline>
    //                       | 'specialized' <Whitespace> <WhereField>
    //                       | ':'  <Whitespace> ? <Type> <Endline> 
    enum AttributeField:Parseable
    {
        struct Frozen:Parseable.Terminal 
        {
            static 
            let token:String = "frozen"
        }
        struct Inlinable:Parseable.Terminal 
        {
            static 
            let token:String = "inlinable"
        }
        struct PropertyWrapper:Parseable.Terminal 
        {
            static 
            let token:String = "propertyWrapper"
        }
        struct Specialized:Parseable.Terminal 
        {
            static 
            let token:String = "specialized"
        }
        
        case frozen 
        case inlinable 
        case wrapper
        case specialized(Symbol.WhereField)
        case wrapped(Symbol.SwiftType)
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.At              = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?    =     .parse(tokens, position: &position)
            
            if      let _:Frozen = .parse(tokens, position: &position)
            {
                return .frozen
            }
            else if let _:Inlinable = .parse(tokens, position: &position)
            {
                return .inlinable 
            }
            else if let _:PropertyWrapper = 
                .parse(tokens, position: &position)
            {
                return .wrapper 
            }
            else if let specialized:List<Specialized, List<Symbol.Whitespace, Symbol.WhereField>> = 
                .parse(tokens, position: &position)
            {
                return .specialized(specialized.body.body)
            }
            else if let wrapped:List<Token.Colon, List<Symbol.Whitespace?, Symbol.SwiftType>> = 
                .parse(tokens, position: &position)
            {
                return .wrapped(wrapped.body.body) 
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // ParameterField      ::= '-' <Whitespace> ? <ParameterName> <Whitespace> ? ':' <Whitespace> ? <FunctionParameter> <Endline>
    // ParameterName       ::= <Identifier> 
    //                       | '->'
    struct ParameterField:Parseable, CustomStringConvertible
    {
        let name:Symbol.ParameterName 
        let parameter:Symbol.FunctionParameter 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Hyphen              = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                name:Symbol.ParameterName   = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                _:Token.Colon               = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                parameter:Symbol.FunctionParameter = try .parse(tokens, position: &position), 
                _:Symbol.Endline            = try .parse(tokens, position: &position)
            return .init(name: name, parameter: parameter)
        }
        
        var description:String 
        {
            """
            ParameterField 
            {
                name        : \(self.name)
                parameter   : \(self.parameter)
            }
            """
        }
    }
    enum ParameterName:Parseable
    {
        case parameter(String) 
        case `return`
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let identifier:Symbol.Identifier = .parse(tokens, position: &position)
            {
                return .parameter(identifier.string)
            }
            else if let _:Token.Arrow = .parse(tokens, position: &position)
            {
                return .return
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // ThrowsField         ::= 'throws' <Endline>
    //                       | 'rethrows' <Endline>
    enum ThrowsField:Parseable 
    {
        case `throws` 
        case `rethrows`
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:Token.Throws = .parse(tokens, position: &position)
            {
                return .throws
            }
            else if let _:Token.Rethrows = .parse(tokens, position: &position)
            {
                return .rethrows
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // RequirementField    ::= 'required' <Endline>
    //                       | 'defaulted' <Endline>
    enum RequirementField:Parseable 
    {
        struct Required:Parseable.Terminal 
        {
            static 
            let token:String = "required"
        }
        struct Defaulted:Parseable.Terminal 
        {
            static 
            let token:String = "defaulted"
        }
        
        case required
        case defaulted
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:Required = .parse(tokens, position: &position)
            {
                return .required
            }
            else if let _:Defaulted = .parse(tokens, position: &position)
            {
                return .defaulted
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // TopicField          ::= '#' <Whitespace>? '[' <BalancedContent> * ']' <Whitespace>? '(' <BalancedContent> * ')' <Endline>
    // TopicElementField   ::= '##' <Whitespace>? '(' ( <ASCIIDigit> * <Whitespace> ? ':' <Whitespace> ? ) ? <BalancedContent> * ')' <Endline>
    struct TopicField:Parseable 
    {
        let display:String, 
            key:String 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Hashtag             = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                _:Token.Bracket.Left        = try .parse(tokens, position: &position), 
                display:[Token.BalancedContent] = .parse(tokens, position: &position), 
                _:Token.Bracket.Right       = try .parse(tokens, position: &position), 
                _:Token.Parenthesis.Left    = try .parse(tokens, position: &position), 
                key:[Token.BalancedContent] =     .parse(tokens, position: &position), 
                _:Token.Parenthesis.Right   = try .parse(tokens, position: &position), 
                _:Symbol.Endline            = try .parse(tokens, position: &position)
            return .init(display: .init(display.map(\.character)), key: .init(key.map(\.character)))
        }
    }
    struct TopicElementField:Parseable
    {
        let key:String
        let rank:Int
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Hashtag             = try .parse(tokens, position: &position), 
                _:Token.Hashtag             = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                _:Token.Parenthesis.Left    = try .parse(tokens, position: &position), 
                rank:List<[Token.ASCIIDigit], List<Symbol.Whitespace?, List<Token.Colon, Symbol.Whitespace?>>>? = 
                                                  .parse(tokens, position: &position),
                key:[Token.BalancedContent] =     .parse(tokens, position: &position), 
                _:Token.Parenthesis.Right   = try .parse(tokens, position: &position), 
                _:Symbol.Endline            = try .parse(tokens, position: &position)
            let r:Int = Int.init(String.init(rank?.head.map(\.character) ?? [])) ?? Int.max
            return .init(key: .init(key.map(\.character)), rank: r)
        }
    }
    
    // ParagraphField      ::= <ParagraphLine> <ParagraphLine> *
    // ParagraphLine       ::= '    ' ' ' * [^\s] . * '\n'
    struct ParagraphField:Parseable, CustomStringConvertible
    {
        let elements:[Markdown.Element]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let head:Symbol.ParagraphLine   = try .parse(tokens, position: &position), 
                body:[Symbol.ParagraphLine] =     .parse(tokens, position: &position)
            
            var characters:[Character] = []
            for line:Symbol.ParagraphLine in [head] + body 
            {
                let trimmed:String = 
                {
                    var substring:Substring = line.string[...] 
                    while substring.last?.isWhitespace == true 
                    {
                        substring.removeLast()
                    }
                    return .init(substring)
                }()
                characters.append(contentsOf: trimmed)
                characters.append(" ")
            }
            var c:Int = characters.startIndex
            let elements:[Markdown.Element] = .parse(characters, position: &c)
            return .init(elements: elements)
        }
        
        var description:String 
        {
            "\(self.elements)"
        }
    }
    struct ParagraphLine:Parseable 
    {
        let string:String
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Space           = try .parse(tokens, position: &position), 
                _:Token.Space           = try .parse(tokens, position: &position), 
                _:Token.Space           = try .parse(tokens, position: &position), 
                _:Token.Space           = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?    =     .parse(tokens, position: &position), 
                head:Token.Darkspace    = try .parse(tokens, position: &position), 
                body:[Token.Wildcard]   =     .parse(tokens, position: &position), 
                _:Token.Newline         = try .parse(tokens, position: &position)
            return .init(string: .init([head.character] + body.map(\.character)))
        }
    }
    
    // Field               ::= <FunctionField>
    //                       | <SubscriptField>
    //                       | <MemberField>
    //                       | <TypeField>
    //                       | <TypealiasField>
    //                       | <AssociatedtypeField>
    //                       | <AnnotationField>
    //                       | <AttributeField>
    //                       | <WhereField>
    //                       | <ThrowsField>
    //                       | <RequirementField>
    //                       | <ParameterField>
    //                       | <TopicField>
    //                       | <TopicElementField>
    //                       | <ParagraphField>
    //                       | <Separator>
    // Separator           ::= <Endline>
    enum Field:Parseable 
    {
        case `subscript`(Symbol.SubscriptField) 
        case function(Symbol.FunctionField) 
        case member(Symbol.MemberField) 
        case type(Symbol.TypeField) 
        case `typealias`(Symbol.TypealiasField) 
        case `associatedtype`(Symbol.AssociatedtypeField) 
        
        case annotation(Symbol.AnnotationField) 
        case attribute(Symbol.AttributeField) 
        case `where`(Symbol.WhereField) 
        case `throws`(Symbol.ThrowsField) 
        case requirement(Symbol.RequirementField) 
        case parameter(Symbol.ParameterField) 
        
        case topic(Symbol.TopicField)
        case topicElement(Symbol.TopicElementField)
        
        case paragraph(Symbol.ParagraphField) 
        case separator
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let field:Symbol.FunctionField = .parse(tokens, position: &position)
            {
                return .function(field)
            }
            else if let field:Symbol.SubscriptField = .parse(tokens, position: &position)
            {
                return .subscript(field)
            }
            else if let field:Symbol.MemberField = .parse(tokens, position: &position)
            {
                return .member(field)
            }
            else if let field:Symbol.TypeField = .parse(tokens, position: &position)
            {
                return .type(field)
            }
            else if let field:Symbol.TypealiasField = .parse(tokens, position: &position)
            {
                return .typealias(field)
            }
            else if let field:Symbol.AssociatedtypeField = .parse(tokens, position: &position)
            {
                return .associatedtype(field)
            }
            else if let field:Symbol.AnnotationField = .parse(tokens, position: &position)
            {
                return .annotation(field)
            }
            else if let field:Symbol.AttributeField = .parse(tokens, position: &position)
            {
                return .attribute(field)
            }
            else if let field:Symbol.WhereField = .parse(tokens, position: &position)
            {
                return .where(field)
            }
            else if let field:Symbol.ThrowsField = .parse(tokens, position: &position)
            {
                return .throws(field)
            }
            else if let field:Symbol.RequirementField = .parse(tokens, position: &position)
            {
                return .requirement(field)
            }
            else if let field:Symbol.ParameterField = .parse(tokens, position: &position)
            {
                return .parameter(field)
            }
            else if let field:Symbol.TopicField = .parse(tokens, position: &position)
            {
                return .topic(field)
            }
            else if let field:Symbol.TopicElementField = .parse(tokens, position: &position)
            {
                return .topicElement(field)
            }
            else if let field:Symbol.ParagraphField = .parse(tokens, position: &position)
            {
                return .paragraph(field)
            }
            else if let _:Symbol.Endline = .parse(tokens, position: &position)
            {
                return .separator 
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
}

// baseurl without trailing slash
func main(sources:[String], directory:String, urlpattern:(prefix:String, suffix:String)) throws
{
    var doccomments:[[Character]] = [] 
    for path:String in sources 
    {
        guard let contents:String = File.source(path: path) 
        else 
        {
            continue 
        }
        
        var doccomment:[Character] = []
        for line in contents.split(separator: "\n")
        {
            let line:[Character] = .init(line.drop{ $0.isWhitespace && !$0.isNewline })
            if line.starts(with: ["/", "/", "/"]) 
            {
                if line.count > 3, line[3] == " " 
                {
                    doccomment.append(contentsOf: line.dropFirst(4))
                }
                else 
                {
                    doccomment.append(contentsOf: line.dropFirst(3))
                }
                doccomment.append("\n")
            }
            else if !doccomment.isEmpty
            {
                doccomments.append(doccomment)
                doccomment = []
            }
        }
        
        if !doccomment.isEmpty
        {
            doccomments.append(doccomment)
        }
    }
    
    var pages:[Page.Binding] = []
    for (i, doccomment):(Int, [Character]) in doccomments.enumerated()
    {
        let fields:[Symbol.Field]           = [Symbol.Field].parse(doccomment) 
        let body:ArraySlice<Symbol.Field>   = fields.dropFirst()
        switch fields.first 
        {
        case .subscript(let header)?:
            pages.append(Page.Binding.create(header, fields: body, order: i, urlpattern: urlpattern))
        case .function(let header)?:
            pages.append(Page.Binding.create(header, fields: body, order: i, urlpattern: urlpattern))
        case .member(let header)?:
            pages.append(Page.Binding.create(header, fields: body, order: i, urlpattern: urlpattern))
        case .type(let header)?:
            pages.append(Page.Binding.create(header, fields: body, order: i, urlpattern: urlpattern))
        case .typealias(let header)?:
            pages.append(Page.Binding.create(header, fields: body, order: i, urlpattern: urlpattern))
        case .associatedtype(let header)?:
            pages.append(Page.Binding.create(header, fields: body, order: i, urlpattern: urlpattern))
        default:
            break 
        }
    }
    
    let tree:PageTree = .assemble(pages)
    print(tree)
    
    tree.crosslink()
    tree.attachTopics()
    
    for page:Page.Binding in pages
    {
        let document:String = 
        """
        <head>
            <meta charset="UTF-8">
            <link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,600;1,400;1,600&family=Questrial&display=swap" rel="stylesheet"> 
            <link href="\(urlpattern.prefix)style.css" rel="stylesheet"> 
        </head> 
        <body>
            \(page.page.html.string)
        </body>
        """
        File.pave([directory] + page.path)
        File.save(.init(document.utf8), path: "\(directory)/\(page.filepath)/index.html")
    }
    
    // copy big-sur.css 
    guard let stylesheet:String = File.source(path: "documentation-generator/big-sur.css") 
    else 
    {
        fatalError("missing stylesheet") 
    }
    File.save(.init(stylesheet.utf8), path: "\(directory)/style.css")
}

guard CommandLine.arguments.count >= 4 
else 
{
    fatalError("need at least 3 arguments (destination directory, url prefix, url suffix)")
}

try main(sources: .init(CommandLine.arguments.dropFirst()), 
    directory: CommandLine.arguments[1], 
    urlpattern: 
    (
        prefix: CommandLine.arguments[2], 
        suffix: CommandLine.arguments[3] == "/" ? "" : CommandLine.arguments[3]
    ))
