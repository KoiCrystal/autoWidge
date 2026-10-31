//
//  ShowWidget.swift
//  ShowWidget
//
//  Created by Jinyu Zhang on 2026/5/8.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    
    // 动态从 App Group 中查询最新的实体数据（包含最新的背景类型、颜色、图片、字号和文本）
    private func fetchInstance(for instance: WidgetDataSourceEntity?) -> WidgetDataSourceEntity? {
        guard let id = instance?.id else { return nil }
        let allInstances = WidgetInstanceQuery().loadAllInstances()
        return allInstances.first(where: { $0.id == id })
    }
    
    private func fetchText(for instance: WidgetDataSourceEntity?) -> String {
        guard let target = fetchInstance(for: instance) else {
            return instance == nil ? "请选择实例" : "实例不存在"
        }
        return target.text ?? "暂无文本"
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(),
                    configuration: ConfigurationAppIntent(),
                    resolvedInstance: nil,
                    text: "占位文本")
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let resolved = fetchInstance(for: configuration.instance)
        return SimpleEntry(date: Date(),
                    configuration: configuration,
                    resolvedInstance: resolved, // 👈 传入查到的最新实例
                    text: fetchText(for: configuration.instance))
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let resolved = fetchInstance(for: configuration.instance)
        let entry = SimpleEntry(
            date: Date(),
            configuration: configuration,
            resolvedInstance: resolved, // 👈 传入查到的最新实例
            text: fetchText(for: configuration.instance)
        )
        return Timeline(entries: [entry], policy: .never)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    var resolvedInstance: WidgetDataSourceEntity? = nil // 👈 加上默认值 = nil，避免其他地方初始化报错
    let text: String
}

struct ShowWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        // 优先使用实时查询到的最新数据，降级使用配置中的数据
        let instance = entry.resolvedInstance ?? entry.configuration.instance
        let fontSize = instance?.fontSize ?? 17
        
        VStack {
            Text(entry.text)
                .font(.system(size: fontSize))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShowWidget: Widget {
    let kind: String = "ShowWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            let instance = entry.resolvedInstance ?? entry.configuration.instance
            let bgType = instance?.backgroundType ?? "system"
            let colorHex = instance?.backgroundColorName ?? "#FFFFFF"
            let customColor = Color(hex: colorHex)
            let uiImage = SharedImageHelper.loadImage(fileName: instance?.backgroundImageName)
            
            ShowWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    switch bgType {
                    case "color":
                        customColor
                    case "image":
                        if let uiImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        } else {
                            Color(.systemBackground)
                        }
                    default:
                        // 跟随系统（适配系统暗黑/浅色模式背景）
                        ContainerRelativeShape().fill(Color(.systemBackground))
                    }
                }
        }
    }
}
