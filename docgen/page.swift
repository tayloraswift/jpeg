final 
class Page 
{
    enum Label 
    {
        case enumeration 
        case genericEnumeration 
        case structure 
        case genericStructure 
        case `class`
        case genericClass 
        case `protocol`
        
        case enumerationCase
        case initializer
        case genericInitializer
        case staticMethod 
        case genericStaticMethod 
        case instanceMethod 
        case genericInstanceMethod 
        case staticProperty
        case instanceProperty
        case `associatedtype`
        case `subscript` 
    }
    
    enum Link:Equatable
    {
        case unresolved(path:[String])
        case resolved(url:String)
        case apple(url:String)
        
        static 
        func appleify(_ path:[String]) -> Self 
        {
            .apple(url: "https://developer.apple.com/documentation/\(path.map{ $0.lowercased() }.joined(separator: "/"))")
        }
        
        static 
        func link<T>(_ components:[(String, T)]) -> [(component:(String, T), link:Link)]
        {
            let scan:[(component:(String, T), accumulated:[String])] = components.enumerated().map 
            {
                (($0.1.0, $0.1.1), components.prefix($0.0 + 1).map(\.0))
            }
            
            if scan.first?.component.0 == "Swift" 
            {
                return scan.dropFirst().map 
                {
                    ($0.component, .appleify($0.accumulated))
                }
            } 
            else 
            {
                return scan.map 
                {
                    ($0.component, .unresolved(path: $0.accumulated))
                }
            }
        }
    }
    
    enum Declaration 
    {
        enum Token:Equatable
        {
            case whitespace 
            case breakableWhitespace
            case keyword(String)
            case identifier(String)
            case type(String, Link)
            case typePunctuation(String, Link)
            case punctuation(String)
        }
        
        static 
        func tokenize(_ identifiers:[String]) -> [Token]
        {
            return .init(Link.link(identifiers.map{ ($0, ()) }).map 
            {
                [.type($0.component.0, $0.link)]
            }.joined(separator: [.punctuation(".")]))
        }
        
        static 
        func tokenize(_ type:Symbol.SwiftType) -> [Token] 
        {
            switch type 
            {
            case .named(let identifiers):
                if      identifiers.count           == 2, 
                        identifiers[0].identifier   == "Swift",
                        identifiers[0].generics.isEmpty
                {
                    if      identifiers[1].identifier       == "Optional", 
                            identifiers[1].generics.count   == 1
                    {
                        let element:Symbol.SwiftType    = identifiers[1].generics[0]
                        let link:Link                   = .appleify(["Swift", "Optional"])
                        var tokens:[Token] = []
                        tokens.append(contentsOf: Self.tokenize(element))
                        tokens.append(.typePunctuation("?", link))
                        return tokens 
                    }
                    else if identifiers[1].identifier       == "Array", 
                            identifiers[1].generics.count   == 1
                    {
                        let element:Symbol.SwiftType    = identifiers[1].generics[0]
                        let link:Link                   = .appleify(["Swift", "Array"])
                        var tokens:[Token] = []
                        tokens.append(.typePunctuation("[", link))
                        tokens.append(contentsOf: Self.tokenize(element))
                        tokens.append(.typePunctuation("]", link))
                        return tokens 
                    }
                    else if identifiers[1].identifier       == "Dictionary", 
                            identifiers[1].generics.count   == 2
                    {
                        let key:Symbol.SwiftType    = identifiers[1].generics[0],
                            value:Symbol.SwiftType  = identifiers[1].generics[1]
                        let link:Link               = .appleify(["Swift", "Dictionary"])
                        var tokens:[Token] = []
                        tokens.append(.typePunctuation("[", link))
                        tokens.append(contentsOf: Self.tokenize(key))
                        tokens.append(.typePunctuation(":", link))
                        tokens.append(.whitespace)
                        tokens.append(contentsOf: Self.tokenize(value))
                        tokens.append(.typePunctuation("]", link))
                        return tokens 
                    }
                }
                
                return .init(Link.link(identifiers.map{ ($0.identifier, $0.generics) }).map 
                {
                    (element:(component:(identifier:String, generics:[Symbol.SwiftType]), link:Link)) -> [Token] in 
                    var tokens:[Token] = [.type(element.component.identifier, element.link)]
                    if !element.component.generics.isEmpty
                    {
                        tokens.append(.punctuation("<"))
                        tokens.append(contentsOf: element.component.generics.map(Self.tokenize(_:))
                            .joined(separator: [.punctuation(","), .breakableWhitespace]))
                        tokens.append(.punctuation(">"))
                    }
                    return tokens
                }.joined(separator: [.punctuation(".")]))
            
            case .compound(let elements):
                var tokens:[Token] = []
                tokens.append(.punctuation("("))
                tokens.append(contentsOf: elements.map 
                {
                    (element:Symbol.LabeledType) -> [Token] in
                    var tokens:[Token]  = []
                    if let label:String = element.label
                    {
                        tokens.append(.identifier(label))
                        tokens.append(.punctuation(":"))
                    }
                    tokens.append(contentsOf: Self.tokenize(element.type))
                    return tokens 
                }.joined(separator: [.punctuation(","), .breakableWhitespace]))
                tokens.append(.punctuation(")"))
                return tokens
            
            case .function(let type):
                var tokens:[Token] = []
                for attribute:Symbol.Attribute in type.attributes
                {
                    tokens.append(.keyword("\(attribute)"))
                    tokens.append(.breakableWhitespace)
                }
                tokens.append(.punctuation("("))
                tokens.append(contentsOf: type.parameters.map 
                {
                    (parameter:Symbol.FunctionParameter) -> [Token] in
                    var tokens:[Token]  = []
                    for attribute:Symbol.Attribute in parameter.attributes
                    {
                        tokens.append(.keyword("\(attribute)"))
                        tokens.append(.whitespace)
                    }
                    if parameter.inout 
                    {
                        tokens.append(.keyword("inout"))
                        tokens.append(.whitespace)
                    }
                    tokens.append(contentsOf: Self.tokenize(parameter.type))
                    return tokens 
                }.joined(separator: [.punctuation(","), .breakableWhitespace]))
                tokens.append(.punctuation(")"))
                tokens.append(.breakableWhitespace)
                if type.throws
                {
                    tokens.append(.keyword("throws"))
                    tokens.append(.breakableWhitespace)
                }
                tokens.append(.keyword("->"))
                tokens.append(.whitespace)
                tokens.append(contentsOf: Self.tokenize(type.return))
                return tokens
            }
        } 
        
        // includes trailing whitespace 
        static 
        func tokenize(_ attributes:[Symbol.AttributeField]) -> [Token] 
        {
            var tokens:[Page.Declaration.Token] = []
            for attribute:Symbol.AttributeField in attributes 
            {
                switch attribute
                {
                case .frozen:
                    tokens.append(.keyword("@frozen"))
                    tokens.append(.breakableWhitespace)
                case .inlinable:
                    tokens.append(.keyword("@inlinable"))
                    tokens.append(.breakableWhitespace)
                case .wrapper:
                    tokens.append(.keyword("@propertyWrapper"))
                    tokens.append(.breakableWhitespace)
                case .wrapped(let wrapper):
                    tokens.append(.keyword("@"))
                    tokens.append(contentsOf: Self.tokenize(wrapper))
                    tokens.append(.breakableWhitespace)
                case .specialized:
                    break // not implemented 
                }
            }
            return tokens
        }
    }
    
    enum Signature
    {
        enum Token:Equatable
        {
            case whitespace 
            case text(String)
            case punctuation(String)
            case highlight(String)
        }
        
        static 
        func convert(_ declaration:[Declaration.Token]) -> [Token] 
        {
            declaration.map 
            {
                switch $0 
                {
                case    .whitespace, .breakableWhitespace:
                    return .whitespace
                case    .keyword(let text), 
                        .identifier(let text),
                        .type(let text, _):
                    return .text(text)
                case    .typePunctuation(let text, _), 
                        .punctuation(let text):
                    return .punctuation(text)
                }
            }
        }
    }
    
    struct Binding 
    {
        struct Key:Hashable 
        {
            let key:String 
            let rank:Int, 
                order:Int 
            
            init(_ field:Symbol.TopicElementField, order:Int) 
            {
                self.key   = field.key 
                self.rank  = field.rank
                self.order = order
            }
        }
        
        let url:String
        let locals:Set<String>, 
            keys:Set<Key>
        let page:Page 
        
        static 
        func url(_ identifiers:[String]) -> String 
        {
            identifiers.joined(separator: "-")
        }
    }
    
    typealias TopicSymbol   = (signature:[Signature.Token], url:String, blurb:[Markdown.Element], required:[Markdown.Element])
    typealias Topic         = (topic:String, key:String, symbols:[TopicSymbol])
    
    let label:Label 
    let name:String 
    let signature:[Signature.Token]
    var declaration:[Declaration.Token] 
    var blurb:[Markdown.Element]
    var discussion:
    (
        parameters:[(name:String, paragraphs:[[Markdown.Element]])], 
        return:[[Markdown.Element]],
        overview:[[Markdown.Element]], 
        required:[Markdown.Element]
    )
    
    var topics:[Topic]
    var breadcrumbs:[(text:String, link:Link)], 
        breadcrumb:String 
    
    init(label:Label, name:String, signature:[Signature.Token], declaration:[Declaration.Token], 
        fields:Fields, path:[String])
    {
        self.label          = label 
        self.name           = name 
        self.signature      = signature 
        self.declaration    = declaration 
        self.blurb          = fields.blurb?.elements ?? [] 
        
        let required:[Markdown.Element] 
        switch fields.requirement 
        {
        case nil:
            switch label 
            {
            case .initializer, .genericInitializer, .staticMethod, .genericStaticMethod, 
                .instanceMethod, .genericInstanceMethod, .staticProperty, .instanceProperty, 
                .subscript:
                let conformances:[String] = fields.annotations.map 
                {
                    if $0.annotations.count != 1 
                    {
                        Swift.print("warning: annotation for \(path) cannot conform to protocol conjunctions")
                    }
                    return "[`\($0.annotations[0].joined(separator: "."))`]"
                }
                
                guard let first:String = conformances.first 
                else 
                {
                    fallthrough 
                }
                guard let second:String = conformances.dropFirst().first 
                else 
                {
                    required = .parse("Implements requirement in \(first)")
                    break 
                }
                guard let last:String = conformances.dropFirst(2).last 
                else 
                {
                    required = .parse("Implements requirement in \(first) and \(second)")
                    break 
                }
                required = .parse("Implements requirement in \(conformances.dropLast().joined(separator: ", ")), and \(last)")
                
            default:
                required = []
            }
        
        case .required?:
            required = .parse("**Required.**")
        case .defaulted?:
            required = .parse("**Required.** Default implementation provided.")
        }
        self.discussion     = 
        (
            fields.parameters.map{ ($0.name, $0.paragraphs.map(\.elements)) }, 
            fields.return?.paragraphs.map(\.elements) ?? [], 
            fields.discussion.map(\.elements), 
            required
        )
        self.topics         = fields.topics
        self.breadcrumbs    = Link.link(path.dropLast().map{ ($0, ()) }).map 
        {
            ($0.component.0, $0.link)
        }
        switch label 
        {
        case    .enumerationCase, .initializer, .genericInitializer, 
                .staticMethod, .genericStaticMethod, 
                .instanceMethod, .genericInstanceMethod, .
                subscript:
            self.breadcrumb     = name
        default:
            self.breadcrumb     = path[path.endIndex - 1]
        }
    }
}
extension Page 
{
    private static 
    func crosslink(_ unlinked:[Markdown.Element], scopes:[PageTree]) -> [Markdown.Element]
    {
        var elements:[Markdown.Element] = []
        for element:Markdown.Element in unlinked
        {
            outer:
            switch element 
            {
            case .symbol(let link):
                elements.append(.text(.backtick(count: 1)))
                elements.append(contentsOf: link.paths.map 
                {
                    (sublink:Markdown.Element.SymbolLink.Path) in 
                    Link.link(sublink.path.map{ ($0, ()) }).map 
                    {
                        (element:(component:(String, Void), link:Link)) -> [Markdown.Element] in
                        let target:String, 
                            `class`:String
                        switch element.link 
                        {
                        case .apple(url: let url):
                            target  = url 
                            `class` = "syntax-swift-type"
                        case .resolved(url: let url):
                            target  = url 
                            `class` = "syntax-type"
                        case .unresolved(path: let path):
                            let full:[String] = sublink.prefix + path 
                            guard let binding:Binding = PageTree.resolve(full[...], in: scopes)
                            else 
                            {
                                return element.component.0.map{ .text(.wildcard($0)) }
                            }
                            target = binding.url
                            `class` = "syntax-type"
                        }
                        
                        return 
                            [
                            .link(.init(text: element.component.0.map(Markdown.Element.Text.wildcard(_:)), url: target, classes: [`class`])), 
                            ]
                    }.joined(separator: [.text(.wildcard("."))])
                }.joined(separator: [.text(.wildcard("."))]))
                for component:String in link.suffix 
                {
                    elements.append(.text(.wildcard(".")))
                    elements.append(contentsOf: component.map{ .text(.wildcard($0)) })
                }
                elements.append(.text(.backtick(count: 1)))
                
                continue 
            default:
                break 
            }
            elements.append(element)
        }
        return elements
    }
    
    func crosslink(scopes:[PageTree]) 
    {
        self.declaration = self.declaration.map 
        {
            switch $0 
            {
            case .type(let component, .unresolved(path: let path)):
                guard let binding:Binding = PageTree.resolve(path[...], in: scopes)
                else 
                {
                    return .identifier(component)
                }
                return .type(component, .resolved(url: binding.url))
            default:
                return $0
            }
        }
        
        self.blurb                  = Self.crosslink(self.blurb, scopes: scopes)
        self.discussion.parameters  = self.discussion.parameters.map 
        {
            ($0.name, $0.paragraphs.map{ Self.crosslink($0, scopes: scopes) })
        }
        self.discussion.return      = self.discussion.return.map{   Self.crosslink($0, scopes: scopes) }
        self.discussion.overview    = self.discussion.overview.map{ Self.crosslink($0, scopes: scopes) }
        self.discussion.required    = Self.crosslink(self.discussion.required, scopes: scopes) 
        
        self.breadcrumbs = self.breadcrumbs.map 
        {
            switch $0.link 
            {
            case .unresolved(path: let path):
                guard let binding:Binding = PageTree.resolve(path[...], in: scopes)
                else 
                {
                    break 
                }
                return ($0.text, .resolved(url: binding.url))
            default:
                break 
            }
            return $0
        }
    }
    
    func attachTopics<C>(children:C, global:[String: [TopicSymbol]]) 
        where C:Collection, C.Element == PageTree 
    {
        for i:Int in self.topics.indices 
        {
            self.topics[i].symbols.append(contentsOf: 
            global[self.topics[i].key, default: []].filter 
            {
                $0.signature != self.signature
            })
        }
        let seen:Set<String> = .init(self.topics.flatMap{ $0.symbols.map(\.url) })
        var topics: 
        (
            enumerations        :[TopicSymbol],
            structures          :[TopicSymbol],
            classes             :[TopicSymbol],
            protocols           :[TopicSymbol],
            cases               :[TopicSymbol],
            initializers        :[TopicSymbol],
            typeMethods         :[TopicSymbol],
            instanceMethods     :[TopicSymbol],
            typeProperties      :[TopicSymbol],
            instanceProperties  :[TopicSymbol],
            associatedtypes     :[TopicSymbol],
            subscripts          :[TopicSymbol]
        )
        topics = ([], [], [], [], [], [], [], [], [], [], [], [])
        for binding:Page.Binding in 
            (children.flatMap(\.pages).sorted{ $0.page.name < $1.page.name })
        {
            guard !seen.contains(binding.url)
            else 
            {
                continue 
            }
            
            let symbol:TopicSymbol = 
            (
                binding.page.signature, 
                binding.url, 
                binding.page.blurb, 
                binding.page.discussion.required
            )
            switch binding.page.label 
            {
            case .enumeration, .genericEnumeration:
                topics.enumerations.append(symbol)
            case .structure, .genericStructure:
                topics.structures.append(symbol)
            case .class, .genericClass:
                topics.classes.append(symbol)
            case .protocol:
                topics.protocols.append(symbol)
            
            case .enumerationCase:
                topics.cases.append(symbol)
            case .initializer, .genericInitializer:
                topics.initializers.append(symbol)
            case .staticMethod, .genericStaticMethod:
                topics.typeMethods.append(symbol)
            case .instanceMethod, .genericInstanceMethod:
                topics.instanceMethods.append(symbol)
            case .staticProperty:
                topics.typeProperties.append(symbol)
            case .instanceProperty:
                topics.instanceProperties.append(symbol)
            case .associatedtype:
                topics.associatedtypes.append(symbol)
            case .subscript:
                topics.subscripts.append(symbol)
            }
        }
        
        for builtin:(topic:String, symbols:[TopicSymbol]) in 
        [
            (topic: "Enumeration cases",    symbols: topics.cases), 
            (topic: "Associatedtypes",      symbols: topics.associatedtypes), 
            (topic: "Initializers",         symbols: topics.initializers), 
            (topic: "Subscripts",           symbols: topics.subscripts), 
            (topic: "Type properties",      symbols: topics.typeProperties), 
            (topic: "Instance properties",  symbols: topics.instanceProperties), 
            (topic: "Type methods",         symbols: topics.typeMethods), 
            (topic: "Instance methods",     symbols: topics.instanceMethods), 
            (topic: "Enumerations",         symbols: topics.enumerations), 
            (topic: "Structures",           symbols: topics.structures), 
            (topic: "Classes",              symbols: topics.classes), 
            (topic: "Protocols",            symbols: topics.protocols), 
        ]
            where !builtin.symbols.isEmpty
        {
            self.topics.append((builtin.topic, "$builtin", builtin.symbols))
        }
        
        // move 'see also' to the end 
        if let i:Int = (self.topics.firstIndex{ $0.topic.lowercased() == "see also" })
        {
            let seealso:Topic = self.topics.remove(at: i)
            self.topics.append(seealso)
        }
    }
    
    static 
    func print(function fields:Fields, labels:[String], delimiters:(Character, Character),
        signature:inout [Signature.Token], declaration:inout [Declaration.Token]) -> [String]
    {
        guard labels.count == fields.parameters.count 
        else 
        {
            fatalError("warning: function/subscript '\(signature)' has \(labels.count) labels, but \(fields.parameters.count) parameters")
        }
        
        signature.append(.punctuation(.init(delimiters.0)))
        declaration.append(.punctuation(.init(delimiters.0)))
        
        var mangled:[String] = []
        
        var interior:(signature:[[Page.Signature.Token]], declaration:[[Page.Declaration.Token]]) = 
            ([], [])
        for (label, (name, parameter, _)):(String, (String, Symbol.FunctionParameter, [Symbol.ParagraphField])) in 
            zip(labels, fields.parameters)
        {
            var signature:[Page.Signature.Token]        = []
            var declaration:[Page.Declaration.Token]    = []
            
            if label != "_" 
            {
                mangled.append(label)
                signature.append(.highlight(label))
                signature.append(.punctuation(":"))
                declaration.append(.identifier(label))
            }
            else 
            {
                declaration.append(.keyword(label))
            }
            if label != name || delimiters == ("[", "]")
            {
                declaration.append(.whitespace)
                declaration.append(.identifier(name))
            }
            declaration.append(.punctuation(":"))
            for attribute:Symbol.Attribute in parameter.attributes
            {
                declaration.append(.keyword("\(attribute)"))
                declaration.append(.whitespace)
            }
            if parameter.inout 
            {
                mangled.append("inout")
                signature.append(.text("inout"))
                signature.append(.whitespace)
                declaration.append(.keyword("inout"))
                declaration.append(.whitespace)
            }
            let type:(declaration:[Page.Declaration.Token], signature:[Page.Signature.Token]) 
            type.declaration = Page.Declaration.tokenize(parameter.type)
            type.signature   = Page.Signature.convert(type.declaration)
            for token:Page.Signature.Token in type.signature 
            {
                switch token 
                {
                case    .whitespace, .punctuation:
                    break
                case    .text(let text), .highlight(let text):
                    mangled.append(text)
                }
            }
            signature.append(contentsOf: type.signature)
            declaration.append(contentsOf: type.declaration)
            
            interior.signature.append(signature)
            interior.declaration.append(declaration)
        }
        
        signature.append(contentsOf: 
            interior.signature.joined(separator: [.punctuation(","), .whitespace]))
        declaration.append(contentsOf: 
            interior.declaration.joined(separator: [.punctuation(","), .breakableWhitespace]))
        
        signature.append(.punctuation(.init(delimiters.1)))
        declaration.append(.punctuation(.init(delimiters.1)))
        
        if let `throws`:Symbol.ThrowsField = fields.throws
        {
            signature.append(.whitespace)
            signature.append(.text("\(`throws`)"))
            declaration.append(.breakableWhitespace)
            declaration.append(.keyword("\(`throws`)"))
        }
        
        if let type:Symbol.SwiftType = fields.return?.type 
        {
            signature.append(.whitespace)
            signature.append(.punctuation("->"))
            signature.append(.whitespace)
            declaration.append(.breakableWhitespace)
            declaration.append(.punctuation("->"))
            declaration.append(.whitespace)
            
            let tokens:[Page.Declaration.Token] = Page.Declaration.tokenize(type)
            signature.append(contentsOf: Page.Signature.convert(tokens))
            declaration.append(contentsOf: tokens)
        }
        
        return mangled
    }
}
extension Page 
{
    struct Fields
    {
        let annotations:[Symbol.AnnotationField], 
            attributes:[Symbol.AttributeField], 
            wheres:[Symbol.WhereField], 
            paragraphs:[Symbol.ParagraphField],
            `throws`:Symbol.ThrowsField?, 
            requirement:Symbol.RequirementField?
        let keys:Set<Page.Binding.Key>,
            topics:[Page.Topic]
        let parameters:[(name:String, type:Symbol.FunctionParameter, paragraphs:[Symbol.ParagraphField])], 
            `return`:(type:Symbol.SwiftType, paragraphs:[Symbol.ParagraphField])?
        
        var blurb:Symbol.ParagraphField?
        {
            self.paragraphs.first
        }
        var discussion:ArraySlice<Symbol.ParagraphField> 
        {
            self.paragraphs.dropFirst()
        }
        
        init<S>(_ fields:S, order:Int) where S:Sequence, S.Element == Symbol.Field 
        {
            var annotations:[Symbol.AnnotationField]    = [], 
                attributes:[Symbol.AttributeField]      = [], 
                wheres:[Symbol.WhereField]              = [], 
                paragraphs:[Symbol.ParagraphField]      = [],
                topics:[Symbol.TopicField]              = [], 
                keys:[Symbol.TopicElementField]         = []
            var `throws`:Symbol.ThrowsField?, 
                requirement:Symbol.RequirementField?
            var parameters:[(parameter:Symbol.ParameterField, paragraphs:[Symbol.ParagraphField])] = []
            
            for field:Symbol.Field in fields
            {
                switch field 
                {
                case .annotation    (let field):
                    annotations.append(field)
                case .attribute     (let field):
                    attributes.append(field)
                case .where         (let field):
                    wheres.append(field)
                case .paragraph     (let field):
                    if parameters.isEmpty 
                    {
                        paragraphs.append(field)
                    }
                    else 
                    {
                        parameters[parameters.endIndex - 1].paragraphs.append(field)
                    }
                case .topic         (let field):
                    topics.append(field)
                case .topicElement  (let field):
                    keys.append(field)
                
                case .parameter     (let field):
                    parameters.append((field, []))
                    
                case .throws        (let field):
                    guard `throws` == nil 
                    else 
                    {
                        fatalError("only one throws field per doccomnent allowed")
                    }
                    `throws` = field 
                    
                case .requirement   (let field):
                    guard requirement == nil 
                    else 
                    {
                        fatalError("only one requirement field per doccomnent allowed")
                    }
                    requirement = field 
                
                case .subscript, .function, .member, .type, .typealias, .associatedtype:
                    fatalError("only one header field per doccomnent allowed")
                    
                case .separator:
                    break
                }
            }
            
            self.annotations    = annotations
            self.attributes     = attributes
            self.wheres         = wheres
            self.paragraphs     = paragraphs
            self.throws         = `throws`
            self.requirement    = requirement
            
            self.keys           = .init(keys.map{ .init($0, order: order) })
            self.topics         = topics.map{ ($0.display, $0.key, []) }
            
            if  let (last, paragraphs):(Symbol.ParameterField, [Symbol.ParagraphField]) = 
                parameters.last, 
                case .return = last.name
            {
                self.return = (last.parameter.type, paragraphs)
                parameters.removeLast()
            }
            else 
            {
                self.return = nil
            }
            
            self.parameters = parameters.map 
            {
                guard case .parameter(let name) = $0.parameter.name 
                else 
                {
                    fatalError("return value must be the last parameter field")
                }
                return (name, $0.parameter.parameter, $0.paragraphs)
            }
        }
    }
}
extension Page.Binding 
{
    static 
    func create(_ header:Symbol.SubscriptField, fields:ArraySlice<Symbol.Field>, order:Int) 
        -> (page:Self, path:[String]) 
    {
        let fields:Page.Fields = .init(fields, order: order)
        if !fields.wheres.isEmpty 
        {
            print("warning: where fields are ignored in a subscript doccoment")
        }
        
        let name:String = "[\(header.labels.map{ "\($0):" }.joined())]" 
        
        var declaration:[Page.Declaration.Token]    = 
            Page.Declaration.tokenize(fields.attributes) + [.keyword("subscript")]
        var signature:[Page.Signature.Token]        =      [   .text("subscript")]
        
        
        let mangled:[String] = Page.print(function: fields, labels: header.labels, delimiters: ("[", "]"), 
            signature: &signature, declaration: &declaration)
        
        let path:[String] = header.identifiers + ["subscript"]
        let page:Page = .init(label: .subscript, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           path)
        let binding:Page.Binding    = .init(url: Self.url(path + mangled), 
            locals: [], keys: fields.keys, page: page)
        return (page: binding, path: path)
    }
    static 
    func create(_ header:Symbol.FunctionField, fields:ArraySlice<Symbol.Field>, order:Int) 
        -> (page:Self, path:[String]) 
    {
        let fields:Page.Fields = .init(fields, order: order)
        if !fields.wheres.isEmpty 
        {
            print("warning: where fields are ignored in a function doccoment")
        }
        
        var declaration:[Page.Declaration.Token] = Page.Declaration.tokenize(fields.attributes)
        
        let basename:String = header.identifiers[header.identifiers.endIndex - 1]
        let label:Page.Label, 
            keywords:[String] 
        switch (header.keyword, header.generics)
        {
        case (.`init`, []):
            label    = .initializer 
            keywords = []
        case (.`init`, _):
            label    = .genericInitializer 
            keywords = []
        
        case (.func, []):
            label    = .instanceMethod 
            keywords = ["func"]
        case (.func, _):
            label    = .genericInstanceMethod 
            keywords = ["func"]
        
        case (.mutatingFunc, []):
            label    = .instanceMethod 
            keywords = ["mutating", "func"]
        case (.mutatingFunc, _):
            label    = .genericInstanceMethod 
            keywords = ["mutating", "func"]
        
        case (.staticFunc, []):
            label    = .staticMethod 
            keywords = ["static", "func"]
        case (.staticFunc, _):
            label    = .genericStaticMethod 
            keywords = ["static", "func"]
        
        case (.case, _):
            label    = .enumerationCase
            keywords = ["case"]
        case (.indirectCase, _):
            label    = .enumerationCase
            keywords = ["indirect", "case"]
        }
        
        var signature:[Page.Signature.Token] = keywords.flatMap 
        {
            [.text($0), .whitespace]
        }
        declaration.append(contentsOf: keywords.flatMap 
        {
            [.keyword($0), .breakableWhitespace]
        })
        
        signature.append(.highlight(basename))
        declaration.append(.identifier(basename))
        
        if header.failable 
        {
            signature.append(.punctuation("?"))
            declaration.append(.punctuation("?"))
        }
        if !header.generics.isEmpty
        {
            var tokens:[Page.Declaration.Token] = []
            tokens.append(.punctuation("<"))
            tokens.append(contentsOf: header.generics.map
            { 
                [.identifier($0)] 
            }.joined(separator: [.punctuation(","), .breakableWhitespace]))
            tokens.append(.punctuation(">"))
            
            signature.append(contentsOf: Page.Signature.convert(tokens))
            declaration.append(contentsOf: tokens)
        }
        
        let name:String, 
            mangled:[String]
        if case .enumerationCase = label, header.labels.isEmpty, fields.parameters.isEmpty 
        {
            mangled = []
            name    = basename
        }
        else 
        {
            mangled = Page.print(function: fields, labels: header.labels, delimiters: ("(", ")"), 
                signature: &signature, declaration: &declaration)
            name    = "\(basename)(\(header.labels.map{ "\($0):" }.joined()))" 
        }
        
        let page:Page = .init(label: label, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers)
        let binding:Page.Binding    = .init(url: Self.url(header.identifiers + mangled), 
            locals: [], keys: fields.keys, page: page)
        return (page: binding, path: header.identifiers.dropLast() + [name])
    }
    
    static 
    func create(_ header:Symbol.MemberField, fields:ArraySlice<Symbol.Field>, order:Int) 
        -> (page:Self, path:[String]) 
    {
        let fields:Page.Fields = .init(fields, order: order)
        if !fields.wheres.isEmpty 
        {
            print("warning: where fields are ignored in a member doccoment")
        }
        if !fields.parameters.isEmpty || fields.return != nil
        {
            print("warning: parameter/return fields are ignored in a member doccoment")
        }
        if fields.throws != nil
        {
            print("warning: throws fields are ignored in a member doccoment")
        }
        
        var declaration:[Page.Declaration.Token] = Page.Declaration.tokenize(fields.attributes)
        
        let name:String = header.identifiers[header.identifiers.endIndex - 1] 
        let label:Page.Label, 
            keywords:[String] 
        switch header.keyword
        {
        case .let:
            label    = .instanceProperty 
            keywords = ["let"]
        case .var:
            label    = .instanceProperty 
            keywords = ["var"]
        case .staticLet:
            label    = .staticProperty 
            keywords = ["static", "let"]
        case .staticVar:
            label    = .staticProperty 
            keywords = ["static", "var"]
        case .associatedtype:
            label    = .associatedtype 
            keywords = ["associatedtype"]
        }
        let type:[Page.Declaration.Token] = Page.Declaration.tokenize(header.type)
        let signature:[Page.Signature.Token] = keywords.flatMap 
        {
            [.text($0), .whitespace]
        }
        + 
        [.highlight(name), .punctuation(":")]
        + 
        Page.Signature.convert(type)
        
        declaration.append(contentsOf: keywords.flatMap
        {
            [.keyword($0), .breakableWhitespace]
        })
        declaration.append(.identifier(name))
        declaration.append(.punctuation(":"))
        declaration.append(contentsOf: type)
        if let mutability:Symbol.MemberMutability = header.mutability 
        {
            declaration.append(.breakableWhitespace)
            declaration.append(.punctuation("{"))
            declaration.append(.whitespace)
            declaration.append(.keyword("get"))
            switch mutability 
            {
            case .get:
                break 
            case .getset:
                declaration.append(.whitespace)
                declaration.append(.keyword("set"))
            }
            declaration.append(.whitespace)
            declaration.append(.punctuation("}"))
        }
        
        let page:Page = .init(label: label, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers)
        let binding:Page.Binding = .init(url: Self.url(header.identifiers), 
            locals: [], keys: fields.keys, page: page)
        return (page: binding, path: header.identifiers)
    }
    
    static 
    func create(_ header:Symbol.TypeField, fields:ArraySlice<Symbol.Field>, order:Int) 
        -> (page:Self, path:[String]) 
    {
        let fields:Page.Fields = .init(fields, order: order)
        if !fields.parameters.isEmpty || fields.return != nil
        {
            print("warning: parameter/return fields are ignored in a type doccoment")
        }
        if fields.throws != nil
        {
            print("warning: throws fields are ignored in a type doccoment")
        }
        
        var declaration:[Page.Declaration.Token] = Page.Declaration.tokenize(fields.attributes)
        
        let name:String = header.identifiers.joined(separator: ".")
        let label:Page.Label, 
            keyword:String 
        switch (header.keyword, header.generics) 
        {
        case (.protocol, []):
            label   = .protocol 
            keyword = "protocol"
        case (.protocol, _):
            fatalError("protocol cannot have generic parameters")
        
        case (.class, []), (.finalClass, []):
            label   = .class 
            keyword = "class"
        case (.class, _), (.finalClass, _):
            label   = .genericClass 
            keyword = "class"
        
        case (.struct, []):
            label   = .structure 
            keyword = "struct"
        case (.struct, _):
            label   = .genericStructure 
            keyword = "struct"
        case (.enum, []):
            label   = .enumeration
            keyword = "enum"
        case (.enum, _):
            label   = .genericEnumeration
            keyword = "enum"
        }
        var signature:[Page.Signature.Token] = [.text(keyword), .whitespace] + 
            header.identifiers.map{ [.highlight($0)] }.joined(separator: [.punctuation(".")])
        
        declaration.append(.keyword(keyword))
        declaration.append(.breakableWhitespace)
        declaration.append(.identifier(header.identifiers[header.identifiers.endIndex - 1]))
        if !header.generics.isEmpty
        {
            signature.append(.punctuation("<"))
            declaration.append(.punctuation("<"))
            signature.append(contentsOf: header.generics.map
            { 
                [.text($0)] 
            }.joined(separator: [.punctuation(","), .whitespace]))
            declaration.append(contentsOf: header.generics.map
            { 
                [.identifier($0)] 
            }.joined(separator: [.punctuation(","), .breakableWhitespace]))
            signature.append(.punctuation(">"))
            declaration.append(.punctuation(">"))
        }
        if !fields.annotations.isEmpty 
        {
            declaration.append(.punctuation(":"))
            declaration.append(contentsOf: fields.annotations.map 
            {
                $0.annotations.map(Page.Declaration.tokenize(_:))
                .joined(separator: [.punctuation("&")])
            }.joined(separator: [.punctuation(","), .breakableWhitespace]))
        }
        if !fields.wheres.isEmpty 
        {
            declaration.append(.breakableWhitespace)
            declaration.append(.keyword("where"))
            declaration.append(.whitespace)
            declaration.append(contentsOf: fields.wheres.map 
            {
                (where:Symbol.WhereField) -> [Page.Declaration.Token] in 
                var tokens:[Page.Declaration.Token] = []
                // strip links from lhs
                tokens.append(contentsOf: Page.Declaration.tokenize(`where`.lhs).map 
                {
                    if case .type(let string, _) = $0 
                    {
                        return .identifier(string)
                    }
                    else 
                    {
                        return $0
                    }
                })
                switch `where`.relation
                {
                case .conforms:
                    tokens.append(.punctuation(":"))
                case .equals:
                    tokens.append(.punctuation("=="))
                }
                tokens.append(contentsOf: Page.Declaration.tokenize(`where`.rhs))
                return tokens
            }.joined(separator: [.punctuation(","), .breakableWhitespace]))
        }
        
        let page:Page = .init(label: label, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers)
        let locals:Set<String>      = .init(header.generics + ["Self"])
        let binding:Page.Binding    = .init(url: Self.url(header.identifiers), 
            locals: locals, keys: fields.keys, page: page)
        return (page: binding, path: header.identifiers)
    }
    
    static 
    func create(_ header:Symbol.AssociatedtypeField, fields:ArraySlice<Symbol.Field>, order:Int) 
        -> (page:Self, path:[String]) 
    {
        let fields:Page.Fields = .init(fields, order: order)
        if !fields.attributes.isEmpty 
        {
            print("warning: attribute fields are ignored in an associatedtype doccoment")
        }
        if !fields.wheres.isEmpty 
        {
            print("warning: where fields are ignored in an associatedtype doccoment")
        }
        if !fields.parameters.isEmpty || fields.return != nil
        {
            print("warning: parameter/return fields are ignored in an associatedtype doccoment")
        }
        if fields.throws != nil
        {
            print("warning: throws fields are ignored in an associatedtype doccoment")
        }
        
        let name:String = header.identifiers[header.identifiers.endIndex - 1]
        
        var signature:[Page.Signature.Token]        = 
            [.text("associatedtype"), .whitespace, .highlight(name)] 
        var declaration:[Page.Declaration.Token]    = 
            [.keyword("associatedtype"), .breakableWhitespace, .identifier(name)]
        
        if !fields.annotations.isEmpty 
        {
            signature.append(.punctuation(":"))
            declaration.append(.punctuation(":"))
            let annotations:[Page.Declaration.Token] = .init(fields.annotations.map 
            {
                $0.annotations.map(Page.Declaration.tokenize(_:))
                .joined(separator: [.punctuation("&")])
            }.joined(separator: [.punctuation(","), .breakableWhitespace]))
            
            signature.append(contentsOf: Page.Signature.convert(annotations))
            declaration.append(contentsOf: annotations)
        }
        
        let page:Page = .init(label: .associatedtype, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers)
        let binding:Page.Binding    = .init(url: Self.url(header.identifiers), 
            locals: [], keys: fields.keys, page: page)
        return (page: binding, path: header.identifiers)
    }
}

struct PageTree 
{
    var pages:[Page.Binding] 
    var children:[String: PageTree]
    var anchors:[String: [Page.TopicSymbol]]
    
    static 
    let empty:Self = .init(pages: [], children: [:], anchors: [:])
    
    static 
    func assemble(_ pages:[(page:Page.Binding, path:[String])]) -> Self 
    {
        var root:Self = .empty
        var anchors:[String: [(rank:(Int, Int), symbol:Page.TopicSymbol)]] = [:]
        for (order, (page, path)):(Int, (Page.Binding, [String])) in pages.enumerated()
        {
            root.insert(page, at: path[...], absolute: path)
            let symbol:Page.TopicSymbol = 
            (
                page.page.signature, 
                page.url, 
                page.page.blurb,
                page.page.discussion.required
            )
            for key:Page.Binding.Key in page.keys 
            {
                anchors[key.key, default: []].append(((key.rank, order), symbol))
            }
        }
        root.anchors = anchors.mapValues 
        {
            $0.sorted{ $0.rank < $1.rank }.map(\.symbol)
        }
        return root
    }
    
    func crosslink(scopes:[Self] = []) 
    {
        for binding:Page.Binding in self.pages 
        {
            binding.page.crosslink(scopes: scopes)
        }
        
        let scopes:[Self] = scopes + [self]
        for child:Self in self.children.values 
        {
            child.crosslink(scopes: scopes)
        }
    }
    
    func attachTopics() 
    {
        self.attachTopics(global: self.anchors)
    }
    
    func attachTopics(global:[String: [Page.TopicSymbol]]) 
    {
        for binding:Page.Binding in self.pages 
        {
            binding.page.attachTopics(children: self.children.values, global: global)
        }
        for child:Self in self.children.values 
        {
            child.attachTopics(global: global)
        }
    }
    
    static 
    func resolve(_ path:ArraySlice<String>, in scopes:[Self]) -> Page.Binding?
    {
        let debugPath:String = path.joined(separator: ".")
        higher:
        for scope:Self in scopes.reversed() 
        {
            var path:ArraySlice<String> = path, 
                scope:Self              = scope
            while let root:String = path.first 
            {
                if      let next:Self = scope.children[root] 
                {
                    path    = path.dropFirst()
                    scope   = next 
                }
                else if let page:Page.Binding = scope.pages.first, 
                    page.locals.contains(root), 
                    path.dropFirst().isEmpty
                {
                    if scope.pages.count > 1 
                    {
                        print("warning: path '\(debugPath)' is ambiguous")
                    }
                    return page
                }
                else 
                {
                    continue higher 
                }
            }
            
            guard let page:Page.Binding = scope.pages.first
            else 
            {
                break higher 
            }
            if scope.pages.count > 1 
            {
                print("warning: path '\(debugPath)' is ambiguous")
            }
            
            return page
        }
        
        print("failed to resolve '\(debugPath)'")
        return nil
    }
    
    mutating 
    func insert(_ page:Page.Binding, at path:ArraySlice<String>, absolute:[String]) 
    {
        guard let key:String = path.first 
        else 
        {
            self.pages.append(page)
            return 
        }
        
        self.children[key, default: .empty].insert(page, 
            at: path.dropFirst(), absolute: absolute)
    }
}
extension PageTree:CustomStringConvertible
{
    var description:String 
    {
        self.describe()
    }
    private 
    func describe(indent:Int = 0) -> String 
    {
        var description:String = 
            "\(String.init(repeating: " ", count: indent * 4))\(self.pages.map(\.url))\n"
        for child:Self in self.children.values 
        {
            description += child.describe(indent: indent + 1)
        }
        return description
    }
}
