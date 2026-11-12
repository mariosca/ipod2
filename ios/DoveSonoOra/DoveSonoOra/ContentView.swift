import MapKit
import SwiftUI
import UIKit

extension Color {
    static let beacon = Color(red: 0xF2 / 255, green: 0xA9 / 255, blue: 0x3B / 255)
    static let fixOK = Color(red: 0x3F / 255, green: 0xCF / 255, blue: 0x8E / 255)
    static let fixBad = Color(red: 0xE2 / 255, green: 0x63 / 255, blue: 0x5A / 255)
    static let ground = Color(red: 0x0A / 255, green: 0x14 / 255, blue: 0x1C / 255)
    static let inkFaint = Color(red: 0x6A / 255, green: 0x84 / 255, blue: 0x93 / 255)
}

enum MapKind: String, CaseIterable, Identifiable {
    case hybrid = "Ibrido"
    case satellite = "Satellite"
    case standard = "Mappa"

    var id: String { rawValue }

    var style: MapStyle {
        switch self {
        case .hybrid: .hybrid(elevation: .realistic)
        case .satellite: .imagery(elevation: .realistic)
        case .standard: .standard(elevation: .realistic)
        }
    }
}

@MainActor
struct ContentView: View {
    @State private var model = LocationModel()
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var mapKind: MapKind = .hybrid
    @State private var showManual = false
    @State private var manualLat = ""
    @State private var manualLng = ""
    @State private var toast: String?

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var share: ShareInfo? {
        guard let c = model.coordinate else { return nil }
        return ShareInfo(coordinate: c, accuracy: model.accuracy,
                         altitude: model.altitude, date: model.timestamp ?? Date())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            map
            LinearGradient(colors: [.clear, .ground.opacity(0.75), .ground.opacity(0.97)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 420)
                .allowsHitTesting(false)
                .ignoresSafeArea()
            panel
        }
        .background(Color.ground)
        .overlay(alignment: .top) { toastView }
        .onAppear { model.start() }
        .onChange(of: scenePhase) { _, phase in
            // Al ritorno dalle Impostazioni il permesso potrebbe essere cambiato.
            if phase == .active, model.source != .manual { model.start() }
        }
    }

    // MARK: - Mappa

    private var map: some View {
        Map(position: $camera) {
            if model.source == .gps {
                UserAnnotation()
            }
            if let c = model.coordinate {
                if model.source == .manual {
                    Marker("Posizione", coordinate: c).tint(Color.beacon)
                }
                if let acc = model.accuracy {
                    MapCircle(center: c, radius: max(acc, 4))
                        .foregroundStyle(Color.beacon.opacity(0.13))
                        .stroke(Color.beacon.opacity(0.5), lineWidth: 1)
                }
            }
        }
        .mapStyle(mapKind.style)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea()
    }

    // MARK: - Pannello

    private var panel: some View {
        VStack(spacing: 12) {
            dock
            if let msg = noticeText { notice(msg) }
            readout
            if showManual || noticeText != nil { manualEntry }
            shareButtons
            Text(metaText)
                .font(.caption)
                .foregroundStyle(Color.inkFaint)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
    }

    private var dock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                statusPill
                Spacer()
                Button(action: recenter) {
                    Image(systemName: "location.fill")
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Ricentra sulla mia posizione")

                Button {
                    withAnimation { showManual.toggle() }
                } label: {
                    Image(systemName: "keyboard")
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Inserisci coordinate a mano")
            }

            Picker("Tipo di mappa", selection: $mapKind) {
                ForEach(MapKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .tint(.beacon)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(statusLabel)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var readout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                coordColumn("Latitudine", model.coordinate?.latitude, isLat: true)
                Divider().frame(height: 64)
                coordColumn("Longitudine", model.coordinate?.longitude, isLat: false)
            }
            Divider()
            HStack(spacing: 0) {
                instrument("Precisione", model.accuracy.map { "±\(Int($0.rounded())) m" },
                           color: accuracyColor)
                instrument("Altitudine", model.altitude.map { "\(Int($0.rounded())) m" })
                instrument("Velocità", model.speed.map { String(format: "%.1f km/h", $0 * 3.6) })
                instrument("Direzione", model.course.map { "\(Int($0.rounded()))° \(Fmt.cardinal($0))" })
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func coordColumn(_ label: String, _ value: Double?, isLat: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.beacon)
            Text(value.map { Fmt.dms($0, isLatitude: isLat) } ?? "—")
                .font(.system(.headline, design: .monospaced))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(value.map { Fmt.decimal($0) + "°" } ?? " ")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .textSelection(.enabled)
    }

    private func instrument(_ label: String, _ value: String?, color: Color = .primary) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.inkFaint)
            Text(value ?? "—")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(value == nil ? Color.primary : color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var manualEntry: some View {
        HStack(spacing: 8) {
            TextField("Latitudine", text: $manualLat)
            TextField("Longitudine", text: $manualLng)
            Button("Usa", action: applyManual)
                .buttonStyle(.bordered)
            if model.source == .manual {
                Button("GPS") {
                    model.resumeGPS()
                    camera = .userLocation(fallback: .automatic)
                }
                .buttonStyle(.bordered)
            }
        }
        .textFieldStyle(.roundedBorder)
        .keyboardType(.numbersAndPunctuation)
        .font(.system(.body, design: .monospaced))
        .tint(.beacon)
    }

    private var shareButtons: some View {
        VStack(spacing: 9) {
            if let share {
                ShareLink(item: share.text, subject: Text("La mia posizione attuale")) {
                    Text("Condividi posizione")
                        .font(.title3.weight(.bold))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.02))
                        .background(Color.beacon, in: RoundedRectangle(cornerRadius: 14))
                }
                HStack(spacing: 7) {
                    quick("WhatsApp", "message.fill") { openURL(share.whatsappURL) }
                    quick("Telegram", "paperplane.fill") { openURL(share.telegramURL) }
                    quick("SMS", "bubble.left.fill") { openURL(share.smsURL) }
                    quick("Email", "envelope.fill") { openURL(share.mailURL) }
                    quick("Copia", "doc.on.doc") {
                        UIPasteboard.general.string = share.text
                        showToast("Posizione copiata")
                    }
                }
                HStack(spacing: 7) {
                    mapsButton("Apri in Mappe") { openURL(share.appleMapsURL) }
                    mapsButton("Google Maps") { openURL(share.googleMapsURL) }
                }
            } else {
                Text("In attesa della posizione…")
                    .font(.title3.weight(.bold))
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(Color.inkFaint)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func quick(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 17))
                Text(title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(.primary)
    }

    private func mapsButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
        .foregroundStyle(.secondary)
    }

    private func notice(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text).font(.subheadline)
            if model.status == .denied {
                Button("Apri Impostazioni") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.beacon)
                .foregroundStyle(.black)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.fixBad.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.fixBad.opacity(0.4)))
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.subheadline.weight(.semibold))
                .textCase(.uppercase)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .foregroundStyle(.black)
                .background(Color.beacon, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Stato

    private var statusLabel: String {
        switch model.status {
        case .searching: "Ricerca segnale"
        case .active: "Posizione attiva"
        case .manual: "Posizione manuale"
        case .denied, .restricted, .unavailable: "Nessun fix"
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .searching: .beacon
        case .active, .manual: .fixOK
        case .denied, .restricted, .unavailable: .fixBad
        }
    }

    private var accuracyColor: Color {
        guard let acc = model.accuracy else { return .primary }
        return acc <= 15 ? .fixOK : acc <= 60 ? .beacon : .fixBad
    }

    private var noticeText: String? {
        switch model.status {
        case .denied:
            "Permesso di posizione negato. Apri Impostazioni › Dove Sono › Posizione e scegli “Mentre usi l’app”, oppure inserisci le coordinate a mano."
        case .restricted:
            "La posizione è bloccata da restrizioni del dispositivo (Tempo di utilizzo o profilo). Puoi inserire le coordinate a mano."
        case .unavailable:
            "Segnale non disponibile. Controlla che i Servizi di localizzazione siano attivi e spostati all’aperto, oppure inserisci le coordinate a mano."
        default:
            nil
        }
    }

    private var metaText: String {
        switch model.source {
        case .gps:
            "Fix GPS · WGS84 · aggiornato alle " + Fmt.time(model.timestamp ?? Date())
        case .manual:
            "Coordinate inserite a mano · WGS84"
        case .none:
            "In attesa del primo fix GPS"
        }
    }

    // MARK: - Azioni

    private func recenter() {
        if model.source == .manual, let c = model.coordinate {
            camera = .region(MKCoordinateRegion(center: c, latitudinalMeters: 500, longitudinalMeters: 500))
        } else {
            model.start()
            camera = .userLocation(fallback: .automatic)
        }
    }

    private func applyManual() {
        let la = Double(manualLat.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces))
        let lo = Double(manualLng.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces))
        guard let la, let lo, (-90...90).contains(la), (-180...180).contains(lo) else {
            showToast("Coordinate non valide")
            return
        }
        model.useManual(latitude: la, longitude: lo)
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: la, longitude: lo),
            latitudinalMeters: 500, longitudinalMeters: 500))
        hideKeyboard()
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if toast == text { toast = nil } }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
