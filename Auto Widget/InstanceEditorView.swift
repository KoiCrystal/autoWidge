//
//  InstanceEditorView.swift
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/8/30.
//

import SwiftUI
import AppIntents
import WidgetKit

struct InstanceEditorView: View {
    
    let existingInstance: WidgetDataSourceEntity?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    /// 💡 调色盘颜色状态（默认纯白）
    @State private var selectedColor: Color = .white
    @State private var selectedFontSize: CGFloat = 17
    @State private var currentText: String = "暂无文本"
    
    var onSaved: (String) -> Void
    
    init(existingInstance: WidgetDataSourceEntity? = nil, onSaved: @escaping (String) -> Void) {
        self.existingInstance = existingInstance
        self.onSaved = onSaved
        _name = State(initialValue: existingInstance?.name ?? "")
        
        if let instance = existingInstance {
            let all = WidgetInstanceQuery().loadAllInstances()
            if let latest = all.first(where: { $0.id == instance.id }) {
                _currentText = State(initialValue: latest.text ?? "暂无文本")
                _selectedFontSize = State(initialValue: latest.fontSize ?? 17)
                // 💡 如果有存过颜色 Hex，则解析加载
                if let colorHex = latest.backgroundColorName {
                    _selectedColor = State(initialValue: Color(hex: colorHex))
                }
            }
        }
    }
    
    private var isEditing: Bool {
        existingInstance != nil
    }
    
    private var previewEntry: SimpleEntry {
        let config = ConfigurationAppIntent()
        let mockEntity = WidgetDataSourceEntity(
            id: existingInstance?.id ?? "preview_id",
            name: name.isEmpty ? "小组件名称" : name,
            text: currentText,
            backgroundColorName: selectedColor.toHex(), //  转换为 Hex 存储
            fontSize: selectedFontSize
        )
        config.instance = mockEntity
        return SimpleEntry(date: Date(), configuration: config, text: currentText)
    }
    
    var body: some View {
        Form {
            // 名称输入
            Section {
                TextField("新建实例", text: $name, axis: .vertical)
                    .font(.system(size: 28, weight: .bold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(1...3)
                    .padding(.vertical, 6)
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .listRowBackground(Color.clear)
            
            // 小组件预览
            Section {
                VStack {
                    ShowWidgetEntryView(entry: previewEntry)
                        .frame(width: 160, height: 160)
                        .background {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(selectedColor)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        }
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .listSectionSeparator(.hidden)
            
            // 外观设置：使用系统调色盘 ColorPicker + 字号滑块
            Section("外观设置") {
                ColorPicker("背景颜色", selection: $selectedColor)
                
                VStack(alignment: .leading) {
                    Text("文字大小: \(Int(selectedFontSize)) pt")
                    Slider(value: $selectedFontSize, in: 12...32, step: 1)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    public func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        isSaving = true
        errorMessage = nil
        
        let query = WidgetInstanceQuery()
        var instances = query.loadAllInstances()
        let colorHex = selectedColor.toHex()
        
        if let existing = existingInstance {
            if let index = instances.firstIndex(where: { $0.id == existing.id }) {
                instances[index].name = trimmed
                instances[index].backgroundColorName = colorHex
                instances[index].fontSize = selectedFontSize
                
                query.saveInstances(instances)
                currentText = instances[index].text ?? "暂无文本"
                dismiss()
            } else {
                errorMessage = "更新失败：未找到该实例"
            }
        } else {
            let newInstance = WidgetDataSourceEntity(
                id: UUID().uuidString,
                name: trimmed,
                backgroundColorName: colorHex,
                fontSize: selectedFontSize
            )
            instances.append(newInstance)
            query.saveInstances(instances)
            currentText = "暂无文本"
            dismiss()
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        isSaving = false
    }
}


extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB (24位) -> #RRGGBB
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: // RGBA (32位) -> #RRGGBBAA
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
    
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        let a = Int(alpha * 255)
        
        return String(format: "#%02x%02x%02x%02x", r, g, b, a)
    }
}
