import CoreLocation
import SwiftUI

/// Carta OpenTopoMap disegnata a tessere: sull'orologio MapKit non accetta
/// mappe esterne. Digital Crown per lo zoom, dito per spostarsi; la mappa
/// segue la posizione finché non la si sposta (il pulsante ricentra).
@MainActor
struct TopoMapView: View {
    let user: CLLocationCoordinate2D?
    let accuracy: Double?
    let recenterTick: Int

    /// Lato di una tessera sullo schermo: le tessere da 256 pixel a metà
    /// dimensione restano nitide sullo schermo Retina.
    private let tile: Double = 128
    private static let maxZoom = 17.0 // OpenTopoMap arriva fino a 17

    @State private var zoom = 15.0
    /// Centro scelto spostando la mappa col dito; nil = segue la posizione.
    @State private var manualCenter: CLLocationCoordinate2D?
    @State private var dragStart: CLLocationCoordinate2D?

    private static let fallback = CLLocationCoordinate2D(latitude: 41.8902, longitude: 12.4922)

    var body: some View {
        GeometryReader { geo in
            let z = Int(zoom.rounded())
            let center = manualCenter ?? user ?? Self.fallback
            let c = worldPoint(center, z: z)
            let origin = CGPoint(x: c.x - geo.size.width / 2, y: c.y - geo.size.height / 2)
            let count = 1 << z

            let minX = Int(floor(origin.x / tile))
            let maxX = Int(floor((origin.x + geo.size.width) / tile))
            let minY = max(0, Int(floor(origin.y / tile)))
            let maxY = min(count - 1, Int(floor((origin.y + geo.size.height) / tile)))

            ZStack(alignment: .topLeading) {
                Color(white: 0.92)

                if minY <= maxY {
                    ForEach(minY...maxY, id: \.self) { ty in
                        ForEach(minX...maxX, id: \.self) { tx in
                            // Le tessere si ripetono in orizzontale attorno al mondo.
                            let wrapped = ((tx % count) + count) % count
                            TopoTile(z: z, x: wrapped, y: ty)
                                .frame(width: tile, height: tile)
                                .position(x: Double(tx) * tile + tile / 2 - origin.x,
                                          y: Double(ty) * tile + tile / 2 - origin.y)
                        }
                    }
                }

                if let user {
                    let p = worldPoint(user, z: z)
                    userDot(radius: accuracyRadius(at: user, z: z))
                        .position(x: p.x - origin.x, y: p.y - origin.y)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? center
                        if dragStart == nil { dragStart = start }
                        let s = worldPoint(start, z: z)
                        manualCenter = coordinate(at: CGPoint(x: s.x - value.translation.width,
                                                              y: s.y - value.translation.height),
                                                  z: z)
                    }
                    .onEnded { _ in dragStart = nil }
            )
        }
        .focusable()
        .digitalCrownRotation($zoom, from: 3, through: Self.maxZoom, by: 1,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .overlay(alignment: .bottomTrailing) {
            Text("© OpenStreetMap · OpenTopoMap")
                .font(.system(size: 8))
                .foregroundStyle(.black.opacity(0.6))
                .padding(.trailing, 4)
                .padding(.bottom, 26)
        }
        .onChange(of: recenterTick) { manualCenter = nil }
    }

    private func userDot(radius: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .overlay(Circle().stroke(Color.blue.opacity(0.4), lineWidth: 1))
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .fill(Color.blue)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .frame(width: 12, height: 12)
        }
        .allowsHitTesting(false)
    }

    /// Raggio del cerchio di precisione, in punti sullo schermo.
    private func accuracyRadius(at c: CLLocationCoordinate2D, z: Int) -> Double {
        guard let accuracy else { return 0 }
        let metersPerPoint = 156_543.034 * cos(c.latitude * .pi / 180) / pow(2, Double(z)) * (256 / tile)
        return min(max(accuracy / metersPerPoint, 6), 120)
    }

    // MARK: - Proiezione Web Mercator

    private func worldPoint(_ c: CLLocationCoordinate2D, z: Int) -> CGPoint {
        let n = Double(1 << z) * tile
        let lat = min(max(c.latitude, -85.0511), 85.0511) * .pi / 180
        let x = (c.longitude + 180) / 360 * n
        let y = (1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2 * n
        return CGPoint(x: x, y: y)
    }

    private func coordinate(at p: CGPoint, z: Int) -> CLLocationCoordinate2D {
        let n = Double(1 << z) * tile
        let lon = p.x / n * 360 - 180
        let lat = atan(sinh(.pi * (1 - 2 * p.y / n))) * 180 / .pi
        return CLLocationCoordinate2D(latitude: min(max(lat, -85), 85),
                                      longitude: (lon + 540).truncatingRemainder(dividingBy: 360) - 180)
    }
}

/// Una tessera OpenTopoMap, scaricata e tenuta in cache da URLCache.
private struct TopoTile: View {
    let z: Int
    let x: Int
    let y: Int

    var body: some View {
        let server = ["a", "b", "c"][(x + y) % 3]
        AsyncImage(url: URL(string: "https://\(server).tile.opentopomap.org/\(z)/\(x)/\(y).png")) { phase in
            if let image = phase.image {
                image.resizable().interpolation(.medium)
            } else {
                Color(white: 0.92)
            }
        }
    }
}
