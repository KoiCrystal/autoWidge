//
//  CustomFontManager.swift
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/11/11.
//

import SwiftUI
import UIKit
import CoreText

struct CustomFontEntity: Identifiable, Codable {
    var id: String { "\(isPreset ? "preset_" : "user_")\(fileName)" }
    let name: String        // 字体实际的 PostScript 名字（用于 SwiftUI / UIKit 渲染）
    let displayName: String // 界面上显示的名称
    let fileName: String    // 保存的文件名
    var isPreset: Bool = false
}

enum FontWeightCapability: Equatable {
    /// 离散档位（例如系统字体的 100...900 九档）
    case discrete(values: [CGFloat], defaultValue: CGFloat)
    /// 无级连续可变（读取自字体内部的 wght 轴范围）
    case variable(min: CGFloat, max: CGFloat, defaultValue: CGFloat)
    /// 固定字重（非可变字体，不可调节）
    case fixed
}

class CustomFontManager {
    static let shared = CustomFontManager()
    
    // 使用 App Group 共享容器（确保小组件 Extension 也能用自定义字体）
    private let groupIdentifier = "group.autowidget.app2widget"
    
    // OpenType 'wght' 字重轴的 FourCC 标识
    private let wghtAxisIdentifier: UInt32 = 0x77676874
    
    // 💡 预设字体显示名称映射表
    // Key 可填写：完整文件名（如 "LXGWWenKai-Regular.ttf"）、不含后缀的文件名（如 "LXGWWenKai-Regular"）或 PostScript 名称
    // Value 为界面上显示的名称，以后添加新预设字体时直接在这里增加一行即可
    private let presetFontDisplayNames: [String: String] = [
        "ClawdMono": "爪迹等宽",
        "LXGWWenKaiGBLite-Medium": "霞鹜文楷",
    ]
    
    private let stateLock = NSLock()
    // 💡 记录已在内存中注册过的字体路径与名称，防止重复注册与重复 IO
    private var registeredFontPaths = Set<String>()
    private var registeredFontNames = Set<String>()
    private var capabilityCache: [String: FontWeightCapability] = [:]
    
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
    
    // 根据映射表解析预设字体的显示名称
    private func resolvePresetDisplayName(fileName: String, postScriptName: String) -> String {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let candidates = [fileName, baseName, postScriptName]
        
        for candidate in candidates {
            if let matched = presetFontDisplayNames.first(where: { $0.key.caseInsensitiveCompare(candidate) == .orderedSame }) {
                return matched.value
            }
        }
        return postScriptName
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
    
    // 1. 获取所有已导入的字体（同时支持 Bundle 中的预设字体和 App Group 目录）
    func loadSavedFonts() -> [CustomFontEntity] {
        var fonts: [CustomFontEntity] = []
        var seenNames = Set<String>()
        
        // A. 加载 Bundle 中的预设字体
        for url in bundleFontURLs() {
            if let fontName = getFontName(from: url), !seenNames.contains(fontName) {
                seenNames.insert(fontName)
                let fileName = url.lastPathComponent
                let displayName = resolvePresetDisplayName(fileName: fileName, postScriptName: fontName)
                fonts.append(CustomFontEntity(name: fontName, displayName: displayName, fileName: fileName, isPreset: true))
            }
        }
        
        // B. 加载 App Group 目录中的动态导入字体
        guard let url = fontDirectoryURL,
              let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return fonts
        }
        
        for file in files where file.pathExtension.lowercased() == "ttf" || file.pathExtension.lowercased() == "otf" {
            if let fontName = getFontName(from: file), !seenNames.contains(fontName) {
                seenNames.insert(fontName)
                fonts.append(CustomFontEntity(name: fontName, displayName: fontName, fileName: file.lastPathComponent, isPreset: false))
            }
        }
        
        return fonts
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
        // A. 自动注册 Bundle 中内置的预设字体
        for url in bundleFontURLs() {
            registerFont(at: url)
        }
        
        // B. 注册 App Group 目录中的动态导入字体
        guard let url = fontDirectoryURL,
              let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files where file.pathExtension.lowercased() == "ttf" || file.pathExtension.lowercased() == "otf" {
            registerFont(at: file)
        }
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
            let fontName = getFontName(from: url)
            stateLock.lock()
            registeredFontPaths.insert(standardizedPath)
            if let fontName {
                registeredFontNames.insert(fontName)
                capabilityCache.removeValue(forKey: fontName)
            }
            stateLock.unlock()
            return true
        } else {
            let cfError = error?.takeRetainedValue()
            let nsError = cfError as Error? as NSError?
            if nsError?.domain == kCTFontManagerErrorDomain as String,
               nsError?.code == CTFontManagerError.alreadyRegistered.rawValue {
                let fontName = getFontName(from: url)
                stateLock.lock()
                registeredFontPaths.insert(standardizedPath)
                if let fontName {
                    registeredFontNames.insert(fontName)
                }
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
            return registerFont(at: destURL)
        } catch {
            print("导入字体文件错误: \(error)")
            return false
        }
    }
    
    func deleteFont(fileName: String) {
        guard let destDir = fontDirectoryURL else { return }
        let fileURL = destDir.appendingPathComponent(fileName)
        let fontName = getFontName(from: fileURL)
        
        var error: Unmanaged<CFError>?
        _ = CTFontManagerUnregisterFontsForURL(fileURL as CFURL, .process, &error)
        
        stateLock.lock()
        registeredFontPaths.remove(fileURL.standardizedFileURL.path)
        if let fontName {
            registeredFontNames.remove(fontName)
            capabilityCache.removeValue(forKey: fontName)
        }
        stateLock.unlock()
        
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - 字体粗细能力探测与构造
    
    /// 查询指定字体的字重调节能力（系统字体返回 100-900 离散档位；自定义字体读取内部 wght 轴范围）
    func weightCapability(for customFontName: String?) -> FontWeightCapability {
        guard let customFontName, !customFontName.isEmpty else {
            return .discrete(values: [100, 200, 300, 400, 500, 600, 700, 800, 900], defaultValue: 400)
        }
        
        stateLock.lock()
        if let cached = capabilityCache[customFontName] {
            stateLock.unlock()
            return cached
        }
        stateLock.unlock()
        
        if UIFont(name: customFontName, size: 17) == nil {
            registerAllFonts()
        }
        
        guard let baseFont = UIFont(name: customFontName, size: 17) else {
            return .fixed
        }
        
        let ctFont = baseFont as CTFont
        var resolvedCapability: FontWeightCapability = .fixed
        
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
        case ..<150:     return "100 (UltraLight)"
        case 150..<250:  return "200 (Thin)"
        case 250..<350:  return "300 (Light)"
        case 350..<450:  return "400 (Regular)"
        case 450..<550:  return "500 (Medium)"
        case 550..<650:  return "600 (Semibold)"
        case 650..<750:  return "700 (Bold)"
        case 750..<850:  return "800 (Heavy)"
        default:         return "900 (Black)"
        }
    }
    
    /// 构造应用了正确字重（包括可变字体 wght 轴）的 UIFont
    func resolvedUIFont(customFontName: String?, size: CGFloat, weight: CGFloat) -> UIFont {
        if let customFontName, !customFontName.isEmpty {
            if UIFont(name: customFontName, size: size) == nil {
                registerAllFonts()
            }
            if let baseFont = UIFont(name: customFontName, size: size) {
                if case .variable(let minVal, let maxVal, _) = weightCapability(for: customFontName) {
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
