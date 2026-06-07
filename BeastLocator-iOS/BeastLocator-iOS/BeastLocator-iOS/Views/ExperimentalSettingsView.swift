import SwiftUI

struct ExperimentalSettingsView: View {
    @ObservedObject var store = DestinationStore.shared
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        Form {
            Section(header: Text("sound_settings_title"), footer: Text("sound_settings_help")) {
                Toggle("arrival_sound_toggle", isOn: Binding(
                    get: { store.isArrivalSoundEnabled },
                    set: {
                        store.isArrivalSoundEnabled = $0
                        locationManager.updateBackgroundModes()
                    }
                ))
                Text("arrival_sound_toggle_help")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Toggle("distance_114514_sound_toggle", isOn: Binding(
                    get: { store.isDistance114514SoundEnabled },
                    set: {
                        store.isDistance114514SoundEnabled = $0
                        locationManager.updateBackgroundModes()
                    }
                ))
                Text("distance_114514_sound_toggle_help")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button("distance_114514_link_button") {
                    if let url = URL(string: "https://www.nicovideo.jp/watch/sm33266722") {
                        UIApplication.shared.open(url)
                    }
                }
                
                Toggle("distance_interval_sound_toggle", isOn: Binding(
                    get: { store.isDistanceIntervalSoundEnabled },
                    set: {
                        store.isDistanceIntervalSoundEnabled = $0
                        locationManager.updateBackgroundModes()
                    }
                ))
                Text("distance_interval_sound_toggle_help")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if store.isDistanceIntervalSoundEnabled {
                    VStack(alignment: .leading) {
                        Text("distance_interval_sound_distance_title")
                        HStack {
                            Slider(value: Binding(
                                get: { Double(store.distanceIntervalSoundMeters) },
                                set: { store.distanceIntervalSoundMeters = Int($0) }
                            ), in: 100...5000, step: 100)
                            Text(formatIntervalLabel())
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
            
            Section(header: Text("experimental_compass_title")) {
                Toggle("experimental_compass_smoothing_toggle", isOn: $store.isCompassSmoothingEnabled)
                Text("experimental_compass_smoothing_toggle_help")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Section(header: Text("experimental_language_title")) {
                Toggle("experimental_language_toggle", isOn: $store.isNonJapaneseLanguageEnabled)
                Text("experimental_language_toggle_help")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button("experimental_language_open_settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("experimental_settings_screen_title")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatIntervalLabel() -> String {
        let meters = store.distanceIntervalSoundMeters
        if meters >= 1000 {
            return String(format: "%.1f km", Double(meters) / 1000.0)
        } else {
            return "\(meters) m"
        }
    }
}
