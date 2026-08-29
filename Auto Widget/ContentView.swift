//
//  ContentView.swift
//  Auto Widget
//
//  Created by Jinyu Zhang & Zhaomin Wu on 2026/5/8.
//

import SwiftUI
import AppIntents

struct ContentView: View {
    @State private var newName: String = ""
    @State private var instances: [WidgetDataSourceEntity] = []
    @State private var message: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("输入实例名称", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Button("创建新实例") {
                    Task {
                        await createInstance()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)

                if !message.isEmpty {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                List(instances, id: \.id) { instance in
                    Text(instance.name)
                }
            }
            .padding()
            .navigationTitle("小组件实例管理")
            .onAppear {
                refreshInstances()
            }
        }
    }

    private func createInstance() async {
        let intent = CreateWidgetInstanceIntent()
        intent.name = newName.trimmingCharacters(in: .whitespaces)

        do {
            let result = try await intent.perform()
            if let entity = result.value {
                message = "已成功创建：\(entity.name)"
                newName = ""
                refreshInstances()
            }
        } catch {
            message = "创建失败：\(error.localizedDescription)"
        }
    }

    private func refreshInstances() {
        instances = WidgetInstanceQuery().loadAllInstances()
    }
}
