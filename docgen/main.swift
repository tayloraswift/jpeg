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
    
    // FunctionField       ::= <FunctionKeyword> <Whitespace> <QualifiedIdentifier> <TypeParameters> ? '?' ? '(' <FunctionArguments> ')' <Endline>
    // FunctionKeyword     ::= 'init'
    //                       | 'func'
    //                       | 'mutating' <Whitespace> 'func'
    //                       | 'static' <Whitespace> 'func'
    //                       | 'case' 
    //                       | 'indirect' <Whitespace> 'case' 
    // FunctionArguments   ::= ( <Identifier> ':' ) * 
    // QualifiedIdentifier ::= <Identifier> ( '.' <Identifier> ) *
    // TypeParameters      ::= '<' <Whitespace> ? <Identifier> <Whitespace> ? ( ',' <Whitespace> ? <Identifier> <Whitespace> ? ) * '>'
    struct FunctionField:Parseable, CustomStringConvertible
    {
        let keyword:Symbol.FunctionKeyword
        let identifier:Symbol.QualifiedIdentifier
        let generics:Symbol.TypeParameters? 
        let failable:Bool
        let arguments:FunctionArguments
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let keyword:Symbol.FunctionKeyword          = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace                     = try .parse(tokens, position: &position),
                identifier:Symbol.QualifiedIdentifier   = try .parse(tokens, position: &position),
                generics:Symbol.TypeParameters?         =     .parse(tokens, position: &position),
                failable:Token.Question?                =     .parse(tokens, position: &position),
                _:Token.Parenthesis.Left                = try .parse(tokens, position: &position),
                arguments:Symbol.FunctionArguments      = try .parse(tokens, position: &position),
                _:Token.Parenthesis.Right               = try .parse(tokens, position: &position),
                _:Symbol.Endline                        = try .parse(tokens, position: &position)
            return .init(keyword: keyword, 
                identifier: identifier, 
                generics:   generics, 
                failable:   failable != nil, 
                arguments:  arguments)
        }
        
        var description:String 
        {
            """
            FunctionField
            {
                keyword     : \(self.keyword)
                identifier  : \(self.identifier)
                generics    : \(self.generics.map(String.init(describing:)) ?? "")
                failable    : \(self.failable)
                arguments   : \(self.arguments)
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
    struct FunctionArguments:Parseable, CustomStringConvertible
    {
        let arguments:[Symbol.Identifier]
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let arguments:[List<Symbol.Identifier, Token.Colon>] = .parse(tokens, position: &position)
            return .init(arguments: arguments.map(\.head))
        }
        
        var description:String 
        {
            "\(self.arguments)"
        }
    }
    struct QualifiedIdentifier:Parseable, CustomStringConvertible
    {
        let prefix:[Symbol.Identifier], 
            identifier:Symbol.Identifier
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let head:Symbol.Identifier = try .parse(tokens, position: &position)
            let body:[List<Token.Period, Symbol.Identifier>] = .parse(tokens, position: &position)
            let identifiers:[Symbol.Identifier] = [head] + body.map(\.body)
            return .init(prefix: .init(identifiers.dropLast()), 
                identifier: identifiers[identifiers.endIndex - 1])
        }
        
        var description:String 
        {
            "\((self.prefix + [self.identifier]).map(String.init(describing:)).joined(separator: "."))"
        }
    }
    struct TypeParameters:Parseable, CustomStringConvertible
    {
        let identifiers:[Symbol.Identifier]
            
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
            return .init(identifiers: [head] + body.map(\.body.body.head))
        }
        
        var description:String 
        {
            "<\(self.identifiers.map(String.init(describing:)).joined(separator: ", "))>"
        }
    }
    
    // SubscriptField      ::= 'subscript' <Whitespace> '[' <FunctionArguments> ']' <Endline> 
    struct SubscriptField:Parseable, CustomStringConvertible
    {
        struct Subscript:Parseable.Terminal 
        {
            static 
            let token:String = "subscript"
        }
        
        let arguments:FunctionArguments
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Subscript                         = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace                 = try .parse(tokens, position: &position),
                _:Token.Bracket.Left                = try .parse(tokens, position: &position),
                arguments:Symbol.FunctionArguments  = try .parse(tokens, position: &position),
                _:Token.Bracket.Right               = try .parse(tokens, position: &position),
                _:Symbol.Endline                    = try .parse(tokens, position: &position)
            return .init(arguments:  arguments)
        }
        
        var description:String 
        {
            """
            SubscriptField 
            {
                arguments   : \(self.arguments)
            }
            """
        }
    }
    
    // MemberField         ::= <MemberKeyword> <Whitespace> <QualifiedIdentifier> <Whitespace> ? ':' <Whitespace> ? <Type> <MemberMutability> ? <Endline> 
    // MemberKeyword       ::= 'let'
    //                       | 'var'
    //                       | 'static' <Whitespace> 'let'
    //                       | 'static' <Whitespace> 'var'
    //                       | 'associatedtype'
    // MemberMutability    ::= '{' <Whitespace> ? 'get' ( <Whitespace> 'set' ) ? <Whitespace> ? '}'
    struct MemberField:Parseable, CustomStringConvertible
    {
        let keyword:Symbol.MemberKeyword
        let identifier:Symbol.QualifiedIdentifier
        let type:Symbol.SwiftType
        let mutability:Symbol.MemberMutability?
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let keyword:Symbol.MemberKeyword            = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace                     = try .parse(tokens, position: &position),
                identifier:Symbol.QualifiedIdentifier   = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?                    =     .parse(tokens, position: &position),
                _:Token.Colon                           = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?                    =     .parse(tokens, position: &position),
                type:Symbol.SwiftType                   = try .parse(tokens, position: &position),
                mutability:Symbol.MemberMutability?     =     .parse(tokens, position: &position),
                _:Symbol.Endline                        = try .parse(tokens, position: &position)
            return .init(keyword: keyword, 
                identifier: identifier, 
                type:       type,
                mutability: mutability)
        }
        
        var description:String 
        {
            """
            MemberField 
            {
                keyword     : \(self.keyword)
                identifier  : \(self.identifier)
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
    // UnwrappedType       ::= <NormalType>
    //                       | <CompoundType>
    //                       | <FunctionType>
    //                       | <CollectionType>
    // NormalType          ::= <TypeIdentifier> ( '.' <TypeIdentifier> ) *
    // TypeIdentifier      ::= <Identifier> <TypeArguments> ?
    // TypeArguments       ::= '<' <Whitespace> ? <Type> <Whitespace> ? ( ',' <Whitespace> ? <Type> <Whitespace> ? ) * '>'
    // CompoundType        ::= '(' <Whitespace> ? ( <LabeledType> <Whitespace> ? ( ',' <Whitespace> ? <LabeledType> <Whitespace> ? ) * ) ? ')'
    // LabeledType         ::= ( <Identifier> <Whitespace> ? ':' <Whitespace> ? ) ? <Type> 
    // FunctionType        ::= ( <Attribute> <Whitespace> ) ? <FunctionParameters> <Whitespace> ? ( 'throws' <Whitespace> ? ) ? '->' <Whitespace> ? <Type>
    // FunctionParameters  ::= '(' <Whitespace> ? ( <ParameterType> <Whitespace> ? ( ',' <Whitespace> ? <ParameterType> <Whitespace> ? ) * ) ? ')'
    // ParameterType       ::= ( <Attribute> <Whitespace> ) ? ( 'inout' <Whitespace> ) ? <Type>
    // Attribute           ::= '@' <Identifier>
    // CollectionType      ::= '[' <Whitespace> ? <Type> <Whitespace> ? ( ':' <Whitespace> ? <Type> <Whitespace> ? ) ? ']'
    enum SwiftType:Parseable
    {
        indirect
        case normal(Symbol.NormalType)
        indirect 
        case compound(Symbol.CompoundType)
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
            case .normal(let type):
                inner = .normal(type)
            case .compound(let type):
                inner = .compound(type)
            case .function(let type):
                inner = .function(type)
            case .collection(let type):
                if let value:Self = type.value 
                {
                    inner = .normal(.init(
                        prefix: [.init(identifier: .init(string: "Swift"), generics: nil)], 
                        identifier: .init(
                            identifier: .init(string: "Dictionary"), 
                            generics:   .init(types: [type.key, value]))
                        ))
                }
                else 
                {
                    inner = .normal(.init(
                        prefix: [.init(identifier: .init(string: "Swift"), generics: nil)], 
                        identifier: .init(
                            identifier: .init(string: "Array"), 
                            generics:   .init(types: [type.key]))
                        ))
                }
            }
            for _ in optionals 
            {
                inner = .normal(.init(
                    prefix: [.init(identifier: .init(string: "Swift"), generics: nil)], 
                    identifier: .init(
                        identifier: .init(string: "Optional"), 
                        generics:   .init(types: [inner]))
                    ))
            }
            return inner
        }
    }
    enum UnwrappedType:Parseable 
    {
        case normal(Symbol.NormalType)
        case compound(Symbol.CompoundType)
        case function(Symbol.FunctionType)
        case collection(Symbol.CollectionType)
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let type:Symbol.NormalType = .parse(tokens, position: &position)
            {
                return .normal(type)
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
    struct NormalType:Parseable, CustomStringConvertible
    {
        let prefix:[Symbol.TypeIdentifier], 
            identifier:Symbol.TypeIdentifier
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let head:Symbol.TypeIdentifier = try .parse(tokens, position: &position)
            let body:[List<Token.Period, Symbol.TypeIdentifier>] = .parse(tokens, position: &position)
            let identifiers:[Symbol.TypeIdentifier] = [head] + body.map(\.body)
            return .init(prefix: .init(identifiers.dropLast()), 
                identifier: identifiers[identifiers.endIndex - 1])
        }
        
        var description:String 
        {
            "\((self.prefix + [self.identifier]).map(String.init(describing:)).joined(separator: "."))"
        }
    }
    struct TypeIdentifier:Parseable, CustomStringConvertible
    {
        let identifier:Symbol.Identifier
        let generics:Symbol.TypeArguments?
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let identifier:Symbol.Identifier    = try .parse(tokens, position: &position), 
                generics:Symbol.TypeArguments?  =     .parse(tokens, position: &position)
            return .init(identifier: identifier, generics: generics)
        }
        
        var description:String 
        {
            "\(self.identifier)\(self.generics.map(String.init(describing:)) ?? "")"
        }
    }
    struct TypeArguments:Parseable, CustomStringConvertible
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
        
        var description:String 
        {
            "<\(self.types.map(String.init(describing:)).joined(separator: ", "))>"
        }
    }
    struct CompoundType:Parseable, CustomStringConvertible
    {
        let types:[Symbol.LabeledType]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Parenthesis.Left        = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                types:List<Symbol.LabeledType, List<Symbol.Whitespace?, [List<Token.Comma, List<Symbol.Whitespace?, List<Symbol.LabeledType, Symbol.Whitespace?>>>]>>? = 
                                                      .parse(tokens, position: &position), 
                _:Token.Parenthesis.Right       = try .parse(tokens, position: &position)
            return .init(types: types.map{ [$0.head] + $0.body.body.map(\.body.body.head) } ?? [])
        }
        
        var description:String 
        {
            "(\(self.types.map(String.init(describing:)).joined(separator: ", ")))"
        }
    }
    struct LabeledType:Parseable, CustomStringConvertible
    {
        let label:Symbol.Identifier?
        let type:Symbol.SwiftType
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let label:List<Symbol.Identifier, List<Symbol.Whitespace?, List<Token.Colon, Symbol.Whitespace?>>>? = 
                                            .parse(tokens, position: &position), 
                type:Symbol.SwiftType = try .parse(tokens, position: &position)
            return .init(label: label?.head, type: type)
        }
        
        var description:String 
        {
            "\(self.label.map{ "\($0):" } ?? "")\(self.type)"
        }
    }
    struct FunctionType:Parseable, CustomStringConvertible
    {
        let attribute:Symbol.Attribute?
        let parameters:Symbol.FunctionParameters 
        let `throws`:Bool
        let `return`:Symbol.SwiftType
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let attribute:List<Symbol.Attribute, Symbol.Whitespace>? = 
                                                      .parse(tokens, position: &position), 
                parameters:FunctionParameters   = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                `throws`:List<Token.Throws, Symbol.Whitespace?>? = 
                                                      .parse(tokens, position: &position), 
                _:Token.Arrow                   = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                `return`:Symbol.SwiftType       = try .parse(tokens, position: &position)
            return .init(attribute: attribute?.head, 
                parameters: parameters, 
                throws:     `throws` != nil, 
                return:     `return`)
        }
        
        var description:String 
        {
            "\(self.attribute.map{ "\($0) " } ?? "")\(self.parameters)\(self.throws ? " throws" : "") -> \(self.return)"
        }
    }
    struct FunctionParameters:Parseable, CustomStringConvertible
    {
        let parameters:[ParameterType]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Parenthesis.Left    = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                parameters:List<Symbol.ParameterType, List<Symbol.Whitespace?, [List<Token.Comma, List<Symbol.Whitespace?, List<Symbol.ParameterType, Symbol.Whitespace?>>>]>>? = 
                                                  .parse(tokens, position: &position), 
                _:Token.Parenthesis.Right   = try .parse(tokens, position: &position)
            return .init(parameters: parameters.map{ [$0.head] + $0.body.body.map(\.body.body.head) } ?? [])
        }
        
        var description:String 
        {
            "(\(parameters.map(String.init(describing:)).joined(separator: ", ")))"
        }
    }
    struct ParameterType:Parseable, CustomStringConvertible
    {
        struct Inout:Parseable.Terminal 
        {
            static 
            let token:String = "inout"
        }
        
        let attribute:Symbol.Attribute?
        let `inout`:Bool
        let type:Symbol.SwiftType
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let attribute:List<Symbol.Attribute, Symbol.Whitespace>? = 
                                                              .parse(tokens, position: &position), 
                `inout`:List<Inout, Symbol.Whitespace>? =     .parse(tokens, position: &position), 
                type:Symbol.SwiftType                   = try .parse(tokens, position: &position)
            return .init(attribute: attribute?.head, `inout`: `inout` != nil, type: type)
        }
        
        var description:String 
        {
            "\(self.attribute.map{ "\($0) " } ?? "")\(self.inout ? "inout " : "")\(self.type)"
        }
    }
    struct Attribute:Parseable, CustomStringConvertible
    {
        let identifier:Symbol.Identifier
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.At                      = try .parse(tokens, position: &position),
                identifier:Symbol.Identifier    = try .parse(tokens, position: &position)
            return .init(identifier: identifier)
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
    
    // TypeField           ::= <TypeKeyword> <Whitespace> <QualifiedIdentifier> <TypeParameters> ? <Endline>
    // TypeKeyword         ::= 'protocol'
    //                       | 'class'
    //                       | 'final' <Whitespace> 'class'
    //                       | 'struct'
    //                       | 'enum'
    struct TypeField:Parseable, CustomStringConvertible
    {
        let keyword:TypeKeyword 
        let identifier:Symbol.QualifiedIdentifier
        let generics:Symbol.TypeParameters?
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let keyword:Symbol.TypeKeyword              = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace                     = try .parse(tokens, position: &position), 
                identifier:Symbol.QualifiedIdentifier   = try .parse(tokens, position: &position), 
                generics:Symbol.TypeParameters?         =     .parse(tokens, position: &position), 
                _:Symbol.Endline                        = try .parse(tokens, position: &position)
            return .init(keyword: keyword, identifier: identifier, generics: generics)
        }
        
        var description:String 
        {
            """
            TypeField 
            {
                keyword     : \(self.keyword)
                identifier  : \(self.identifier)
                generics    : \(self.generics.map(String.init(describing:)) ?? "")
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
    
    // TypealiasField      ::= 'typealias' <Whitespace> <QualifiedIdentifier> <Whitespace> ? '=' <Whitespace> ? <Type> <Endline>
    struct TypealiasField:Parseable, CustomStringConvertible
    {
        struct Typealias:Parseable.Terminal 
        {
            static 
            let token:String = "typealias"
        }
        
        let identifier:Symbol.QualifiedIdentifier
        let target:Symbol.SwiftType
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Typealias                             = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace                     = try .parse(tokens, position: &position), 
                identifier:Symbol.QualifiedIdentifier   = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?                    =     .parse(tokens, position: &position), 
                _:Token.Equals                          = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?                    =     .parse(tokens, position: &position), 
                target:Symbol.SwiftType                 = try .parse(tokens, position: &position), 
                _:Symbol.Endline                        = try .parse(tokens, position: &position)
            return .init(identifier: identifier, target: target)
        }
        
        var description:String 
        {
            """
            TypealiasField 
            {
                identifier  : \(self.identifier)
                target      : \(self.target)
            }
            """
        }
    }
    // AssociatedtypeField ::= 'associatedtype' <Whitespace> <Identifier> <Endline>
    struct AssociatedtypeField:Parseable, CustomStringConvertible
    {
        struct Associatedtype:Parseable.Terminal 
        {
            static 
            let token:String = "associatedtype"
        }
        
        let identifier:Symbol.Identifier
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Associatedtype                = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace             = try .parse(tokens, position: &position), 
                identifier:Symbol.Identifier    = try .parse(tokens, position: &position), 
                _:Symbol.Endline                = try .parse(tokens, position: &position)
            return .init(identifier: identifier)
        }
        
        var description:String 
        {
            """
            AssociatedtypeField 
            {
                identifier  : \(self.identifier)
            }
            """
        }
    }
    // AnnotationField     ::= ':' <Whitespace> ? <QualifiedIdentifier> <Whitespace> ? ( '&' <Whitespace> ? <QualifiedIdentifier> <Whitespace> ? ) * '\n'
    struct AnnotationField:Parseable, CustomStringConvertible
    {
        let identifiers:[Symbol.QualifiedIdentifier]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Colon                   = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                head:Symbol.QualifiedIdentifier = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                body:[List<Token.Ampersand, List<Symbol.Whitespace?, List<Symbol.QualifiedIdentifier, Symbol.Whitespace?>>>] =
                                                      .parse(tokens, position: &position),
                _:Token.Newline                 = try .parse(tokens, position: &position)
            return .init(identifiers: [head] + body.map(\.body.body.head))
        }
        
        var description:String 
        {
            """
            AnnotationField 
            {
                identifiers  : \(self.identifiers)
            }
            """
        }
    }
    
    // WhereField          ::= 'where' <Whitespace> <QualifiedIdentifier> <Whitespace> ? <WhereRelation> <Whitespace> ? <QualifiedIdentifier> <Endline>
    // WhereRelation       ::= ':' 
    //                       | '=='
    struct WhereField:Parseable, CustomStringConvertible
    {
        struct Where:Parseable.Terminal 
        {
            static 
            let token:String = "where"
        }
        
        let lhs:Symbol.QualifiedIdentifier, 
            rhs:Symbol.QualifiedIdentifier, 
            relation:Symbol.WhereRelation 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Where                         = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace             = try .parse(tokens, position: &position), 
                lhs:Symbol.QualifiedIdentifier  = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                relation:Symbol.WhereRelation   = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                rhs:Symbol.QualifiedIdentifier  = try .parse(tokens, position: &position),
                _:Symbol.Endline                = try .parse(tokens, position: &position)
            return .init(lhs: lhs, rhs: rhs, relation: relation)
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
    //                       | ':'  <Whitespace> ? <NormalType> <Endline> 
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
        case wrapped(Symbol.NormalType)
        
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
            else if let wrapped:List<Token.Colon, List<Symbol.Whitespace?, Symbol.NormalType>> = 
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
    
    // ParameterField      ::= '-' <Whitespace> ? <ParameterName> <Whitespace> ? ':' <Whitespace> ? <ParameterType> <Endline>
    // ParameterName       ::= <Identifier> 
    //                       | '->'
    struct ParameterField:Parseable, CustomStringConvertible
    {
        let name:Symbol.ParameterName 
        let type:Symbol.ParameterType 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Hyphen              = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                name:Symbol.ParameterName   = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                _:Token.Colon               = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                type:Symbol.ParameterType   = try .parse(tokens, position: &position), 
                _:Symbol.Endline            = try .parse(tokens, position: &position)
            return .init(name: name, type: type)
        }
        
        var description:String 
        {
            """
            ParameterField 
            {
                name: \(self.name)
                type: \(self.type)
            }
            """
        }
    }
    enum ParameterName:Parseable
    {
        case parameter(Symbol.Identifier) 
        case `return`
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let identifier:Symbol.Identifier = .parse(tokens, position: &position)
            {
                return .parameter(identifier)
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
    
    // ParagraphField      ::= <ParagraphLine> <ParagraphLine> *
    // ParagraphLine       ::= '    ' ' ' * [^\s] . * '\n'
    struct ParagraphField:Parseable, CustomStringConvertible
    {
        let string:String
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let head:Symbol.ParagraphLine   = try .parse(tokens, position: &position), 
                body:[Symbol.ParagraphLine] =     .parse(tokens, position: &position)
            
            var string:String = ""
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
                string.append(contentsOf: trimmed)
                string.append(" ")
            }
            return .init(string: string)
        }
        
        var description:String 
        {
            self.string
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
    //                       | <ParameterField>
    //                       | <ParagraphField>
    //                       | <Separator>
    // Separator           ::= <Endline>
    enum Field:Parseable 
    {
        case function(Symbol.FunctionField) 
        case `subscript`(Symbol.SubscriptField) 
        case member(Symbol.MemberField) 
        case type(Symbol.TypeField) 
        case `typealias`(Symbol.TypealiasField) 
        case `associatedtype`(Symbol.AssociatedtypeField) 
        case annotation(Symbol.AnnotationField) 
        case attribute(Symbol.AttributeField) 
        case `where`(Symbol.WhereField) 
        case `throws`(Symbol.ThrowsField) 
        case parameter(Symbol.ParameterField) 
        
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
            else if let field:Symbol.ParameterField = .parse(tokens, position: &position)
            {
                return .parameter(field)
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

func main(_ paths:[String]) throws
{
    for path:String in paths 
    {
        guard let contents:String = File.source(path: path) 
        else 
        {
            continue 
        }
        
        var doccomments:[[Character]] = [], 
            doccomment:[Character]    = []
        for line in contents.split(separator: "\n")
        {
            let line:[Character] = .init(line.drop{ $0.isWhitespace && !$0.isNewline })
            if line.starts(with: ["/", "/", "/"]) 
            {
                if line[3] == " " 
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
        
        
        var pages:[(page:Page.Binding, path:[String])] = []
        for doccomment:[Character] in doccomments
        {
            var c:Int = 0
            let fields:[Symbol.Field] = [Symbol.Field].parse(doccomment, position: &c) 
            if case .type(let header)? = fields.first 
            {
                pages.append(Page.Binding.create(header, fields: fields.dropFirst()))
            }
        }
        
        let tree:PageTree = .assemble(pages)
        print(tree)
        
        tree.resolve()
        for (page, _):(Page.Binding, [String]) in pages
        {
            let document:String = 
            """
            <head>
                <meta charset="UTF-8">
                <link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital@0;1&family=Questrial&display=swap" rel="stylesheet"> 
                <link href="style.css" rel="stylesheet"> 
            </head> 
            <body>
                \(page.page.html.rendered())
            </body>
            """
            File.save(.init(document.utf8), path: "documentation/\(page.url)")
        }
    }
}

try main(.init(CommandLine.arguments.dropFirst()))
