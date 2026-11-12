import Foundation

/// Legge feed RSS 2.0, RSS 1.0 (RDF) e Atom.
final class FeedParser: NSObject, XMLParserDelegate {
    struct Output {
        var articles: [Article]
        var channelDate: Date?
    }

    static func parse(_ data: Data, limit: Int = 10) -> Output? {
        let delegate = FeedParser(limit: limit)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        parser.parse() // si interrompe da solo dopo `limit` notizie
        guard delegate.sawFeedRoot else { return nil }
        return Output(articles: delegate.articles, channelDate: delegate.channelDate)
    }

    private let limit: Int
    private var articles: [Article] = []
    private var channelDate: Date?
    private var sawFeedRoot = false

    private var inItem = false
    private var text = ""
    private var title: String?
    private var link: String?
    private var guidLink: String?
    private var date: Date?
    private var summary: String?
    private var image: String?

    private init(limit: Int) {
        self.limit = limit
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        let name = elementName.lowercased()
        text = ""

        switch name {
        case "rss", "feed", "rdf:rdf":
            sawFeedRoot = true
        case "item", "entry":
            inItem = true
            title = nil; link = nil; guidLink = nil; date = nil; summary = nil; image = nil
        case "link" where inItem:
            // Atom: <link rel="alternate" href="..."/>
            if let href = attributes["href"], link == nil {
                let rel = attributes["rel"] ?? "alternate"
                if rel == "alternate" { link = href }
            }
        case "media:content", "media:thumbnail":
            guard inItem, image == nil, let url = attributes["url"] else { break }
            let type = attributes["type"] ?? ""
            let medium = attributes["medium"] ?? ""
            if medium == "image" || type.hasPrefix("image") || (type.isEmpty && medium.isEmpty) {
                image = url
            }
        case "enclosure":
            if inItem, image == nil, let url = attributes["url"],
               (attributes["type"] ?? "").hasPrefix("image") {
                image = url
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(data: CDATABlock, encoding: .utf8)
            ?? String(data: CDATABlock, encoding: .isoLatin1) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = elementName.lowercased()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { text = "" }

        guard inItem else {
            if ["lastbuilddate", "pubdate", "updated", "dc:date"].contains(name),
               let d = DateParsing.parse(value), channelDate == nil || d > channelDate! {
                channelDate = d
            }
            return
        }

        switch name {
        case "title":
            if title == nil { title = value }
        case "link":
            if link == nil, !value.isEmpty { link = value }
        case "guid", "id":
            if value.hasPrefix("http") { guidLink = value }
        case "pubdate", "dc:date", "published", "updated":
            if date == nil { date = DateParsing.parse(value) }
        case "description", "summary":
            if summary == nil, !value.isEmpty { summary = value }
        case "content:encoded", "content":
            if summary == nil, !value.isEmpty { summary = value }
        case "item", "entry":
            finishItem()
            if articles.count >= limit { parser.abortParsing() }
        default:
            break
        }
    }

    private func finishItem() {
        inItem = false
        let cleanTitle = HTMLText.plain(title ?? "")
        guard !cleanTitle.isEmpty else { return }

        let rawSummary = summary ?? ""
        if image == nil { image = HTMLText.firstImage(in: rawSummary) }
        let cleanSummary = HTMLText.plain(rawSummary)

        articles.append(Article(
            title: cleanTitle,
            link: (link ?? guidLink).flatMap { URL(string: $0.trimmingCharacters(in: .whitespaces)) },
            date: date,
            summary: cleanSummary.isEmpty ? nil : String(cleanSummary.prefix(400)),
            imageURL: image.flatMap { URL(string: $0.replacingOccurrences(of: "&amp;", with: "&")) }
        ))
    }
}

enum DateParsing {
    private static let rfc822: [DateFormatter] = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, d MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm Z",
        "dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd HH:mm:ss",
    ].map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Rome")
        f.dateFormat = format
        return f
    }

    private static let iso = ISO8601DateFormatter()
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func parse(_ string: String) -> Date? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if let d = iso.date(from: s) ?? isoFractional.date(from: s) { return d }
        for f in rfc822 {
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}

enum HTMLText {
    /// Toglie i tag HTML, decodifica le entità e compatta gli spazi.
    static func plain(_ html: String) -> String {
        var s = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        s = decodeEntities(s)
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func firstImage(in html: String) -> String? {
        guard let range = html.range(of: "<img[^>]+src=[\"']([^\"']+)[\"']",
                                     options: [.regularExpression, .caseInsensitive]) else { return nil }
        let tag = String(html[range])
        guard let start = tag.range(of: "src=", options: .caseInsensitive)?.upperBound else { return nil }
        let rest = tag[start...].dropFirst() // salta la virgoletta
        return rest.split(whereSeparator: { $0 == "\"" || $0 == "'" }).first.map(String.init)
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "laquo": "«", "raquo": "»", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "ndash": "–", "mdash": "—", "hellip": "…", "euro": "€", "deg": "°",
        "agrave": "à", "egrave": "è", "eacute": "é", "igrave": "ì", "ograve": "ò", "ugrave": "ù",
        "Agrave": "À", "Egrave": "È", "Eacute": "É", "ccedil": "ç", "uuml": "ü", "ouml": "ö",
        "auml": "ä", "szlig": "ß", "ntilde": "ñ", "aacute": "á", "iacute": "í", "oacute": "ó",
        "uacute": "ú",
    ]

    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "&", let semi = s[i...].prefix(12).firstIndex(of: ";") {
                let entity = String(s[s.index(after: i)..<semi])
                if let decoded = decode(entity) {
                    out += decoded
                    i = s.index(after: semi)
                    continue
                }
            }
            out.append(s[i])
            i = s.index(after: i)
        }
        return out
    }

    private static func decode(_ entity: String) -> String? {
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            return UInt32(entity.dropFirst(2), radix: 16).flatMap { Unicode.Scalar($0) }.map { String($0) }
        }
        if entity.hasPrefix("#") {
            return UInt32(entity.dropFirst()).flatMap { Unicode.Scalar($0) }.map { String($0) }
        }
        return named[entity]
    }
}
