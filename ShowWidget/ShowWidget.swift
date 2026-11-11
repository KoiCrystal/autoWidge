//
//  ShowWidget.swift
//  ShowWidget
//
//  Created by Jinyu Zhang on 2026/5/8.
//

import WidgetKit
import SwiftUI
import UIKit

struct Provider: AppIntentTimelineProvider {
    
    init() {
        CustomFontManager.shared.registerAllFonts()
    }
    
    // 动态从 App Group 中查询最新的实体数据
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
                           resolvedInstance: resolved,
                           text: fetchText(for: configuration.instance))
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let resolved = fetchInstance(for: configuration.instance)
        let entry = SimpleEntry(
            date: Date(),
            configuration: configuration,
            resolvedInstance: resolved, 
            text: fetchText(for: configuration.instance)
        )
        return Timeline(entries: [entry], policy: .never)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    var resolvedInstance: WidgetDataSourceEntity? = nil
    let text: String
}

struct ShowWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetRenderingMode) private var renderingMode
    
    var body: some View {
        let instance = entry.resolvedInstance ?? entry.configuration.instance
        let fontSize = instance?.fontSize ?? 17
        let fontWeightValue = instance?.fontWidth ?? 0.4
        let fontStyle = instance?.fontStyle ?? "system"
        let customFontName = instance?.customFontName
        let textColorType = instance?.textColorType ?? (instance?.textColorName != nil ? "color" : "system")
        let textColorHex = instance?.textColorName ?? "#ffffffff"
        let customTextColor = Color(hex: textColorHex)
        let isGlass = instance?.isLiquidGlass ?? false
        
        let baseColor: Color = (textColorType == "color") ? customTextColor : .primary
        
        let fontDesign: Font.Design = {
            switch fontStyle {
            case "monospaced": return .monospaced
            case "serif":      return .serif
            case "rounded":    return .rounded
            default:           return .default
            }
        }()
        
        let swiftUIWeight: Font.Weight = {
            if fontWeightValue < -0.4 { return .ultraLight }
            if fontWeightValue < -0.2 { return .thin }
            if fontWeightValue < 0.0  { return .light }
            if fontWeightValue < 0.15 { return .regular }
            if fontWeightValue < 0.3  { return .medium }
            if fontWeightValue < 0.45 { return .semibold }
            if fontWeightValue < 0.6  { return .bold }
            return .black
        }()
        
        let uiWeight: UIFont.Weight = {
            if fontWeightValue < -0.4 { return .ultraLight }
            if fontWeightValue < -0.2 { return .thin }
            if fontWeightValue < 0.0  { return .light }
            if fontWeightValue < 0.15 { return .regular }
            if fontWeightValue < 0.3  { return .medium }
            if fontWeightValue < 0.45 { return .semibold }
            if fontWeightValue < 0.6  { return .bold }
            return .black
        }()
        
        // 💡 构造对应的 UIFont 实例
        let resolvedUIFont: UIFont = {
            if let customFontName, !customFontName.isEmpty, let f = UIFont(name: customFontName, size: fontSize) {
                return f
            }
            switch fontStyle {
            case "monospaced":
                return UIFont.monospacedSystemFont(ofSize: fontSize, weight: uiWeight)
            case "serif":
                let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                    .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                return UIFont(descriptor: descriptor, size: fontSize)
            case "rounded":
                let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                    .withDesign(.rounded) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                return UIFont(descriptor: descriptor, size: fontSize)
            default:
                return UIFont.systemFont(ofSize: fontSize, weight: uiWeight)
            }
        }()
        
        let hasCustomFont = (customFontName != nil && !customFontName!.isEmpty)
        
        VStack {
            if isGlass {
                if #available(iOS 18.0, *) {
                    let textPath = textToPath(entry.text, font: resolvedUIFont)
                    let bounds = textPath.boundingRect
                    
                    GlassEffectContainer {
                        Rectangle()
                            .fill(Color.white.opacity(0.01))
                            .frame(width: max(bounds.width, 10), height: max(bounds.height, 10))
                            .glassEffect(.regular, in: textPath)
                    }
                }
            } else {
                if hasCustomFont {
                    // 💡 对于动态自定义字体：使用矢量路径渲染，彻底解决 SpringBoard 找不到自定义字体的问题
                    let textPath = textToPath(entry.text, font: resolvedUIFont)
                    let bounds = textPath.boundingRect
                    
                    textPath
                        .fill(baseColor)
                        .frame(width: max(bounds.width, 1), height: max(bounds.height, 1))
                } else {
                    // 系统字体直接使用标准 Text，支持动态缩放和标准渲染
                    Text(entry.text)
                        .font(.system(size: fontSize, weight: swiftUIWeight, design: fontDesign))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(baseColor)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
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
                        ContainerRelativeShape().fill(Color(.systemBackground))
                    }
                }
        }
    }
}

// 💡 增强的多行/单行文本转矢量路径函数
func textToPath(_ text: String, font: UIFont) -> Path {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    
    let attributedString = NSAttributedString(
        string: text,
        attributes: [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
    )
    
    let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
    let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
        framesetter,
        CFRange(location: 0, length: attributedString.length),
        nil,
        CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude),
        nil
    )
    
    let framePath = CGPath(rect: CGRect(origin: .zero, size: suggestedSize), transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributedString.length), framePath, nil)
    
    guard let lines = CTFrameGetLines(frame) as? [CTLine] else {
        return Path()
    }
    
    var origins = [CGPoint](repeating: .zero, count: lines.count)
    CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
    
    let combinedPath = CGMutablePath()
    
    for (index, line) in lines.enumerated() {
        let lineOrigin = origins[index]
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { continue }
        
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            guard glyphCount > 0 else { continue }
            
            var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
            var positions = [CGPoint](repeating: .zero, count: glyphCount)
            
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            
            let attributes = CTRunGetAttributes(run) as? [CFString: Any] ?? [:]
            guard let fontObject = attributes[kCTFontAttributeName] else { continue }
            let runFont = fontObject as! CTFont
            
            for i in 0..<glyphCount {
                if let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                    var transform = CGAffineTransform(
                        translationX: lineOrigin.x + positions[i].x,
                        y: lineOrigin.y + positions[i].y
                    )
                    transform = transform.scaledBy(x: 1, y: -1)
                    
                    if let transformedPath = glyphPath.mutableCopy(using: &transform) {
                        combinedPath.addPath(transformedPath)
                    }
                }
            }
        }
    }
    
    var path = Path(combinedPath)
    let bounds = path.boundingRect
    if !bounds.isNull && !bounds.isEmpty {
        path = path.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
    }
    
    return path
}
