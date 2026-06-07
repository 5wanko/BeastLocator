import SwiftUI
import CoreLocation

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store = DestinationStore.shared
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var showingDebugReset = false
    @State private var showingEditCoordinates = false
    @State private var showingEditDistance = false
    @State private var tempLat = ""
    @State private var tempLng = ""
    @State private var tempDistance = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("notification_title_group")) {
                    Toggle("arrival_notification_toggle", isOn: $store.isArrivalNotificationEnabled)
                    Toggle("live_update_toggle", isOn: $store.isLiveUpdateEnabled)
                    
                    if store.isLiveUpdateEnabled {
                        VStack(alignment: .leading) {
                            Text("live_update_start_distance_title")
                            HStack {
                                Slider(value: Binding(
                                    get: { Double(store.liveUpdateStartDistanceMeters) },
                                    set: { store.liveUpdateStartDistanceMeters = Int($0) }
                                ), in: 200...5000, step: 100)
                                Text(formatLiveUpdateLabel())
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }
                
                Section(header: Text("privacy_guard_title")) {
                    Toggle("screenshot_mask_toggle", isOn: $store.isDistanceMaskButtonVisible)
                    Toggle("screenshot_warning_toggle", isOn: $store.isScreenshotWarningEnabled)
                }
                
                Section(header: Text("compass_settings_title")) {
                    Toggle("compass_legacy_mode_title", isOn: $store.isLegacyCompassModeEnabled)
                }
                
                Section(header: Text("background_location_section_title")) {
                    Toggle("background_location_update_toggle", isOn: Binding(
                        get: { store.isBackgroundLocationUpdateEnabled },
                        set: { isChecked in
                            if isChecked {
                                triggerBatteryWarning {
                                    store.isBackgroundLocationUpdateEnabled = true
                                    locationManager.updateBackgroundModes()
                                }
                            } else {
                                store.isBackgroundLocationUpdateEnabled = false
                                locationManager.updateBackgroundModes()
                            }
                        }
                    ))
                    .disabled(store.isBackgroundLocationUpdateForcedBySound)
                    
                    Text(store.isBackgroundLocationUpdateForcedBySound ? "background_location_update_help_forced" : "background_location_update_help")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section {
                    NavigationLink(destination: ExperimentalSettingsView()) {
                        Text("experimental_settings_title")
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        Text("about_screen_title")
                    }
                }
                
                // Debug Menu Toggle
                Section {
                    Button(action: {
                        store.isDebugMenuVisible = !store.isDebugMenuVisible
                    }) {
                        Text(store.isDebugMenuVisible ? "debug_toggle_hide" : "debug_toggle_show")
                    }
                }
                
                // Debug Options
                if store.isDebugMenuVisible {
                    Section(header: Text("debug_section_title")) {
                        // Current Destination Coordinates
                        let dest = store.getDestination()
                        let label = store.isDebugDestinationOverrideEnabled ? "debug_destination_mode_override" : "debug_destination_mode_default"
                        let latStr = String(format: "%.6f", dest.latitude)
                        let lngStr = String(format: "%.6f", dest.longitude)
                        Text(String(format: NSLocalizedString(label, comment: ""), latStr, lngStr))
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Button("debug_destination_edit_button") {
                            tempLat = latStr
                            tempLng = lngStr
                            showingEditCoordinates = true
                        }
                        
                        Button("debug_destination_reset_button") {
                            store.clearDebugDestinationOverride()
                            store.destinationAnswered = false
                            let target = store.getDestination()
                            LocalNotificationManager.shared.cancelApproachProgress()
                            locationManager.processLocationUpdate(current: locationManager.currentLocation ?? target)
                        }
                        
                        Button("debug_show_reached") {
                            let destination = store.getDestination()
                            store.destinationAnswered = true
                            store.arrivalDestinationName = String(format: "%.6f, %.6f", destination.latitude, destination.longitude)
                            LocalNotificationManager.shared.cancelApproachProgress()
                            
                            if store.isArrivalSoundEnabled {
                                AudioPlayer.shared.playSound(resource: "arrival_0km.wav", priority: 2)
                            }
                            
                            locationManager.resolveArrivalName(destination: destination)
                        }
                        
                        Button("debug_start_approach") {
                            guard let current = locationManager.currentLocation else { return }
                            let destination = store.getDestination()
                            let distance = GeoUtils.shared.distanceMeters(from: current, to: destination)
                            if distance > 50 {
                                store.liveUpdateAnchorDistanceMeters = Float(distance)
                                LocalNotificationManager.shared.showApproachProgress(remainingMeters: distance, progressPercent: 0)
                            }
                        }
                        
                        Button("debug_set_distance_button") {
                            showingEditDistance = true
                        }
                        
                        Button("debug_reset_distance_button") {
                            store.clearDebugDistanceOverride()
                        }
                    }
                }
            }
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("back") {
                        dismiss()
                    }
                }
            }
            .alert(NSLocalizedString("debug_destination_edit_title", comment: ""), isPresented: $showingEditCoordinates) {
                TextField("Latitude", text: $tempLat)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $tempLng)
                    .keyboardType(.decimalPad)
                Button("OK") {
                    if let lat = Double(tempLat), let lng = Double(tempLng),
                       lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0 {
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        store.setDebugDestinationOverride(coordinate)
                        LocalNotificationManager.shared.cancelApproachProgress()
                        locationManager.processLocationUpdate(current: locationManager.currentLocation ?? coordinate)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(NSLocalizedString("debug_destination_edit_message", comment: ""))
            }
            .alert(NSLocalizedString("background_location_update_warning_title", comment: ""), isPresented: $showingBatteryWarning) {
                Button("OK") {
                    batteryWarningAction?()
                }
                Button("Cancel", role: .cancel) {
                    store.isBackgroundLocationUpdateEnabled = false
                    locationManager.updateBackgroundModes()
                }
            } message: {
                Text(NSLocalizedString("background_location_update_warning_message", comment: ""))
            }
            .sheet(isPresented: $showingEditDistance) {
                editDistanceSheet()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func formatLiveUpdateLabel() -> String {
        let meters = store.liveUpdateStartDistanceMeters
        if meters >= 1000 {
            return String(format: "%.1f km", Double(meters) / 1000.0)
        } else {
            return "\(meters) m"
        }
    }
    
    @State private var showingBatteryWarning = false
    @State private var batteryWarningAction: (() -> Void)?
    
    private func triggerBatteryWarning(onConfirm: @escaping () -> Void) {
        batteryWarningAction = onConfirm
        showingBatteryWarning = true
    }
    

    
    private func editDistanceSheet() -> some View {
        VStack(spacing: 20) {
            Text("debug_set_distance_title")
                .font(.headline)
            Text("debug_set_distance_message")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            TextField("debug_set_distance_hint", text: $tempDistance)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            HStack {
                Button("Cancel") {
                    showingEditDistance = false
                }
                .padding()
                
                Spacer()
                
                Button("OK") {
                    if let dist = Double(tempDistance), dist >= 0 && dist <= 20000000.0 {
                        let destination = store.getDestination()
                        let mockCurrent = buildMockCurrentLocation(destination: destination, distanceMeters: dist)
                        store.setDebugDistanceOverrideLocation(mockCurrent.latitude, mockCurrent.longitude)
                        
                        // Always reset arrival status to allow re-testing of arrival sounds and notifications
                        store.isArrivalRearmRequired = false
                        store.destinationAnswered = false
                        
                        locationManager.processLocationUpdate(current: mockCurrent)
                        showingEditDistance = false
                    }
                }
                .padding()
                .foregroundColor(.blue)
            }
        }
        .padding()
    }
    
    private func buildMockCurrentLocation(destination: CLLocationCoordinate2D, distanceMeters: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0
        let angularDistance = distanceMeters / earthRadius
        let bearing = 180.0 * Double.pi / 180.0
        let lat1 = destination.latitude * Double.pi / 180.0
        let lon1 = destination.longitude * Double.pi / 180.0
        
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(latitude: lat2 * 180.0 / .pi, longitude: lon2 * 180.0 / .pi)
    }
}
