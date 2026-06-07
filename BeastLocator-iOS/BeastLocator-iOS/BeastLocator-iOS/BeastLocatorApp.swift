import SwiftUI

@main
struct BeastLocatorApp: App {
    @StateObject private var store = DestinationStore.shared
    @StateObject private var locationManager = LocationManager.shared
    
    init() {
        LocalNotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .environmentObject(locationManager)
                .onAppear {
                    locationManager.requestPermissions()
                    locationManager.startUpdating()
                }
        }
    }
}
