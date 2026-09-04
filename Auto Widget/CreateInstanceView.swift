//
//  CreateInstanceView.swift
//  Auto Widget
//
//  Created by Jinyu Zhang on 2026/8/30.
//

import SwiftUI
import AppIntents

struct CreateInstanceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    /// Called when creation succeeds. Receives the success message.
    var onCreated: (String) -> Void

    var body: some View {
        Form {
            Section {
                TextField("输入实例名称", text: $newName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("实例信息")
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await createInstance() }
                } label: {
                    HStack {
                        Spacer()
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("创建")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
            }
        }
        .navigationTitle("新建实例")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func createInstance() async {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        let intent = CreateWidgetInstanceIntent()
        intent.name = trimmedName

        do {
            let result = try await intent.perform()
            if let entity = result.value {
                onCreated("已成功创建：\(entity.name)")
                dismiss()
            } else {
                errorMessage = "创建失败：未返回有效结果"
            }
        } catch {
            errorMessage = "创建失败：\(error.localizedDescription)"
        }

        isCreating = false
    }
}
