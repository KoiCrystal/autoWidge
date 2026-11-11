//
//  CustomFontManager.swift
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/11/11.
//

import SwiftUI
import CoreText

struct CustomFontEntity: Identifiable, Codable {
    var id: String { fileName }
    let name: String     // 字体实际的 PostScript 名字（用于 SwiftUI 渲染）
    let fileName: String // 保存的文件名
}

class CustomFontManager {
    static let shared = CustomFontManager()
    
    // 使用 App Group 共享容器（确保小组件 Extension 也能用自定义字体）
    private let groupIdentifier = "group.autowidget.app2widget"
    
    // 💡 记录已在内存中注册过的字体，防止重复注册报错
    private var registeredFontNames = Set<String>()
    
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
    
    // 1. 获取所有已导入的字体
    func loadSavedFonts() -> [CustomFontEntity] {
        guard let url = fontDirectoryURL,
              let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var fonts: [CustomFontEntity] = []
        for file in files where file.pathExtension.lowercased() == "ttf" || file.pathExtension.lowercased() == "otf" {
            if let fontName = getFontName(from: file) {
                fonts.append(CustomFontEntity(name: fontName, fileName: file.lastPathComponent))
            }
        }
        return fonts
    }
    
    // 2. 从文件 URL 提取字体的 PostScript 名字
    func getFontName(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider),
              let postScriptName = cgFont.postScriptName as String? else {
            return nil
        }
        return postScriptName
    }
    
    // 3. 注册所有已保存的字体（轻量安全，只在进程内存中注册一次）
    func registerAllFonts() {
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
        guard let data = try? Data(contentsOf: url),
              let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider) else {
            return false
        }
        
        let fontName = (cgFont.postScriptName as String?) ?? url.lastPathComponent
        if registeredFontNames.contains(fontName) {
            return true
        }

        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(cgFont, &error)

        if success {
            registeredFontNames.insert(fontName)
            return true
        } else {
            // 如果已注册过，也视作成功
            registeredFontNames.insert(fontName)
            return true
        }
    }
    
    // 4. 导入新字体
    func importFont(from sourceURL: URL) -> Bool {
        guard let destDir = fontDirectoryURL else { return false }
        
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }
        
        let destURL = destDir.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
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

        if let data = try? Data(contentsOf: fileURL),
           let provider = CGDataProvider(data: data as CFData),
           let cgFont = CGFont(provider) {
            var error: Unmanaged<CFError>?
            _ = CTFontManagerUnregisterGraphicsFont(cgFont, &error)
            if let fontName = cgFont.postScriptName as String? {
                registeredFontNames.remove(fontName)
            }
        }

        try? FileManager.default.removeItem(at: fileURL)
    }
}
