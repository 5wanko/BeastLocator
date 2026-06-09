import ActivityKit
import WidgetKit
import SwiftUI

struct BeastLocatorWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var distanceText: String
        var directionText: String
    }

    var name: String
}

struct BeastLocatorWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BeastLocatorWidgetAttributes.self) { context in
            // Lock screen/banner UI
            HStack(spacing: 16) {
                Image("yjsnpi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.distanceText)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    
                    if !context.state.directionText.isEmpty {
                        Text(context.state.directionText)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color(red: 10/255, green: 14/255, blue: 30/255))
            .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Image("yjsnpi")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .cornerRadius(6)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.distanceText)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.state.directionText.isEmpty {
                        Text(context.state.directionText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            } compactLeading: {
                Image("yjsnpi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .cornerRadius(4)
            } compactTrailing: {
                Text(context.state.distanceText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            } minimal: {
                Image("yjsnpi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .cornerRadius(4)
            }
            .keylineTint(Color.cyan)
        }
    }
}
