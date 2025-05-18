import CoreLocation

final class LocationHelper: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var handler: ((CLLocation?) -> Void)?

    func getOnce(completion: @escaping (CLLocation?) -> Void) {
        handler = completion
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            completion(nil)
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else {
            handler?(nil); handler = nil
        }
    }

    func locationManager(_ m: CLLocationManager,
                         didUpdateLocations locs: [CLLocation]) {
        handler?(locs.first)
        handler = nil
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
        handler?(nil)
        handler = nil
    }
}

