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
        let allInstances = WidgetInstanceQuery().loadAllInstances()
        if let targetInstance = allInstances.first(where: { $0.id == id }) {
            return targetInstance.text ?? "暂无文本"
        }
        return "实例不存在"
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
        let instance = entry.configuration.instance
        let fontSize = instance?.fontSize ?? 17
        let colorHex = instance?.backgroundColorName ?? "#FFFFFF"
        
        VStack {
            Text(entry.text)
                .font(.system(size: fontSize))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
        //.background(customColor)
    }
}

struct ShowWidget: Widget {
    let kind: String = "ShowWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            let instance = entry.configuration.instance
            let colorHex = instance?.backgroundColorName ?? "#FFFFFF"
            let customColor = Color(hex: colorHex) // 解析调色盘颜色
            
            ShowWidgetEntryView(entry: entry)
                .containerBackground(customColor, for: .widget)
        }
    }
}
