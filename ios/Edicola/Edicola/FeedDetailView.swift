import SafariServices
import SwiftUI

/// Le prime 10 notizie di un giornale.
@MainActor
struct FeedDetailView: View {
    @Environment(FeedStore.self) private var store
    let feed: Feed
    @State private var reading: WebLink?

    var body: some View {
        let snapshot = store.snapshots[feed.id]
        List {
            if let error = store.errors[feed.id] {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            if let articles = snapshot?.articles {
                ForEach(Array(articles.enumerated()), id: \.offset) { index, article in
                    Button {
                        if let link = article.link { reading = WebLink(url: link) }
                    } label: {
                        ArticleRow(index: index + 1, article: article)
                    }
                    .buttonStyle(.plain)
                }
            } else if store.loading.contains(feed.id) {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.plain)
        .navigationTitle(feed.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh([feed]) }
        .sheet(item: $reading) { SafariView(url: $0.url).ignoresSafeArea() }
        .safeAreaInset(edge: .bottom) {
            if let fetched = snapshot?.fetchedAt {
                Text("Scaricato alle " + fetched.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.bar)
            }
        }
    }
}

@MainActor
struct ArticleRow: View {
    let index: Int
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                if let summary = article.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                if let date = article.date {
                    Text(RelativeTime.string(date))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let image = article.imageURL {
                Thumbnail(url: image, size: 64)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

/// Browser interno di Safari, con modalità lettura e pulsante per aprire in Safari.
@MainActor
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIViewController {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return UIHostingController(rootView: Text("Link non valido"))
        }
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
