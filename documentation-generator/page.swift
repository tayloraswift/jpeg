final 
class Page 
{
    enum Label 
    {
        case framework 
        
        case enumeration 
        case genericEnumeration 
        case structure 
        case genericStructure 
        case `class`
        case genericClass 
        case `protocol`
        case `typealias`
        
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
        let metatype:Self = .apple(url: "https://docs.swift.org/swift-book/ReferenceManual/Types.html#ID455")
        
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
            else if let (last, _):((String, T), [String]) = scan.last, 
                last.0 == "Type" 
            {
                return scan.dropLast().map 
                {
                    ($0.component, .unresolved(path: $0.accumulated))
                } + 
                [(last, Self.metatype)]
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
        func tokenize(_ type:Symbol.SwiftType, locals:Set<String> = []) -> [Token] 
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
                        tokens.append(contentsOf: Self.tokenize(element, locals: locals))
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
                        tokens.append(contentsOf: Self.tokenize(element, locals: locals))
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
                        tokens.append(contentsOf: Self.tokenize(key, locals: locals))
                        tokens.append(.typePunctuation(":", link))
                        tokens.append(.whitespace)
                        tokens.append(contentsOf: Self.tokenize(value, locals: locals))
                        tokens.append(.typePunctuation("]", link))
                        return tokens 
                    }
                }
                else if let first:String = identifiers.first?.identifier, 
                    locals.contains(first), 
                    identifiers.allSatisfy(\.generics.isEmpty) 
                {
                    if identifiers.count == 2, identifiers[1].identifier == "Type"
                    {
                        return [.identifier(identifiers[0].identifier), .punctuation("."), .type("Type", Link.metatype)]
                    }
                    else 
                    {
                        return .init(identifiers.map{ [.identifier($0.identifier)] }.joined(separator: [.punctuation(".")]))
                    }
                }
                
                return .init(Link.link(identifiers.map{ ($0.identifier, $0.generics) }).map 
                {
                    (element:(component:(identifier:String, generics:[Symbol.SwiftType]), link:Link)) -> [Token] in 
                    var tokens:[Token] = [.type(element.component.identifier, element.link)]
                    if !element.component.generics.isEmpty
                    {
                        tokens.append(.punctuation("<"))
                        tokens.append(contentsOf: element.component.generics.map{ Self.tokenize($0, locals: locals) }
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
                    tokens.append(contentsOf: Self.tokenize(element.type, locals: locals))
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
                    tokens.append(contentsOf: Self.tokenize(parameter.type, locals: locals))
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
                tokens.append(contentsOf: Self.tokenize(type.return, locals: locals))
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
        
        let urlpattern:(prefix:String, suffix:String)
        let page:Page 
        let locals:Set<String>, 
            keys:Set<Key>
        
        var path:[String] 
        {
            self.page.path 
        }
        
        // needed to uniquify overloaded symbols
        var uniquePath:[String] 
        {
            if let overload:UInt32 = self.page.overload 
            {
                return self.path.dropLast() + ["\(overload)-\(self.path[self.path.endIndex - 1])"]
            }
            else 
            {
                return self.path 
            }
        }
        
        var url:String 
        {
            "\(self.urlpattern.prefix)/\(self.uniquePath.map(Self.escape(url:)).joined(separator: "/"))\(self.urlpattern.suffix)"
        }
        var filepath:String 
        {
            self.uniquePath.joined(separator: "/")
        }
        
        init(_ page:Page, locals:Set<String>, keys:Set<Key>, urlpattern:(prefix:String, suffix:String)) 
        {
            self.urlpattern = urlpattern
            self.page       = page 
            self.locals     = locals 
            self.keys       = keys 
        }
        
        private static 
        func hex(_ value:UInt8) -> UInt8
        {
            if value < 10 
            {
                return 0x30 + value 
            }
            else 
            {
                return 0x37 + value 
            }
        }
        private static 
        func escape(url:String) -> String 
        {
            .init(decoding: url.utf8.flatMap 
            {
                (byte:UInt8) -> [UInt8] in 
                switch byte 
                {
                ///  [0-9]          [A-Z]        [a-z]            '-'   '_'   '~'
                case 0x30 ... 0x39, 0x41 ... 0x5a, 0x61 ... 0x7a, 0x2d, 0x5f, 0x7e:
                    return [byte] 
                default:
                    return [0x25, hex(byte >> 4), hex(byte & 0x0f)]
                }
            }, as: Unicode.ASCII.self)
        }
    }
    
    typealias TopicSymbol   = (signature:[Signature.Token], url:String, blurb:[Markdown.Element], required:[Markdown.Element])
    typealias Topic         = (topic:String, key:String, symbols:[TopicSymbol])
    
    let label:Label 
    let name:String //name is not always last component of path 
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
    
    var inheritances:[[String]] 
    let overload:UInt32?
    
    let path:[String]
    
    init(label:Label, name:String, signature:[Signature.Token], declaration:[Declaration.Token], 
        fields:Fields, path:[String], inheritances:[[String]] = [], overload:UInt32? = nil)
    {
        self.label          = label 
        self.name           = name 
        self.signature      = signature 
        self.declaration    = declaration 
        self.inheritances   = inheritances.filter{ !($0.first == "Swift") }
        
        self.blurb          = fields.blurb?.elements ?? [] 
        
        let relationships:[Markdown.Element] 
        switch label 
        {
        // "Required ..."
        case .initializer, .genericInitializer, .staticMethod, .genericStaticMethod, 
            .instanceMethod, .genericInstanceMethod, .staticProperty, .instanceProperty, 
            .subscript, .associatedtype, .typealias:
            guard fields.conformances.isEmpty 
            else 
            {
                fatalError("member '\(name)' cannot have conformances")
            }
            
            if let requirement:Symbol.RequirementField = fields.requirement 
            {
                guard fields.implementation == nil 
                else 
                {
                    fatalError("member '\(name)' cannot have both a requirement field and implementations fields.")
                }
                
                switch requirement 
                {
                case .required:
                    relationships = .parse("**Required.**")
                case .defaulted:
                    relationships = .parse("**Required.** Default implementation provided.")
                }
            }
            else 
            {
                fallthrough
            }
        
        // "Implements requirement in ... . Available when ... ."
        //  or 
        // "Conforms to ... when ... ."
        case .enumeration, .genericEnumeration, .structure, .genericStructure, .class, .genericClass: 
            guard fields.requirement == nil 
            else 
            {
                fatalError("member '\(name)' cannot have a requirement field")
            }
            
            var sentences:[String] = []
            if let implementation:Symbol.ImplementationField = fields.implementation
            {
                sentences.append("Implements requirement in [`\(implementation.conformance.joined(separator: "."))`].")
                if !implementation.conditions.isEmpty 
                {
                    sentences.append("Available when \(Self.prose(conditions: implementation.conditions)).")
                }
            }
            // non-conditional conformances go straight into the type declaration 
            for conformance:Symbol.ConformanceField in fields.conformances where !conformance.conditions.isEmpty 
            {
                let conformances:String = Self.prose(separator: ",", list: conformance.conformances.map 
                {
                    "[`\($0.joined(separator: "."))`]"
                })
                sentences.append("Conforms to \(conformances) when \(Self.prose(conditions: conformance.conditions)).")
            }
            
            relationships = .parse(sentences.joined(separator: " "))
        
        case .protocol, .enumerationCase, .framework: 
            relationships = [] 
        }
        
        self.discussion     = 
        (
            fields.parameters.map{ ($0.name, $0.paragraphs.map(\.elements)) }, 
            fields.return?.paragraphs.map(\.elements) ?? [], 
            fields.discussion.map(\.elements), 
            relationships
        )
        self.topics         = fields.topics
        
        var breadcrumbs:[(text:String, link:Link)] = [("Documentation", .unresolved(path: []))]
        +
        Link.link(path.map{ ($0, ()) }).map 
        {
            ($0.component.0, $0.link)
        }
        
        self.breadcrumb     = breadcrumbs.removeLast().text 
        self.breadcrumbs    = breadcrumbs
        self.overload       = overload 
        
        self.path           = path
    }
    
    private static 
    func prose(conditions:[Symbol.WhereClause]) -> String 
    {
        return Self.prose(separator: ";", list: conditions.map 
        {
            (clause:Symbol.WhereClause) in 
            let relation:String 
            switch clause.relation 
            {
            case .equals:
                relation = "is"
            case .conforms:
                relation = "conforms to"
            }
            let constraints:[String] = clause.object.map{ "[`\($0.joined(separator: "."))`]" }
            return "`\(clause.subject.joined(separator: "."))` \(relation) \(Self.prose(separator: ",", list: constraints))"
        })
    }
    
    private static 
    func prose(separator:String, list:[String]) -> String 
    {
        guard let first:String = list.first 
        else 
        {
            fatalError("list must have at least one element")
        }
        guard let second:String = list.dropFirst().first 
        else 
        {
            return first 
        }
        guard let last:String = list.dropFirst(2).last 
        else 
        {
            return "\(first) and \(second)"
        }
        return "\(list.dropLast().joined(separator: "\(separator) "))\(separator) and \(last)"
    }
}
extension Page 
{
    private static 
    func crosslink(_ unlinked:[Markdown.Element], scopes:[PageTree.Node]) -> [Markdown.Element]
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
                            guard let url:String = PageTree.Node.resolve(full[...], in: scopes)
                            else 
                            {
                                return element.component.0.map{ .text(.wildcard($0)) }
                            }
                            target = url
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
    
    func crosslink(scopes:[PageTree.Node]) 
    {
        self.declaration = self.declaration.map 
        {
            switch $0 
            {
            case .type(let component, .unresolved(path: let path)):
                guard let url:String = PageTree.Node.resolve(path[...], in: scopes)
                else 
                {
                    return .identifier(component)
                }
                return .type(component, .resolved(url: url))
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
                guard let url:String = PageTree.Node.resolve(path[...], in: scopes)
                else 
                {
                    break 
                }
                return ($0.text, .resolved(url: url))
            default:
                break 
            }
            return $0
        }
    }
    
    enum ParameterScheme 
    {
        case `subscript`
        case function 
        case associatedValues 
        
        var delimiter:(String, String) 
        {
            switch self 
            {
            case .subscript:
                return ("[", "]")
            case .function, .associatedValues:
                return ("(", ")")
            }
        }
        
        func names(_ label:String, _ name:String) -> [String] 
        {
            switch self 
            {
            case .subscript:
                switch (label, name) 
                {
                case ("_",             "_"):
                    return ["_"]
                case ("_",       let inner):
                    return [inner]
                case (let outer, let inner):
                    return [outer, inner]
                }
            case .function:
                return label == name ? [label] : [label, name] 
            case .associatedValues:
                if label != name 
                {
                    Swift.print("warning: enumeration case cannot have different labels '\(label)', '\(name)'")
                }
                return label == "_" ? [] : [label]
            }
        }
    }
    static 
    func print(wheres fields:Fields, declaration:inout [Declaration.Token]) 
    {
        guard let constraints:Symbol.ConstraintsField = fields.constraints 
        else 
        {
            return 
        }
        declaration.append(.breakableWhitespace)
        declaration.append(.keyword("where"))
        declaration.append(.whitespace)
        declaration.append(contentsOf: constraints.clauses.map 
        {
            (clause:Symbol.WhereClause) -> [Page.Declaration.Token] in 
            var tokens:[Page.Declaration.Token] = []
            // strip links from lhs
            tokens.append(contentsOf: Page.Declaration.tokenize(clause.subject).map 
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
            switch clause.relation
            {
            case .conforms:
                tokens.append(.punctuation(":"))
            case .equals:
                tokens.append(.whitespace)
                tokens.append(.punctuation("=="))
                tokens.append(.whitespace)
            }
            tokens.append(contentsOf: clause.object.map(Page.Declaration.tokenize(_:))
                .joined(separator: [.whitespace, .punctuation("&"), .whitespace]))
            return tokens
        }.joined(separator: [.punctuation(","), .breakableWhitespace]))
    }
    static 
    func print(function fields:Fields, labels:[(name:String, variadic:Bool)], 
        scheme:ParameterScheme,
        signature:inout [Signature.Token], 
        declaration:inout [Declaration.Token], 
        locals:Set<String> = []) 
        -> UInt32 
    {
        var overload:UInt32 = 0 
        
        guard labels.count == fields.parameters.count 
        else 
        {
            fatalError("warning: function/subscript '\(signature)' has \(labels.count) labels, but \(fields.parameters.count) parameters")
        }
        
        signature.append(.punctuation(scheme.delimiter.0))
        declaration.append(.punctuation("("))
        
        var interior:(signature:[[Page.Signature.Token]], declaration:[[Page.Declaration.Token]]) = 
            ([], [])
        for ((label, variadic), (name, parameter, _)):
        (
            (String, Bool), 
            (String, Symbol.FunctionParameter, [Symbol.ParagraphField])
        ) in zip(labels, fields.parameters)
        {
            var signature:[Page.Signature.Token]        = []
            var declaration:[Page.Declaration.Token]    = []
            
            if label != "_" 
            {
                signature.append(.highlight(label))
                signature.append(.punctuation(":"))
            }
            
            let names:[String] = scheme.names(label, name)
            if !names.isEmpty 
            {
                declaration.append(contentsOf: names.map 
                {
                    [$0 == "_" ? .keyword($0) : .identifier($0)]
                }.joined(separator: [.whitespace]))
                declaration.append(.punctuation(":"))
            }
            for attribute:Symbol.Attribute in parameter.attributes
            {
                declaration.append(.keyword("\(attribute)"))
                declaration.append(.whitespace)
            }
            if parameter.inout 
            {
                signature.append(.text("inout"))
                signature.append(.whitespace)
                declaration.append(.keyword("inout"))
                declaration.append(.whitespace)
            }
            let type:(declaration:[Page.Declaration.Token], signature:[Page.Signature.Token]) 
            type.declaration = Page.Declaration.tokenize(parameter.type, locals: locals)
            type.signature   = Page.Signature.convert(type.declaration)
            signature.append(contentsOf: type.signature)
            declaration.append(contentsOf: type.declaration)
            
            if variadic 
            {
                signature.append(contentsOf: repeatElement(.punctuation("."), count: 3))
                declaration.append(contentsOf: repeatElement(.punctuation("."), count: 3))
            }
            
            hash:
            if  label == "as", 
                case .named(let identifiers) = parameter.type, 
                let last:Symbol.TypeIdentifier = identifiers.last, 
                last.identifier == "Type",
                last.generics.isEmpty
            {
                // exempt types which use an `as:` with a generic parameter 
                if  identifiers.count == 2, 
                    identifiers[0].generics.isEmpty, 
                    locals.contains(identifiers[0].identifier)
                {
                    break hash 
                }
                
                for u:Unicode.Scalar in identifiers.map(\.description).joined().unicodeScalars
                {
                    overload &+= u.value
                }
            }
            
            interior.signature.append(signature)
            interior.declaration.append(declaration)
        }
        
        signature.append(contentsOf: 
            interior.signature.joined(separator: [.punctuation(","), .whitespace]))
        declaration.append(contentsOf: 
            interior.declaration.joined(separator: [.punctuation(","), .breakableWhitespace]))
        
        signature.append(.punctuation(scheme.delimiter.1))
        declaration.append(.punctuation(")"))
        
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
            
            let tokens:[Page.Declaration.Token] = Page.Declaration.tokenize(type, locals: locals)
            signature.append(contentsOf: Page.Signature.convert(tokens))
            declaration.append(contentsOf: tokens)
        }
        
        return overload 
    }
}
extension Page 
{
    struct Fields
    {
        let conformances:[Symbol.ConformanceField], 
            implementation:Symbol.ImplementationField?, 
            constraints:Symbol.ConstraintsField?, 
            attributes:[Symbol.AttributeField], 
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
            var conformances:[Symbol.ConformanceField]          = [], 
                attributes:[Symbol.AttributeField]              = [], 
                paragraphs:[Symbol.ParagraphField]              = [],
                topics:[Symbol.TopicField]                      = [], 
                keys:[Symbol.TopicElementField]                 = []
            var `throws`:Symbol.ThrowsField?, 
                requirement:Symbol.RequirementField?, 
                constraints:Symbol.ConstraintsField?,
                implementation:Symbol.ImplementationField?
            var parameters:[(parameter:Symbol.ParameterField, paragraphs:[Symbol.ParagraphField])] = []
            
            for field:Symbol.Field in fields
            {
                switch field 
                {
                case .attribute     (let field):
                    attributes.append(field)
                case .conformance   (let field):
                    conformances.append(field)
                case .implementation(let field):
                    guard implementation == nil 
                    else 
                    {
                        fatalError("only one implementation field per doccomnent allowed")
                    }
                    implementation = field
                case .constraints   (let field):
                    guard constraints == nil 
                    else 
                    {
                        fatalError("only one constraints field per doccomnent allowed")
                    }
                    constraints = field
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
                
                case .subscript, .function, .member, .type, .typealias, .module:
                    fatalError("only one header field per doccomnent allowed")
                    
                case .separator:
                    break
                }
            }
            
            self.conformances       = conformances
            self.implementation     = implementation
            self.constraints        = constraints
            self.attributes         = attributes
            self.paragraphs         = paragraphs
            self.throws             = `throws`
            self.requirement        = requirement
            
            self.keys               = .init(keys.map{ .init($0, order: order) })
            self.topics             = topics.map{ ($0.display, $0.key, []) }
            
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
    func create(_ header:Symbol.ModuleField, fields:ArraySlice<Symbol.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self
    {
        let fields:Page.Fields = .init(fields, order: order)
        
        let page:Page = .init(label: .framework, name: header.identifier, 
            signature:      [], 
            declaration:    [.keyword("import"), .whitespace, .identifier(header.identifier)], 
            fields:         fields, 
            path:           [], 
            overload:       nil)
        return .init(page, locals: [], keys: fields.keys, urlpattern: urlpattern)
    }
    
    static 
    func create(_ header:Symbol.SubscriptField, fields:ArraySlice<Symbol.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self
    {
        let fields:Page.Fields = .init(fields, order: order)
        if fields.constraints != nil 
        {
            print("warning: where fields are ignored in a subscript doccoment")
        }
        
        let name:String = "[\(header.labels.map{ "\($0):" }.joined())]" 
        
        var declaration:[Page.Declaration.Token]    = 
            Page.Declaration.tokenize(fields.attributes) + [  .keyword("subscript")]
        var signature:[Page.Signature.Token]        =      [.highlight("subscript")]
        
        let overload:UInt32 = Page.print(function: fields, 
            labels: header.labels.map{ ($0, false) }, scheme: .subscript, 
            signature: &signature, declaration: &declaration)
        
        declaration.append(.breakableWhitespace)
        declaration.append(.punctuation("{"))
        declaration.append(.whitespace)
        declaration.append(.keyword("get"))
        switch header.mutability 
        {
        case .get:
            break 
        case .nonmutatingset:
            declaration.append(.whitespace)
            declaration.append(.keyword("nonmutating"))
            fallthrough
        case .getset:
            declaration.append(.whitespace)
            declaration.append(.keyword("set"))
        }
        declaration.append(.whitespace)
        declaration.append(.punctuation("}"))
        
        let page:Page = .init(label: .subscript, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers + [name], 
            overload:       overload == 0 ? nil : overload)
        return .init(page, locals: [], keys: fields.keys, urlpattern: urlpattern)
    }
    static 
    func create(_ header:Symbol.FunctionField, fields:ArraySlice<Symbol.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self 
    {
        let fields:Page.Fields = .init(fields, order: order)
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
        declaration.append(header.keyword == .`init` ? .keyword(basename) : .identifier(basename))
        
        if header.failable 
        {
            signature.append(.punctuation("?"))
            declaration.append(.typePunctuation("?", .appleify(["Swift", "Optional"])))
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
        
        let name:String 
        var overload:UInt32?
        if case .enumerationCase = label, header.labels.isEmpty, fields.parameters.isEmpty 
        {
            name        = basename
        }
        else 
        {
            overload = Page.print(function: fields, labels: header.labels, 
                scheme: header.keyword == .case ? .associatedValues : .function, 
                signature: &signature, declaration: &declaration, locals: .init(header.generics))
            name    = "\(basename)(\(header.labels.map{ "\($0.variadic && $0.name == "_" ? "" : $0.name)\($0.variadic ? "..." : ""):" }.joined()))" 
        }
        
        // enum cases, even with associated values, do not need overload hashes 
        if case .enumerationCase = label 
        {
            overload = nil 
        }
        
        Page.print(wheres: fields, declaration: &declaration) 
        
        let page:Page = .init(label: label, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers.dropLast() + [name], 
            overload:       overload == 0 ? nil : overload)
        return .init(page, locals: [], keys: fields.keys, urlpattern: urlpattern)
    }
    
    static 
    func create(_ header:Symbol.MemberField, fields:ArraySlice<Symbol.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self
    {
        let fields:Page.Fields = .init(fields, order: order)
        if fields.constraints != nil 
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
        
        let signature:[Page.Signature.Token]
        switch (header.type, header.mutability) 
        {
        case (nil, _?):
            fatalError("cannot have mutability annotation and no type annotation")
        case (nil, nil):
            guard label == .associatedtype 
            else 
            {
                fatalError("only associatedtype members can omit type annotation")
            }
            
            signature   = [.text("associatedtype"), .whitespace, .highlight(name)]
            declaration.append(.keyword("associatedtype"))
            declaration.append(.breakableWhitespace)
            declaration.append(.identifier(name))
        
        case (let type?, _):
            let type:[Page.Declaration.Token] = Page.Declaration.tokenize(type)
            signature = keywords.flatMap 
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
                case .nonmutatingset:
                    declaration.append(.whitespace)
                    declaration.append(.keyword("nonmutating"))
                    fallthrough
                case .getset:
                    declaration.append(.whitespace)
                    declaration.append(.keyword("set"))
                }
                declaration.append(.whitespace)
                declaration.append(.punctuation("}"))
            }
        }
        
        let page:Page       = .init(label: label, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers)
        return .init(page, locals: [], keys: fields.keys, urlpattern: urlpattern)
    }
    
    static 
    func create(_ header:Symbol.TypeField, fields:ArraySlice<Symbol.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self
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
        
        // only put universal conformances in the declaration 
        let conformances:[[[String]]] = fields.conformances.compactMap 
        {
            $0.conditions.isEmpty ? $0.conformances : nil 
        }
        if !conformances.isEmpty 
        {
            declaration.append(.punctuation(":"))
            declaration.append(contentsOf: conformances.map 
            {
                $0.map(Page.Declaration.tokenize(_:))
                .joined(separator: [.punctuation("&")])
            }.joined(separator: [.punctuation(","), .breakableWhitespace]))
        }
        let inheritances:[[String]] = conformances.flatMap{ $0 }
        
        Page.print(wheres: fields, declaration: &declaration) 
        
        let page:Page = .init(label: label, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers, 
            inheritances:   inheritances)
        let locals:Set<String>      = .init(header.generics + ["Self"])
        return .init(page, locals: locals, keys: fields.keys, urlpattern: urlpattern)
    }
    
    static 
    func create(_ header:Symbol.TypealiasField, fields:ArraySlice<Symbol.Field>, 
        order:Int, urlpattern:(prefix:String, suffix:String)) 
        -> Self
    {
        let fields:Page.Fields = .init(fields, order: order)
        if !fields.attributes.isEmpty 
        {
            print("warning: attribute fields are ignored in an associatedtype doccoment")
        }
        if fields.constraints != nil 
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
        
        let name:String = header.identifiers.joined(separator: ".")
        let signature:[Page.Signature.Token]        = [.text("typealias"), .whitespace] + 
            header.identifiers.map{ [.highlight($0)] }.joined(separator: [.punctuation(".")])
        var declaration:[Page.Declaration.Token]    = 
        [
            .keyword("typealias"), 
            .whitespace,
            .identifier(header.identifiers[header.identifiers.endIndex - 1])
        ]
        
        declaration.append(.whitespace)
        declaration.append(.punctuation("="))
        declaration.append(.breakableWhitespace)
        declaration.append(contentsOf: Page.Declaration.tokenize(header.target))
        
        let inheritances:[[String]]
        switch header.target 
        {
        case .named(let identifiers):
            inheritances = [identifiers.map(\.identifier)]
        default:
            inheritances = []
        }
        
        let page:Page = .init(label: .typealias, name: name, 
            signature:      signature, 
            declaration:    declaration, 
            fields:         fields, 
            path:           header.identifiers, 
            inheritances:   inheritances)
        return .init(page, locals: [], keys: fields.keys, urlpattern: urlpattern)
    }
    
    func attachTopics<C>(children:C, global:[String: [Page.TopicSymbol]]) 
        where C:Collection, C.Element == PageTree.Node 
    {
        for i:Int in self.page.topics.indices 
        {
            self.page.topics[i].symbols.append(contentsOf: 
            global[self.page.topics[i].key, default: []].filter 
            {
                $0.url != self.url
            })
        }
        let seen:Set<String> = .init(self.page.topics.flatMap{ $0.symbols.map(\.url) })
        var topics: 
        (
            enumerations        :[Page.TopicSymbol],
            structures          :[Page.TopicSymbol],
            classes             :[Page.TopicSymbol],
            protocols           :[Page.TopicSymbol],
            typealiases         :[Page.TopicSymbol],
            cases               :[Page.TopicSymbol],
            initializers        :[Page.TopicSymbol],
            typeMethods         :[Page.TopicSymbol],
            instanceMethods     :[Page.TopicSymbol],
            typeProperties      :[Page.TopicSymbol],
            instanceProperties  :[Page.TopicSymbol],
            associatedtypes     :[Page.TopicSymbol],
            subscripts          :[Page.TopicSymbol]
        )
        topics = ([], [], [], [], [], [], [], [], [], [], [], [], [])
        for binding:Self in 
            (children.flatMap
            { 
                $0.payloads.compactMap
                { 
                    if case .binding(let binding) = $0 
                    {
                        return binding 
                    }
                    else 
                    {
                        return nil 
                    }
                } 
            }.sorted{ $0.page.name < $1.page.name })
        {
            guard !seen.contains(binding.url)
            else 
            {
                continue 
            }
            
            let symbol:Page.TopicSymbol = 
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
            case .typealias:
                topics.typealiases.append(symbol)
            
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
            case .framework:
                break
            }
        }
        
        for builtin:(topic:String, symbols:[Page.TopicSymbol]) in 
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
            (topic: "Typealiases",          symbols: topics.typealiases), 
        ]
            where !builtin.symbols.isEmpty
        {
            self.page.topics.append((builtin.topic, "$builtin", builtin.symbols))
        }
        
        // move 'see also' to the end 
        if let i:Int = (self.page.topics.firstIndex{ $0.topic.lowercased() == "see also" })
        {
            let seealso:Page.Topic = self.page.topics.remove(at: i)
            self.page.topics.append(seealso)
        }
    }
}

struct PageTree 
{
    struct Node 
    {
        enum Payload 
        {
            case binding(Page.Binding)
            case redirect(url:String)
            
            var url:String 
            {
                switch self 
                {
                case .binding(let binding):
                    return binding.url 
                case .redirect(url: let url):
                    return url 
                }
            }
        }
        
        var payloads:[Payload]
        var children:[String: Self]
        
        static 
        let empty:Self = .init(payloads: [], children: [:])
    }
}
extension PageTree.Node 
{
    mutating 
    func insert(_ binding:Page.Binding, at path:ArraySlice<String>) 
    {
        guard let key:String = path.first 
        else 
        {
            self.payloads.append(.binding(binding))
            return 
        }
        
        self.children[key, default: .empty].insert(binding, at: path.dropFirst())
    }
    mutating 
    func attachInheritedSymbols(scopes:[Self] = []) 
    {
        // go through the children first since we are writing to self.children later 
        let next:[Self] = scopes + [self]
        self.children = self.children.mapValues  
        {
            var child:Self = $0
            child.attachInheritedSymbols(scopes: next)
            return child
        }
        
        if case .binding(let binding)? = self.payloads.first 
        {
            // we also have to bring in everything the inheritances themselves inherit
            var inheritances:[[String]] = binding.page.inheritances
            while let path:[String] = inheritances.popLast() 
            {
                let (clones, next):([String: Self], [[String]]) = 
                    Self.clone(path[...], in: scopes)
                self.children.merge(clones) 
                { 
                    (current, _) in current 
                }
                
                inheritances.append(contentsOf: next)
            }
        }
    }
    
    var cloned:Self 
    {
        .init(payloads: self.payloads.map{ .redirect(url: $0.url) }, 
            children: self.children.mapValues(\.cloned))
    }
    static 
    func clone(_ path:ArraySlice<String>, in scopes:[Self]) -> (cloned:[String: Self], next:[[String]])
    {
        let debugPath:String = path.joined(separator: "/")
        higher:
        for scope:Self in scopes.reversed() 
        {
            var path:ArraySlice<String> = path, 
                scope:Self              = scope
            while let root:String = path.first 
            {
                if let next:Self = scope.children[root] 
                {
                    path    = path.dropFirst()
                    scope   = next 
                }
                else if case .binding(let binding)? = scope.payloads.first, 
                    binding.locals.contains(root), 
                    path.dropFirst().isEmpty
                {
                    break
                }
                else 
                {
                    continue higher 
                }
            }
            
            let inheritances:[[String]]
            if case .binding(let binding)? = scope.payloads.first 
            {
                inheritances = binding.page.inheritances
            }
            else 
            {
                inheritances = []
            }
            return (scope.children.mapValues(\.cloned), inheritances)
        }
        
        print("(PageTree.clone(_:in:)): failed to resolve '\(debugPath)'")
        return ([:], [])
    }
    static 
    func resolve(_ path:ArraySlice<String>, in scopes:[Self]) -> String?
    {
        if  path.isEmpty, 
            let root:Self       = scopes.first, 
            let payload:Payload = root.payloads.first
        {
            return payload.url 
        }
        
        let debugPath:String = path.joined(separator: "/")
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
                else if case .binding(let binding)? = scope.payloads.first, 
                    binding.locals.contains(root), 
                    path.dropFirst().isEmpty
                {
                    break
                }
                else 
                {
                    continue higher 
                }
            }
            
            guard let payload:Payload = scope.payloads.first
            else 
            {
                break higher 
            }
            if scope.payloads.count > 1 
            {
                print("warning: path '\(debugPath)' is ambiguous")
            }
            
            return payload.url
        }
        
        print("(PageTree.resolve(_:in:)): failed to resolve '\(debugPath)'")
        return nil
    }
    
    func traverse(scopes:[Self] = [], _ body:([Self], Self) throws -> ()) rethrows 
    {
        try body(scopes, self)
        
        let scopes:[Self] = scopes + [self]
        for child:Self in self.children.values 
        {
            try child.traverse(scopes: scopes, body)
        }
    }
    
    fileprivate 
    func describe(indent:Int = 0) -> String 
    {
        var description:String = 
            "\(String.init(repeating: " ", count: indent * 4))\(self.payloads.map(\.url))\n"
        for child:Self in self.children.values 
        {
            description += child.describe(indent: indent + 1)
        }
        return description
    }
}        
extension PageTree 
{
    static 
    func assemble(_ pages:[Page.Binding]) 
    {
        var root:Node = .empty
        for page:Page.Binding in pages
        {
            root.insert(page, at: page.path[...])
        }
        
        // attach inherited symbols 
        root.attachInheritedSymbols()
        // resolve type links 
        root.traverse
        {
            (scopes:[Node], node:Node) in 
            for payload:Node.Payload in node.payloads
            {
                if case .binding(let binding) = payload 
                {
                    binding.page.crosslink(scopes: scopes)
                }
            }
        }
        
        // cannot collect anchors before resolving type links 
        var anchors:[String: [(rank:(Int, Int), symbol:Page.TopicSymbol)]] = [:]
        for (order, page):(Int, Page.Binding) in pages.enumerated()
        {
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
        // sort anchors 
        let global:[String: [Page.TopicSymbol]] = anchors.mapValues 
        {
            $0.sorted{ $0.rank < $1.rank }.map(\.symbol)
        }
        
        // attach topics 
        root.traverse
        {
            (_:[Node], node:Node) in 
            for payload:Node.Payload in node.payloads  
            {
                if case .binding(let binding) = payload 
                {
                    binding.attachTopics(children: node.children.values, global: global)
                }
            }
        }
        // print out root 
        print(root.describe())
    }
}
