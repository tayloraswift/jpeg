enum Options 
{
    case directory 
    case urlprefix
    case urlsuffix 
    case github
}

func pages(sources:[String], directory:String, urlpattern:(prefix:String, suffix:String), github:String)
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
        for line in contents.split(separator: "\n", omittingEmptySubsequences: false)
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
        case .module(let header)?:
            pages.append(Page.Binding.create(header, fields: body, order: i, urlpattern: urlpattern))
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
        default:
            print("warning unparsed doccoment '\(String.init(doccomment))'") 
        }
    }
    
    PageTree.assemble(pages)
    
    for page:Page.Binding in pages
    {
        let document:String = 
        """
        <head>
            <meta charset="UTF-8">
            <link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,600;1,400;1,600&family=Questrial&display=swap" rel="stylesheet"> 
            <link href="\(urlpattern.prefix)/style.css" rel="stylesheet"> 
        </head> 
        <body>
            \(page.page.html(github: github).string)
        </body>
        """
        File.pave([directory] + page.uniquePath)
        File.save(.init(document.utf8), path: "\(directory)/\(page.filepath)/index.html")
    }
    
    // copy big-sur.css 
    guard let stylesheet:String = File.source(path: "documentation-generator/big-sur.css") 
    else 
    {
        fatalError("missing stylesheet") 
    }
    File.save(.init(stylesheet.utf8), path: "\(directory)/style.css")
    // copy github-icon.svg 
    guard let icon:String = File.source(path: "documentation-generator/github-icon.svg") 
    else 
    {
        fatalError("missing github icon") 
    }
    File.save(.init(icon.utf8), path: "\(directory)/github-icon.svg")
}

var sources:[String]                    = []
var directory:String                    = "documentation"
var url:(prefix:String, suffix:String)  = ("", "")
var github:String                       = "https://github.com"

func help() 
{
    print("""
    usage: \(CommandLine.arguments[0]) sources... [-d/--directory directory] [-p/--url-prefix prefix] [-s/--url-suffix suffix] [-g/--github github]
    """)
}

func main() 
{
    var arguments:[String] = .init(CommandLine.arguments.dropFirst().reversed())
    while let argument:String = arguments.popLast()
    {
        switch argument 
        {
        case "-d", "--directory":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            // remove trailing and doubled slashes 
            guard let head:Character = next.first 
            else 
            {
                // arguments strings should never be empty 
                fatalError("unreachable")
            }
            directory = "\(head)\(next.dropFirst().split(separator: "/").joined(separator: "/"))"
        
        case "-p", "--url-prefix":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            url.prefix = next 
        case "-s", "--url-suffix":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            // remove leading, trailing, and doubled slashes 
            url.suffix = "/\(next.split(separator: "/").joined(separator: "/"))"
        case "-g", "--github":
            guard let next:String = arguments.popLast() 
            else 
            {
                help()
                return 
            }
            github = next 
        case "-h", "--help":
            help()
            return 
        default:
            sources.append(argument)
        }
    }

    pages(sources: sources, directory: directory, urlpattern: url, github: github)
}

main()
