enum HTML 
{
    struct Tag 
    {
        enum Content 
        {
            case character(Character)
            case child(HTML.Tag)
            
            static 
            func escape(_ content:[Self]) -> [Self] 
            {
                var escaped:[Self] = []
                for content:Self in content 
                {
                    switch content 
                    {
                    case .character("<"):
                        escaped.append(contentsOf: "&lt;".map(Content.character(_:)))
                    case .character(">"):
                        escaped.append(contentsOf: "&gt;".map(Content.character(_:)))
                    case .character("&"):
                        escaped.append(contentsOf: "&amp;".map(Content.character(_:)))
                    case .character("\""):
                        escaped.append(contentsOf: "&quot;".map(Content.character(_:)))
                    default:
                        escaped.append(content)
                    }
                }
                return escaped
            }
        }
        
        let name:String, 
            attributes:[String: String]
        var content:[Content] 
        
        init(_ name:String, _ attributes:[String: String], _ text:String) 
        {
            self.init(name, attributes, content: text.map(Content.character(_:)))
        }
        
        init(_ name:String, _ attributes:[String: String], escaped:String) 
        {
            self.name       = name 
            self.attributes = attributes 
            self.content    = escaped.map(Content.character(_:))
        }
        
        init(_ name:String, _ attributes:[String: String], content:[Content]) 
        {
            self.name       = name 
            self.attributes = attributes 
            self.content    = Content.escape(content)
        }
        
        init(_ name:String, _ attributes:[String: String], _ children:[Self]) 
        {
            self.name       = name 
            self.attributes = attributes 
            self.content    = children.map(Content.child(_:))
        }
        
        var string:String 
        {
            let content:String = self.content.map 
            {
                switch $0 
                {
                case .character(let c):
                    return "\(c)"
                case .child(let tag):
                    return tag.string 
                }
            }.joined()
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
        case .framework:
            text = "Framework"
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
        case .typealias:
            text = "Typealias"
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
            
            grouped.append(.init("span", ["class": "syntax-group"], content: group.map(HTML.Tag.Content.child(_:)) + [.character(" ")]))
            
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
            
            let content:[HTML.Tag.Content] 
            if grouped.isEmpty 
            {
                content = group.map(HTML.Tag.Content.child(_:))
            }
            else 
            {
                content = [.character(" ")] + group.map(HTML.Tag.Content.child(_:))
            }
            grouped.append(.init("span", ["class": "signature-group"], content: content))
            
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
    func breadcrumbs(github:String) -> HTML.Tag 
    {
        let icon:HTML.Tag = .init("li", ["class": "github-icon-container"], 
            [.init("a", ["href": github], 
                [.init("span", ["class": "github-icon", "title": "Github repository"], [])])])
        var breadcrumbs:[HTML.Tag] = self.breadcrumbs.map 
        {
            switch $0.link 
            {
            case .resolved(url: let target), .apple(url: let target):
                return .init("li", [:], [.init("a", ["href": target], $0.text)])
            case .unresolved(let path):
                fatalError("attempted to render unresolved link \(path)")
            }
        }
        breadcrumbs.append(.init("li", [:], [.init("span", [:], self.breadcrumb)]))
        return .init("div", ["class": "navigation-container"], [.init("ul", [:], [icon] + breadcrumbs)])
    }
    func html(github:String) -> HTML.Tag
    {
        var sections:[HTML.Tag] = [.init("nav", [:], [self.breadcrumbs(github: github)])]
        func create(class:String, section:[HTML.Tag]) 
        {
            sections.append(
                .init("section", ["class": `class`], 
                [.init("div", ["class": "section-container"], section)]))
        }
        
        // intro 
        var introduction:[HTML.Tag] = 
        [
            self.label.html, 
            .init("h1", ["class": "topic-heading"], self.name), 
            self.blurb.isEmpty ? 
                .init("p", ["class": "topic-blurb"], "No overview available") :
                Markdown.html(tag: .p, attributes: ["class": "topic-blurb"], elements: self.blurb),
        ]
        if !self.discussion.required.isEmpty 
        {
            introduction.append(Markdown.html(tag: .p, attributes: ["class": "topic-required"], elements: self.discussion.required))
        }
        create(class: "introduction", section: introduction)
        
        // discussion 
        var discussion:[HTML.Tag] = 
        [
            .init("h2", [:], "Declaration"),
            .init("div", ["class": "declaration-container"], 
                [.init("code", ["class": "declaration"], Page.Declaration.html(self.declaration))])
        ]
        
        if !self.discussion.parameters.isEmpty
        {
            discussion.append(.init("h2", [:], self.label == .enumerationCase ? "Associated values" : "Parameters"))
            var list:[HTML.Tag] = []
            for (name, paragraphs):(String, [[Markdown.Element]]) in self.discussion.parameters 
            {
                list.append(.init("dt", [:], [.init("code", [:], name)]))
                list.append(.init("dd", [:], paragraphs.map 
                {
                    Markdown.html(tag: .p, attributes: [:], elements: $0)
                }))
            }
            discussion.append(.init("dl", ["class": "parameter-list"], list))
        }
        if !self.discussion.return.isEmpty
        {
            discussion.append(.init("h2", [:], "Return value"))
            discussion.append(contentsOf: self.discussion.return.map 
            {
                Markdown.html(tag: .p, attributes: [:], elements: $0)
            })
        }
        if !self.discussion.overview.isEmpty
        {
            discussion.append(.init("h2", [:], "Overview"))
            discussion.append(contentsOf: self.discussion.overview.map 
            {
                Markdown.html(tag: .p, attributes: [:], elements: $0)
            })
        }
        create(class: "discussion", section: discussion)
        // topics 
        if !self.topics.isEmpty 
        {
            var topics:[HTML.Tag] = [.init("h2", [:], "Topics")]
            for (topic, _, symbols):Page.Topic in self.topics 
            {
                let left:HTML.Tag    = .init("h3", [:], topic)
                var right:[HTML.Tag] = []
                
                for (signature, url, blurb, required):Page.TopicSymbol in symbols 
                {
                    var container:[HTML.Tag] = 
                    [
                        .init("code", ["class": "signature"], 
                            [.init("a", ["href": url], Page.Signature.html(signature))])
                    ]
                    if !blurb.isEmpty
                    {
                        container.append(
                            Markdown.html(tag: .p, attributes: ["class": "topic-symbol-blurb"], elements: blurb))
                    }
                    if !required.isEmpty
                    {
                        container.append(
                            Markdown.html(tag: .p, attributes: ["class": "topic-symbol-required"], elements: required))
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
