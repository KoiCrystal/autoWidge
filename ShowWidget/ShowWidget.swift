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
    @Environment(\.colorScheme) private var colorScheme
    
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
                        fontSize: fontSize,
                        fontWeight: fontWeightValue,
                        backgroundImage: resolvedBgImage,
                        backgroundColor: bgColor,
                        imageScale: previewImageScale,
                        imageOffset: previewImageOffset,
                        tintColor: textColorType == "color" ? customTextColor : nil,
                        colorScheme: colorScheme,
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

// MARK: - Widget 兼容的均匀着色凸透镜液态玻璃文字视图
private struct LiquidGlassTextPathView: View {
    let textPath: Path
    let bounds: CGRect
    let containerSize: CGSize
    let fontSize: CGFloat
    let fontWeight: CGFloat
    let backgroundImage: UIImage?
    let backgroundColor: Color?
    let imageScale: CGFloat
    let imageOffset: CGSize
    let tintColor: Color?
    let colorScheme: ColorScheme
    let renderingMode: WidgetRenderingMode
    
    // 提取颜色纯色相与用户选择的透明度
    private var decomposedTint: (color: Color, alpha: CGFloat)? {
        guard let tintColor else { return nil }
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
        UIColor(tintColor).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: 1.0), max(0, min(a, 1)))
    }
    
    // 判断非图片背景是否为浅色，用于微调玻璃轮廓对比度
    private var isLightSolidBackground: Bool {
        if let backgroundColor {
            var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
            UIColor(backgroundColor).getRed(&r, green: &g, blue: &b, alpha: &a)
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            return a < 0.25 ? (colorScheme == .light) : (luminance > 0.65)
        }
        return colorScheme == .light
    }
    
    var body: some View {
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let hasBackgroundImage = (backgroundImage != nil)
        let tintInfo = decomposedTint
        let hasTint = (tintInfo != nil)
        let pureTint = tintInfo?.color ?? .white
        let tintAlpha = Double(tintInfo?.alpha ?? 1.0)
        
        // 💡 根据字号与字重动态推算笔画粗细，避免细字体被厚描边淹没
        let weightFactor = max(0.36, min(fontWeight / 400.0, 2.0))
        let stemEstimate = max(0.9, fontSize * 0.082 * weightFactor)
        let isThinGlyph = (fontWeight < 350) || (fontSize < 16)
        
        let rimBandWidth = min(max(stemEstimate * 1.15, 1.4), 4.8)
        let innerHighlightWidth = min(max(stemEstimate * 0.42, 0.55), 1.40)
        let innerShadowWidth = min(max(stemEstimate * 0.48, 0.60), 1.75)
        let causticWidth = min(max(stemEstimate * 0.52, 0.70), 2.0)
        let bevelOffset = min(max(stemEstimate * 0.24, 0.28), 0.85)
        let bevelBlur = min(max(stemEstimate * 0.20, 0.20), 0.75)
        let outerStrokeWidth: CGFloat = isThinGlyph ? 0.85 : 0.70
        
        ZStack {
            if renderingMode == .fullColor {
                // 1. 图像背景：双层凸透镜折射采样
                if let backgroundImage {
                    // 1a. 中心透镜放大区（1.22x 放大，高通透）
                    refractedImageLayer(
                        image: backgroundImage,
                        lensScale: 1.22,
                        lensOffset: CGSize(width: 0, height: -0.7),
                        blurRadius: 0.25
                    )
                    .saturation(1.22)
                    .contrast(1.05)
                    .mask {
                        textPath
                            .fill(Color.white)
                            .frame(width: width, height: height)
                    }
                    
                    // 1b. 弯月面边缘强弯曲折射区（1.48x 放大 + 偏心偏移）
                    refractedImageLayer(
                        image: backgroundImage,
                        lensScale: 1.48,
                        lensOffset: CGSize(width: 1.8, height: 1.8),
                        blurRadius: 0.15
                    )
                    .brightness(hasTint ? 0.03 : 0.07)
                    .saturation(1.30)
                    .contrast(1.08)
                    .mask {
                        textPath
                            .stroke(Color.white, lineWidth: rimBandWidth)
                            .frame(width: width, height: height)
                            .mask {
                                textPath
                                    .fill(Color.white)
                                    .frame(width: width, height: height)
                            }
                    }
                } else {
                    // 1c. 非图片背景（系统/纯色）：统一中性透光基底，避免在多彩背景上发灰或偏色
                    textPath
                        .fill(.ultraThinMaterial)
                        .frame(width: width, height: height)
                        .opacity(hasTint ? 0.20 : (isLightSolidBackground ? 0.34 : 0.26))
                    
                    if !hasTint {
                        textPath
                            .fill(
                                isLightSolidBackground
                                ? Color.black.opacity(0.07)
                                : Color.white.opacity(0.08)
                            )
                            .frame(width: width, height: height)
                    }
                }
                
                // 2. 均匀彩色玻璃染色层（保持首尾字符与多行文字深浅一致，同时贴合不同背景）
                if hasTint {
                    let uniformTintOpacity = (hasBackgroundImage ? 0.32 : 0.42) * tintAlpha
                    
                    textPath
                        .fill(pureTint.opacity(uniformTintOpacity))
                        .frame(width: width, height: height)
                }
                
                // 3. 立体玻璃内部体积光影（按笔画比例缩放，仅作用于局部边缘，不改变整体颜色深浅）
                // 3a. 右下内部微暗棱（构建厚实液体边缘）
                textPath
                    .stroke(
                        Color.black.opacity((!hasBackgroundImage && isLightSolidBackground) ? 0.22 : 0.15),
                        lineWidth: innerShadowWidth
                    )
                    .offset(x: -bevelOffset, y: -bevelOffset)
                    .blur(radius: bevelBlur)
                    .frame(width: width, height: height)
                    .mask {
                        textPath
                            .fill(Color.white)
                            .frame(width: width, height: height)
                    }
                
                // 3b. 左上锐利湿润高光弧线
                textPath
                    .stroke(
                        Color.white.opacity(hasTint ? 0.44 : 0.54),
                        lineWidth: innerHighlightWidth
                    )
                    .offset(x: bevelOffset, y: bevelOffset)
                    .blur(radius: bevelBlur * 0.65)
                    .frame(width: width, height: height)
                    .mask {
                        textPath
                            .fill(Color.white)
                            .frame(width: width, height: height)
                    }
                
                // 3c. 底部微弱光焦散内反光（均匀作用于每个字的底沿，避免跨字符色差）
                textPath
                    .stroke(
                        (hasTint ? pureTint : Color.white).opacity(
                            hasTint ? (0.34 * tintAlpha) : 0.38
                        ),
                        lineWidth: causticWidth
                    )
                    .offset(x: -bevelOffset * 0.35, y: -bevelOffset * 0.95)
                    .blur(radius: bevelBlur * 0.85)
                    .frame(width: width, height: height)
                    .mask {
                        textPath
                            .fill(Color.white)
                            .frame(width: width, height: height)
                    }
                
                // 4. 克制的表面镜面光泽（仅轻微提亮顶部受光面，不再导致前后字色差）
                textPath
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(hasTint ? 0.14 : 0.18), location: 0.0),
                                .init(color: .white.opacity(0.03), location: 0.35),
                                .init(color: .clear, location: 0.70),
                                .init(color: .white.opacity(0.05), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width, height: height)
                
                // 5. 均匀菲涅尔外轮廓描边（保持彩色均匀环绕，仅在顶部叠加柔和白光）
                textPath
                    .stroke(
                        (hasTint ? pureTint : Color.white).opacity(
                            hasTint ? (0.58 * tintAlpha) : (isThinGlyph ? 0.44 : 0.34)
                        ),
                        lineWidth: outerStrokeWidth
                    )
                    .frame(width: width, height: height)
                
                textPath
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(isThinGlyph ? 0.68 : 0.56), location: 0.0),
                                .init(color: .white.opacity(0.18), location: 0.5),
                                .init(color: .white.opacity(0.28), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: outerStrokeWidth * 0.85
                    )
                    .frame(width: width, height: height)
            } else {
                // 系统透明/色调（Accented / Vibrant）桌面模式下，交由系统玻璃引擎统一着色
                textPath
                    .fill(.white.opacity(0.76))
                    .frame(width: width, height: height)
                    .widgetAccentable()
                
                textPath
                    .stroke(.white.opacity(0.48), lineWidth: 0.6)
                    .frame(width: width, height: height)
                    .widgetAccentable()
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        // 彩色玻璃额外产生一层柔和均匀的彩色光焦散阴影
        .shadow(
            color: (renderingMode == .fullColor && hasTint)
                ? pureTint.opacity(0.24 * tintAlpha)
                : .clear,
            radius: 3.8,
            x: 0,
            y: 2.0
        )
        .shadow(
            color: renderingMode == .fullColor
                ? .black.opacity(isThinGlyph ? 0.24 : 0.18)
                : .clear,
            radius: isThinGlyph ? 2.6 : 3.2,
            x: 0,
            y: isThinGlyph ? 1.4 : 1.8
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
