import CoreLocation
import Observation

/// Tiene la posizione corrente: dal GPS del telefono o inserita a mano.
@MainActor
@Observable
final class LocationModel: NSObject, CLLocationManagerDelegate {
    enum Source { case none, gps, manual }

    enum Status: Equatable {
        case searching
        case active
        case manual
        case denied
        case restricted
        case unavailable
    }

    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var accuracy: Double?
    private(set) var altitude: Double?
    private(set) var speed: Double?
    private(set) var course: Double?
    private(set) var timestamp: Date?
    private(set) var source: Source = .none
    private(set) var status: Status = .searching

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
    }

    /// Chiede il permesso se serve e avvia gli aggiornamenti.
    func start() {
        handle(manager.authorizationStatus)
    }

    func useManual(latitude: Double, longitude: Double) {
        manager.stopUpdatingLocation()
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        accuracy = nil
        altitude = nil
        speed = nil
        course = nil
        timestamp = Date()
        source = .manual
        status = .manual
    }

    /// Torna al GPS dopo aver inserito coordinate a mano.
    func resumeGPS() {
        if source == .manual { source = .none }
        status = .searching
        start()
    }

    // MARK: - Interno

    private func handle(_ auth: CLAuthorizationStatus) {
        switch auth {
        case .notDetermined:
            status = .searching
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            if source != .manual { status = coordinate == nil ? .searching : .active }
            manager.startUpdatingLocation()
        case .denied:
            manager.stopUpdatingLocation()
            if source != .manual { status = .denied }
        case .restricted:
            manager.stopUpdatingLocation()
            if source != .manual { status = .restricted }
        @unknown default:
            status = .unavailable
        }
    }

    private func apply(_ loc: CLLocation) {
        guard source != .manual else { return }
        coordinate = loc.coordinate
        accuracy = loc.horizontalAccuracy >= 0 ? loc.horizontalAccuracy : nil
        altitude = loc.verticalAccuracy > 0 ? loc.altitude : nil
        speed = loc.speed >= 0 ? loc.speed : nil
        course = loc.course >= 0 ? loc.course : nil
        timestamp = loc.timestamp
        source = .gps
        status = .active
    }

    private func fail(_ code: CLError.Code?) {
        switch code {
        case .denied:
            if source != .manual { status = .denied }
        case .locationUnknown:
            break // temporaneo: Core Location continua a cercare
        default:
            if coordinate == nil { status = .unavailable }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        Task { @MainActor in self.handle(auth) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.apply(loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code = (error as? CLError)?.code
        Task { @MainActor in self.fail(code) }
    }
}
