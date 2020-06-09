struct Markdown 
{
    struct Asterisk:Parseable.Terminal
    {
        static 
        let token:String = "*"
    } 
    struct Backtick:Parseable.Terminal
    {
        static 
        let token:String = "`"
    } 
    struct Tilde:Parseable.Terminal
    {
        static 
        let token:String = "~"
    } 
    struct Ditto:Parseable.Terminal
    {
        static 
        let token:String = "^"
    } 
    struct Backslash:Parseable.Terminal
    {
        static 
        let token:String = "\\"
    } 
    //  ParagraphToken          ::= <ParagraphLink> 
    //                            | <ParagraphSymbolLink>
    //                            | <ParagraphSubscript>
    //                            | <ParagraphSuperscript>
    //                            | '***'
    //                            | '**'
    //                            | '*'
    //                            | .
    //  ParagraphSubscript      ::= '~' [^~] * '~'
    //  ParagraphSuperscript    ::= '^' [^\^] * '^'
    //  ParagraphSymbolLink     ::= '[' <SymbolPath> <SymbolPath> * ( <Identifier> '`' ) * ']'
    //  SymbolPath              ::= '`' ( '(' <Identifiers> ').' ) ? <SymbolTail> '`'
    //  SymbolTail              ::= <Identifiers> ? '[' ( <FunctionLabel> ':' ) * ']'
    //                            | <Identifiers> ( '(' ( <FunctionLabel> ':' ) * ')' ) ?
    //  ParagraphLink           ::= '[' [^\]] * '](' [^\)] ')'
    struct NotClosingBracket:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            return !character.isNewline && character != "]"
        }
    } 
    struct NotClosingParenthesis:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            return !character.isNewline && character != ")"
        }
    } 
    struct NotClosingTilde:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            return !character.isNewline && character != "~"
        }
    } 
    struct NotClosingDitto:Parseable.TerminalClass
    {
        let character:Character 
        
        static 
        func test(_ character:Character) -> Bool 
        {
            return !character.isNewline && character != "^"
        }
    } 
    
    enum Element:Parseable
    {
        enum Text:Parseable
        {
            case star3
            case star2 
            case star1 
            case backtick(count:Int)
            case wildcard(Character)
            
            static 
            func parse(_ tokens:[Character], position:inout Int) throws -> Self
            {
                if      let _:List<Asterisk, List<Asterisk, Asterisk>> = 
                    .parse(tokens, position: &position) 
                {
                    return .star3
                }
                else if let _:List<Asterisk, Asterisk> = 
                    .parse(tokens, position: &position) 
                {
                    return .star2
                }
                else if let _:Asterisk = 
                    .parse(tokens, position: &position) 
                {
                    return .star1
                }
                else if let backticks:List<Backtick, [Backtick]> = 
                    .parse(tokens, position: &position) 
                {
                    return .backtick(count: 1 + backticks.body.count)
                }
                // escape sequences 
                else if let _:List<Backslash, Asterisk> = 
                    .parse(tokens, position: &position) 
                {
                    return .wildcard("*")
                }
                else if let _:List<Backslash, Backtick> = 
                    .parse(tokens, position: &position) 
                {
                    return .wildcard("`")
                }
                else if let _:List<Backslash, Backslash> = 
                    .parse(tokens, position: &position) 
                {
                    return .wildcard("\\")
                }
                else if let _:List<Backslash, Token.Space> = 
                    .parse(tokens, position: &position) 
                {
                    return .wildcard("\u{A0}")
                }
                else if position < tokens.endIndex
                {
                    defer 
                    {
                        position += 1
                    }
                    return .wildcard(tokens[position])
                }
                else 
                {
                    throw ParsingError.unexpectedEOS(expected: Self.self)
                }
            }
        }
        
        struct SymbolLink:Parseable
        {
            struct Path:Parseable
            {
                let prefix:[String], 
                    path:[String]
                    
                static 
                func parse(_ tokens:[Character], position:inout Int) throws -> Self
                {
                    let _:Backtick                      = try .parse(tokens, position: &position), 
                        prefix:List<Token.Parenthesis.Left, List<Symbol.Identifiers, List<Token.Parenthesis.Right, Token.Period>>>? = 
                                                              .parse(tokens, position: &position)
                    let path:[String]
                    // parse subscript first, or else it’s ambiguous 
                    if      let tail:List<Symbol.Identifiers?, 
                        List<Token.Bracket.Left, List<[List<Symbol.FunctionLabel, Token.Colon>], Token.Bracket.Right>>> = 
                        .parse(tokens, position: &position)
                    {
                        path = (tail.head?.identifiers ?? []) + 
                            ["[\(tail.body.body.head.map(\.head.description).joined())]"]
                    }
                    else if let tail:Symbol.Identifiers = .parse(tokens, position: &position) 
                    {
                        if let labels:List<Token.Parenthesis.Left, List<[List<Symbol.FunctionLabel, Token.Colon>], Token.Parenthesis.Right>> = 
                            .parse(tokens, position: &position)
                        {
                            path = tail.identifiers.dropLast() + 
                                ["\(tail.identifiers[tail.identifiers.endIndex - 1])(\(labels.body.head.map(\.head.description).joined()))"]
                        }
                        else 
                        {
                            path = tail.identifiers
                        }
                        
                    }
                    else 
                    {
                        throw ParsingError.unexpected(tokens, position, expected: Self.self)
                    }
                    
                    let _:Backtick = try .parse(tokens, position: &position)
                    return .init(prefix: prefix?.body.head.identifiers ?? [], path: path)
                }
            }
            
            let paths:[Path], 
                suffix:[String]
            
            static 
            func parse(_ tokens:[Character], position:inout Int) throws -> Self
            {
                let _:Token.Bracket.Left            = try .parse(tokens, position: &position),
                    head:Path                       = try .parse(tokens, position: &position), 
                    body:[Path]                     =     .parse(tokens, position: &position),
                    suffix:[List<Symbol.Identifier, Backtick>] = .parse(tokens, position: &position), 
                    _:Token.Bracket.Right           = try .parse(tokens, position: &position) 
                return .init(paths: [head] + body, suffix: suffix.map(\.head.string))
            }
        }
        struct Link:Parseable
        {
            let text:[Text], 
                url:String, 
                classes:[String]
            
            init(text:[Text], url:String, classes:[String] = []) 
            {
                self.text       = text 
                self.url        = url 
                self.classes    = classes 
            }
                
            static 
            func parse(_ tokens:[Character], position:inout Int) throws -> Self
            {
                let _:Token.Bracket.Left            = try .parse(tokens, position: &position),
                    text:[NotClosingBracket]        =     .parse(tokens, position: &position),
                    _:Token.Bracket.Right           = try .parse(tokens, position: &position),
                    _:Token.Parenthesis.Left        = try .parse(tokens, position: &position),
                    url:[NotClosingParenthesis]     =     .parse(tokens, position: &position),
                    _:Token.Parenthesis.Right       = try .parse(tokens, position: &position)
                let characters:[Character] = text.map(\.character)
                var c:Int = characters.startIndex
                return .init(text: .parse(characters, position: &c), url: .init(url.map(\.character)))
            }
        }
        
        case symbol(SymbolLink)
        case link(Link)
        case sub([Text])
        case sup([Text])
        case text(Text)
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let symbol:SymbolLink = .parse(tokens, position: &position) 
            {
                return .symbol(symbol)
            }
            else if let link:Link = .parse(tokens, position: &position) 
            {
                return .link(link)
            }
            else if let sub:List<Tilde, List<[NotClosingTilde], Tilde>> = 
                .parse(tokens, position: &position) 
            {
                return .sub(.parse(sub.body.head.map(\.character)))
            }
            else if let sup:List<Ditto, List<[NotClosingDitto], Ditto>> = 
                .parse(tokens, position: &position) 
            {
                return .sup(.parse(sup.body.head.map(\.character)))
            }
            else if let text:Text = .parse(tokens, position: &position) 
            {
                return .text(text)
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    enum Tag 
    {
        case triple 
        case strong 
        case em 
        case code(count:Int) 
        
        case a 
        case p
        case sub 
        case sup 
    }
    static 
    func html(tag:Tag, attributes:[String: String], elements:[Element]) -> HTML.Tag
    {
        var stack:[(tag:Tag, attributes:[String: String], content:[HTML.Tag.Content])] = 
            [(tag, attributes, [])]
        for element:Element in elements 
        {
            switch element 
            {
            case .symbol(let link):
                stack[stack.endIndex - 1].content.append(.child(
                    .init("code", [:], (link.paths.map(\.path).flatMap{ $0 } + link.suffix).joined(separator: "."))))
            
            case .link(let link):
                var attributes:[String: String] = ["href": link.url, "target": "_blank"]
                if !link.classes.isEmpty 
                {
                    attributes["class"] = link.classes.joined(separator: " ")
                }
                stack[stack.endIndex - 1].content.append(.child(
                    Self.html(tag: .a, attributes: attributes, elements: link.text.map(Element.text(_:)))))
            
            case .sub(let text):
                stack[stack.endIndex - 1].content.append(.child(
                    Self.html(tag: .sub, attributes: [:], elements: text.map(Element.text(_:)))))
            case .sup(let text):
                stack[stack.endIndex - 1].content.append(.child(
                    Self.html(tag: .sup, attributes: [:], elements: text.map(Element.text(_:)))))
            
            case .text(.wildcard(let c)):
                stack[stack.endIndex - 1].content.append(.character(c))
            
            case .text(.star3):
                switch stack.last
                {
                case (.triple, let attributes, let content)?:
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("em", [:], 
                        [
                            .init("strong", attributes, content: content)
                        ])))
                case (.strong, let attributes, let content)?: // treat as '**' '*'
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("strong", attributes, content: content)))
                    stack.append((.em, [:], []))
                case (.em, let attributes, let content)?: // treat as '*' '**'
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("em", attributes, content: content)))
                    stack.append((.strong, [:], []))
                case (.code, _, _)?: // treat as raw text
                    stack[stack.endIndex - 1].content.append(contentsOf: "***".map(HTML.Tag.Content.character(_:)))
                default:
                    stack.append((.triple, [:], []))
                }
            
            case .text(.star2):
                switch stack.last
                {
                case (.triple, let attributes, let content)?:
                    stack.removeLast()
                    stack.append((.em, attributes, [.child(.init("strong", [:], content: content))]))
                case (.strong, let attributes, let content)?: 
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("strong", attributes, content: content)))
                case (.em, let attributes, let content)?: // treat as '*' '*'
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("em", attributes, content: content)))
                    stack.append((.em, [:], []))
                case (.code, _, _)?: // treat as raw text
                    stack[stack.endIndex - 1].content.append(contentsOf: "**".map(HTML.Tag.Content.character(_:)))
                default:
                    stack.append((.strong, [:], []))
                }
            
            case .text(.star1):
                switch stack.last
                {
                case (.triple, let attributes, let content)?: // **|*  *
                    stack.removeLast()
                    stack.append((.strong, attributes, [.child(.init("em", [:], content: content))]))
                
                case (.em, let attributes, let content)?: 
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("em", attributes, content: content)))
                case (.code, _, _)?: // treat as raw text
                    stack[stack.endIndex - 1].content.append(.character("*"))
                default:
                    stack.append((.em, [:], []))
                }
            
            case .text(.backtick(count: let count)):
                switch stack.last 
                {
                case (.code(count: count), let attributes, let content)?:
                    stack.removeLast()
                    stack[stack.endIndex - 1].content.append(.child(
                        .init("code", attributes, content: content)))
                case (.code(count: _), _, _)?:
                    stack[stack.endIndex - 1].content.append(contentsOf: repeatElement(.character("`"), count: count))
                default:
                    stack.append((.code(count: count), [:], []))
                }
            }
        }
        
        // flatten stack (happens when there are unclosed delimiters)
        while stack.count > 1
        {
            let (tag, _, content):(Tag, [String: String], [HTML.Tag.Content]) = stack.removeLast()
            let plain:[Character] 
            switch tag 
            {
            case .triple:
                plain = ["*", "*", "*"]
            case .strong:
                plain = ["*", "*"]
            case .em:
                plain = ["*"]
            case .code(count: let count):
                plain = .init(repeating: "`", count: count)
            default:
                plain = []
            }
            stack[stack.endIndex - 1].content.append(contentsOf: plain.map(HTML.Tag.Content.character(_:)) + content)
        }
        switch tag 
        {
        case .p:
            return .init("p", attributes, content: stack[stack.endIndex - 1].content)
        case .a:
            return .init("a", attributes, content: stack[stack.endIndex - 1].content)
        case .sub:
            return .init("sub", attributes, content: stack[stack.endIndex - 1].content)
        case .sup:
            return .init("sup", attributes, content: stack[stack.endIndex - 1].content)
        default:
            fatalError("unreachable")
        }
    }
}
