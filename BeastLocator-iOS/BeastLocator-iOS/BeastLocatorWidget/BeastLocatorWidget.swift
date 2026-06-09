import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            distanceText: "114.514 km",
            directionText: "方角: S",
            rotationDegrees: 180.0,
            waitingLocation: false,
            destinationAnswered: false,
            arrivalName: "",
            arrivalCoords: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = readCurrentState()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = readCurrentState()
        // We only reload when the main app tells us to, so return a single entry with infinite expiration (.never)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
    
    private func readCurrentState() -> SimpleEntry {
        let prefs = UserDefaults(suiteName: "group.jp.linkserver.beastlocator") ?? .standard
        let waiting = prefs.bool(forKey: "widget_waiting_location")
        let answered = prefs.bool(forKey: "widget_destination_answered")
        
        let dist = prefs.string(forKey: "widget_distance_text") ?? (waiting ? "現在地を取得中..." : "--")
        let dir = prefs.string(forKey: "widget_direction_text") ?? ""
        let rot = prefs.double(forKey: "widget_rotation_degrees")
        let arrivalName = prefs.string(forKey: "widget_arrival_destination_name") ?? ""
        let arrivalCoords = prefs.string(forKey: "widget_arrival_coords_text") ?? ""
        
        return SimpleEntry(
            date: Date(),
            distanceText: dist,
            directionText: dir,
            rotationDegrees: rot,
            waitingLocation: waiting,
            destinationAnswered: answered,
            arrivalName: arrivalName,
            arrivalCoords: arrivalCoords
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let distanceText: String
    let directionText: String
    let rotationDegrees: Double
    let waitingLocation: Bool
    let destinationAnswered: Bool
    let arrivalName: String
    let arrivalCoords: String
}

struct BeastLocatorWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Dark blue background matching the app theme
            Color(red: 10/255, green: 14/255, blue: 30/255)

            if entry.destinationAnswered {
                // Arrival UI
                VStack(spacing: 8) {
                    Text("🎉")
                        .font(.title)
                    
                    Text("こ↑こ↓")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(entry.arrivalName.isEmpty ? "到着地" : entry.arrivalName)
                        .font(.system(.subheadline, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if family != .systemSmall {
                        Text(entry.arrivalCoords)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
            } else {
                // Navigation UI
                VStack(spacing: family == .systemSmall ? 4 : 12) {
                    // Compass Image (Rotating Arrow)
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.2), .blue.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                            .frame(width: family == .systemSmall ? 65 : 85, height: family == .systemSmall ? 65 : 85)
                        
                        Image("yjsnpi")
                            .resizable()
                            .scaledToFit()
                            .frame(width: family == .systemSmall ? 55 : 75, height: family == .systemSmall ? 55 : 75)
                            .rotationEffect(Angle(degrees: entry.waitingLocation ? 0.0 : entry.rotationDegrees))
                    }
                    
                    VStack(spacing: 2) {
                        Text(entry.distanceText)
                            .font(.system(family == .systemSmall ? .headline : .title2, design: .default))
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        if !entry.directionText.isEmpty {
                            Text(entry.directionText)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(8)
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 10/255, green: 14/255, blue: 30/255)
        }
    }
}

struct BeastLocatorWidget: Widget {
    let kind: String = "BeastLocatorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BeastLocatorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("BeastLocator")
        .description("目的地までの方角と距離を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
