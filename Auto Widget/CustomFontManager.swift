//
//  CustomFontManager.swift
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/11/11.
//

import SwiftUI
import UIKit
import CoreText

struct CustomFontVariant: Identifiable, Codable, Hashable {
    var id: String { "\(postScriptName)_\(fileName)" }
    let postScriptName: String
    let fileName: String
    let fileURL: URL
    let weight: CGFloat
    let isVariable: Bool
    let isPreset: Bool
}

struct CustomFontEntity: Identifiable, Codable {
    var id: String { "\(isPreset ? "preset_" : "user_")\(name)" }
    let name: String        // 代表性的 PostScript 名字（如 Regular 或最接近 400 的变体）
    let displayName: String // 界面上显示的名称
    let fileName: String    // 代表性文件名
    var isPreset: Bool = false
    var variants: [CustomFontVariant] = []
}

enum FontWeightCapability: Equatable {
    /// 离散档位（例如系统字体 100...900 九档，或多文件静态字体的可用字重）
    case discrete(values: [CGFloat], defaultValue: CGFloat)
    /// 无级连续可变（读取自字体内部的 wght 轴范围）
    case variable(min: CGFloat, max: CGFloat, defaultValue: CGFloat)
    /// 固定字重（仅单个静态文件，不可调节）
    case fixed
}

class CustomFontManager {
    static let shared = CustomFontManager()
    
    // 使用 App Group 共享容器（确保小组件 Extension 也能用自定义字体）
    private let groupIdentifier = "group.autowidget.app2widget"
    
    // OpenType 'wght' 字重轴的 FourCC 标识
    private let wghtAxisIdentifier: UInt32 = 0x77676874
    
    // 💡 预设字体显示名称映射表
    // 支持填写：完整文件名、不含后缀的文件名、PostScript 名称、字体家族名称或前缀关键词（自动忽略空格与连字符）
    private let presetFontDisplayNames: [String: String] = [
        "ClawdMono": "爪迹等宽",
        "LXGWWenKai": "霞鹜文楷",
        "LianshengLingguang": "莲生灵光",
    ]
    
    private let stateLock = NSLock()
    // 💡 记录已在内存中注册过的字体路径与缓存的家族索引
    private var registeredFontPaths = Set<String>()
    private var capabilityCache: [String: FontWeightCapability] = [:]
    private var cachedFamilies: [CustomFontEntity] = []
    private var postScriptToFamilyMap: [String: CustomFontEntity] = [:]
    private var isFamilyIndexBuilt = false
    
    private var fontDirectoryURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
            .appendingPathComponent("CustomFonts", isDirectory: true)
    }
    
    init() {
        createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() {
        if let url = fontDirectoryURL, !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    private func normalizedFontKey(_ text: String) -> String {
        text.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { String($0).lowercased() }
            .joined()
    }
    
    // 根据映射表解析预设字体的显示名称（支持精确匹配与忽略空格/连字符/版本号的前缀包含匹配）
    private func resolvePresetDisplayName(
        familyDisplayName: String,
        isItalic: Bool,
        variants: [CustomFontVariant]
    ) -> String {
        var candidates: [String] = [familyDisplayName]
        for variant in variants {
            let baseName = URL(fileURLWithPath: variant.fileName).deletingPathExtension().lastPathComponent
            candidates.append(contentsOf: [variant.fileName, baseName, variant.postScriptName])
        }
        
        // 1. 精确匹配（忽略大小写）
        for candidate in candidates {
            if let matched = presetFontDisplayNames.first(where: { $0.key.caseInsensitiveCompare(candidate) == .orderedSame }) {
                return isItalic && !matched.value.localizedCaseInsensitiveContains("italic")
                    ? "\(matched.value) Italic"
                    : matched.value
            }
        }
        
        let normalizedCandidates = candidates.map { normalizedFontKey($0) }.filter { !$0.isEmpty }
        let sortedEntries = presetFontDisplayNames
            .map { (normalizedKey: normalizedFontKey($0.key), value: $0.value) }
            .filter { !$0.normalizedKey.isEmpty }
            .sorted { $0.normalizedKey.count > $1.normalizedKey.count }
        
        // 2. 归一化后精确匹配
        for entry in sortedEntries {
            if normalizedCandidates.contains(entry.normalizedKey) {
                return isItalic && !entry.value.localizedCaseInsensitiveContains("italic")
                    ? "\(entry.value) Italic"
                    : entry.value
            }
        }
        
        // 3. 归一化后前缀或包含匹配（适配带版本后缀、字重后缀或空格的字体名）
        for entry in sortedEntries {
            if normalizedCandidates.contains(where: { $0.hasPrefix(entry.normalizedKey) || $0.contains(entry.normalizedKey) }) {
                return isItalic && !entry.value.localizedCaseInsensitiveContains("italic")
                    ? "\(entry.value) Italic"
                    : entry.value
            }
        }
        
        return familyDisplayName
    }
    
    // 获取 Bundle 中的预设字体文件 URL（同时兼容 Folder Reference 与 Xcode Group 平铺打包）
    private func bundleFontURLs() -> [URL] {
        let extensions = ["ttf", "otf", "TTF", "OTF"]
        var urls: [URL] = []
        var seenPaths = Set<String>()
        
        for subdirectory in ["Fonts", nil] as [String?] {
            for ext in extensions {
                if let found = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: subdirectory) {
                    for url in found where !seenPaths.contains(url.path) {
                        seenPaths.insert(url.path)
                        urls.append(url)
                    }
                }
            }
        }
        return urls
    }
    
    private func userFontURLs() -> [URL] {
        guard let url = fontDirectoryURL,
              let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }
        return files.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "ttf" || ext == "otf"
        }
    }
    
    // 从 URL 提取字体家族、PostScript 名、字重与斜体信息（不读取整个文件进内存）
    private struct ScannedFontMetadata {
        let postScriptName: String
        let familyGroupKey: String
        let familyDisplayName: String
        let isItalic: Bool
        let weight: CGFloat
        let isVariable: Bool
        let fileURL: URL
        let isPreset: Bool
    }
    
    private func scanMetadata(from url: URL, isPreset: Bool) -> ScannedFontMetadata? {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first,
              let postScriptName = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else {
            return nil
        }
        
        let familyName = (CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let styleName = (CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [CFString: Any]
        let symbolicRaw = (traits?[kCTFontSymbolicTrait] as? NSNumber)?.uint32Value ?? 0
        let isItalic = CTFontSymbolicTraits(rawValue: symbolicRaw).contains(.traitItalic)
            || styleName.localizedCaseInsensitiveContains("italic")
            || styleName.localizedCaseInsensitiveContains("oblique")
        
        let traitWeight = (traits?[kCTFontWeightTrait] as? NSNumber)?.doubleValue
        let resolvedWeight = inferStaticWeight(
            styleName: styleName,
            postScriptName: postScriptName,
            traitWeight: traitWeight
        )
        
        let baseFamily = (familyName?.isEmpty == false ? familyName! : postScriptName)
        let groupKey = "\(isPreset ? "preset" : "user")::\(baseFamily.lowercased())::\(isItalic ? "italic" : "upright")"
        let displayFamily = isItalic && !baseFamily.localizedCaseInsensitiveContains("italic")
            ? "\(baseFamily) Italic"
            : baseFamily
        
        let variationAxes = CTFontDescriptorCopyAttribute(descriptor, kCTFontVariationAttribute) as? [Any]
        let isVarByDescriptor = (variationAxes?.isEmpty == false)
        
        return ScannedFontMetadata(
            postScriptName: postScriptName,
            familyGroupKey: groupKey,
            familyDisplayName: displayFamily,
            isItalic: isItalic,
            weight: resolvedWeight,
            isVariable: isVarByDescriptor,
            fileURL: url,
            isPreset: isPreset
        )
    }
    
    /// 根据样式名、PostScript 名与 CoreText Weight Trait 推断 100-900 字重
    private func inferStaticWeight(styleName: String, postScriptName: String, traitWeight: Double?) -> CGFloat {
        let combined = "\(styleName) \(postScriptName)".lowercased()
        
        // 先匹配复合词，避免 "semibold" 被误判为 "bold"、"extralight" 被误判为 "light"
        if combined.contains("hairline") || combined.contains("thin") { return 100 }
        if combined.contains("extralight") || combined.contains("extra-light") || combined.contains("extra light")
            || combined.contains("ultralight") || combined.contains("ultra-light") || combined.contains("ultra light") { return 200 }
        if combined.contains("light") { return 300 }
        if combined.contains("semibold") || combined.contains("semi-bold") || combined.contains("semi bold")
            || combined.contains("demibold") || combined.contains("demi-bold") || combined.contains("demi") { return 600 }
        if combined.contains("extrabold") || combined.contains("extra-bold") || combined.contains("extra bold")
            || combined.contains("ultrabold") || combined.contains("ultra-bold") || combined.contains("ultra bold") { return 800 }
        if combined.contains("black") || combined.contains("extrablack") || combined.contains("ultrablack") { return 900 }
        if combined.contains("heavy") { return 800 }
        if combined.contains("bold") { return 700 }
        if combined.contains("medium") { return 500 }
        if combined.contains("regular") || combined.contains("normal") || combined.contains("book") || combined.contains("roman") { return 400 }
        
        if let w = traitWeight {
            switch w {
            case ..<(-0.70):      return 100
            case -0.70..<(-0.50): return 200
            case -0.50..<(-0.15): return 300
            case -0.15..<0.12:    return 400
            case 0.12..<0.27:     return 500
            case 0.27..<0.35:     return 600
            case 0.35..<0.50:     return 700
            case 0.50..<0.60:     return 800
            default:              return 900
            }
        }
        
        return 400
    }
    
    /// 重建字体家族索引（按 Family 归类多文件字重）
    @discardableResult
    private func rebuildFontIndex() -> [CustomFontEntity] {
        var grouped: [String: (displayName: String, isItalic: Bool, isPreset: Bool, variants: [CustomFontVariant])] = [:]
        var orderedKeys: [String] = []
        var seenPostScriptNames = Set<String>()
        
        let allSources: [(url: URL, isPreset: Bool)] =
            bundleFontURLs().map { ($0, true) } + userFontURLs().map { ($0, false) }
        
        for source in allSources {
            guard let meta = scanMetadata(from: source.url, isPreset: source.isPreset) else { continue }
            if seenPostScriptNames.contains(meta.postScriptName) { continue }
            seenPostScriptNames.insert(meta.postScriptName)
            
            let variant = CustomFontVariant(
                postScriptName: meta.postScriptName,
                fileName: source.url.lastPathComponent,
                fileURL: source.url,
                weight: meta.weight,
                isVariable: meta.isVariable,
                isPreset: source.isPreset
            )
            
            if grouped[meta.familyGroupKey] == nil {
                grouped[meta.familyGroupKey] = (meta.familyDisplayName, meta.isItalic, meta.isPreset, [variant])
                orderedKeys.append(meta.familyGroupKey)
            } else {
                grouped[meta.familyGroupKey]?.variants.append(variant)
            }
        }
        
        var entities: [CustomFontEntity] = []
        var psMap: [String: CustomFontEntity] = [:]
        
        for key in orderedKeys {
            guard let group = grouped[key] else { continue }
            
            // 按字重从小到大排序，并避免相同字重重复
            var uniqueByWeight: [CGFloat: CustomFontVariant] = [:]
            for v in group.variants {
                if uniqueByWeight[v.weight] == nil {
                    uniqueByWeight[v.weight] = v
                }
            }
            let sortedVariants = uniqueByWeight.values.sorted { $0.weight < $1.weight }
            guard let canonical = sortedVariants.min(by: { abs($0.weight - 400) < abs($1.weight - 400) }) ?? sortedVariants.first else {
                continue
            }
            
            let displayName = group.isPreset
                ? resolvePresetDisplayName(
                    familyDisplayName: group.displayName,
                    isItalic: group.isItalic,
                    variants: sortedVariants
                )
                : group.displayName
            
            let entity = CustomFontEntity(
                name: canonical.postScriptName,
                displayName: displayName,
                fileName: canonical.fileName,
                isPreset: group.isPreset,
                variants: sortedVariants
            )
            entities.append(entity)
            
            for variant in sortedVariants {
                psMap[variant.postScriptName] = entity
            }
        }
        
        stateLock.lock()
        cachedFamilies = entities
        postScriptToFamilyMap = psMap
        isFamilyIndexBuilt = true
        capabilityCache.removeAll()
        stateLock.unlock()
        
        return entities
    }
    
    private func ensureIndexBuilt() {
        stateLock.lock()
        let built = isFamilyIndexBuilt
        stateLock.unlock()
        if !built {
            rebuildFontIndex()
        }
    }
    
    // 1. 获取所有已导入的字体家族（自动将同家族的多字重文件归类在一起）
    func loadSavedFonts() -> [CustomFontEntity] {
        return rebuildFontIndex()
    }
    
    // 2. 从文件 URL 提取字体的 PostScript 名字（不将整文件读入内存，适配小组件低内存限制）
    func getFontName(from url: URL) -> String? {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let firstDescriptor = descriptors.first,
              let postScriptName = CTFontDescriptorCopyAttribute(firstDescriptor, kCTFontNameAttribute) as? String else {
            return nil
        }
        return postScriptName
    }
    
    // 3. 注册所有已保存的字体（同时支持 Bundle 中的预设字体和 App Group 目录）
    func registerAllFonts() {
        for url in bundleFontURLs() {
            registerFont(at: url)
        }
        for url in userFontURLs() {
            registerFont(at: url)
        }
        rebuildFontIndex()
    }
    
    @discardableResult
    func registerFont(at url: URL) -> Bool {
        let standardizedPath = url.standardizedFileURL.path
        
        stateLock.lock()
        let alreadyRegistered = registeredFontPaths.contains(standardizedPath)
        stateLock.unlock()
        if alreadyRegistered {
            return true
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        
        if success {
            stateLock.lock()
            registeredFontPaths.insert(standardizedPath)
            capabilityCache.removeAll()
            isFamilyIndexBuilt = false
            stateLock.unlock()
            return true
        } else {
            let cfError = error?.takeRetainedValue()
            let nsError = cfError as Error? as NSError?
            if nsError?.domain == kCTFontManagerErrorDomain as String,
               nsError?.code == CTFontManagerError.alreadyRegistered.rawValue {
                stateLock.lock()
                registeredFontPaths.insert(standardizedPath)
                stateLock.unlock()
                return true
            }
            print("注册字体失败 (\(url.lastPathComponent)): \(cfError?.localizedDescription ?? "未知错误")")
            return false
        }
    }
    
    // 4. 导入新字体
    func importFont(from sourceURL: URL) -> Bool {
        guard let destDir = fontDirectoryURL else { return false }
        createDirectoryIfNeeded()
        
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }
        
        let destURL = destDir.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                var error: Unmanaged<CFError>?
                _ = CTFontManagerUnregisterFontsForURL(destURL as CFURL, .process, &error)
                stateLock.lock()
                registeredFontPaths.remove(destURL.standardizedFileURL.path)
                stateLock.unlock()
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            let ok = registerFont(at: destURL)
            rebuildFontIndex()
            return ok
        } catch {
            print("导入字体文件错误: \(error)")
            return false
        }
    }
    
    func deleteFont(fileName: String) {
        guard let destDir = fontDirectoryURL else { return }
        let fileURL = destDir.appendingPathComponent(fileName)
        
        var error: Unmanaged<CFError>?
        _ = CTFontManagerUnregisterFontsForURL(fileURL as CFURL, .process, &error)
        
        stateLock.lock()
        registeredFontPaths.remove(fileURL.standardizedFileURL.path)
        capabilityCache.removeAll()
        isFamilyIndexBuilt = false
        stateLock.unlock()
        
        try? FileManager.default.removeItem(at: fileURL)
        rebuildFontIndex()
    }
    
    func deleteFontFamily(_ family: CustomFontEntity) {
        guard !family.isPreset else { return }
        if family.variants.isEmpty {
            deleteFont(fileName: family.fileName)
            return
        }
        for variant in family.variants {
            deleteFont(fileName: variant.fileName)
        }
    }
    
    /// 根据任意变体 PostScript 名找到所属家族的代表性 PostScript 名（用于选择器对齐）
    func canonicalFontName(for postScriptName: String?) -> String? {
        guard let postScriptName, !postScriptName.isEmpty else { return nil }
        ensureIndexBuilt()
        stateLock.lock()
        let canonical = postScriptToFamilyMap[postScriptName]?.name ?? postScriptName
        stateLock.unlock()
        return canonical
    }
    
    // MARK: - 字体粗细能力探测与构造
    
    /// 查询指定字体的字重调节能力
    /// - 系统字体：100-900 九档离散调节
    /// - 自定义可变字体：读取内部 wght 轴范围无级调节
    /// - 自定义多文件静态家族：返回实际拥有的离散字重列表
    /// - 单个静态文件：fixed（不可调节）
    func weightCapability(for customFontName: String?) -> FontWeightCapability {
        guard let customFontName, !customFontName.isEmpty else {
            return .discrete(values: [100, 200, 300, 400, 500, 600, 700, 800, 900], defaultValue: 400)
        }
        
        ensureIndexBuilt()
        
        stateLock.lock()
        if let cached = capabilityCache[customFontName] {
            stateLock.unlock()
            return cached
        }
        let family = postScriptToFamilyMap[customFontName]
        stateLock.unlock()
        
        let targetPSName = family?.name ?? customFontName
        if UIFont(name: targetPSName, size: 17) == nil {
            registerAllFonts()
        }
        
        var resolvedCapability: FontWeightCapability = .fixed
        
        // 1. 先探测是否为可变字体（存在 wght 轴）
        if let baseFont = UIFont(name: targetPSName, size: 17) {
            let ctFont = baseFont as CTFont
            if let axes = CTFontCopyVariationAxes(ctFont) as? [[CFString: Any]] {
                for axis in axes {
                    guard let identifier = (axis[kCTFontVariationAxisIdentifierKey] as? NSNumber)?.uint32Value,
                          identifier == wghtAxisIdentifier,
                          let minValue = (axis[kCTFontVariationAxisMinimumValueKey] as? NSNumber)?.doubleValue,
                          let maxValue = (axis[kCTFontVariationAxisMaximumValueKey] as? NSNumber)?.doubleValue,
                          maxValue > minValue else {
                        continue
                    }
                    
                    let defaultValue = (axis[kCTFontVariationAxisDefaultValueKey] as? NSNumber)?.doubleValue ?? minValue
                    let clampedDefault = min(max(defaultValue, minValue), maxValue)
                    resolvedCapability = .variable(
                        min: CGFloat(minValue),
                        max: CGFloat(maxValue),
                        defaultValue: CGFloat(clampedDefault)
                    )
                    break
                }
            }
        }
        
        // 2. 若非可变字体，检查同一家族是否包含多个静态字重文件
        if resolvedCapability == .fixed, let family, family.variants.count > 1 {
            let weights = family.variants.map { $0.weight }.sorted()
            let defaultVal = weights.min(by: { abs($0 - 400) < abs($1 - 400) }) ?? weights[0]
            resolvedCapability = .discrete(values: weights, defaultValue: defaultVal)
        }
        
        stateLock.lock()
        capabilityCache[customFontName] = resolvedCapability
        stateLock.unlock()
        
        return resolvedCapability
    }
    
    /// 将 100-900 字重映射为 SwiftUI Font.Weight
    func swiftUIWeight(for weight: CGFloat) -> Font.Weight {
        switch Int(weight.rounded()) {
        case ..<150:     return .ultraLight // 100
        case 150..<250:  return .thin       // 200
        case 250..<350:  return .light      // 300
        case 350..<450:  return .regular    // 400
        case 450..<550:  return .medium     // 500
        case 550..<650:  return .semibold   // 600
        case 650..<750:  return .bold       // 700
        case 750..<850:  return .heavy      // 800
        default:         return .black      // 900
        }
    }
    
    /// 将 100-900 字重映射为 UIFont.Weight
    func uiFontWeight(for weight: CGFloat) -> UIFont.Weight {
        switch Int(weight.rounded()) {
        case ..<150:     return .ultraLight // 100
        case 150..<250:  return .thin       // 200
        case 250..<350:  return .light      // 300
        case 350..<450:  return .regular    // 400
        case 450..<550:  return .medium     // 500
        case 550..<650:  return .semibold   // 600
        case 650..<750:  return .bold       // 700
        case 750..<850:  return .heavy      // 800
        default:         return .black      // 900
        }
    }
    
    /// 标准 100-900 字重显示名称
    func discreteWeightDisplayName(for weight: CGFloat) -> String {
        switch Int(weight.rounded()) {
        case ..<150:     return "100 (Thin)"
        case 150..<250:  return "200 (ExtraLight)"
        case 250..<350:  return "300 (Light)"
        case 350..<450:  return "400 (Regular)"
        case 450..<550:  return "500 (Medium)"
        case 550..<650:  return "600 (Semibold)"
        case 650..<750:  return "700 (Bold)"
        case 750..<850:  return "800 (Heavy)"
        default:         return "900 (Black)"
        }
    }
    
    /// 构造应用了正确字重（包括可变字体 wght 轴 与 多文件静态字重选择）的 UIFont
    func resolvedUIFont(customFontName: String?, size: CGFloat, weight: CGFloat) -> UIFont {
        if let customFontName, !customFontName.isEmpty {
            ensureIndexBuilt()
            
            stateLock.lock()
            let family = postScriptToFamilyMap[customFontName]
            stateLock.unlock()
            
            // 若属于多文件静态家族，选择字重最接近的变体文件对应的 PostScript 名
            let targetPSName: String = {
                if let family, family.variants.count > 1 {
                    let matched = family.variants.min(by: { abs($0.weight - weight) < abs($1.weight - weight) })
                    return matched?.postScriptName ?? customFontName
                }
                return customFontName
            }()
            
            if UIFont(name: targetPSName, size: size) == nil {
                registerAllFonts()
            }
            if let baseFont = UIFont(name: targetPSName, size: size) {
                if case .variable(let minVal, let maxVal, _) = weightCapability(for: targetPSName) {
                    let clamped = min(max(weight, minVal), maxVal)
                    let variationDict: [NSNumber: NSNumber] = [
                        NSNumber(value: wghtAxisIdentifier): NSNumber(value: Double(clamped))
                    ]
                    let descriptor = CTFontDescriptorCreateWithAttributes([
                        kCTFontVariationAttribute: variationDict
                    ] as CFDictionary)
                    let variedCTFont = CTFontCreateCopyWithAttributes(baseFont as CTFont, size, nil, descriptor)
                    return variedCTFont as UIFont
                }
                return baseFont
            }
        }
        
        return UIFont.systemFont(ofSize: size, weight: uiFontWeight(for: weight))
    }
}
