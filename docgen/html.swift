enum HTML 
{
    struct Tag 
    {
        enum Content 
        {
            case text(String)
            case children([HTML.Tag])
        }
        
        let name:String, 
            attributes:[String: String],
            content:Content 
        
        init(_ name:String, _ attributes:[String: String], _ content:String) 
        {
            var text:String = ""
            for c:Character in content 
            {
                switch c 
                {
                case "<":
                    text += "&lt;"
                case ">":
                    text += "&gt;"
                case "&":
                    text += "&amp;"
                case "\"":
                    text += "&quot;"
                default:
                    text.append(c)
                }
            }
            self.name       = name 
            self.attributes = attributes 
            self.content    = .text(text)
        }
        
        init(_ name:String, _ attributes:[String: String], _ content:[Self]) 
        {
            self.name       = name 
            self.attributes = attributes 
            self.content    = .children(content)
        }
        
        func rendered() -> String 
        {
            let content:String 
            switch self.content 
            {
            case .text(let text):
                content = text 
            case .children(let children):
                content = children.map{ $0.rendered() }.joined()
            }
            return "<\(self.name) \(self.attributes.map{ "\($0.key)=\"\($0.value)\"" }.joined(separator: " "))>\(content)</\(self.name)>"
        }
    }
}

extension Page.Label 
{
    var html:HTML.Tag
    {
        let text:String 
        switch self 
        {
        case .enumeration:
            text = "Enumeration"
        case .genericEnumeration:
            text = "Generic Enumeration"
        case .structure:
            text = "Structure"
        case .genericStructure:
            text = "Generic Structure"
        case .class:
            text = "Class"
        case .genericClass:
            text = "Generic Class"
        case .protocol:
            text = "Protocol"
        case .enumerationCase:
            text = "Enumeration Case"
        case .initializer:
            text = "Initializer"
        case .staticMethod:
            text = "Static Method"
        case .instanceMethod:
            text = "Instance Method"
        case .staticProperty:
            text = "Static Property"
        case .instanceProperty:
            text = "Instance Property"
        case .subscript:
            text = "Subscript"
        }
        return .init("div", ["class": "eyebrow"], text)
    }
}
extension Page.Declaration.Token 
{
    var html:HTML.Tag 
    {
        switch self 
        {
        case .whitespace:
            return .init("span", ["class": "syntax-whitespace"], " ")
        case .keyword(let text):
            return .init("span", ["class": "syntax-keyword"], text)
        case .identifier(let text):
            return .init("span", ["class": "syntax-identifier"], text)
        case .type(_, .unresolved):
            fatalError("attempted to render unresolved link")
        case .type(let text, .resolved(url: let target)):
            return .init("a", ["class": "syntax-type", "href": target], text)
        case .type(let text, .apple(url: let target)):
            return .init("a", ["class": "syntax-type syntax-swift-type", "href": target], text)
        case .punctuation(let text):
            return .init("span", ["class": "syntax-punctuation"], text)
        }
    }
}
extension Page 
{
    var html:HTML.Tag
    {
        let label:HTML.Tag          = self.label.html
        let name:HTML.Tag           = .init("h1", ["class": "topic-heading"], self.name)
        let summary:HTML.Tag        = .init("p", ["class": "topic-summary"], self.overview ?? "No overview available")
        let declaration:HTML.Tag    = .init("code", ["class": "declaration"], self.declaration.map(\.html))
        let discussion:[HTML.Tag]   = self.discussion.map 
        {
            .init("p", ["class": "topic-discussion"], $0)
        }
        
        var contents:[HTML.Tag] = 
        [
            label, 
            name, 
            summary, 
            .init("h2", [:], "Declaration"),
            declaration,
        ]
        if !discussion.isEmpty
        {
            contents.append(.init("h2", [:], "Overview"))
            contents.append(contentsOf: discussion)
        }
        
        return .init("main", [:], contents)
    }
}
