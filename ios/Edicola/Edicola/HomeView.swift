import SwiftUI

/// Un link da aprire nel browser interno.
struct WebLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

@MainActor
struct HomeView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("region") private var region: Region = .italia
    @State private var showSettings = false
    @State private var reading: WebLink?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    let list = store.feeds(in: region)
                    if list.isEmpty {
                        ContentUnavailableView("Nessun giornale",
                                               systemImage: "newspaper",
                                               description: Text("Attivane qualcuno da Giornali."))
                    }
                    ForEach(list) { feed in
                        NavigationLink(value: feed) {
                            FeedCard(feed: feed) { reading = WebLink(url: $0) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .navigationTitle("Edicola")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Giornali", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .refreshable { await store.refreshAll() }
            .navigationDestination(for: Feed.self) { FeedDetailView(feed: $0) }
            .sheet(isPresented: $showSettings) { FeedsSettingsView() }
            .sheet(item: $reading) { SafariView(url: $0.url).ignoresSafeArea() }
        }
        .task {
            if store.needsRefresh { await store.refreshAll() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, store.needsRefresh {
                Task { await store.refreshAll() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Picker("Zona", selection: $region) {
                ForEach(Region.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Group {
                if !store.loading.isEmpty {
                    Text("Aggiornamento in corso…")
                } else if let last = store.lastRefresh {
                    Text("Aggiornato alle " + last.formatted(date: .omitted, time: .shortened)
                         + " · dal più recente")
                } else {
                    Text("Tira giù per aggiornare")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// Riquadro di un giornale nella vista d'insieme: nome, ultimo aggiornamento
/// e prime tre notizie.
@MainActor
struct FeedCard: View {
    @Environment(FeedStore.self) private var store
    let feed: Feed
    let open: (URL) -> Void

    var body: some View {
        let snapshot = store.snapshots[feed.id]
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(feed.name)
                    .font(.system(.title3, design: .serif).weight(.bold))
                Spacer()
                if store.loading.contains(feed.id) {
                    ProgressView().controlSize(.small)
                } else if let updated = snapshot?.updated {
                    Text(RelativeTime.string(updated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            if let error = store.errors[feed.id], snapshot == nil {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if let articles = snapshot?.articles {
                if let first = articles.first {
                    leadStory(first)
                }
                ForEach(Array(articles.dropFirst().prefix(2).enumerated()), id: \.offset) { _, article in
                    Divider()
                    Button {
                        if let link = article.link { open(link) }
                    } label: {
                        Text(article.title)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("In attesa delle notizie…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private func leadStory(_ article: Article) -> some View {
        Button {
            if let link = article.link { open(link) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(article.title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let image = article.imageURL {
                    Thumbnail(url: image, size: 72)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

@MainActor
struct Thumbnail: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Color(.tertiarySystemFill)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

enum RelativeTime {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.unitsStyle = .short
        return f
    }()

    static func string(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 60 { return "ora" }
        return formatter.localizedString(for: min(date, Date()), relativeTo: Date())
    }
}
