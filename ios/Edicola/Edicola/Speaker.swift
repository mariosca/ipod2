import AVFoundation
import NaturalLanguage
import Observation

/// Legge ad alta voce gli articoli, uno dopo l'altro: giornale, titolo e
/// sommario, con la voce della lingua in cui è scritto l'articolo.
@MainActor
@Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var queue: [SavedArticle] = []
    private(set) var index: Int?
    private(set) var isPaused = false

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    var isActive: Bool { index != nil }

    var current: SavedArticle? {
        guard let index, queue.indices.contains(index) else { return nil }
        return queue[index]
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(_ items: [SavedArticle], from start: Int = 0) {
        guard items.indices.contains(start) else { return }
        synthesizer.stopSpeaking(at: .immediate)
        // Si sente anche con l'interruttore del silenzioso attivo.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        queue = items
        index = start
        isPaused = false
        speakCurrent()
    }

    func pauseOrResume() {
        guard isActive else { return }
        if isPaused {
            synthesizer.continueSpeaking()
        } else {
            synthesizer.pauseSpeaking(at: .word)
        }
        isPaused.toggle()
    }

    func next() { jump(by: 1) }
    func previous() { jump(by: -1) }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        index = nil
        isPaused = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func jump(by step: Int) {
        guard let index else { return }
        let target = index + step
        guard queue.indices.contains(target) else {
            if step > 0 { stop() }
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        self.index = target
        isPaused = false
        speakCurrent()
    }

    private func speakCurrent() {
        guard let item = current else {
            stop()
            return
        }
        var text = item.feedName + ". " + item.article.title + "."
        if let summary = item.article.summary, !summary.isEmpty {
            text += " " + summary
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLanguage(for: text))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.postUtteranceDelay = 0.8
        synthesizer.speak(utterance)
    }

    /// Lingua della voce, riconosciuta dal testo dell'articolo.
    private static func voiceLanguage(for text: String) -> String {
        let voices = ["it": "it-IT", "en": "en-GB", "fr": "fr-FR", "de": "de-DE", "es": "es-ES",
                      "pt": "pt-PT", "zh": "zh-CN", "ja": "ja-JP"]
        let code = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue ?? "it"
        let prefix = String(code.prefix(2))
        return voices[prefix] ?? "it-IT"
    }

    private func finished() {
        guard let index else { return }
        if queue.indices.contains(index + 1) {
            self.index = index + 1
            speakCurrent()
        } else {
            stop()
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        // Arriva solo a fine lettura, non quando si salta o si ferma.
        Task { @MainActor in self.finished() }
    }
}
