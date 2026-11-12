import Foundation

enum Region: String, Codable, CaseIterable, Identifiable {
    case italia
    case estero

    var id: String { rawValue }
    var title: String { self == .italia ? "Italia" : "Estero" }
}

struct Feed: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var url: URL
    var region: Region
    var enabled = true
}

struct Article: Codable, Hashable {
    let title: String
    let link: URL?
    let date: Date?
    let summary: String?
    let imageURL: URL?
}

/// Ultimo scaricamento riuscito di un feed.
struct FeedSnapshot: Codable {
    /// Le prime notizie, nell'ordine scelto dal giornale.
    var articles: [Article]
    /// Data della notizia più recente (o dell'aggiornamento del canale).
    var updated: Date?
    var fetchedAt: Date
}

extension Feed {
    private static func make(_ name: String, _ url: String, _ region: Region) -> Feed {
        Feed(name: name, url: URL(string: url)!, region: region)
    }

    /// Elenco iniziale. Si può modificare dall'app (Giornali › tocca un giornale).
    static let defaults: [Feed] = [
        make("ANSA", "https://www.ansa.it/sito/notizie/topnews/topnews_rss.xml", .italia),
        make("Corriere della Sera", "https://xml2.corriereobjects.it/rss/homepage.xml", .italia),
        make("la Repubblica", "https://www.repubblica.it/rss/homepage/rss2.0.xml", .italia),
        make("La Stampa", "https://www.lastampa.it/rss/copertina.xml", .italia),
        make("Il Sole 24 Ore", "https://www.ilsole24ore.com/rss/italia.xml", .italia),
        make("Il Fatto Quotidiano", "https://www.ilfattoquotidiano.it/feed/", .italia),
        make("Il Giornale", "https://www.ilgiornale.it/feed.xml", .italia),
        make("Il Messaggero", "https://www.ilmessaggero.it/rss/home.xml", .italia),
        make("Il Mattino", "https://www.ilmattino.it/rss/home.xml", .italia),
        make("Rai News", "https://www.rainews.it/rss/tutti", .italia),

        make("BBC News", "https://feeds.bbci.co.uk/news/rss.xml", .estero),
        make("The Guardian", "https://www.theguardian.com/international/rss", .estero),
        make("The New York Times", "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml", .estero),
        make("The Washington Post", "https://feeds.washingtonpost.com/rss/world", .estero),
        make("The Wall Street Journal", "https://feeds.a.dj.com/rss/RSSWorldNews.xml", .estero),
        make("Le Monde", "https://www.lemonde.fr/rss/une.xml", .estero),
        make("Le Figaro", "https://www.lefigaro.fr/rss/figaro_actualites.xml", .estero),
        make("El País", "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada", .estero),
        make("Der Spiegel", "https://www.spiegel.de/schlagzeilen/index.rss", .estero),
        make("Frankfurter Allgemeine", "https://www.faz.net/rss/aktuell/", .estero),
        make("Al Jazeera", "https://www.aljazeera.com/xml/rss/all.xml", .estero),
        make("NPR", "https://feeds.npr.org/1001/rss.xml", .estero),
    ]

    /// Feed dell'elenco iniziale che non funzionano più, con il giornale che li sostituisce.
    /// Si applica anche agli elenchi già salvati sul telefono.
    static let replacements: [String: Feed] = [
        "https://www.ilpost.it/feed/": make("Il Giornale", "https://www.ilgiornale.it/feed.xml", .italia),
        "https://www.avvenire.it/rss": make("Il Mattino", "https://www.ilmattino.it/rss/home.xml", .italia),
    ]
}
