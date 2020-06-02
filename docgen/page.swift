final 
class Page 
{
    static 
    func path(_ identifier:Symbol.QualifiedIdentifier) -> [String]
    {
        identifier.prefix.map(\.string) + [identifier.identifier.string]
    }
    
    static 
    func accumulate(_ identifier:Symbol.QualifiedIdentifier) -> [(component:String, link:Link)]
    {
        let components:[String] = 
            identifier.prefix.map(\.string) + [identifier.identifier.string] 
        guard components.first != "Swift" 
        else 
        {
            return components.dropFirst().enumerated().map
            {
                (
                    $0.1, 
                    .apple(url: "https://developer.apple.com/documentation/\(components.prefix($0.0 + 2).map{ $0.lowercased() }.joined(separator: "/"))")
                )
            }
        }
        
        return components.enumerated().map
        {
            (
                $0.1, 
                .unresolved(path: .init(components.prefix($0.0 + 1)))
            )
        }
    }
    
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
        case staticMethod 
        case instanceMethod 
        case staticProperty
        case instanceProperty
        case `subscript` 
    }
    
    enum Link 
    {
        case unresolved(path:[String])
        case resolved(url:String)
        case apple(url:String)
    }
    
    enum Declaration 
    {
        enum Token 
        {
            case whitespace 
            case keyword(String)
            case identifier(String)
            case type(String, Link)
            case punctuation(String)
        }
    }
    
    enum Signature
    {
        enum Token 
        {
            case whitespace 
            case text(String)
            case highlight(String)
        }
    }
    
    struct Binding 
    {
        let url:String
        let locals:Set<String>
        let page:Page 
    }
    
    let label:Label 
    let name:String 
    let signature:[Signature.Token]
    var declaration:[Declaration.Token] 
    let overview:String?
    let discussion:[String]
    
    init(label:Label, name:String, signature:[Signature.Token], declaration:[Declaration.Token], 
        overview:String?, discussion:[String]) 
    {
        self.label          = label 
        self.name           = name 
        self.signature      = signature 
        self.declaration    = declaration 
        self.overview       = overview 
        self.discussion     = discussion
    }
}
extension Page 
{
    func resolve(scopes:[PageTree]) 
    {
        self.declaration = self.declaration.map 
        {
            switch $0 
            {
            case .type(let component, .unresolved(path: let path)):
                for scope:PageTree in scopes.reversed() 
                {
                    if let resolved:Declaration.Token = 
                        scope.resolve(path[...], component: component)
                    {
                        return resolved 
                    }
                }
                print("failed to resolve '\(path.joined(separator: "."))'")
                return .identifier(component)
            default:
                return $0
            }
        }
    }
}
extension Page.Binding 
{
    static 
    func create(_ header:Symbol.TypeField, fields:ArraySlice<Symbol.Field>) 
        -> (page:Self, path:[String]) 
    {
        var annotations:[Symbol.AnnotationField]    = [], 
            attributes:[Symbol.AttributeField]      = [], 
            wheres:[Symbol.WhereField]              = [], 
            paragraphs:[Symbol.ParagraphField]      = []
        for field:Symbol.Field in fields
        {
            switch field 
            {
            case .annotation(let field):
                annotations.append(field)
            case .attribute (let field):
                attributes.append(field)
            case .where     (let field):
                wheres.append(field)
            case .paragraph (let field):
                paragraphs.append(field)
            default:
                break
            }
        }
        
        var declaration:[Page.Declaration.Token] = []
        for attribute:Symbol.AttributeField in attributes 
        {
            switch attribute
            {
            case .frozen:
                declaration.append(.keyword("@frozen"))
                declaration.append(.whitespace)
            case .inlinable:
                declaration.append(.keyword("@inlinable"))
                declaration.append(.whitespace)
            case .wrapper:
                declaration.append(.keyword("@propertyWrapper"))
                declaration.append(.whitespace)
            case .wrapped:
                break // not possible for type fields 
            case .specialized:
                break // not implemented 
            }
        }
        
        let path:[String]   = Page.path(header.identifier), 
            name:String     = path.joined(separator: ".")
        let label:Page.Label, 
            keyword:String 
        switch (header.keyword, header.generics) 
        {
        case (.protocol, nil):
            label   = .protocol 
            keyword = "protocol"
        case (.protocol, _?):
            fatalError("protocol cannot have generic parameters")
        
        case (.class, nil), (.finalClass, nil):
            label   = .class 
            keyword = "class"
        case (.class, _?), (.finalClass, _?):
            label   = .genericClass 
            keyword = "class"
        
        case (.struct, nil):
            label   = .structure 
            keyword = "struct"
        case (.struct, _?):
            label   = .genericStructure 
            keyword = "struct"
        case (.enum, nil):
            label   = .enumeration
            keyword = "enum"
        case (.enum, _?):
            label   = .genericEnumeration
            keyword = "enum"
        }
        let signature:[Page.Signature.Token] = 
            [.text(keyword), .whitespace, .highlight(name)]
        
        declaration.append(.keyword(keyword))
        declaration.append(.whitespace)
        declaration.append(.identifier(header.identifier.identifier.string))
        if let generics:Symbol.TypeParameters = header.generics 
        {
            declaration.append(.punctuation("<"))
            declaration.append(contentsOf: generics.identifiers.map
            { 
                [.identifier($0.string)] 
            }.joined(separator: [.punctuation(","), .whitespace]))
            declaration.append(.punctuation(">"))
        }
        if !annotations.isEmpty 
        {
            declaration.append(.punctuation(":"))
            declaration.append(contentsOf: annotations.map 
            {
                (annotation:Symbol.AnnotationField) in 
                annotation.identifiers.map
                { 
                    Page.accumulate($0).map
                    {
                        [.type($0.component, $0.link)] 
                    }.joined(separator: [.punctuation(".")])
                }.joined(separator: [.punctuation("&")])
            }.joined(separator: [.punctuation(","), .whitespace]))
        }
        if !wheres.isEmpty 
        {
            declaration.append(.whitespace)
            declaration.append(.keyword("where"))
            declaration.append(.whitespace)
            declaration.append(contentsOf: wheres.map 
            {
                (where:Symbol.WhereField) -> [Page.Declaration.Token] in 
                var tokens:[Page.Declaration.Token] = .init(
                    Page.accumulate(`where`.lhs).map 
                {
                    [.type($0.component, $0.link)] 
                }.joined(separator: [.punctuation(".")]))
                
                switch `where`.relation
                {
                case .conforms:
                    tokens.append(.punctuation(":"))
                case .equals:
                    tokens.append(.punctuation("=="))
                }
                
                tokens.append(contentsOf: 
                    Page.accumulate(`where`.rhs).map 
                {
                    [.type($0.component, $0.link)] 
                }.joined(separator: [.punctuation(".")]))
                
                return tokens
            }.joined(separator: [.punctuation(","), .whitespace]))
        }
        
        let page:Page = .init(
            label:          label, 
            name:           name, 
            signature:      signature, 
            declaration:    declaration, 
            overview:       paragraphs.first?.string, 
            discussion:     paragraphs.dropFirst().map(\.string))
        let locals:Set<String>  = .init((header.generics?.identifiers ?? []).map(\.string))
        let url:String          = path.joined(separator: "-")
        return (page: .init(url: url, locals: locals, page: page), path: path)
    }
}

struct PageTree 
{
    var page:Page.Binding? 
    var children:[String: PageTree]
    
    static 
    let empty:Self = .init(page: nil, children: [:])
    
    static 
    func assemble(_ pages:[(page:Page.Binding, path:[String])]) -> Self 
    {
        var root:Self = .empty
        for (page, path):(Page.Binding, [String]) in pages 
        {
            root.insert(page, at: path[...], absolute: path)
        }
        return root
    }
    
    func resolve(scopes:[Self] = []) 
    {
        self.page?.page.resolve(scopes: scopes)
        let scopes:[Self] = scopes + [self]
        for child:Self in self.children.values 
        {
            child.resolve(scopes: scopes)
        }
    }
    
    func resolve(_ path:ArraySlice<String>, component:String) 
        -> Page.Declaration.Token?
    {
        guard let root:String = path.first 
        else 
        {
            guard let url:String = self.page?.url 
            else 
            {
                print("failed to resolve '\(path.joined(separator: "."))'")
                return .identifier(component)
            }
            
            return .type(component, .resolved(url: url))
        }
        
        if      let next:Self = self.children[root] 
        {
            return next.resolve(path.dropFirst(), component: component)
        }
        else if let page:Page.Binding = self.page, 
            page.locals.contains(root), 
            path.dropFirst().isEmpty
        {
            return .type(component, .resolved(url: page.url))
        }
        else 
        {
            return nil 
        }
    }
    
    mutating 
    func insert(_ page:Page.Binding, at path:ArraySlice<String>, absolute:[String]) 
    {
        guard let key:String = path.first 
        else 
        {
            guard self.page == nil
            else 
            {
                fatalError("duplicate entry '\(absolute.joined(separator: "."))'")
            }
            
            self.page = page 
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
            "\(String.init(repeating: " ", count: indent * 4))\(self.page?.url ?? "nil")\n"
        for child:Self in self.children.values 
        {
            description += child.describe(indent: indent + 1)
        }
        return description
    }
}
