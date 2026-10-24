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
    
    // 传入 nil 表示新建，传入已有实体表示编辑
    let existingInstance: WidgetDataSourceEntity?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    /// 当前实例的最新文本（用于预览）
    @State private var currentText: String = "暂无文本"

    /// Called when creation succeeds. Receives the success message.
    var onSaved: (String) -> Void
    
    init(existingInstance: WidgetDataSourceEntity? = nil, onSaved: @escaping (String) -> Void) {
        self.existingInstance = existingInstance
        self.onSaved = onSaved
        _name = State(initialValue: existingInstance?.name ?? "")
        
        // 初始化时加载当前文本
        if let instance = existingInstance {
            let all = WidgetInstanceQuery().loadAllInstances()
            if let latest = all.first(where: { $0.id == instance.id }) {
                _currentText = State(initialValue: latest.text ?? "暂无文本")
            }
        }
    }
    
    private var isEditing: Bool {
        existingInstance != nil
    }
    
    /// 构造用于预览的 Entry
    private var previewEntry: SimpleEntry {
        let config = ConfigurationAppIntent()
        // 新建模式下没有真实 instance，预览时传 nil 即可
        config.instance = existingInstance
        return SimpleEntry(
            date: Date(),
            configuration: config,
            text: currentText
        )
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
                        .frame(width: 155, height: 155)
                        .background {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color(uiColor: .systemBackground))
                        }
                        .clipShape(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )
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

    // MARK: - 保存逻辑
    public func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        isSaving = true
        errorMessage = nil
        
        let query = WidgetInstanceQuery()
        var instances = query.loadAllInstances()
        
        if let existing = existingInstance {
            // 编辑模式：更新名称
            if let index = instances.firstIndex(where: { $0.id == existing.id }) {
                instances[index].name = trimmed
                query.saveInstances(instances)
                
                // 更新预览文本（名称变了不影响 text）
                currentText = instances[index].text ?? "暂无文本"
                

                dismiss()
            } else {
                errorMessage = "更新失败：未找到该实例"
            }
        } else {
            // 新建模式
            let newInstance = WidgetDataSourceEntity(id: UUID().uuidString, name: trimmed)
            instances.append(newInstance)
            query.saveInstances(instances)
            
            currentText = "暂无文本"
            dismiss()
        }
        
        // 通知小组件刷新
        WidgetCenter.shared.reloadAllTimelines()
        
        isSaving = false
    }
}
