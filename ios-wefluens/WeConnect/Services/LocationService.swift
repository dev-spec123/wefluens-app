//
//  LocationService.swift
//  WeConnect
//
//  CoreLocation wrapper for auto-filling the profile location field.
//

import CoreLocation

/// Represents the resolution state of a location request.
enum LocationStatus: Equatable {
    case idle
    case locating
    case resolved(String)      // e.g. "Beijing, China"
    case denied
    case unavailable
    case error(String)

    var label: String {
        switch self {
        case .idle:          return ""
        case .locating:      return "locatingStatus"
        case .resolved:      return ""
        case .denied:        return "locatingDenied"
        case .unavailable:   return "locatingUnavailable"
        case .error:         return "locatingError"
        }
    }
}

/// A dedicated, non-observable actor that talks to CoreLocation
/// on the main thread and bounces results back to the UI via a callback.
final class LocationService: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var completionHandler: ((LocationStatus) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Start a single-shot location → reverse-geocode → city string.
    func requestLocation(completion: @escaping (LocationStatus) -> Void) {
        completionHandler = completion

        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // Wait for delegate callback
        case .authorizedWhenInUse, .authorizedAlways:
            requestCurrentLocation()
        case .denied, .restricted:
            completion(.denied)
        @unknown default:
            completion(.denied)
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.requestCurrentLocation()
            case .denied, .restricted:
                self.completionHandler?(.denied)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        manager.stopUpdatingLocation()

        // Force English so the saved "City, Country" is the same for every viewer,
        // regardless of the phone's language (mirrors the RN app's English geocode).
        geocoder.reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "en_US")) { [weak self] placemarks, error in
            guard let self else { return }
            if let error {
                Task { @MainActor in
                    self.completionHandler?(.error(error.localizedDescription))
                }
                return
            }
            let name = Self.formatPlacemark(placemarks?.first)
            Task { @MainActor in
                self.completionHandler?(.resolved(name))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        manager.stopUpdatingLocation()
        Task { @MainActor in
            self.completionHandler?(.error(error.localizedDescription))
        }
    }

    // MARK: - Private

    private func requestCurrentLocation() {
        completionHandler?(.locating)
        manager.requestLocation()
    }

    /// Long country names shortened to keep "City, Country" compact (mirrors RN).
    private static let countryShort: [String: String] = [
        "United States": "US",
        "United States of America": "US",
        "United Kingdom": "UK",
        "United Arab Emirates": "UAE",
        "Russian Federation": "Russia",
        "Republic of Korea": "South Korea",
        "Democratic Republic of the Congo": "DR Congo",
        "Czech Republic": "Czechia",
        "Dominican Republic": "Dominican Rep.",
        "Bolivarian Republic of Venezuela": "Venezuela",
    ]

    /// Shortens a long country name (US / UK / UAE…), falling back to the 2-letter
    /// ISO code for anything still longer than 16 chars.
    private static func shortCountry(_ name: String, isoCode: String?) -> String {
        if name.isEmpty { return "" }
        if let mapped = countryShort[name] { return mapped }
        if name.count > 16, let code = isoCode, !code.isEmpty { return code.uppercased() }
        return name
    }

    private static func formatPlacemark(_ pm: CLPlacemark?) -> String {
        guard let pm else { return "Unknown location" }
        let city = pm.locality ?? pm.administrativeArea ?? ""
        let country = shortCountry(pm.country ?? "", isoCode: pm.isoCountryCode)
        if !city.isEmpty, !country.isEmpty {
            return "\(city), \(country)"
        } else if !city.isEmpty {
            return city
        } else if !country.isEmpty {
            return country
        } else {
            return "Unknown location"
        }
    }
}
