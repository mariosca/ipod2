import Foundation
import SwiftUI

extension Color {
    /// Viola del titolo e dei dettagli.
    static let brand = Color(red: 0x6B / 255, green: 0x2F / 255, blue: 0xA0 / 255)
    /// Sfondo chiaro delle schermate.
    static let paper = Color(red: 0xFB / 255, green: 0xF9 / 255, blue: 0xFE / 255)
}

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
        make("Le Monde", "https://www.lemonde.fr/rss/une.xml", .estero),
        make("Le Figaro", "https://www.lefigaro.fr/rss/figaro_actualites.xml", .estero),
        make("El País", "https://feeds.elpais.com/mrss-s/pages/ep/site/elpais.com/portada", .estero),
        make("Der Spiegel", "https://www.spiegel.de/schlagzeilen/index.rss", .estero),
        make("Frankfurter Allgemeine", "https://www.faz.net/rss/aktuell/", .estero),
        make("Al Jazeera", "https://www.aljazeera.com/xml/rss/all.xml", .estero),
        make("NPR", "https://feeds.npr.org/1001/rss.xml", .estero),
    ] + added(in: 3)

    /// Modifiche all'elenco iniziale nel tempo, applicate anche agli elenchi già
    /// salvati sul telefono: tolgono i feed che non funzionano e aggiungono i nuovi.
    static let migrations: [(version: Int, remove: [String], add: [Feed])] = [
        (2,
         ["https://www.ilpost.it/feed/", "https://www.avvenire.it/rss"],
         [
            make("Il Giornale", "https://www.ilgiornale.it/feed.xml", .italia),
            make("Il Mattino", "https://www.ilmattino.it/rss/home.xml", .italia),
         ]),
        (3,
         ["https://feeds.a.dj.com/rss/RSSWorldNews.xml"],
         [
            make("The Independent", "https://www.independent.co.uk/news/world/rss", .estero),
            make("Süddeutsche Zeitung", "https://rss.sueddeutsche.de/rss/Topthemen", .estero),
            make("Neue Zürcher Zeitung", "https://www.nzz.ch/recent.rss", .estero),
            make("The Times of India", "https://timesofindia.indiatimes.com/rssfeedstopstories.cms", .estero),
            make("France 24", "https://www.france24.com/en/rss", .estero),
         ]),
    ]

    static var latestVersion: Int { migrations.map(\.version).max() ?? 1 }

    private static func added(in version: Int) -> [Feed] {
        migrations.first { $0.version == version }?.add ?? []
    }
}
