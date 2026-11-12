import MapKit
import SwiftUI

enum WatchMapKind: String {
    case satellite
    case topo
}

@MainActor
struct WatchContentView: View {
    @State private var location = WatchLocation()
    @AppStorage("watchMapKind") private var kind: WatchMapKind = .topo
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var topoRecenter = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                switch kind {
                case .satellite:
                    Map(position: $camera) {
                        UserAnnotation()
                    }
                    .mapStyle(.imagery(elevation: .flat))
                case .topo:
                    TopoMapView(user: location.coordinate,
                                accuracy: location.accuracy,
                                recenterTick: topoRecenter)
                }

                coordinates
            }
            .ignoresSafeArea(edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if kind == .satellite {
                            camera = .userLocation(fallback: .automatic)
                        } else {
                            topoRecenter += 1
                        }
                    } label: {
                        Image(systemName: "location.fill")
                    }
                    .accessibilityLabel("Ricentra")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        kind = kind == .topo ? .satellite : .topo
                    } label: {
                        Image(systemName: kind == .topo ? "globe.europe.africa.fill" : "mountain.2.fill")
                    }
                    .accessibilityLabel(kind == .topo ? "Passa al satellite" : "Passa alla carta Topo")
                }
            }
        }
        .onAppear { location.start() }
        .onChange(of: scenePhase) { _, phase in
            // Il GPS consuma batteria: si spegne quando l'app non è in primo piano.
            if phase == .active { location.start() } else { location.stop() }
        }
    }

    /// Coordinate in basso, piccole, su fondo scuro.
    private var coordinates: some View {
        Group {
            if location.denied {
                Text("Posizione non consentita: attivala in Impostazioni › Privacy")
            } else if let c = location.coordinate {
                VStack(spacing: 0) {
                    Text(String(format: "%.5f, %.5f", c.latitude, c.longitude))
                        .monospacedDigit()
                    if let alt = location.altitude {
                        Text("\(Int(alt.rounded())) m s.l.m."
                             + (location.accuracy.map { " · ±\(Int($0.rounded())) m" } ?? ""))
                    }
                }
            } else {
                Text("Ricerca del GPS…")
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.black.opacity(0.7), in: Capsule())
        .padding(.bottom, 6)
        .allowsHitTesting(false)
    }
}
