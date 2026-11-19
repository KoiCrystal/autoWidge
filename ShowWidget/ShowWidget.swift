//
//  ShowWidget.swift
//  ShowWidget
//
//  Created by Zhaomin Wu & Jinyu Zhang on 2026/5/8.
//

import WidgetKit
import SwiftUI
import UIKit

struct Provider: AppIntentTimelineProvider {
    
    init() {
        CustomFontManager.shared.registerAllFonts()
    }
    
    // 动态从 App Group 中查询最新的实体数据
    private func resolveLatest(for instance: WidgetDataSourceEntity?) -> (entity: WidgetDataSourceEntity?, text: String) {
        guard let id = instance?.id else {
            return (nil, "请选择实例")
        }
        let allInstances = WidgetInstanceQuery().loadAllInstances()
        guard let target = allInstances.first(where: { $0.id == id }) else {
            return (nil, "实例不存在")
        }
        return (target, target.text ?? "暂无文本")
    }
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(),
                    configuration: ConfigurationAppIntent(),
                    resolvedInstance: nil,
                    text: "占位文本")
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let resolved = resolveLatest(for: configuration.instance)
        return SimpleEntry(date: Date(),
                           configuration: configuration,
                           resolvedInstance: resolved.entity,
                           text: resolved.text)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let resolved = resolveLatest(for: configuration.instance)
        let entry = SimpleEntry(
            date: Date(),
            configuration: configuration,
            resolvedInstance: resolved.entity,
            text: resolved.text
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
    var preloadedBackgroundImage: UIImage? = nil
    var previewImageScale: CGFloat = 1.0
    var previewImageOffset: CGSize = .zero
    
    @Environment(\.widgetRenderingMode) private var renderingMode
    
    var body: some View {
        let instance = entry.resolvedInstance ?? entry.configuration.instance
        let fontSize = instance?.fontSize ?? 17
        let fontWeightValue = instance?.fontWeight ?? 400
        let customFontName = instance?.customFontName
        let textColorType = instance?.textColorType ?? (instance?.textColorName != nil ? "color" : "system")
        let textColorHex = instance?.textColorName ?? "#ffffffff"
        let customTextColor = Color(hex: textColorHex)
        let isGlass = instance?.isLiquidGlass ?? false
        let bgType = instance?.backgroundType ?? "system"
        let bgColorHex = instance?.backgroundColorName ?? "#FFFFFF"
        let bgColor: Color? = (bgType == "color") ? Color(hex: bgColorHex) : nil
        
        let resolvedBgImage: UIImage? = if bgType == "image" {
            preloadedBackgroundImage ?? SharedImageHelper.loadImage(fileName: instance?.backgroundImageName)
        } else {
            nil
        }
        
        let baseColor: Color = (textColorType == "color") ? customTextColor : .primary
        let swiftUIWeight = CustomFontManager.shared.swiftUIWeight(for: fontWeightValue)
        let hasCustomFont = (customFontName != nil && !customFontName!.isEmpty)
        
        // 💡 仅在需要路径绘制（自定义字体或液态玻璃）时构造 UIFont
        let resolvedUIFont: UIFont? = (hasCustomFont || isGlass)
            ? CustomFontManager.shared.resolvedUIFont(
                customFontName: customFontName,
                size: fontSize,
                weight: fontWeightValue
            )
            : nil
        
        // 💡 使用 GeometryReader 获取小组件当前的实际可用渲染尺寸
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - 28, 20)
            
            VStack(alignment: .center) {
                if isGlass, let resolvedUIFont {
                    let textPath = textToPath(entry.text, font: resolvedUIFont, constrainedWidth: availableWidth)
                    let bounds = textPath.boundingRect
                    
                    LiquidGlassTextPathView(
                        textPath: textPath,
                        bounds: bounds,
                        containerSize: geometry.size,
                        backgroundImage: resolvedBgImage,
                        backgroundColor: bgColor,
                        imageScale: previewImageScale,
                        imageOffset: previewImageOffset,
                        tintColor: textColorType == "color" ? customTextColor : nil,
                        renderingMode: renderingMode
                    )
                } else {
                    if hasCustomFont, let resolvedUIFont {
                        let textPath = textToPath(entry.text, font: resolvedUIFont, constrainedWidth: availableWidth)
                        let bounds = textPath.boundingRect
                        
                        textPath
                            .fill(baseColor)
                            .frame(width: max(bounds.width, 1), height: max(bounds.height, 1))
                    } else {
                        // 系统字体直接使用标准 Text，支持动态缩放和标准渲染
                        Text(entry.text)
                            .font(.system(size: fontSize, weight: swiftUIWeight))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(baseColor)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Widget 兼容的凸透镜折射液态玻璃文字视图
private struct LiquidGlassTextPathView: View {
    let textPath: Path
    let bounds: CGRect
    let containerSize: CGSize
    let backgroundImage: UIImage?
    let backgroundColor: Color?
    let imageScale: CGFloat
    let imageOffset: CGSize
    let tintColor: Color?
    let renderingMode: WidgetRenderingMode
    
    var body: some View {
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let hasBackgroundImage = (backgroundImage != nil)
        
        ZStack {
            if renderingMode == .fullColor {
                // 1. 图像背景：双层凸透镜折射采样（保留清晰背景纹理，避免过度磨砂）
                if let backgroundImage {
                    // 1a. 中心透镜放大区（1.20x 放大 + 轻微光学提亮与饱和度增强）
                    refractedImageLayer(
                        image: backgroundImage,
                        lensScale: 1.20,
                        lensOffset: CGSize(width: 0, height: -0.8),
                        blurRadius: 0.45
                    )
                    .brightness(0.06)
                    .saturation(1.30)
                    .contrast(1.08)
                    .mask {
                        textPath
                            .fill(Color.white)
                            .frame(width: width, height: height)
                    }
                    
                    // 1b. 液态弯月面边缘强折射区（1.45x 放大 + 偏心错位，贴合内轮廓）
                    refractedImageLayer(
                        image: backgroundImage,
                        lensScale: 1.45,
                        lensOffset: CGSize(width: 1.8, height: 1.8),
                        blurRadius: 0.3
                    )
                    .brightness(0.14)
                    .saturation(1.42)
                    .contrast(1.12)
                    .mask {
                        textPath
                            .stroke(Color.white, lineWidth: 5.5)
                            .frame(width: width, height: height)
                            .mask {
                                textPath
                                    .fill(Color.white)
                                    .frame(width: width, height: height)
                            }
                    }
                } else {
                    // 1c. 非图片背景（系统/纯色）：营造透明折射基底，避免死白发灰
                    textPath
                        .fill(.ultraThinMaterial)
                        .frame(width: width, height: height)
                        .opacity(0.62)
                    
                    if let backgroundColor {
                        textPath
                            .fill(
                                LinearGradient(
                                    colors: [
                                        backgroundColor.opacity(0.22),
                                        backgroundColor.opacity(0.45),
                                        .white.opacity(0.28)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: width, height: height)
                    }
                }
                
                // 2. 极轻的玻璃基底透光（保持通透水感，不过度遮盖折射像素）
                if hasBackgroundImage {
                    textPath
                        .fill(.ultraThinMaterial)
                        .frame(width: width, height: height)
                        .opacity(0.18)
                }
                
                // 3. 可选的玻璃染色层（仅在用户选择“自定义颜色”时生效）
                if let tintColor {
                    textPath
                        .fill(tintColor.opacity(hasBackgroundImage ? 0.20 : 0.28))
                        .frame(width: width, height: height)
                }
                
                // 4. 立体液态鼓包体积感（内倒角高光、内暗面与底部焦散光斑）
                // 4a. 宽幅柔和内部亮面（模拟液滴隆起顶部受光）
                textPath
                    .stroke(Color.white.opacity(0.68), lineWidth: 5.0)
                    .offset(x: 1.2, y: 1.4)
                    .blur(radius: 1.8)
                    .frame(width: width, height: height)
                    .mask {
                        textPath
                            .fill(Color.white)
                            .frame(width: width, height: height)
                    }
                
                // 4b. 底部内部暗角（增强厚实玻璃体深邃感）
                textPath
                    .stroke(Color.black.opacity(0.22), lineWidth: 4.0)
                    .offset(x: -1.0, y: -1.2)
                    .blur(radius: 1.6)
                    .frame(width: width, height: height)
                    .mask {
                        textPath
                            .fill(Color.white)
                            .frame(width: width, height: height)
                    }
                
                // 4c. 锐利内高光边（贴合左上边缘）
                textPath
                    .stroke(Color.white.opacity(0.92), lineWidth: 1.4)
                    .offset(x: 0.6, y: 0.8)
                    .blur(radius: 0.45)
                    .frame(width: width, height: height)
                    .mask {
                        textPath
                            .fill(Color.white)
                            .frame(width: width, height: height)
                    }
                
                // 4d. 底部/右下光焦散聚焦（光线穿透液滴后在底部聚光）
                textPath
                    .stroke(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.15), .white.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.4
                    )
                    .offset(x: -0.4, y: -0.9)
                    .blur(radius: 0.85)
                    .frame(width: width, height: height)
                    .mask {
                        textPath
                            .fill(Color.white)
                            .frame(width: width, height: height)
                    }
                
                // 5. 表面湿润镜面高光带（左上亮泽反光 -> 中段通透 -> 右下微反光）
                textPath
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.54), location: 0.0),
                                .init(color: .white.opacity(0.16), location: 0.28),
                                .init(color: .white.opacity(0.02), location: 0.55),
                                .init(color: .white.opacity(0.24), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: width, height: height)
                
                // 6. 纯净无色菲涅尔外轮廓描边（去除任何偏蓝/青色调）
                textPath
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.95), location: 0.0),
                                .init(color: .white.opacity(0.30), location: 0.45),
                                .init(color: .white.opacity(0.22), location: 0.65),
                                .init(color: .white.opacity(0.78), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.85
                    )
                    .frame(width: width, height: height)
            } else {
                // 系统透明/色调（Accented / Vibrant）桌面模式下，交由系统玻璃引擎统一着色
                textPath
                    .fill(.white.opacity(0.85))
                    .frame(width: width, height: height)
                    .widgetAccentable()
                
                textPath
                    .stroke(.white.opacity(0.55), lineWidth: 0.6)
                    .frame(width: width, height: height)
                    .widgetAccentable()
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .shadow(
            color: renderingMode == .fullColor ? .black.opacity(0.24) : .clear,
            radius: 4.0,
            x: 0,
            y: 2.5
        )
    }
    
    @ViewBuilder
    private func refractedImageLayer(
        image: UIImage,
        lensScale: CGFloat,
        lensOffset: CGSize,
        blurRadius: CGFloat
    ) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(imageScale)
            .offset(imageOffset)
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
            .scaleEffect(lensScale)
            .offset(lensOffset)
            .blur(radius: blurRadius)
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
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
            
            ShowWidgetEntryView(entry: entry, preloadedBackgroundImage: uiImage)
                .containerBackground(for: .widget) {
                    switch bgType {
                    case "color":
                        customColor
                    case "image":
                        if let uiImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                        } else {
                            Color(.systemBackground)
                        }
                    default:
                        ContainerRelativeShape().fill(Color(.systemBackground))
                    }
                }
        }
        .contentMarginsDisabled()
    }
}

// 💡 解决单字方向正确、多行顺序正常，且自动消除自交/笔画重叠（如数字 5 等）的文本转路径函数
func textToPath(_ text: String, font: UIFont, constrainedWidth: CGFloat = 280) -> Path {
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
        CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude),
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
    let totalHeight = suggestedSize.height
    
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
                    // 💡 正确的矩阵变换组合：
                    // 1. 将字形自身的 Y 轴翻转（y: -1），纠正字形笔画倒立问题
                    // 2. 将行原点从底向上的坐标转换为从上向下的正确行序 (totalHeight - lineOrigin.y)
                    let correctedY = totalHeight - lineOrigin.y
                    
                    var transform = CGAffineTransform(
                        translationX: lineOrigin.x + positions[i].x,
                        y: correctedY + positions[i].y
                    )
                    transform = transform.scaledBy(x: 1, y: -1)
                    
                    if let transformedPath = glyphPath.mutableCopy(using: &transform) {
                        combinedPath.addPath(transformedPath)
                    }
                }
            }
        }
    }
    
    // 💡 合并字形内部交叉与重叠笔画（如可变字体/手写体中的数字 5），消除描边时的内部割裂轮廓
    let resolvedCGPath: CGPath = combinedPath.isEmpty
        ? combinedPath
        : combinedPath.normalized(using: .winding)
    
    var path = Path(resolvedCGPath)
    let bounds = path.boundingRect
    if !bounds.isNull && !bounds.isEmpty {
        path = path.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
    }
    
    return path
}
