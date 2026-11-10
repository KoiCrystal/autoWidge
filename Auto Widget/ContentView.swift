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
    
    private var filteredInstances: [WidgetDataSourceEntity] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return instances
        }
        return instances.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            // MARK: - Instance List
            List {
                
                
                // 实例列表区块
                Section {
                    if filteredInstances.isEmpty {
                        ContentUnavailableView(
                            "暂无实例",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text(
                                searchText.isEmpty
                                ? "点击右下角按钮创建新的小组件实例"
                                : "未找到匹配的实例"
                            )
                        )
                    } else {
                        // 列表点击进入编辑
                        ForEach(filteredInstances, id: \.id) { instance in
                            NavigationLink {
                                InstanceEditorView(existingInstance: instance) { message in
                                    self.message = message
                                    refreshInstances()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(instance.name)
                                        .font(.headline)
                                   
                                    // 显示当前文本，如果没有内容则显示灰色提示
                                    Text(instance.text ?? "暂无内容")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary) // 次要文本色
                                        .lineLimit(1) // 限制只显示单行，避免文本太长撑乱布局
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { offsets in
                            let ids = Set(
                                offsets.map { filteredInstances[$0].id }
                            )
                           
                            WidgetInstanceQuery().deleteInstances(withIDs: ids)
                           
                            refreshInstances()
                        }
                    }
                }
                
                // 💡 新增：将字体管理独立为单独的一行/区块，不再挤在底部工具栏
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
            // 取消列表后的小箭头
            .navigationLinkIndicatorVisibility(.hidden)
            .navigationTitle("小组件实例管理")
            .overlay(alignment: .top) {
                if !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
            .searchable(text: $searchText, prompt: "搜索")
            
            .toolbar {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.flexible, placement: .bottomBar)
               
                // 底部仅保留创建新实例的加号按钮
                ToolbarItem(placement: .bottomBar) {
                    NavigationLink {
                        InstanceEditorView { message in
                            self.message = message
                            refreshInstances()
                        }
                    } label: {
                        Image(systemName: "plus")
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
    }
    
    private func refreshInstances() {
        instances = WidgetInstanceQuery().loadAllInstances()
    }
}

#Preview {
    ContentView()
}
