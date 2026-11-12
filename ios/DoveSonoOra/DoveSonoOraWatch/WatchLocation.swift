import CoreLocation
import Observation

/// Posizione dell'orologio (GPS proprio o quello dell'iPhone vicino).
@MainActor
@Observable
final class WatchLocation: NSObject, CLLocationManagerDelegate {
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var accuracy: Double?
    private(set) var altitude: Double?
    private(set) var denied = false

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
    }

    func start() {
        handle(manager.authorizationStatus)
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    private func handle(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            denied = false
            manager.startUpdatingLocation()
        default:
            denied = true
            manager.stopUpdatingLocation()
        }
    }

    private func apply(_ location: CLLocation) {
        coordinate = location.coordinate
        accuracy = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
        altitude = location.verticalAccuracy > 0 ? location.altitude : nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.handle(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in self.apply(last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied {
            Task { @MainActor in self.denied = true }
        }
    }
}
