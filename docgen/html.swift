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
            self.init(name, attributes, escaped: text)
        }
        
        init(_ name:String, _ attributes:[String: String], escaped:String) 
        {
            self.name       = name 
            self.attributes = attributes 
            self.content    = .text(escaped)
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
        case .genericInitializer:
            text = "Generic Initializer"
        case .genericStaticMethod:
            text = "Generic Static Method"
        case .genericInstanceMethod:
            text = "Generic Instance Method"
        case .staticProperty:
            text = "Static Property"
        case .instanceProperty:
            text = "Instance Property"
        case .associatedtype:
            text = "Associatedtype"
        case .subscript:
            text = "Subscript"
        }
        return .init("div", ["class": "eyebrow"], text)
    }
}
extension Page.Declaration 
{
    static 
    func html(_ tokens:[Token]) -> [HTML.Tag] 
    {
        var i:Int = tokens.startIndex
        var grouped:[HTML.Tag] = []
        while i < tokens.endIndex
        {
            var group:[HTML.Tag] = []
            darkspace:
            while i < tokens.endIndex
            {
                defer 
                {
                    i += 1
                }
                switch tokens[i] 
                {
                case .breakableWhitespace:
                    break darkspace
                case .whitespace:
                    group.append(.init("span", ["class": "syntax-whitespace"], escaped: "&nbsp;"))
                case .keyword(let text):
                    group.append(.init("span", ["class": "syntax-keyword"], text))
                case .identifier(let text):
                    group.append(.init("span", ["class": "syntax-identifier"], text))
                case .type(_, .unresolved), .typePunctuation(_, .unresolved):
                    fatalError("attempted to render unresolved link")
                case .type(let text, .resolved(url: let target)):
                    group.append(.init("a", ["class": "syntax-type", "href": target], text))
                case .type(let text, .apple(url: let target)):
                    group.append(.init("a", ["class": "syntax-type syntax-swift-type", "href": target], text))
                case .typePunctuation(let text, .resolved(url: let target)):
                    group.append(.init("a", ["class": "syntax-type syntax-punctuation", "href": target], text))
                case .typePunctuation(let text, .apple(url: let target)):
                    group.append(.init("a", ["class": "syntax-type syntax-swift-type syntax-punctuation", "href": target], text))
                case .punctuation(let text):
                    group.append(.init("span", ["class": "syntax-punctuation"], text))
                }
            }
            
            grouped.append(.init("span", ["class": "syntax-group"], group))
            
            while i < tokens.endIndex, case .breakableWhitespace = tokens[i]
            {
                i += 1
            }
        }
        return grouped 
    }
}
extension Page.Signature 
{
    static 
    func html(_ tokens:[Token]) -> [HTML.Tag] 
    {
        var i:Int = tokens.startIndex
        var grouped:[HTML.Tag] = []
        while i < tokens.endIndex
        {
            var group:[HTML.Tag] = []
            darkspace:
            while i < tokens.endIndex
            {
                defer 
                {
                    i += 1
                }
                switch tokens[i] 
                {
                case .text(let text):
                    group.append(.init("span", ["class": "signature-text"], text))
                case .punctuation(let text):
                    group.append(.init("span", ["class": "signature-punctuation"], text))
                case .highlight(let text):
                    group.append(.init("span", ["class": "signature-highlight"], text))
                case .whitespace:
                    break darkspace
                }
            }
            
            grouped.append(.init("span", ["class": "signature-group"], group))
            
            while i < tokens.endIndex, case .whitespace = tokens[i]
            {
                i += 1
            }
        }
        return grouped 
    }
}
extension Page 
{
    var html:HTML.Tag
    {
        var sections:[HTML.Tag] = []
        func create(class:String, section:[HTML.Tag]) 
        {
            sections.append(
                .init("section", ["class": `class`], 
                [.init("div", ["class": "section-container"], section)]))
        }
        
        var discussion:[HTML.Tag] = 
        [
            self.label.html, 
            .init("h1", ["class": "topic-heading"], self.name), 
            .init("p", ["class": "topic-blurb"], self.blurb ?? "No overview available"), 
            .init("h2", [:], "Declaration"),
            .init("code", ["class": "declaration"], Page.Declaration.html(self.declaration)),
        ]
        
        if !self.discussion.parameters.isEmpty
        {
            discussion.append(.init("h2", [:], "Parameters"))
            var list:[HTML.Tag] = []
            for (name, paragraphs):(String, [String]) in self.discussion.parameters 
            {
                list.append(.init("dt", [:], [.init("code", [:], name)]))
                list.append(.init("dd", [:], paragraphs.map 
                {
                    .init("p", [:], $0)
                }))
            }
            discussion.append(.init("dl", ["class": "parameter-list"], list))
        }
        if !self.discussion.return.isEmpty
        {
            discussion.append(.init("h2", [:], "Return value"))
            discussion.append(contentsOf: self.discussion.return.map 
            {
                .init("p", [:], $0)
            })
        }
        if !self.discussion.overview.isEmpty
        {
            discussion.append(.init("h2", [:], "Overview"))
            discussion.append(contentsOf: self.discussion.overview.map 
            {
                .init("p", [:], $0)
            })
        }
        create(class: "discussion", section: discussion)
        
        if !self.topics.isEmpty 
        {
            var topics:[HTML.Tag] = [.init("h2", [:], "Topics")]
            for (topic, _, symbols):Page.Topic in self.topics 
            {
                let left:HTML.Tag    = .init("h3", [:], topic)
                var right:[HTML.Tag] = []
                
                for (signature, url, blurb):Page.TopicSymbol in symbols 
                {
                    var container:[HTML.Tag] = 
                    [
                        .init("code", ["class": "signature"], 
                            [.init("a", ["href": url], Page.Signature.html(signature))])
                    ]
                    if let blurb:String = blurb 
                    {
                        container.append(.init("p", ["class": "topic-symbol-blurb"], blurb))
                    }
                    right.append(.init("div", ["class": "topic-container-symbol"], container))
                }
                
                topics.append(.init("div", ["class": "topic"], 
                [
                    .init("div", ["class": "topic-container-right"], [left]),
                    .init("div", ["class": "topic-container-left"], right),
                ]))
            }
            
            create(class: "topics", section: topics)
        }
        
        return .init("main", [:], sections)
    }
}
