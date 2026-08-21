//
//  ShowWidget.swift
//  ShowWidget
//
//  Created by Jinyu Zhang on 2026/5/8.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    private func fetchText() -> String {
        let sharedDefaults = UserDefaults(suiteName: "group.autowidget.app2widge")
        return sharedDefaults?.string(forKey: "widgetText") ?? "暂无文本"
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), text: fetchText())
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration, text: fetchText())
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(
            date: Date(),
            configuration: configuration,
            text: fetchText()
        )
        
        return Timeline(
            entries: [entry],
            policy: .never
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let text: String
}

struct ShowWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack {
            Text(entry.text)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
    }
}

struct ShowWidget: Widget {
    let kind: String = "ShowWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            ShowWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    ShowWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley, text: "预览文本")
    SimpleEntry(date: .now, configuration: .starEyes, text: "快捷指令结果示例")
}
