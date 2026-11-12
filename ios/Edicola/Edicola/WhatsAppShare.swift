import SwiftUI

enum WhatsApp {
    /// Link che apre WhatsApp con il titolo e l'indirizzo dell'articolo, pronti
    /// da inviare a un contatto scelto lì.
    static func shareURL(for article: Article) -> URL? {
        guard let link = article.link else { return nil }
        let text = article.title + "\n" + link.absoluteString
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://wa.me/?text=" + encoded)
    }
}

/// Tocco: apre l'articolo. Pressione di 5 secondi: lo invia su WhatsApp.
/// Mentre si tiene premuto la notizia si schiarisce; all'invio il telefono vibra.
private struct ArticleGestures: ViewModifier {
    @Environment(\.openURL) private var openURL
    let article: Article
    let open: () -> Void
    @State private var pressing = false
    @State private var sent = 0

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .opacity(pressing ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.2), value: pressing)
            .onTapGesture(perform: open)
            .onLongPressGesture(minimumDuration: WhatsApp.holdSeconds) {
                guard let url = WhatsApp.shareURL(for: article) else { return }
                sent += 1
                openURL(url)
            } onPressingChanged: { pressing = $0 }
            .sensoryFeedback(.success, trigger: sent)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Invia su WhatsApp") {
                if let url = WhatsApp.shareURL(for: article) { openURL(url) }
            }
    }
}

extension WhatsApp {
    /// Secondi di pressione sul titolo per inviare l'articolo su WhatsApp.
    static let holdSeconds: Double = 5
}

extension View {
    /// Tocco per aprire l'articolo, pressione lunga per inviarlo su WhatsApp.
    func articleGestures(_ article: Article, open: @escaping () -> Void) -> some View {
        modifier(ArticleGestures(article: article, open: open))
    }
}
