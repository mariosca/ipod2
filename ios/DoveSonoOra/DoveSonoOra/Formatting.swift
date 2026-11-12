import CoreLocation
import Foundation

enum Fmt {
    /// 41° 53′ 24.7″ N
    static func dms(_ value: Double, isLatitude: Bool) -> String {
        let hemi = value < 0 ? (isLatitude ? "S" : "O") : (isLatitude ? "N" : "E")
        let abs = Swift.abs(value)
        let d = Int(abs)
        let mFull = (abs - Double(d)) * 60
        let m = Int(mFull)
        let s = (mFull - Double(m)) * 60
        return String(format: "%ld° %02ld′ %.1f″ %@", d, m, s, hemi)
    }

    static func decimal(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    static func cardinal(_ deg: Double) -> String {
        let pts = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                   "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
        return pts[Int((deg / 22.5).rounded()) % 16]
    }

    static func stamp(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().hour().minute()
            .locale(Locale(identifier: "it_IT")))
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().second().locale(Locale(identifier: "it_IT")))
    }
}

/// Testi e link per condividere una posizione.
struct ShareInfo {
    let coordinate: CLLocationCoordinate2D
    let accuracy: Double?
    let altitude: Double?
    let date: Date

    private var latLng: String {
        Fmt.decimal(coordinate.latitude) + "," + Fmt.decimal(coordinate.longitude)
    }

    var googleMapsURL: URL {
        URL(string: "https://www.google.com/maps?q=\(latLng)")!
    }

    var appleMapsURL: URL {
        URL(string: "https://maps.apple.com/?ll=\(latLng)&q=\(Self.encode("La mia posizione"))")!
    }

    var text: String {
        var lines = [
            "📍 La mia posizione attuale",
            "",
            "Latitudine: " + Fmt.decimal(coordinate.latitude),
            "Longitudine: " + Fmt.decimal(coordinate.longitude),
        ]
        if let accuracy { lines.append("Precisione: ±\(Int(accuracy.rounded())) m") }
        if let altitude { lines.append("Altitudine: \(Int(altitude.rounded())) m s.l.m.") }
        lines.append("Rilevata il " + Fmt.stamp(date))
        lines.append("")
        lines.append("Apri in Google Maps:")
        lines.append(googleMapsURL.absoluteString)
        return lines.joined(separator: "\n")
    }

    var whatsappURL: URL { URL(string: "https://wa.me/?text=" + Self.encode(text))! }

    var telegramURL: URL {
        URL(string: "https://t.me/share/url?url=" + Self.encode(googleMapsURL.absoluteString)
            + "&text=" + Self.encode("La mia posizione attuale"))!
    }

    var smsURL: URL { URL(string: "sms:&body=" + Self.encode(text))! }

    var mailURL: URL {
        URL(string: "mailto:?subject=" + Self.encode("La mia posizione attuale")
            + "&body=" + Self.encode(text))!
    }

    /// Codifica per i parametri di un URL: tiene solo i caratteri non riservati.
    static func encode(_ s: String) -> String {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
