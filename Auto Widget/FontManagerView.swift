//
//  FontManagerView.swift
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/11/11.
//

import SwiftUI
import CoreText
import UniformTypeIdentifiers

struct FontManagerView: View {
    @State private var fonts: [CustomFontEntity] = []
    @State private var isImporterPresented = false
    @State private var errorMessage: String?
    
    private var presetFonts: [CustomFontEntity] {
        fonts.filter { $0.isPreset }
    }
    
    private var importedFonts: [CustomFontEntity] {
        fonts.filter { !$0.isPreset }
    }
    
    var body: some View {
        List {
            if fonts.isEmpty {
                Section {
                    ContentUnavailableView(
                        "暂无自定义字体",
                        systemImage: "textformat.abc",
                        description: Text("点击右上角加号导入 .ttf 或 .otf 字体文件")
                    )
                }
            } else {
                if !presetFonts.isEmpty {
                    Section("预设字体") {
                        ForEach(presetFonts) { font in
                            fontRow(font)
                        }
                    }
                }
                
                Section {
                    if importedFonts.isEmpty {
                        Text("点击右上角加号导入更多 .ttf 或 .otf 字体")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(importedFonts) { font in
                            fontRow(font)
                        }
                        .onDelete(perform: deleteFonts)
                    }
                } header: {
                    Text("已导入字体")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("字体管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    isImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.init(filenameExtension: "ttf")!, .init(filenameExtension: "otf")!],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .onAppear {
            loadFonts()
        }
    }
    
    @ViewBuilder
    private func fontRow(_ font: CustomFontEntity) -> some View {
        let previewUIFont = CustomFontManager.shared.resolvedUIFont(
            customFontName: font.name,
            size: 18,
            weight: 400
        )
        
        let capabilityText: String = {
            switch CustomFontManager.shared.weightCapability(for: font.name) {
            case .variable(let minVal, let maxVal, _):
                if maxVal - minVal >= 20 {
                    return "可变字重 \(Int(minVal.rounded()))–\(Int(maxVal.rounded()))"
                } else {
                    return String(format: "可变字重 %.1f–%.1f", minVal, maxVal)
                }
            case .discrete(let values, _):
                let labels = values.map { "\(Int($0.rounded()))" }.joined(separator: ", ")
                return "多文件字重 (\(labels))"
            case .fixed:
                return "固定字重"
            }
        }()
        
        let subtitle: String = {
            if font.variants.count > 1 {
                return "\(font.displayName) · \(font.variants.count) 个文件 · \(capabilityText)"
            }
            let base = font.displayName == font.name ? font.fileName : "\(font.displayName) (\(font.fileName))"
            return "\(base) · \(capabilityText)"
        }()
        
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview 预览效果: 0123456789")
                .font(Font(previewUIFont as CTFont))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func loadFonts() {
        CustomFontManager.shared.registerAllFonts()
        fonts = CustomFontManager.shared.loadSavedFonts()
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        errorMessage = nil
        do {
            let selectedFiles = try result.get()
            guard !selectedFiles.isEmpty else { return }
            var failedCount = 0
            for file in selectedFiles {
                if !CustomFontManager.shared.importFont(from: file) {
                    failedCount += 1
                }
            }
            loadFonts()
            if failedCount > 0 {
                errorMessage = "有 \(failedCount) 个字体导入或注册失败，文件可能已损坏"
            }
        } catch {
            errorMessage = "选择文件出错: \(error.localizedDescription)"
        }
    }
    
    private func deleteFonts(at offsets: IndexSet) {
        let targets = importedFonts
        for index in offsets {
            let font = targets[index]
            CustomFontManager.shared.deleteFontFamily(font)
        }
        loadFonts()
    }
}
