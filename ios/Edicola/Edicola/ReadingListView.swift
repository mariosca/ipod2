import SwiftUI

/// Gli articoli messi da parte, con il lettore ad alta voce.
@MainActor
struct ReadingListView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var speaker = Speaker()
    @State private var reading: WebLink?
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                if store.saved.isEmpty {
                    ContentUnavailableView(
                        "Nessun articolo",
                        systemImage: "bookmark",
                        description: Text("Tocca il segnalibro accanto a una notizia per metterla qui."))
                        .listRowBackground(Color.clear)
                }
                ForEach(Array(store.saved.enumerated()), id: \.element.id) { index, item in
                    row(item, index: index)
                }
                .onDelete { store.removeSaved(at: $0) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle("Da leggere")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
                if !store.saved.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Svuota", role: .destructive) { confirmClear = true }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !store.saved.isEmpty { player }
            }
            .confirmationDialog("Togliere tutti gli articoli da Da leggere?",
                                isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Svuota", role: .destructive) {
                    speaker.stop()
                    store.clearSaved()
                }
            }
            .sheet(item: $reading) { SafariView(url: $0.url).ignoresSafeArea() }
        }
        .onDisappear { speaker.stop() }
    }

    private func row(_ item: SavedArticle, index: Int) -> some View {
        let isCurrent = speaker.current?.id == item.id
        return HStack(alignment: .top, spacing: 12) {
            Button {
                if let link = item.article.link { reading = WebLink(url: link) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.feedName.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brand)
                    Text(item.article.title)
                        .font(.headline)
                    if let summary = item.article.summary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Legge da questo articolo in poi.
            Button {
                speaker.play(store.saved, from: index)
            } label: {
                Image(systemName: isCurrent ? "speaker.wave.2.fill" : "play.circle")
                    .font(.title2)
                    .foregroundStyle(Color.brand)
                    .symbolEffect(.variableColor.iterative, isActive: isCurrent && !speaker.isPaused)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Leggi ad alta voce da qui")
        }
        .padding(.vertical, 6)
        .listRowBackground(isCurrent ? Color.brand.opacity(0.08) : Color.white)
    }

    /// Comandi del lettore ad alta voce.
    private var player: some View {
        VStack(spacing: 8) {
            if let current = speaker.current {
                Text("Sto leggendo: " + current.article.title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 28) {
                Button(action: speaker.previous) {
                    Image(systemName: "backward.fill")
                }
                .disabled(!speaker.isActive)
                .accessibilityLabel("Articolo precedente")

                Button {
                    if speaker.isActive {
                        speaker.pauseOrResume()
                    } else {
                        speaker.play(store.saved)
                    }
                } label: {
                    Image(systemName: speaker.isActive && !speaker.isPaused
                          ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                }
                .accessibilityLabel(speaker.isActive && !speaker.isPaused
                                    ? "Pausa" : "Leggi ad alta voce")

                Button(action: speaker.next) {
                    Image(systemName: "forward.fill")
                }
                .disabled(!speaker.isActive)
                .accessibilityLabel("Articolo successivo")

                Button(action: speaker.stop) {
                    Image(systemName: "stop.fill")
                }
                .disabled(!speaker.isActive)
                .accessibilityLabel("Ferma")
            }
            .font(.title2)
            .foregroundStyle(Color.brand)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}

/// Segnalibro per mettere o togliere una notizia da "Da leggere".
@MainActor
struct SaveButton: View {
    @Environment(FeedStore.self) private var store
    let article: Article
    let feedName: String

    var body: some View {
        let saved = store.isSaved(article)
        Button {
            store.toggleSaved(article, from: feedName)
        } label: {
            Image(systemName: saved ? "bookmark.fill" : "bookmark")
                .font(.title3)
                .foregroundStyle(Color.brand)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: saved)
        .accessibilityLabel(saved ? "Togli da Da leggere" : "Aggiungi a Da leggere")
    }
}
