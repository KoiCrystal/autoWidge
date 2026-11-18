//
//  ContentView.swift
//  Auto Widget
//
//  Created by Zhaomin Wu & Jinyu Zhang on 2026/5/8.
//

import SwiftUI
import AppIntents

struct ContentView: View {
    @State private var instances: [WidgetDataSourceEntity] = []
    @State private var searchText: String = ""
    @State private var message: String = ""
    
    // 用于 iPad / 大屏的选中状态管理
    @State private var selectedInstanceID: WidgetDataSourceEntity.ID?
    // 控制在 iPad/大屏上通过弹窗创建新实例
    @State private var isCreatingNew: Bool = false
    
    private var filteredInstances: [WidgetDataSourceEntity] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return instances
        }
        return instances.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // MARK: - 侧边栏 / 主列表 (Sidebar / Master)
            List(selection: $selectedInstanceID) {
                Section {
                    if filteredInstances.isEmpty {
                        ContentUnavailableView(
                            "暂无实例",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text(
                                searchText.isEmpty
                                ? "点击右上角按钮创建新的小组件实例"
                                : "未找到匹配的实例"
                            )
                        )
                    } else {
                        ForEach(filteredInstances, id: \.id) { instance in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(instance.name)
                                    .font(.headline)
                                
                                Text(instance.text ?? "暂无内容")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                            .tag(instance.id) // 绑定 Tag 以支持 SplitView 选中
                        }
                        .onDelete { offsets in
                            let ids = Set(
                                offsets.map { filteredInstances[$0].id }
                            )
                            
                            WidgetInstanceQuery().deleteInstances(withIDs: ids)
                            
                            refreshInstances()
                            
                            // 如果当前正处于选中状态的实例被删除了，清空选中项
                            if let selectedID = selectedInstanceID, ids.contains(selectedID) {
                                selectedInstanceID = nil
                            }
                        }
                    }
                }
                
                // 字体管理区块
                Section {
                    NavigationLink {
                        FontManagerView()
                    } label: {
                        Label("字体管理", systemImage: "textformat")
                            .font(.headline)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("小组件实例管理")
            .searchable(text: $searchText, prompt: "搜索")
            .toolbar {
                // 在 iPad/大屏或窄屏上均可方便点击的新增按钮
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isCreatingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            // MARK: - 详情/编辑右侧区块 (Detail)
            Group {
                if let selectedID = selectedInstanceID,
                   let instance = instances.first(where: { $0.id == selectedID }) {
                    // 选中实例时展示编辑界面，绑定 id 确保切换实例时完整刷新状态
                    InstanceEditorView(existingInstance: instance) { message in
                        self.message = message
                        refreshInstances()
                    }
                    .id(instance.id)
                } else {
                    // 未选中任何实例时（特别在 iPad 初始打开时）的空状态占位
                    ContentUnavailableView(
                        "未选择实例",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("请从左侧列表选择一个实例进行编辑，或点击右上角新建实例。")
                    )
                }
            }
        }
        // 顶部提示消息浮层
        .overlay(alignment: .top) {
            if !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        // 新建实例的模态弹窗（适配 iPad 弹窗或全屏 Form 体验）
        .sheet(isPresented: $isCreatingNew) {
            NavigationStack {
                InstanceEditorView { message in
                    self.message = message
                    refreshInstances()
                    isCreatingNew = false
                }
            }
        }
        .onAppear {
            refreshInstances()
        }
        .onChange(of: message) { _, newValue in
            guard !newValue.isEmpty else { return }
            
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                
                withAnimation {
                    message = ""
                }
            }
        }
    }
    
    private func refreshInstances() {
        instances = WidgetInstanceQuery().loadAllInstances()
    }
}

#Preview {
    ContentView()
}
