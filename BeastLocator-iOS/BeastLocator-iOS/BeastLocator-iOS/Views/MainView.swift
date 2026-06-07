import SwiftUI
import CoreLocation

struct MainView: View {
    @EnvironmentObject var store: DestinationStore
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingSettings = false
    @State private var showingWelcome = false
    
    // Constant offsets & constants matching Android
    private let arrowImageForwardOffsetDegrees: Double = 45.0
    private let arrivalThresholdMeters: Double = 50.0
    private let distanceMaskStepKm: Int = 100
    
    var body: some View {
        ZStack {
                // Elegant Dark Mode Theme
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.09, blue: 0.15), Color(red: 0.03, green: 0.04, blue: 0.07)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    // Top Bar (Buttons)
                    HStack {
                        Spacer()
                        
                        if store.isDistanceMaskButtonVisible {
                            Button(action: {
                                store.isManualDistanceMaskEnabled = !store.isManualDistanceMaskEnabled
                            }) {
                                Image(systemName: store.isManualDistanceMaskEnabled ? "eye.slash.fill" : "eye.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .padding(.trailing, 8)
                        }
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    if store.destinationAnswered {
                        // Arrival Card View
                        VStack(spacing: 24) {
                            Text("arrival_title")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text(store.arrivalDestinationName ?? NSLocalizedString("arrival_name_placeholder", comment: ""))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                
                                let dest = store.getDestination()
                                Text(String(format: NSLocalizedString("arrival_coords_format", comment: ""), dest.latitude, dest.longitude))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            
                            Button(action: {
                                resetDestinationProgress()
                            }) {
                                Text("create_next_destination")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 24)
                                    .background(Color.orange)
                                    .cornerRadius(12)
                                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(24)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Main Compass and Readout
                        VStack(spacing: 30) {
                            // Compass Arrow Image (yjsnpi)
                            ZStack {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.cyan.opacity(0.2), .blue.opacity(0.1)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 4
                                    )
                                    .frame(width: 240, height: 240)
                                
                                if locationManager.waitingForLocation {
                                    // Spinning animation
                                    Image("yjsnpi")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200, height: 200)
                                        .rotationEffect(Angle(degrees: animateLoading ? 360 : 0))
                                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: animateLoading)
                                        .onAppear {
                                            animateLoading = true
                                        }
                                        .onDisappear {
                                            animateLoading = false
                                        }
                                } else {
                                    // Pointing to destination
                                    let rotationAngle = calculateRotationAngle()
                                    Image("yjsnpi")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200, height: 200)
                                        .rotationEffect(Angle(degrees: rotationAngle))
                                        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: rotationAngle)
                                }
                            }
                            
                            VStack(spacing: 12) {
                                // Distance View
                                Text(getDistanceText())
                                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                // Direction text
                                Text(getDirectionText())
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                if showingToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingWelcome) {
            WelcomeView()
        }
        .onAppear {
            if !store.welcomeCompleted {
                showingWelcome = true
            }
            // Register Screenshot warning observer
            NotificationCenter.default.addObserver(
                forName: UIApplication.userDidTakeScreenshotNotification,
                object: nil,
                queue: .main
            ) { _ in
                if store.isScreenshotWarningEnabled {
                    triggerScreenshotWarning()
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        }
    }
    
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var animateLoading = false
    
    private func triggerScreenshotWarning() {
        toastMessage = NSLocalizedString("screenshot_privacy_warning", comment: "")
        withAnimation {
            showingToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                showingToast = false
            }
        }
    }
    
    private func calculateRotationAngle() -> Double {
        guard let current = locationManager.currentLocation else { return 0 }
        let target = store.getDestination()
        
        let bearing = GeoUtils.shared.bearingDegrees(from: current, to: target)
        let heading = locationManager.headingDegrees
        
        var relative = bearing - heading - arrowImageForwardOffsetDegrees
        relative = relative.truncatingRemainder(dividingBy: 360.0)
        if relative > 180 { relative -= 360 }
        if relative < -180 { relative += 360 }
        return relative
    }
    
    private func getDistanceText() -> String {
        if locationManager.waitingForLocation {
            return NSLocalizedString("waiting_location", comment: "")
        }
        
        guard let current = locationManager.currentLocation else {
            return NSLocalizedString("waiting_location", comment: "")
        }
        
        let target = store.getDestination()
        let distance = GeoUtils.shared.distanceMeters(from: current, to: target)
        
        if !store.isManualDistanceMaskEnabled {
            return GeoUtils.shared.formatDistance(distance)
        }
        
        let distanceKm = distance / 1000.0
        let maskedDistanceKm: Int
        if distanceKm <= Double(distanceMaskStepKm) {
            maskedDistanceKm = distanceMaskStepKm
        } else {
            maskedDistanceKm = Int(ceil(distanceKm / Double(distanceMaskStepKm))) * distanceMaskStepKm
        }
        return String(format: NSLocalizedString("distance_masked_format_km", comment: ""), maskedDistanceKm)
    }
    
    private func getDirectionText() -> String {
        if locationManager.waitingForLocation { return "" }
        guard let current = locationManager.currentLocation else { return "" }
        
        if store.isManualDistanceMaskEnabled {
            return NSLocalizedString("direction_placeholder", comment: "")
        }
        
        let target = store.getDestination()
        let bearing = GeoUtils.shared.bearingDegrees(from: current, to: target)
        let cardinal = GeoUtils.shared.cardinalFromBearing(bearing)
        
        return String(format: NSLocalizedString("direction_label", comment: ""), cardinal)
    }
    
    private func resetDestinationProgress() {
        let fixedDestination = store.getDestination()
        store.destinationAnswered = false
        store.isArrivalRearmRequired = true
        LocalNotificationManager.shared.cancelApproachProgress()
        locationManager.processLocationUpdate(current: locationManager.currentLocation ?? fixedDestination)
    }
}
