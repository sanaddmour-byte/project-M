//
//  LocationCaptureService.swift
//  SiteVantage
//
//  Implements the location-confidence hierarchy from spec §4 screen 4:
//  - kCLLocationAccuracyBest fix with horizontal accuracy under ~20m -> HIGH / GPS
//  - a fix obtained but with degraded accuracy (e.g. network-based positioning) -> MEDIUM / WIFI_CELL
//  - no fix within a ~5s timeout -> caller falls back to a manual pin -> DECLARED / MANUAL_PIN
//  No BLE beacon tier exists in this build (no beacon infrastructure to target).
//

import Foundation
import CoreLocation

struct LocationCaptureResult {
    var latitude: Double?
    var longitude: Double?
    var source: LocationSource
    var confidence: LocationConfidence
}

@MainActor
final class LocationCaptureService: NSObject, ObservableObject {
    private let highAccuracyThresholdMeters: Double = 20
    private let fixTimeoutSeconds: TimeInterval = 5
    private let headingTimeoutSeconds: TimeInterval = 2

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var headingContinuation: CheckedContinuation<CLHeading?, Never>?

    @Published private(set) var authorizationDenied = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAuthorization() async -> Bool {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            authorizationDenied = false
            return true
        }
        if status == .denied || status == .restricted {
            authorizationDenied = true
            return false
        }

        manager.requestWhenInUseAuthorization()

        // Poll briefly for the delegate callback to land; CLLocationManager
        // has no async authorization API pre-iOS 18, so this bridges it.
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            let current = manager.authorizationStatus
            if current == .authorizedWhenInUse || current == .authorizedAlways {
                authorizationDenied = false
                return true
            }
            if current == .denied || current == .restricted {
                authorizationDenied = true
                return false
            }
        }
        authorizationDenied = true
        return false
    }

    /// Captures a single location fix, classifying confidence per the
    /// hierarchy above. Returns nil coordinates (source .manualPin,
    /// confidence .declared) if no fix arrives within the timeout — the
    /// caller is expected to present the manual pin picker in that case.
    func captureLocation() async -> LocationCaptureResult {
        let fix = await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
            self.locationContinuation = continuation
            self.manager.requestLocation()

            Task {
                try? await Task.sleep(nanoseconds: UInt64(self.fixTimeoutSeconds * 1_000_000_000))
                if let pending = self.locationContinuation {
                    self.locationContinuation = nil
                    pending.resume(returning: nil)
                }
            }
        }

        guard let fix else {
            return LocationCaptureResult(latitude: nil, longitude: nil, source: .manualPin, confidence: .declared)
        }

        if fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= highAccuracyThresholdMeters {
            return LocationCaptureResult(
                latitude: fix.coordinate.latitude,
                longitude: fix.coordinate.longitude,
                source: .gps,
                confidence: .high
            )
        } else {
            return LocationCaptureResult(
                latitude: fix.coordinate.latitude,
                longitude: fix.coordinate.longitude,
                source: .wifiCell,
                confidence: .medium
            )
        }
    }

    func captureHeading() async -> Double? {
        guard CLLocationManager.headingAvailable() else { return nil }

        let heading = await withCheckedContinuation { (continuation: CheckedContinuation<CLHeading?, Never>) in
            self.headingContinuation = continuation
            self.manager.startUpdatingHeading()

            Task {
                try? await Task.sleep(nanoseconds: UInt64(self.headingTimeoutSeconds * 1_000_000_000))
                if let pending = self.headingContinuation {
                    self.headingContinuation = nil
                    self.manager.stopUpdatingHeading()
                    pending.resume(returning: nil)
                }
            }
        }
        manager.stopUpdatingHeading()

        guard let heading else { return nil }
        return heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
    }
}

extension LocationCaptureService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let continuation = self.locationContinuation else { return }
            self.locationContinuation = nil
            continuation.resume(returning: locations.last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let continuation = self.locationContinuation else { return }
            self.locationContinuation = nil
            continuation.resume(returning: nil)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            guard let continuation = self.headingContinuation else { return }
            self.headingContinuation = nil
            continuation.resume(returning: newHeading)
        }
    }
}
