//
//  ShowWidgetLiveActivity.swift
//  ShowWidget
//
//  Created by Jinyu Zhang on 2026/5/8.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ShowWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ShowWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShowWidgetAttributes.self) { context in
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

extension ShowWidgetAttributes {
    fileprivate static var preview: ShowWidgetAttributes {
        ShowWidgetAttributes(name: "World")
    }
}

extension ShowWidgetAttributes.ContentState {
    fileprivate static var smiley: ShowWidgetAttributes.ContentState {
        ShowWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ShowWidgetAttributes.ContentState {
         ShowWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ShowWidgetAttributes.preview) {
   ShowWidgetLiveActivity()
} contentStates: {
    ShowWidgetAttributes.ContentState.smiley
    ShowWidgetAttributes.ContentState.starEyes
}
