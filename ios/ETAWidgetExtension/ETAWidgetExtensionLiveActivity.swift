//
//  ETAWidgetExtensionLiveActivity.swift
//  ETAWidgetExtension
//
//  Created by James Welch on 9/10/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ETAWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ETAWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ETAWidgetExtensionAttributes.self) { context in
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

extension ETAWidgetExtensionAttributes {
    fileprivate static var preview: ETAWidgetExtensionAttributes {
        ETAWidgetExtensionAttributes(name: "World")
    }
}

extension ETAWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: ETAWidgetExtensionAttributes.ContentState {
        ETAWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ETAWidgetExtensionAttributes.ContentState {
         ETAWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ETAWidgetExtensionAttributes.preview) {
   ETAWidgetExtensionLiveActivity()
} contentStates: {
    ETAWidgetExtensionAttributes.ContentState.smiley
    ETAWidgetExtensionAttributes.ContentState.starEyes
}
