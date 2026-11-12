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
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    let list = store.feeds(in: region)
                    if list.isEmpty {
                        ContentUnavailableView("Nessun feed attivo",
                                               systemImage: region.symbol,
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
            .background(Color.paper)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .navigationTitle("MARIO'S EDICOLA")
            // L'intestazione con foto, titolo e data sostituisce la barra di sistema,
            // che non ha spazio per una foto più grande.
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.refresh(region) }
            .navigationDestination(for: Feed.self) { FeedDetailView(feed: $0) }
            .sheet(isPresented: $showSettings) { FeedsSettingsView() }
            .sheet(item: $reading) { SafariView(url: $0.url).ignoresSafeArea() }
        }
        // Si riavvia quando cambi sezione o quando la sezione va riscaricata
        // (per esempio dopo "Ripristina elenco iniziale").
        .task(id: "\(region.rawValue)-\(store.lastRefresh[region] == nil)") {
            if store.needsRefresh(region) { await store.refresh(region) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, store.needsRefresh(region) {
                Task { await store.refresh(region) }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            titleBar
            sectionPicker

            Group {
                if !store.loading.isEmpty {
                    Text("Aggiornamento in corso…")
                } else if let last = store.lastRefresh[region] {
                    Text("Aggiornato alle " + last.formatted(date: .omitted, time: .shortened)
                         + " · dal più recente")
                } else {
                    Text("Tira giù per aggiornare")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .background(Color.paper)
    }

    /// Foto, titolo con data e ora, pulsante dei giornali.
    private var titleBar: some View {
        HStack(spacing: 12) {
            ProfilePhotoButton(size: 60)

            Button {
                // Nuova email, con il destinatario da scegliere nell'app Mail.
                openURL(URL(string: "mailto:?subject=MARIO%27S%20EDICOLA")!)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MARIO'S EDICOLA")
                        .font(.system(.title2, design: .serif).weight(.bold))
                        .foregroundStyle(Color.brand)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    TimelineView(.everyMinute) { context in
                        Text(Self.today(context.date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Scrivi una email")

            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(Color.brand)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Giornali")
        }
        .padding(.horizontal, 16)
    }

    /// "Giovedì 12 novembre 2026 · 17:42"
    private static func today(_ date: Date) -> String {
        let italian = Locale(identifier: "it_IT")
        let day = date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(italian))
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
            .locale(italian))
        return day.prefix(1).uppercased() + String(day.dropFirst()) + " · " + time
    }

    /// Sezioni in una fila scorrevole: quella scelta è viola.
    private var sectionPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Region.allCases) { section in
                        let selected = section == region
                        Button {
                            withAnimation { region = section }
                        } label: {
                            Label(section.title, systemImage: section.symbol)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .foregroundStyle(selected ? Color.white : Color.brand)
                                .background(selected ? Color.brand : Color.white, in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.brand.opacity(selected ? 0 : 0.25)))
                        }
                        .buttonStyle(.plain)
                        .id(section)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear { proxy.scrollTo(region, anchor: .center) }
        }
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.brand.opacity(0.08)))
        .shadow(color: Color.brand.opacity(0.06), radius: 6, y: 2)
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
