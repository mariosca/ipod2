import Foundation
import Observation

enum FeedError: LocalizedError {
    case http(Int)
    case notAFeed

    var errorDescription: String? {
        switch self {
        case .http(let code): "Il sito ha risposto con errore \(code)"
        case .notAFeed: "L'indirizzo non contiene un feed RSS"
        }
    }
}

/// Elenco dei giornali, ultime notizie scaricate e stato degli aggiornamenti.
@MainActor
@Observable
final class FeedStore {
    private(set) var feeds: [Feed]
    private(set) var snapshots: [UUID: FeedSnapshot] = [:]
    private(set) var errors: [UUID: String] = [:]
    private(set) var loading: Set<UUID> = []
    private(set) var lastRefresh: Date?

    private static let feedsKey = "feeds.v1"
    nonisolated private static let articlesPerFeed = 10

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.feedsKey),
           let saved = try? JSONDecoder().decode([Feed].self, from: data) {
            feeds = saved
        } else {
            feeds = Feed.defaults
        }
        snapshots = Self.loadCache()
    }

    /// Giornali attivi di una zona, dal più aggiornato al meno recente.
    func feeds(in region: Region) -> [Feed] {
        feeds
            .filter { $0.enabled && $0.region == region }
            .sorted { a, b in
                let da = snapshots[a.id]?.updated ?? .distantPast
                let db = snapshots[b.id]?.updated ?? .distantPast
                return da != db ? da > db : a.name < b.name
            }
    }

    var needsRefresh: Bool {
        guard let lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) > 10 * 60
    }

    // MARK: - Aggiornamento

    func refreshAll() async {
        await refresh(feeds.filter(\.enabled))
        lastRefresh = Date()
    }

    func refresh(_ targets: [Feed]) async {
        loading.formUnion(targets.map(\.id))
        await withTaskGroup(of: (UUID, Result<FeedSnapshot, Error>).self) { group in
            for feed in targets {
                group.addTask { (feed.id, await Self.fetch(feed.url)) }
            }
            for await (id, result) in group {
                loading.remove(id)
                switch result {
                case .success(let snapshot):
                    snapshots[id] = snapshot
                    errors[id] = nil
                case .failure(let error):
                    errors[id] = error.localizedDescription
                }
            }
        }
        saveCache()
    }

    nonisolated private static func fetch(_ url: URL) async -> Result<FeedSnapshot, Error> {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 20)
        // Alcuni siti rifiutano le richieste senza un User-Agent da browser.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 "
                         + "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 Edicola/1.0",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/atom+xml, application/xml, text/xml, */*",
                         forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return .failure(FeedError.http(http.statusCode))
            }
            guard let output = FeedParser.parse(data, limit: articlesPerFeed),
                  !output.articles.isEmpty else {
                return .failure(FeedError.notAFeed)
            }
            let newest = output.articles.compactMap(\.date).max() ?? output.channelDate
            return .success(FeedSnapshot(articles: output.articles, updated: newest,
                                         fetchedAt: Date()))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Modifica elenco

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        guard let i = feeds.firstIndex(where: { $0.id == id }) else { return }
        feeds[i].enabled = enabled
        saveFeeds()
        if enabled, snapshots[id] == nil {
            let feed = feeds[i]
            Task { await refresh([feed]) }
        }
    }

    func upsert(_ feed: Feed) {
        if let i = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[i] = feed
        } else {
            feeds.append(feed)
        }
        snapshots[feed.id] = nil
        errors[feed.id] = nil
        saveFeeds()
        Task { await refresh([feed]) }
    }

    func delete(_ ids: [UUID]) {
        feeds.removeAll { ids.contains($0.id) }
        for id in ids {
            snapshots[id] = nil
            errors[id] = nil
        }
        saveFeeds()
        saveCache()
    }

    func resetToDefaults() {
        feeds = Feed.defaults
        snapshots = [:]
        errors = [:]
        saveFeeds()
        saveCache()
        Task { await refreshAll() }
    }

    // MARK: - Salvataggio

    private func saveFeeds() {
        if let data = try? JSONEncoder().encode(feeds) {
            UserDefaults.standard.set(data, forKey: Self.feedsKey)
        }
    }

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("snapshots.json")
    }

    private func saveCache() {
        let byKey = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(byKey) {
            try? data.write(to: Self.cacheURL, options: .atomic)
        }
    }

    private static func loadCache() -> [UUID: FeedSnapshot] {
        guard let data = try? Data(contentsOf: cacheURL),
              let byKey = try? JSONDecoder().decode([String: FeedSnapshot].self, from: data)
        else { return [:] }
        var out: [UUID: FeedSnapshot] = [:]
        for (key, value) in byKey {
            if let id = UUID(uuidString: key) { out[id] = value }
        }
        return out
    }
}
