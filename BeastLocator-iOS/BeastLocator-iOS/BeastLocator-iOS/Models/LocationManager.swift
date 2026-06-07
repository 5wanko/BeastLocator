import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private let store = DestinationStore.shared
    
    @Published var headingDegrees: Double = 0.0
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var systemLocationServiceDisabled = false
    @Published var waitingForLocation = true
    
    private var hasHeadingSample = false
    private var distance114514SoundPlayed = false
    private var lastIntervalBucket: Int?
    private var previousDistanceMeters: Double?
    
    private let arrivalThresholdMeters: Double = 50.0
    private let distance114514Meters: Double = 114514.0
    private let distanceMatchToleranceMeters: Double = 80.0
    private var isResolvingArrivalName = false
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.headingFilter = 0.5
        
        // Restore last known location on startup (including debug overrides)
        if let lastLocation = store.getLastKnownLocation() {
            self.currentLocation = lastLocation
            self.waitingForLocation = false
        } else if store.isDebugDistanceOverrideEnabled {
            self.waitingForLocation = false
        }
    }
    
    func requestPermissions() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdating() {
        checkLocationServices()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        updateBackgroundModes()
    }
    
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    func updateBackgroundModes() {
        let forced = store.isBackgroundLocationUpdateActive
        locationManager.allowsBackgroundLocationUpdates = forced
        locationManager.pausesLocationUpdatesAutomatically = false
        if #available(iOS 11.0, *) {
            locationManager.showsBackgroundLocationIndicator = forced
        }
    }
    
    private func checkLocationServices() {
        systemLocationServiceDisabled = !CLLocationManager.locationServicesEnabled()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationServices()
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            waitingForLocation = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        waitingForLocation = false
        
        if store.isDebugDistanceOverrideEnabled { return }
        
        let current = location.coordinate
        currentLocation = current
        _ = store.setLastKnownLocationFromSystem(current.latitude, current.longitude)
        
        if location.course >= 0 {
            store.setLastKnownHeading(Float(location.course))
        }
        
        processLocationUpdate(current: current)
    }
    
    func processLocationUpdate(current: CLLocationCoordinate2D) {
        currentLocation = current
        waitingForLocation = false
        
        let destination = store.getDestination()
        let distance = GeoUtils.shared.distanceMeters(from: current, to: destination)
        
        if store.isArrivalRearmRequired && distance > arrivalThresholdMeters {
            store.isArrivalRearmRequired = false
        }
        
        handleArrivalByDistance(destination: destination, distanceMeters: distance)
        updateApproachLiveUpdate(distanceMeters: distance)
        handleSoundTriggers(distanceMeters: distance)
        
        previousDistanceMeters = distance
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.magneticHeading >= 0 ? newHeading.magneticHeading : newHeading.trueHeading
        guard heading >= 0 else { return }
        
        let targetHeading = heading
        if store.isCompassSmoothingEnabled && hasHeadingSample {
            headingDegrees = smoothAngle(current: headingDegrees, target: targetHeading, alpha: 0.15)
        } else {
            hasHeadingSample = true
            headingDegrees = targetHeading
        }
    }
    
    private func smoothAngle(current: Double, target: Double, alpha: Double) -> Double {
        let delta = normalizeRotation(target - current)
        return normalizeTo360(current + (delta * alpha))
    }
    
    private func normalizeRotation(_ value: Double) -> Double {
        var normalized = value.truncatingRemainder(dividingBy: 360.0)
        if normalized > 180.0 { normalized -= 360.0 }
        if normalized < -180.0 { normalized += 360.0 }
        return normalized
    }
    
    private func normalizeTo360(_ value: Double) -> Double {
        let mod = value.truncatingRemainder(dividingBy: 360.0)
        return mod < 0 ? mod + 360.0 : mod
    }
    
    private func handleArrivalByDistance(destination: CLLocationCoordinate2D, distanceMeters: Double) {
        guard !store.destinationAnswered else { return }
        guard !store.isArrivalRearmRequired else { return }
        guard distanceMeters <= arrivalThresholdMeters else { return }
        
        if store.isArrivalSoundEnabled {
            AudioPlayer.shared.playSound(resource: "arrival_0km.wav", priority: 2)
        }
        
        store.destinationAnswered = true
        store.arrivalDestinationName = String(format: "%.6f, %.6f", destination.latitude, destination.longitude)
        LocalNotificationManager.shared.cancelApproachProgress()
        
        let coordsStr = String(format: NSLocalizedString("notification_body", comment: ""), String(format: "%.6f, %.6f", destination.latitude, destination.longitude))
        LocalNotificationManager.shared.showDestinationReached(message: coordsStr, customSoundName: "arrival_0km.wav")
        
        resolveArrivalName(destination: destination)
    }
    
    func resolveArrivalName(destination: CLLocationCoordinate2D) {
        guard !isResolvingArrivalName else { return }
        isResolvingArrivalName = true
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            self.isResolvingArrivalName = false
            
            guard self.store.destinationAnswered else { return }
            
            let resolved: String
            if let placemark = placemarks?.first, let name = placemark.name {
                resolved = name
            } else {
                resolved = String(format: "%.6f, %.6f", destination.latitude, destination.longitude)
            }
            
            self.store.arrivalDestinationName = resolved
            let bodyStr = String(format: NSLocalizedString("notification_body", comment: ""), resolved)
            LocalNotificationManager.shared.showDestinationReached(message: bodyStr, customSoundName: "arrival_0km.wav")
        }
    }
    
    private func updateApproachLiveUpdate(distanceMeters: Double) {
        guard store.isLiveUpdateEnabled && !store.destinationAnswered else {
            LocalNotificationManager.shared.cancelApproachProgress()
            store.clearLiveUpdateAnchorDistanceMeters()
            return
        }
        
        let startDistance = Double(store.liveUpdateStartDistanceMeters)
        if distanceMeters > startDistance || distanceMeters <= arrivalThresholdMeters {
            LocalNotificationManager.shared.cancelApproachProgress()
            store.clearLiveUpdateAnchorDistanceMeters()
            return
        }
        
        let anchorDistance = Double(store.liveUpdateAnchorDistanceMeters ?? Float(distanceMeters))
        if store.liveUpdateAnchorDistanceMeters == nil {
            store.liveUpdateAnchorDistanceMeters = Float(distanceMeters)
        }
        
        let span = max(1.0, anchorDistance - arrivalThresholdMeters)
        let progress = Int(((anchorDistance - distanceMeters) / span) * 100.0)
        let clampedProgress = max(0, min(100, progress))
        
        LocalNotificationManager.shared.showApproachProgress(remainingMeters: distanceMeters, progressPercent: clampedProgress)
    }
    
    private func handleSoundTriggers(distanceMeters: Double) {
        if store.isDistance114514SoundEnabled &&
           !distance114514SoundPlayed &&
           entered114514Range(previousDistanceMeters: previousDistanceMeters, currentDistanceMeters: distanceMeters) {
            distance114514SoundPlayed = true
            AudioPlayer.shared.playSound(resource: "distance_114514km.mp3", priority: 3)
        }
        
        if store.isDistanceIntervalSoundEnabled {
            handleIntervalDistanceSound(distanceMeters: distanceMeters)
        } else {
            lastIntervalBucket = nil
        }
    }
    
    private func entered114514Range(previousDistanceMeters: Double?, currentDistanceMeters: Double) -> Bool {
        guard let prev = previousDistanceMeters else { return false }
        let threshold = distance114514Meters + distanceMatchToleranceMeters
        return prev > threshold && currentDistanceMeters <= threshold
    }
    
    private func handleIntervalDistanceSound(distanceMeters: Double) {
        guard !store.destinationAnswered else {
            lastIntervalBucket = nil
            return
        }
        
        let interval = Double(store.distanceIntervalSoundMeters)
        let currentBucket = Int(distanceMeters / interval)
        let previousBucket = lastIntervalBucket
        lastIntervalBucket = currentBucket
        
        guard let prev = previousBucket else { return }
        
        if currentBucket < prev {
            AudioPlayer.shared.playSound(resource: "distance_interval_kankaku.mp3", priority: 1)
        }
    }
}
