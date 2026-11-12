import MapKit
import SwiftUI
import UIKit

enum MapKind: String, CaseIterable, Identifiable {
    case hybrid = "Ibrido"
    case satellite = "Satellite"
    case standard = "Mappa"
    case osm = "OSM"
    case topo = "Topo"

    var id: String { rawValue }

    /// Crediti obbligatori per le mappe OpenStreetMap; nil per le mappe Apple.
    var attribution: String? {
        switch self {
        case .osm: "© OpenStreetMap contributors · sentieri waymarkedtrails.org"
        case .topo: "© OpenStreetMap contributors, SRTM · stile © OpenTopoMap (CC-BY-SA)"
        default: nil
        }
    }

    /// Livelli di tessere, dal fondo verso l'alto.
    func makeTileOverlays() -> [MKTileOverlay] {
        switch self {
        case .osm:
            [
                OSMTileOverlay(template: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                               nativeMaxZ: 19, replacesMap: true),
                // Sentieri escursionistici segnati, su sfondo trasparente.
                OSMTileOverlay(template: "https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png",
                               nativeMaxZ: 18, replacesMap: false),
            ]
        case .topo:
            [
                OSMTileOverlay(template: "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png",
                               nativeMaxZ: 17, replacesMap: true),
            ]
        default:
            []
        }
    }
}

/// Mappa basata su MKMapView: la mappa SwiftUI non accetta tessere esterne.
struct TrackingMapView: UIViewRepresentable {
    let kind: MapKind
    /// Coordinate inserite a mano; nil quando si usa il GPS.
    let manualCoordinate: CLLocationCoordinate2D?
    /// Vero quando arriva la posizione GPS: la mappa la segue al primo fix.
    let hasGPSFix: Bool
    /// Ogni incremento ricentra la mappa.
    let recenterTick: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsCompass = true
        map.showsScale = true
        context.coordinator.recenterTick = recenterTick
        context.coordinator.apply(kind, to: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator

        if c.kind != kind { c.apply(kind, to: map) }

        map.showsUserLocation = manualCoordinate == nil

        if !Self.same(c.manual, manualCoordinate) {
            c.manual = manualCoordinate
            map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
            if let m = manualCoordinate {
                let pin = MKPointAnnotation()
                pin.coordinate = m
                pin.title = "Posizione"
                map.addAnnotation(pin)
                map.setUserTrackingMode(.none, animated: false)
                map.setRegion(Self.region(m), animated: true)
            }
        }

        if hasGPSFix, manualCoordinate == nil, !c.followedFirstFix {
            c.followedFirstFix = true
            map.setUserTrackingMode(.follow, animated: true)
        }
        if !hasGPSFix { c.followedFirstFix = false }

        if c.recenterTick != recenterTick {
            c.recenterTick = recenterTick
            if let m = manualCoordinate {
                map.setRegion(Self.region(m), animated: true)
            } else {
                map.setUserTrackingMode(.follow, animated: true)
            }
        }
    }

    private static func region(_ c: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(center: c, latitudinalMeters: 500, longitudinalMeters: 500)
    }

    private static func same(_ a: CLLocationCoordinate2D?, _ b: CLLocationCoordinate2D?) -> Bool {
        switch (a, b) {
        case (nil, nil): true
        case let (a?, b?): a.latitude == b.latitude && a.longitude == b.longitude
        default: false
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var kind: MapKind?
        var manual: CLLocationCoordinate2D?
        var recenterTick = 0
        var followedFirstFix = false

        func apply(_ kind: MapKind, to map: MKMapView) {
            self.kind = kind
            map.removeOverlays(map.overlays)
            switch kind {
            case .hybrid:
                map.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
            case .satellite:
                map.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
            case .standard:
                map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
            case .osm, .topo:
                map.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
                for overlay in kind.makeTileOverlays() {
                    map.addOverlay(overlay, level: .aboveLabels)
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tiles = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tiles)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            view.markerTintColor = UIColor(Color.beacon)
            return view
        }
    }
}

/// Tessere OpenStreetMap con cache su disco e ingrandimento oltre lo zoom massimo
/// del server (la tessera del livello più alto disponibile viene ritagliata e scalata).
final class OSMTileOverlay: MKTileOverlay {
    private let template: String
    private let nativeMaxZ: Int

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 300 << 20)
        config.requestCachePolicy = .returnCacheDataElseLoad
        // I server OpenStreetMap chiedono un User-Agent che identifichi l'app.
        config.httpAdditionalHeaders = ["User-Agent": "DoveSonoOra/1.0 (app iOS personale)"]
        return URLSession(configuration: config)
    }()

    init(template: String, nativeMaxZ: Int, replacesMap: Bool) {
        self.template = template
        self.nativeMaxZ = nativeMaxZ
        super.init(urlTemplate: nil)
        canReplaceMapContent = replacesMap
        minimumZ = 1
        maximumZ = 21
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let servers = ["a", "b", "c"]
        let s = servers[abs(path.x + path.y) % servers.count]
        let string = template
            .replacingOccurrences(of: "{s}", with: s)
            .replacingOccurrences(of: "{z}", with: String(path.z))
            .replacingOccurrences(of: "{x}", with: String(path.x))
            .replacingOccurrences(of: "{y}", with: String(path.y))
        return URL(string: string)!
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        let dz = path.z - nativeMaxZ
        guard dz > 0 else {
            fetch(url(forTilePath: path), result: result)
            return
        }

        var parent = path
        parent.z = nativeMaxZ
        parent.x = path.x >> dz
        parent.y = path.y >> dz
        let cells = 1 << dz
        let subX = path.x - (parent.x << dz)
        let subY = path.y - (parent.y << dz)

        fetch(url(forTilePath: parent)) { data, error in
            guard let data, let image = UIImage(data: data)?.cgImage else {
                result(nil, error)
                return
            }
            let cell = CGFloat(image.width) / CGFloat(cells)
            let rect = CGRect(x: CGFloat(subX) * cell, y: CGFloat(subY) * cell,
                              width: cell, height: cell)
            guard let cropped = image.cropping(to: rect) else {
                result(nil, error)
                return
            }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let size = CGSize(width: image.width, height: image.height)
            let png = UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
                UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: size))
            }
            result(png, nil)
        }
    }

    private func fetch(_ url: URL, result: @escaping (Data?, Error?) -> Void) {
        Self.session.dataTask(with: url) { data, response, error in
            let ok = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            result(ok ? data : nil, error)
        }.resume()
    }
}
