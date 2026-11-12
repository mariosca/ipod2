import SwiftUI

/// Gestione dei giornali: attiva/disattiva, aggiungi, modifica, elimina.
@MainActor
struct FeedsSettingsView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Feed?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(Region.allCases) { region in
                    Section(region.title) {
                        let list = store.feeds.filter { $0.region == region }
                        ForEach(list) { feed in
                            row(feed)
                        }
                        .onDelete { offsets in
                            store.delete(offsets.map { list[$0].id })
                        }
                    }
                }

                Section {
                    Button {
                        editing = Feed(name: "", url: URL(string: "https://example.com")!, region: .italia)
                    } label: {
                        Label("Aggiungi giornale", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label("Ripristina elenco iniziale", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Tocca un giornale per correggerne nome o indirizzo RSS. "
                         + "Scorri a sinistra per eliminarlo.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle("Giornali")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
            .sheet(item: $editing) { feed in
                FeedEditView(feed: feed) { store.upsert($0) }
            }
            .confirmationDialog("Ripristinare l'elenco iniziale dei giornali?",
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Ripristina", role: .destructive) { store.resetToDefaults() }
            } message: {
                Text("Le modifiche e i giornali aggiunti andranno persi.")
            }
        }
    }

    private func row(_ feed: Feed) -> some View {
        HStack {
            Button {
                editing = feed
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.name).foregroundStyle(.primary)
                    Text(feed.url.host() ?? feed.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let error = store.errors[feed.id] {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("Attivo", isOn: Binding(
                get: { feed.enabled },
                set: { store.setEnabled(feed.id, $0) }
            ))
            .labelsHidden()
        }
    }
}

@MainActor
struct FeedEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Feed
    @State private var urlText: String
    let onSave: (Feed) -> Void

    init(feed: Feed, onSave: @escaping (Feed) -> Void) {
        _draft = State(initialValue: feed)
        // Un giornale nuovo arriva senza nome: il campo indirizzo parte vuoto.
        _urlText = State(initialValue: feed.name.isEmpty ? "" : feed.url.absoluteString)
        self.onSave = onSave
    }

    private var parsedURL: URL? {
        var text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("http://") {
            text = "https://" + text.dropFirst("http://".count) // iOS accetta solo https
        } else if !text.lowercased().hasPrefix("https://") {
            text = "https://" + text
        }
        guard let url = URL(string: text), url.host() != nil, text.count > "https://".count else {
            return nil
        }
        return url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Giornale") {
                    TextField("Nome", text: $draft.name)
                    Picker("Zona", selection: $draft.region) {
                        ForEach(Region.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section {
                    TextField("https://…", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Indirizzo RSS")
                } footer: {
                    Text("Di solito si trova in fondo alla pagina del giornale, alla voce RSS.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle(draft.name.isEmpty ? "Nuovo giornale" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard let url = parsedURL else { return }
                        draft.url = url
                        draft.enabled = true
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty || parsedURL == nil)
                }
            }
        }
    }
}
