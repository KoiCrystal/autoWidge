//
//  ShowWidget.swift
//  ShowWidget
//
//  Created by Jinyu Zhang on 2026/5/8.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    private func fetchText(for instance: WidgetDataSourceEntity?) -> String {
        guard let id = instance?.id else { return "请选择实例" }
        let defaults = UserDefaults(suiteName: "group.autowidget.app2widget")
        return defaults?.string(forKey: "widgetText_\(id)") ?? "暂无文本"
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(),
                    configuration: ConfigurationAppIntent(),
                    text: "占位文本")
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(),
                    configuration: configuration,
                    text: fetchText(for: configuration.instance))
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = SimpleEntry(
            date: Date(),
            configuration: configuration,
            text: fetchText(for: configuration.instance)
        )
        return Timeline(entries: [entry], policy: .never)
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
