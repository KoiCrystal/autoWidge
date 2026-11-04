//
//  LiquidGlassText.swift
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/11/4.
//

import SwiftUI
import CoreText
import UIKit

// MARK: - 1. CoreText Multi-line Framesetter Path

private func textToPath(_ text: String, font: UIFont, constrainedWidth: CGFloat) -> Path {
    let attributedString = NSAttributedString(
        string: text,
        attributes: [.font: font]
    )

    let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
    
    // 根据约束宽度计算多行文本所需的大小
    let constraintSize = CGSize(width: max(constrainedWidth, 50), height: CGFloat.greatestFiniteMagnitude)
    let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
        framesetter,
        CFRange(location: 0, length: 0),
        nil,
        constraintSize,
        nil
    )

    let framePath = CGPath(rect: CGRect(origin: .zero, size: suggestedSize), transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), framePath, nil)

    let lines = CTFrameGetLines(frame) as! [CTLine]
    var origins = [CGPoint](repeating: .zero, count: lines.count)
    CTFrameGetLineOrigins(frame, CFRange(location: 0, length: lines.count), &origins)

    let combinedPath = CGMutablePath()

    for (index, line) in lines.enumerated() {
        let origin = origins[index]
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]

        for run in runs {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)

            CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, 0), &positions)

            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let fontValue = attributes[kCTFontAttributeName as String] else { continue }
            let runFont = fontValue as! CTFont

            for i in 0..<count {
                guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else {
                    continue
                }

                let pos = positions[i]
                var transform = CGAffineTransform(translationX: origin.x + pos.x, y: origin.y + pos.y)

                if let translated = glyphPath.copy(using: &transform) {
                    combinedPath.addPath(translated)
                }
            }
        }
    }

    let bounds = combinedPath.boundingBox
    if bounds.isNull || bounds.isEmpty {
        return Path()
    }

    // 转换为左上角原点坐标
    var transform = CGAffineTransform(
        a: 1, b: 0,
        c: 0, d: -1,
        tx: -bounds.minX,
        ty: bounds.maxY
    )

    // 💡 修正了这里的大小写：combinedpath -> combinedPath
    guard let normalized = combinedPath.copy(using: &transform) else {
        return Path()
    }

    return Path(normalized)
}

// MARK: - 2. Glyph Shape

private struct GlyphShape: Shape {
    let glyphPath: Path

    func path(in rect: CGRect) -> Path {
        glyphPath
    }
}

// MARK: - 3. Liquid Glass Text (无外缘描边纯净版)

struct LiquidGlassText: View {

    let text: String
    var fontSize: CGFloat = 40
    var weight: UIFont.Weight = .bold
    var fontStyle: String = "system"
    var constrainedWidth: CGFloat = 250 // 限制最大宽度以触发自动换行

    // 玻璃主体色调
    var tint: Color = .primary

    private var uiFont: UIFont {
        let baseFont: UIFont
        switch fontStyle {
        case "monospaced":
            baseFont = .monospacedSystemFont(ofSize: fontSize, weight: weight)
        case "serif":
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.serif)?
                .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
            baseFont = UIFont(descriptor: descriptor ?? UIFontDescriptor(), size: fontSize)
        case "rounded":
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.rounded)?
                .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
            baseFont = UIFont(descriptor: descriptor ?? UIFontDescriptor(), size: fontSize)
        default:
            baseFont = .systemFont(ofSize: fontSize, weight: weight)
        }
        return baseFont
    }

    private var glyphPath: Path {
        textToPath(text, font: uiFont, constrainedWidth: constrainedWidth)
    }

    var body: some View {
        let path = glyphPath
        let bounds = path.boundingRect

        ZStack {
            // 1. 底层毛玻璃：保留舒适的模糊质感（0.68）
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.68)
                .mask(GlyphShape(glyphPath: path))

            // 2. 中间填充：微微带有一点颜色倾向（0.08）
            GlyphShape(glyphPath: path)
                .fill(tint.opacity(0.7))

            // 3. 顶部镜面流光：靠顶部的微弱高光来表现字体的立体体积感
            GlyphShape(glyphPath: path)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blendMode(.screen)
        }
        .frame(
            width: max(bounds.width, 1),
            height: max(bounds.height, 1)
        )
        .accessibilityLabel(Text(text))
    }
}
