//
//  ContentView.swift
//  Auto Widget
//
//  Created by Jinyu Zhang & Zhaomin Wu on 2026/5/8.
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
                    ForEach(filteredInstances, id: \.id) { instance in
                        Text(instance.name)
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
            .listStyle(.insetGrouped)
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
                ToolbarItem(placement: .bottomBar) {
                    NavigationLink {
                        CreateInstanceView {
                            successMessage in message = successMessage
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


