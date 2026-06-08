//
//  BeastLocatorWidgetLiveActivity.swift
//  BeastLocatorWidget
//
//  Created by haru on 2026/06/08.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BeastLocatorWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BeastLocatorWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BeastLocatorWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension BeastLocatorWidgetAttributes {
    fileprivate static var preview: BeastLocatorWidgetAttributes {
        BeastLocatorWidgetAttributes(name: "World")
    }
}

extension BeastLocatorWidgetAttributes.ContentState {
    fileprivate static var smiley: BeastLocatorWidgetAttributes.ContentState {
        BeastLocatorWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BeastLocatorWidgetAttributes.ContentState {
         BeastLocatorWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BeastLocatorWidgetAttributes.preview) {
   BeastLocatorWidgetLiveActivity()
} contentStates: {
    BeastLocatorWidgetAttributes.ContentState.smiley
    BeastLocatorWidgetAttributes.ContentState.starEyes
}
