import Foundation
import SwiftUI

extension Color {
    /// Viola del titolo e dei dettagli.
    static let brand = Color(red: 0x6B / 255, green: 0x2F / 255, blue: 0xA0 / 255)
    /// Sfondo chiaro delle schermate.
    static let paper = Color(red: 0xFB / 255, green: 0xF9 / 255, blue: 0xFE / 255)
}

/// Sezione dell'app. Il nome resta `Region` perché è salvato così negli elenchi
/// già presenti sul telefono.
enum Region: String, Codable, CaseIterable, Identifiable {
    case italia
    case estero
    case economia
    case tecnologia
    case ia
    case programmazione
    case sicurezza
    case scienza
    case sport
    case cultura
    case design
    case cucina
    case vegana
    case veganaInglese = "vegana_en"
    case videogiochi
    case fumetti
    case podcast
    case youtube
    case reddit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .italia: "News - Ita"
        case .estero: "News - Eng"
        case .economia: "Economia"
        case .tecnologia: "Tecnologia"
        case .ia: "IA"
        case .programmazione: "Programmazione"
        case .sicurezza: "Sicurezza"
        case .scienza: "Scienza"
        case .sport: "Sport"
        case .cultura: "Cultura"
        case .design: "Design"
        case .cucina: "Cucina"
        case .vegana: "Vegan Giuliana"
        case .veganaInglese: "Vegan Inglesi"
        case .videogiochi: "Videogiochi"
        case .fumetti: "Fumetti"
        case .podcast: "Podcast"
        case .youtube: "YouTube"
        case .reddit: "Reddit"
        }
    }

    var symbol: String {
        switch self {
        case .italia: "flag"
        case .estero: "globe.europe.africa"
        case .economia: "chart.line.uptrend.xyaxis"
        case .tecnologia: "iphone"
        case .ia: "sparkles"
        case .programmazione: "chevron.left.forwardslash.chevron.right"
        case .sicurezza: "lock.shield"
        case .scienza: "atom"
        case .sport: "sportscourt"
        case .cultura: "theatermasks"
        case .design: "paintpalette"
        case .cucina: "fork.knife"
        case .vegana: "leaf"
        case .veganaInglese: "leaf.circle"
        case .videogiochi: "gamecontroller"
        case .fumetti: "text.bubble"
        case .podcast: "mic"
        case .youtube: "play.rectangle"
        case .reddit: "bubble.left.and.bubble.right"
        }
    }
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
    ] + added(in: 3) + added(in: 4) + added(in: 5) + added(in: 6)

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
        // Feed dalla pagina "I migliori feed RSS" di Feeder, divisi per sezione.
        (4,
         [],
         [
            make("Reuters", "https://news.google.com/rss/search?q=when:24h+site:reuters.com&ceid=US:en&hl=en-US&gl=US", .estero),
            make("BBC World", "https://feeds.bbci.co.uk/news/world/rss.xml", .estero),
            make("FOX News", "https://feeds.feedburner.com/foxnews/latest", .estero),
            make("The Guardian – World", "https://www.theguardian.com/world/rss", .estero),
            make("The Economist – The world this week", "https://www.economist.com/rss/the_world_this_week_rss.xml", .estero),
            make("The Atlantic", "https://www.theatlantic.com/feed/all/", .estero),
            make("Vox", "https://www.vox.com/rss/index.xml", .estero),
            make("The New York Times – World", "https://rss.nytimes.com/services/xml/rss/nyt/World.xml", .estero),
            make("The Guardian – UK", "https://www.theguardian.com/uk/rss", .estero),
            make("Politico", "https://www.politico.com/rss/politicopicks.xml", .estero),
            make("ProPublica", "https://feeds.propublica.org/propublica/main", .estero),
            make("The New Yorker", "https://www.newyorker.com/feed/everything?_=1794120648685", .estero),
            make("Pew Research Center", "https://www.pewresearch.org/feed/", .estero),
            make("CBC News", "https://www.cbc.ca/webfeed/rss/rss-topstories", .estero),
            make("Deutsche Welle", "https://rss.dw.com/rdf/rss-en-all", .estero),
            make("South China Morning Post", "https://www.scmp.com/rss/91/feed/", .estero),
            make("AP News", "https://news.google.com/rss/search?q=when:24h+site:apnews.com&hl=en-US&gl=US&ceid=US:en", .estero),
            make("TechCrunch", "https://techcrunch.com/feed/", .tecnologia),
            make("The Verge", "https://www.theverge.com/rss/index.xml", .tecnologia),
            make("Wired", "https://www.wired.com/feed/rss", .tecnologia),
            make("Lifehacker", "https://lifehacker.com/rss", .tecnologia),
            make("Hacker News", "https://news.ycombinator.com/rss", .tecnologia),
            make("Ars Technica", "https://feeds.arstechnica.com/arstechnica/index", .tecnologia),
            make("TechRadar", "https://www.techradar.com/rss", .tecnologia),
            make("Engadget", "https://www.engadget.com/rss.xml", .tecnologia),
            make("Mashable", "https://feeds.mashable.com/Mashable", .tecnologia),
            make("Gizmodo", "https://gizmodo.com/rss", .tecnologia),
            make("Digital Trends", "https://www.digitaltrends.com/feed/", .tecnologia),
            make("9to5Mac", "https://9to5mac.com/feed/", .tecnologia),
            make("MacRumors", "https://feeds.macrumors.com/MacRumors-All", .tecnologia),
            make("BBC Technology", "https://feeds.bbci.co.uk/news/technology/rss.xml", .tecnologia),
            make("Slashdot", "https://rss.slashdot.org/Slashdot/slashdot", .tecnologia),
            make("GeekWire", "https://www.geekwire.com/feed/", .tecnologia),
            make("Product Hunt", "https://www.producthunt.com/feed", .tecnologia),
            make("Techmeme", "https://www.techmeme.com/feed.xml", .tecnologia),
            make("404 Media", "https://www.404media.co/rss/", .tecnologia),
            make("MIT Technology Review", "https://www.technologyreview.com/feed/", .tecnologia),
            make("Daring Fireball", "https://daringfireball.net/feeds/main", .tecnologia),
            make("Google – The Keyword", "https://www.blog.google/rss/", .tecnologia),
            make("少数派", "https://sspai.com/feed", .tecnologia),
            make("Hacker Noon", "https://hackernoon.com/feed", .programmazione),
            make("AWS Blog", "https://aws.amazon.com/blogs/aws/feed/", .programmazione),
            make("AWS – Novità", "https://aws.amazon.com/about-aws/whats-new/recent/feed/", .programmazione),
            make("Smashing Magazine", "https://www.smashingmagazine.com/feed/", .programmazione),
            make("Martin Fowler", "https://martinfowler.com/feed.atom", .programmazione),
            make(".NET Blog", "https://devblogs.microsoft.com/dotnet/feed/", .programmazione),
            make("Microsoft Azure Blog", "https://azure.microsoft.com/en-us/blog/feed/", .programmazione),
            make("Kubernetes", "https://kubernetes.io/feed.xml", .programmazione),
            make("CloudFlare", "https://blog.cloudflare.com/rss/", .programmazione),
            make("CSS-Tricks", "https://css-tricks.com/feed/", .programmazione),
            make("Coding Horror", "https://feeds.feedburner.com/codinghorror", .programmazione),
            make("阮一峰的网络日志", "https://feeds.feedburner.com/ruanyifeng", .programmazione),
            make("The GitHub Blog", "https://github.blog/feed/", .programmazione),
            make("The Pragmatic Engineer", "https://blog.pragmaticengineer.com/rss/", .programmazione),
            make("Real Python", "https://realpython.com/atom.xml", .programmazione),
            make("DEV Community", "https://dev.to/feed", .programmazione),
            make("OpenAI News", "https://openai.com/news/rss.xml", .ia),
            make("Google DeepMind", "https://deepmind.google/blog/rss.xml", .ia),
            make("Hugging Face Blog", "https://huggingface.co/blog/feed.xml", .ia),
            make("One Useful Thing", "https://www.oneusefulthing.org/feed", .ia),
            make("Import AI", "https://importai.substack.com/feed", .ia),
            make("Simon Willison's Weblog", "https://simonwillison.net/atom/everything/", .ia),
            make("Towards Data Science", "https://towardsdatascience.com/feed", .ia),
            make("The Hacker News", "https://feeds.feedburner.com/TheHackersNews", .sicurezza),
            make("Krebs on Security", "https://krebsonsecurity.com/feed/", .sicurezza),
            make("BleepingComputer", "https://www.bleepingcomputer.com/feed/", .sicurezza),
            make("Dark Reading", "https://www.darkreading.com/rss.xml", .sicurezza),
            make("Schneier on Security", "https://www.schneier.com/blog/atom.xml", .sicurezza),
            make("CISA – Avvisi", "https://www.cisa.gov/cybersecurity-advisories/all.xml", .sicurezza),
            make("Microsoft – Aggiornamenti di sicurezza", "https://api.msrc.microsoft.com/update-guide/rss", .sicurezza),
            make("Fortinet Firmware Updates", "https://pub.kb.fortinet.com/rss/firmware.xml", .sicurezza),
            make("AWS Security Blog", "https://aws.amazon.com/blogs/security/feed/", .sicurezza),
            make("Nature – Ultimo numero", "https://www.nature.com/nature/current_issue/rss", .scienza),
            make("Nature", "https://www.nature.com/nature.rss", .scienza),
            make("NASA Breaking News", "https://www.nasa.gov/rss/dyn/breaking_news.rss", .scienza),
            make("Scientific American", "https://rss.sciam.com/ScientificAmerican-Global", .scienza),
            make("Science – Ultimo numero", "https://science.sciencemag.org/rss/current.xml", .scienza),
            make("ScienceDaily", "https://www.sciencedaily.com/rss/all.xml", .scienza),
            make("Nature Communications", "https://feeds.nature.com/ncomms/rss/current", .scienza),
            make("New Scientist", "https://www.newscientist.com/feed/", .scienza),
            make("Science News", "https://www.sciencenews.org/feed", .scienza),
            make("Phys.org", "https://phys.org/rss-feed/", .scienza),
            make("Nautilus", "https://nautil.us/feed", .scienza),
            make("EMA – Agenzia europea del farmaco", "https://www.ema.europa.eu/en/news.xml", .scienza),
            make("Bloomberg", "https://news.google.com/rss/search?q=when:24h+site:bloomberg.com&hl=en-US&gl=US&ceid=US:en", .economia),
            make("Entrepreneur", "https://www.entrepreneur.com/rss-feed/latest", .economia),
            make("MarketWatch", "https://feeds.marketwatch.com/marketwatch/topstories", .economia),
            make("HubSpot Marketing Blog", "https://blog.hubspot.com/marketing/rss.xml", .economia),
            make("The New York Times – Business", "https://www.nytimes.com/services/xml/rss/nyt/Business.xml", .economia),
            make("Fast Company", "https://www.fastcompany.com/latest/rss?truncated=true", .economia),
            make("Business Insider", "https://www.businessinsider.com/rss", .economia),
            make("Harvard Business Review", "https://feeds.harvardbusiness.org/harvardbusiness/", .economia),
            make("The Economist – Business", "https://www.economist.com/business/rss.xml", .economia),
            make("BBC Business", "https://feeds.bbci.co.uk/news/business/rss.xml", .economia),
            make("Fortune", "https://fortune.com/feed/", .economia),
            make("CNBC", "https://www.cnbc.com/id/100003114/device/rss/rss.html", .economia),
            make("Financial Times", "https://www.ft.com/?format=rss", .economia),
            make("McKinsey Insights", "https://www.mckinsey.com/Insights/rss.aspx", .economia),
            make("Social Media Today", "https://www.socialmediatoday.com/feeds/news/", .economia),
            make("The Economist – Finanza", "https://www.economist.com/finance-and-economics/rss.xml", .economia),
            make("Seth's Blog", "https://seths.blog/feed/", .economia),
            make("Yahoo Finance – S&P 500", "https://feeds.finance.yahoo.com/rss/2.0/headline?s=%5EGSPC&region=US&lang=en-US", .economia),
            make("ESPN", "https://www.espn.com/espn/rss/news", .sport),
            make("BBC Sport", "https://feeds.bbci.co.uk/sport/rss.xml", .sport),
            make("The Guardian – Calcio", "https://www.theguardian.com/football/rss", .sport),
            make("The Athletic", "https://www.nytimes.com/athletic/rss/news/", .sport),
            make("Formula 1", "https://www.formula1.com/en/latest/all.xml", .sport),
            make("Yahoo Sports", "https://sports.yahoo.com/rss/", .sport),
            make("PC Gamer", "https://www.pcgamer.com/rss/", .videogiochi),
            make("Polygon", "https://www.polygon.com/rss/index.xml", .videogiochi),
            make("IGN", "https://www.ign.com/rss/articles/feed", .videogiochi),
            make("Rock Paper Shotgun", "https://www.rockpapershotgun.com/feed", .videogiochi),
            make("Eurogamer", "https://www.eurogamer.net/feed", .videogiochi),
            make("Nintendo Life", "https://www.nintendolife.com/feeds/latest", .videogiochi),
            make("xkcd", "https://xkcd.com/rss.xml", .fumetti),
            make("Saturday Morning Breakfast Cereal", "https://www.smbc-comics.com/comic/rss", .fumetti),
            make("Order of the Stick", "https://www.giantitp.com/comics/oots.rss", .fumetti),
            make("Penny Arcade", "https://www.penny-arcade.com/feed", .fumetti),
            make("Gunnerkrigg Court", "https://www.gunnerkrigg.com/rss.xml", .fumetti),
            make("Poorly Drawn Lines", "https://poorlydrawnlines.com/feed/", .fumetti),
            make("Existential Comics", "https://existentialcomics.com/rss.xml", .fumetti),
            make("Design Milk", "https://design-milk.com/feed/", .design),
            make("Colossal", "https://www.thisiscolossal.com/feed/", .design),
            make("It's Nice That", "https://feeds2.feedburner.com/itsnicethat/SlXC", .design),
            make("UX Collective", "https://uxdesign.cc/feed", .design),
            make("Bon Appétit", "https://www.bonappetit.com/feed/rss", .cucina),
            make("Smitten Kitchen", "https://smittenkitchen.com/feed/", .cucina),
            make("Budget Bytes", "https://www.budgetbytes.com/feed/", .cucina),
            make("Minimalist Baker", "https://minimalistbaker.com/feed/", .cucina),
            make("Atlas Obscura", "https://www.atlasobscura.com/feeds/latest", .cultura),
            make("Open Culture", "https://www.openculture.com/feed", .cultura),
            make("Variety", "https://variety.com/feed/", .cultura),
            make("Pitchfork", "https://pitchfork.com/feed/feed-news/rss", .cultura),
            make("The Daily", "https://feeds.simplecast.com/54nAGcIl", .podcast),
            make("Radiolab", "https://feeds.simplecast.com/EmVW7VGp", .podcast),
            make("99% Invisible", "https://feeds.simplecast.com/BqbsxVfO", .podcast),
            make("Freakonomics Radio", "https://feeds.simplecast.com/Y8lFbOT4", .podcast),
            make("TED", "https://www.youtube.com/feeds/videos.xml?channel_id=UCAuUUnT6oDeKwE6v1NGQxug", .youtube),
            make("Kurzgesagt", "https://www.youtube.com/feeds/videos.xml?channel_id=UCsXVk37bltHxD1rDPwtNM8Q", .youtube),
            make("Veritasium", "https://www.youtube.com/feeds/videos.xml?channel_id=UCHnyfMqiRRG1u-2MsSQLbXA", .youtube),
            make("3Blue1Brown", "https://www.youtube.com/feeds/videos.xml?channel_id=UCYO_jab_esuFRV4b17AJtAw", .youtube),
            make("Marques Brownlee", "https://www.youtube.com/feeds/videos.xml?channel_id=UCBJycsmduvYEL83R_U4JriQ", .youtube),
            make("r/technology", "https://www.reddit.com/r/technology/.rss", .reddit),
            make("r/worldnews – Top", "https://www.reddit.com/r/worldnews/top/.rss", .reddit),
            make("r/worldnews", "https://www.reddit.com/r/worldnews/.rss", .reddit),
            make("r/space", "https://www.reddit.com/r/space/.rss", .reddit),
            make("r/books", "https://www.reddit.com/r/books/.rss", .reddit),
            make("r/programming", "https://www.reddit.com/r/programming/.rss", .reddit),
            make("r/MachineLearning", "https://www.reddit.com/r/MachineLearning/.rss", .reddit),
         ]),
        // Sezione Vegan Giuliana: blog di ricette vegane in italiano (feed verificati).
        // I blog in inglese erano qui: ora sono in Vegan Inglesi (versione 6).
        (5,
         [],
         [
            make("Vegolosi – Ricette vegane", "https://www.vegolosi.it/ricette-vegane/feed/", .vegana),
            make("Benvenuti a Las Vegans", "https://blog.giallozafferano.it/benvenutialasvegans/feed/", .vegana),
            make("Timo e lenticchie", "https://blog.giallozafferano.it/timoelenticchie/feed/", .vegana),
            make("greenMe – Ricette vegan", "https://www.greenme.it/tag/ricette-vegan/feed/", .vegana),
            make("Ortaggi che passione", "https://blog.giallozafferano.it/ortaggichepassionebysara/feed/", .vegana),
            make("Studenti ai fornelli – Vegane", "https://blog.giallozafferano.it/studentiaifornelli/category/ricette-vegane-per-alimentazione-vegetale/feed/", .vegana),
            make("Anna e la sua cucina – Vegane", "https://blog.giallozafferano.it/annaelasuacucina/category/ricette-vegane/feed/", .vegana),
            make("In cucina con Mary – Vegan", "https://blog.giallozafferano.it/incucinaconmary/category/vegan/feed/", .vegana),
         ]),
        // Sezione Vegan Inglesi: i blog vegani in inglese escono da Vegan Giuliana.
        (6,
         veganInglesi.map(\.url.absoluteString),
         veganInglesi),
    ]

    /// Blog di ricette vegane in inglese, da Feedspot (Top Vegan RSS Feeds).
    private static let veganInglesi: [Feed] = [
        make("Vegan Richa", "https://feeds.feedburner.com/blogspot/yPHzu", .veganaInglese),
        make("It Doesn't Taste Like Chicken", "https://itdoesnttastelikechicken.com/feed/", .veganaInglese),
        make("Pick Up Limes", "https://www.pickuplimes.com/recipe/latest-rss", .veganaInglese),
        make("Connoisseurus Veg", "https://www.connoisseurusveg.com/feed/", .veganaInglese),
        make("Lazy Cat Kitchen", "https://www.lazycatkitchen.com/feed/", .veganaInglese),
        make("Minimalist Baker – Vegan", "https://minimalistbaker.com/recipes/vegan/feed/", .veganaInglese),
        make("Nora Cooks", "https://www.noracooks.com/feed/", .veganaInglese),
        make("Rainbow Plant Life", "https://rainbowplantlife.com/feed/", .veganaInglese),
        make("Elavegan", "https://elavegan.com/feed/", .veganaInglese),
        make("Oh She Glows", "https://ohsheglows.com/feed/", .veganaInglese),
        make("The First Mess", "https://feeds.feedburner.com/TheFirstMess", .veganaInglese),
        make("The Plant Based School", "https://theplantbasedschool.com/feed/", .veganaInglese),
        make("The Vegan Italian Kitchen", "https://www.theveganitaliankitchen.com/blog-feed.xml", .veganaInglese),
        make("VegNews", "https://vegnews.com/feed.rss", .veganaInglese),
    ]

    static var latestVersion: Int { migrations.map(\.version).max() ?? 1 }

    private static func added(in version: Int) -> [Feed] {
        migrations.first { $0.version == version }?.add ?? []
    }
}
