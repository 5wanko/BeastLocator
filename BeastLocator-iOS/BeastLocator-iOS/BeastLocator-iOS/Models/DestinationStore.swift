import Foundation
import CoreLocation

enum WidgetBearingMode: String {
    case absolute = "absolute"
    case relative = "relative"
}

class DestinationStore: ObservableObject {
    static let shared = DestinationStore()
    private let prefs = UserDefaults.standard
    
    private init() {}
    
    var radiusKm: Double {
        get { prefs.double(forKey: "radius_km") != 0 ? prefs.double(forKey: "radius_km") : 5.0 }
        set { prefs.set(newValue, forKey: "radius_km"); objectWillChange.send() }
    }
    
    var isDebugDestinationOverrideEnabled: Bool {
        get { prefs.bool(forKey: "debug_dest_override_enabled") }
        set { prefs.set(newValue, forKey: "debug_dest_override_enabled"); objectWillChange.send() }
    }
    
    var destinationAnswered: Bool {
        get { prefs.bool(forKey: "dest_answered") }
        set {
            prefs.set(newValue, forKey: "dest_answered")
            if newValue == false {
                prefs.removeObject(forKey: "arrival_destination_name")
            }
            clearLiveUpdateAnchorDistanceMeters()
            objectWillChange.send()
        }
    }
    
    var arrivalDestinationName: String? {
        get { prefs.string(forKey: "arrival_destination_name") }
        set { prefs.set(newValue, forKey: "arrival_destination_name"); objectWillChange.send() }
    }
    
    var isArrivalRearmRequired: Bool {
        get { prefs.bool(forKey: "arrival_rearm_required") }
        set { prefs.set(newValue, forKey: "arrival_rearm_required"); objectWillChange.send() }
    }
    
    var isDebugDistanceOverrideEnabled: Bool {
        get { prefs.bool(forKey: "debug_distance_override_enabled") }
        set { prefs.set(newValue, forKey: "debug_distance_override_enabled"); objectWillChange.send() }
    }
    
    var isLiveUpdateEnabled: Bool {
        get { prefs.object(forKey: "live_update_enabled") != nil ? prefs.bool(forKey: "live_update_enabled") : true }
        set {
            prefs.set(newValue, forKey: "live_update_enabled")
            if !newValue {
                clearLiveUpdateAnchorDistanceMeters()
            }
            objectWillChange.send()
        }
    }
    
    var liveUpdateStartDistanceMeters: Int {
        get {
            let val = prefs.integer(forKey: "live_update_start_distance_meters")
            return val != 0 ? val : 300
        }
        set {
            let clamped = max(200, min(5000, newValue))
            prefs.set(clamped, forKey: "live_update_start_distance_meters")
            objectWillChange.send()
        }
    }
    
    var liveUpdateAnchorDistanceMeters: Float? {
        get {
            if prefs.object(forKey: "live_update_anchor_distance_meters") == nil { return nil }
            return prefs.float(forKey: "live_update_anchor_distance_meters")
        }
        set {
            if let val = newValue {
                prefs.set(max(0, val), forKey: "live_update_anchor_distance_meters")
            } else {
                prefs.removeObject(forKey: "live_update_anchor_distance_meters")
            }
            objectWillChange.send()
        }
    }
    
    var isArrivalNotificationEnabled: Bool {
        get { prefs.object(forKey: "arrival_notification_enabled") != nil ? prefs.bool(forKey: "arrival_notification_enabled") : true }
        set { prefs.set(newValue, forKey: "arrival_notification_enabled"); objectWillChange.send() }
    }
    
    var isBackgroundLocationUpdateEnabled: Bool {
        get { prefs.object(forKey: "widget_background_update_enabled") != nil ? prefs.bool(forKey: "widget_background_update_enabled") : true }
        set { prefs.set(newValue, forKey: "widget_background_update_enabled"); objectWillChange.send() }
    }
    
    var widgetBearingMode: WidgetBearingMode {
        get {
            if let val = prefs.string(forKey: "widget_bearing_mode"), let mode = WidgetBearingMode(rawValue: val) {
                return mode
            }
            return .absolute
        }
        set { prefs.set(newValue.rawValue, forKey: "widget_bearing_mode"); objectWillChange.send() }
    }
    
    var isLegacyCompassModeEnabled: Bool {
        get { prefs.bool(forKey: "legacy_compass_mode_enabled") }
        set { prefs.set(newValue, forKey: "legacy_compass_mode_enabled"); objectWillChange.send() }
    }
    
    var isLandOnlyDestinationEnabled: Bool {
        get { prefs.bool(forKey: "land_only_destination_enabled") }
        set { prefs.set(newValue, forKey: "land_only_destination_enabled"); objectWillChange.send() }
    }
    
    var isDistanceMaskButtonVisible: Bool {
        get { prefs.object(forKey: "distance_mask_button_visible") != nil ? prefs.bool(forKey: "distance_mask_button_visible") : true }
        set {
            prefs.set(newValue, forKey: "distance_mask_button_visible")
            if !newValue {
                isManualDistanceMaskEnabled = false
            }
            objectWillChange.send()
        }
    }
    
    var isManualDistanceMaskEnabled: Bool {
        get { prefs.bool(forKey: "manual_distance_mask_enabled") }
        set { prefs.set(newValue, forKey: "manual_distance_mask_enabled"); objectWillChange.send() }
    }
    
    var isScreenshotWarningEnabled: Bool {
        get { prefs.object(forKey: "screenshot_warning_enabled") != nil ? prefs.bool(forKey: "screenshot_warning_enabled") : true }
        set { prefs.set(newValue, forKey: "screenshot_warning_enabled"); objectWillChange.send() }
    }
    
    var isArrivalSoundEnabled: Bool {
        get { prefs.bool(forKey: "arrival_sound_enabled") }
        set { prefs.set(newValue, forKey: "arrival_sound_enabled"); objectWillChange.send() }
    }
    
    var isDistance114514SoundEnabled: Bool {
        get { prefs.bool(forKey: "distance_114514_sound_enabled") }
        set { prefs.set(newValue, forKey: "distance_114514_sound_enabled"); objectWillChange.send() }
    }
    
    var isDistanceIntervalSoundEnabled: Bool {
        get { prefs.bool(forKey: "distance_interval_sound_enabled") }
        set { prefs.set(newValue, forKey: "distance_interval_sound_enabled"); objectWillChange.send() }
    }
    
    var isCompassSmoothingEnabled: Bool {
        get { prefs.object(forKey: "compass_smoothing_enabled") != nil ? prefs.bool(forKey: "compass_smoothing_enabled") : true }
        set { prefs.set(newValue, forKey: "compass_smoothing_enabled"); objectWillChange.send() }
    }
    
    var distanceIntervalSoundMeters: Int {
        get {
            let val = prefs.integer(forKey: "distance_interval_sound_meters")
            return val != 0 ? val : 1000
        }
        set {
            let clamped = max(100, min(5000, newValue))
            prefs.set(clamped, forKey: "distance_interval_sound_meters")
            objectWillChange.send()
        }
    }
    
    var isSoundForegroundMonitorEnabled: Bool {
        return isArrivalSoundEnabled || isDistance114514SoundEnabled || isDistanceIntervalSoundEnabled
    }
    
    var isBackgroundLocationUpdateForcedBySound: Bool {
        return isSoundForegroundMonitorEnabled
    }
    
    var isBackgroundLocationUpdateActive: Bool {
        return isBackgroundLocationUpdateEnabled || isBackgroundLocationUpdateForcedBySound
    }
    
    var isDebugMenuVisible: Bool {
        get { prefs.bool(forKey: "debug_menu_visible") }
        set { prefs.set(newValue, forKey: "debug_menu_visible"); objectWillChange.send() }
    }
    
    var isStableDebugMenuUnlockEnabled: Bool {
        get { prefs.bool(forKey: "stable_debug_menu_unlock_enabled") }
        set { prefs.set(newValue, forKey: "stable_debug_menu_unlock_enabled"); objectWillChange.send() }
    }
    
    var isNonJapaneseLanguageEnabled: Bool {
        get { prefs.object(forKey: "non_japanese_language_enabled") != nil ? prefs.bool(forKey: "non_japanese_language_enabled") : true }
        set { prefs.set(newValue, forKey: "non_japanese_language_enabled"); objectWillChange.send() }
    }
    
    var welcomeCompleted: Bool {
        get { prefs.bool(forKey: "welcome_completed") }
        set { prefs.set(newValue, forKey: "welcome_completed"); objectWillChange.send() }
    }
    
    func getDestination() -> CLLocationCoordinate2D {
        if isDebugDestinationOverrideEnabled,
           prefs.object(forKey: "debug_dest_override_lat") != nil,
           prefs.object(forKey: "debug_dest_override_lng") != nil {
            return CLLocationCoordinate2D(
                latitude: prefs.double(forKey: "debug_dest_override_lat"),
                longitude: prefs.double(forKey: "debug_dest_override_lng")
            )
        }
        return getDefaultDestination()
    }
    
    func setDebugDestinationOverride(_ destination: CLLocationCoordinate2D) {
        prefs.set(destination.latitude, forKey: "debug_dest_override_lat")
        prefs.set(destination.longitude, forKey: "debug_dest_override_lng")
        prefs.set(true, forKey: "debug_dest_override_enabled")
        prefs.set(false, forKey: "dest_answered")
        prefs.set(false, forKey: "arrival_rearm_required")
        prefs.removeObject(forKey: "live_update_anchor_distance_meters")
        prefs.removeObject(forKey: "arrival_destination_name")
        objectWillChange.send()
    }
    
    func clearDebugDestinationOverride() {
        prefs.removeObject(forKey: "debug_dest_override_lat")
        prefs.removeObject(forKey: "debug_dest_override_lng")
        prefs.set(false, forKey: "debug_dest_override_enabled")
        prefs.removeObject(forKey: "dest_answered")
        prefs.set(false, forKey: "arrival_rearm_required")
        prefs.removeObject(forKey: "live_update_anchor_distance_meters")
        prefs.removeObject(forKey: "arrival_destination_name")
        objectWillChange.send()
    }
    
    func getDefaultDestination() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 35.665554, longitude: 139.669717)
    }
    
    func setLastKnownLocation(_ lat: Double, _ lng: Double) {
        prefs.set(lat, forKey: "last_lat")
        prefs.set(lng, forKey: "last_lng")
    }
    
    func setLastKnownLocationFromSystem(_ lat: Double, _ lng: Double) -> Bool {
        if isDebugDistanceOverrideEnabled {
            return false
        }
        setLastKnownLocation(lat, lng)
        return true
    }
    
    func clearLastKnownLocation() {
        prefs.removeObject(forKey: "last_lat")
        prefs.removeObject(forKey: "last_lng")
        prefs.removeObject(forKey: "last_heading")
    }
    
    func setDebugDistanceOverrideLocation(_ lat: Double, _ lng: Double) {
        prefs.set(lat, forKey: "last_lat")
        prefs.set(lng, forKey: "last_lng")
        prefs.set(true, forKey: "debug_distance_override_enabled")
        objectWillChange.send()
    }
    
    func clearDebugDistanceOverride() {
        prefs.removeObject(forKey: "last_lat")
        prefs.removeObject(forKey: "last_lng")
        prefs.removeObject(forKey: "last_heading")
        prefs.set(false, forKey: "debug_distance_override_enabled")
        objectWillChange.send()
    }
    
    func setLastKnownHeading(_ headingDegrees: Float) {
        prefs.set(headingDegrees, forKey: "last_heading")
    }
    
    func getLastKnownHeading() -> Float? {
        if prefs.object(forKey: "last_heading") == nil { return nil }
        return prefs.float(forKey: "last_heading")
    }
    
    func clearLiveUpdateAnchorDistanceMeters() {
        prefs.removeObject(forKey: "live_update_anchor_distance_meters")
    }
    
    func getLastKnownLocation() -> CLLocationCoordinate2D? {
        if prefs.object(forKey: "last_lat") == nil || prefs.object(forKey: "last_lng") == nil { return nil }
        return CLLocationCoordinate2D(
            latitude: prefs.double(forKey: "last_lat"),
            longitude: prefs.double(forKey: "last_lng")
        )
    }
}
