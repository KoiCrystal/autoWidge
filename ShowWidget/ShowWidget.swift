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
    @Environment(\.widgetRenderingMode)
    private var renderingMode

    
    var body: some View {
        let instance = entry.resolvedInstance ?? entry.configuration.instance
        let fontSize = instance?.fontSize ?? 17
        let fontStyle = instance?.fontStyle ?? "system"
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
        
        let textFont: Font = isGlass
            ? .system(size: fontSize, weight: .bold, design: fontDesign)
            : .system(size: fontSize, design: fontDesign)
        
        let textContent = Text(entry.text)
            .font(textFont)
            .multilineTextAlignment(.center)
        
        VStack {
            if isGlass {
                if #available(iOS 26.0, *) {
                    let weight: UIFont.Weight = .bold
                    let uiFont: UIFont = {
                        switch fontStyle {
                        case "monospaced":
                            return UIFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
                        case "serif":
                            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                                .withDesign(.serif)!
                            return UIFont(descriptor: descriptor, size: fontSize)
                        case "rounded":
                            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                                .withDesign(.rounded)!
                            return UIFont(descriptor: descriptor, size: fontSize)
                        default:
                            return UIFont.systemFont(ofSize: fontSize, weight: weight)
                        }
                    }()
                    
                    let textPath = textToPath(entry.text, font: uiFont)
                    let bounds = textPath.boundingRect
                    
                    // 关键用非零透明度 + 明确尺寸，防止被系统优化掉
                    GlassEffectContainer {
                        Rectangle()
                            .fill(Color.white.opacity(0.01))          // 必须有极小但不为零的透明度
                            .frame(width: max(bounds.width, 10), height: max(bounds.height, 10))
                            .glassEffect(.regular, in: textPath)
                    }
                        // 可选：给玻璃一点颜色倾向
                        // .glassEffect(.regular.tint(baseColor.opacity(0.25)), in: textPath)
                    
                } else {
                    // 回退方案
                }
            } else {
                // 普通文字
                if textColorType == "color" {
                    textContent.foregroundStyle(customTextColor)
                } else {
                    textContent.foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // 强制占满可用空间，稳定布局
        .contentShape(Rectangle())                          // 帮助系统正确计算尺寸
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


func textToPath(_ text: String, font: UIFont) -> Path {
    let attributedString = NSAttributedString(
        string: text,
        attributes: [.font: font]
    )
    
    let line = CTLineCreateWithAttributedString(attributedString)
    guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else {
        return Path()
    }
    
    let combinedPath = CGMutablePath()
    
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
                var transform = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
                // Core Text 坐标系与 SwiftUI 相反，需要垂直翻转
                transform = transform.scaledBy(x: 1, y: -1)
                
                if let transformedPath = glyphPath.mutableCopy(using: &transform) {
                    combinedPath.addPath(transformedPath)
                }
            }
        }
    }
    
    var path = Path(combinedPath)
    
    // 将路径原点移动到左上角，方便后续布局
    let bounds = path.boundingRect
    if !bounds.isNull && !bounds.isEmpty {
        path = path.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
    }
    
    return path
}
