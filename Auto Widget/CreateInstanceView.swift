//
//  CreateInstanceView.swift
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/8/30.
//

import SwiftUI
import AppIntents

struct InstanceEditorView: View {
    
    // 传入 nil 表示新建，传入已有实体表示编辑
    let existingInstance: WidgetDataSourceEntity?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    /// Called when creation succeeds. Receives the success message.
    var onSaved: (String) -> Void
    
    init(existingInstance: WidgetDataSourceEntity? = nil, onSaved: @escaping (String) -> Void) {
        self.existingInstance = existingInstance
        self.onSaved = onSaved
        _name = State(initialValue: existingInstance?.name ?? "")
    }
    
    private var isEditing: Bool {
        existingInstance != nil
    }

    var body: some View {
        Form {
            Section {
                TextField("输入实例名称", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
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
        .navigationTitle("新建实例")
        .navigationBarTitleDisplayMode(.inline)
    }

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
                onSaved("已成功更新：\(trimmed)")
                dismiss()
            } else {
                errorMessage = "更新失败：未找到该实例"
            }
        } else {
            // 新建模式
            let newInstance = WidgetDataSourceEntity(id: UUID().uuidString, name: trimmed)
            instances.append(newInstance)
            query.saveInstances(instances)
            onSaved("已成功创建：\(trimmed)")
            dismiss()
        }
        
        isSaving = false
    }
}
