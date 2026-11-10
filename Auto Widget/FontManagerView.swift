//
//  FontManagerView.swift
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/11/11.
//

import SwiftUI
import UniformTypeIdentifiers

struct FontManagerView: View {
    @State private var fonts: [CustomFontEntity] = []
    @State private var isImporterPresented = false
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            Section {
                if fonts.isEmpty {
                    ContentUnavailableView(
                        "暂无自定义字体",
                        systemImage: "textformat.abc",
                        description: Text("点击右上角加号导入 .ttf 或 .otf 字体文件")
                    )
                } else {
                    ForEach(fonts) { font in
                        VStack(alignment: .leading, spacing: 4) {
                            // 预览字体的实际效果
                            Text("Preview 预览效果: 0123456789")
                                .font(.custom(font.name, size: 18))
                            Text(font.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteFonts)
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
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
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onAppear {
            loadFonts()
        }
    }
    
    private func loadFonts() {
        fonts = CustomFontManager.shared.loadSavedFonts()
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        errorMessage = nil
        do {
            guard let selectedFile = try result.get().first else { return }
            let success = CustomFontManager.shared.importFont(from: selectedFile)
            if success {
                loadFonts()
            } else {
                errorMessage = "导入或注册字体失败，文件可能已损坏"
            }
        } catch {
            errorMessage = "选择文件出错: \(error.localizedDescription)"
        }
    }
    
    private func deleteFonts(at offsets: IndexSet) {
        for index in offsets {
            let font = fonts[index]
            CustomFontManager.shared.deleteFont(fileName: font.fileName)
        }
        loadFonts()
    }
}
