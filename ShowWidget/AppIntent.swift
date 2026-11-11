//
//  AppIntent.swift
//  ShowWidget
//
//  Created by Zhaomin Wu & Jinyu Zhang on 2026/5/8.
//

import AppIntents
import WidgetKit

// MARK: - 小组件实例实体
struct WidgetDataSourceEntity: AppEntity, Codable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "小组件实例"
    static var defaultQuery = WidgetInstanceQuery()

    var id: String
    var name: String
    var text: String?
    var updatedAt: Date?
    var textUpdatedAt: Date?    // 新增：专门记录快捷指令更新文本的时间
    var backgroundColorName: String? // color hex
    var backgroundType: String?    // 背景类型："system" (系统), "color" (自定义颜色), "image" (自定义图片)
    var backgroundImageName: String? // 共享容器中的图片文件名
    
    var fontSize: CGFloat?
    var fontWidth: CGFloat?
    var textColorType: String?     // 文字颜色类型 (是否跟随系统
    var textColorName: String?     // 文字颜色与透明度 hex (RGBA)
    var fontStyle: String?         // 字体样式 ("system", "monospaced", "serif", "rounded")
    var isLiquidGlass: Bool?       // 是否开启液态玻璃效果

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - 创建新实例的意图（不可在快捷指令中调用）
struct CreateWidgetInstanceIntent: AppIntent {
    static var title: LocalizedStringResource = "创建新的小组件实例"
    static var description = IntentDescription("创建一个可独立更新的小组件实例")
    static var isDiscoverable: Bool { false }

    @Parameter(title: "实例名称")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("创建名为 \(\.$name) 的小组件实例")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<WidgetDataSourceEntity> {
        let newInstance = WidgetDataSourceEntity(id: UUID().uuidString, name: name)
        var instances = WidgetInstanceQuery().loadAllInstances()
        instances.append(newInstance)
        WidgetInstanceQuery().saveInstances(instances)
        return .result(value: newInstance)
    }
}

// MARK: - 更新后的配置意图
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "配置小组件" }
    static var description: IntentDescription { "选择要显示的小组件实例" }

    @Parameter(title: "小组件实例")
    var instance: WidgetDataSourceEntity?
}

// MARK: - 查询与管理实例（增加线程安全与局部更新支持）
// MARK: - 查询与管理实例（跨进程安全版本）
struct WidgetInstanceQuery: EntityQuery {
    
    private let suiteName = "group.autowidget.app2widget"
    private let instancesKey = "widgetInstances"
    
    // 获取共享容器中的存储文件 URL
    private var storageURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("widget_instances.json")
    }
    
    func entities(for identifiers: [String]) async throws -> [WidgetDataSourceEntity] {
        let all = loadAllInstances()
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }
    
    func suggestedEntities() async throws -> [WidgetDataSourceEntity] {
        loadAllInstances()
    }
    
    func defaultResult() async -> WidgetDataSourceEntity? {
        loadAllInstances().first
    }
    
    // MARK: - 加载
    func loadAllInstances() -> [WidgetDataSourceEntity] {
        guard let url = storageURL else {
            return createDefaultIfNeeded()
        }
        
        var result: [WidgetDataSourceEntity] = []
        
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
            guard let data = try? Data(contentsOf: readURL),
                  let decoded = try? JSONDecoder().decode([WidgetDataSourceEntity].self, from: data) else {
                return
            }
            result = decoded
        }
        
        if result.isEmpty {
            return createDefaultIfNeeded()
        }
        return result
    }
    
    // MARK: - 保存（覆盖写）
    func saveInstances(_ instances: [WidgetDataSourceEntity]) {
        guard let url = storageURL else { return }
        
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
            if let data = try? JSONEncoder().encode(instances) {
                try? data.write(to: writeURL, options: .atomic)
            }
        }
    }
    
    // MARK: - 原子更新单个实例文本（核心修复）
    func updateInstanceText(id: String, text: String, date: Date) {
        guard let url = storageURL else { return }
        
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        // 使用 writing 权限，保证读改写是原子的
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
            // 1. 读取最新数据
            var instances: [WidgetDataSourceEntity] = []
            if let data = try? Data(contentsOf: writeURL),
               let decoded = try? JSONDecoder().decode([WidgetDataSourceEntity].self, from: data) {
                instances = decoded
            } else {
                // 文件不存在时创建默认实例
                instances = [WidgetDataSourceEntity(id: "default_widget_instance_id", name: "默认小组件")]
            }
            
            // 2. 修改目标实例
            if let index = instances.firstIndex(where: { $0.id == id }) {
                instances[index].text = text
                instances[index].textUpdatedAt = date
                
                // 3. 原子写回
                if let encoded = try? JSONEncoder().encode(instances) {
                    try? encoded.write(to: writeURL, options: .atomic)
                }
            }
        }
    }
    
    func deleteInstances(withIDs ids: Set<String>) {
        var instances = loadAllInstances()
        instances.removeAll { ids.contains($0.id) }
        saveInstances(instances)
    }
    
    // 辅助：创建默认实例
    private func createDefaultIfNeeded() -> [WidgetDataSourceEntity] {
        let defaultInstance = WidgetDataSourceEntity(id: "default_widget_instance_id", name: "默认小组件")
        saveInstances([defaultInstance])
        return [defaultInstance]
    }
}

// MARK: - 更新后的文本更新意图（使用原子化更新）
struct UpdateWidgetTextIntent: AppIntent {
    static var title: LocalizedStringResource = "更新小组件文本"
    static var description = IntentDescription("将文本写入指定的小组件实例")

    @Parameter(title: "目标实例")
    var instance: WidgetDataSourceEntity

    @Parameter(title: "文本内容")
    var shortcutText: String

    static var parameterSummary: some ParameterSummary {
        Summary("将 \(\.$instance) 的文本设置为 \(\.$shortcutText)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let query = WidgetInstanceQuery()
        
        // 调用新的原子化更新方法，避免并发覆盖
        query.updateInstanceText(id: instance.id, text: shortcutText, date: Date())
         
        // 只刷新对应的组件或者使用统一刷新
        WidgetCenter.shared.reloadAllTimelines()
        
        // 3. 💡 发送跨进程通知，告知主 App 文本已更新
        let notificationName = "com.autowidget.textUpdated.\(instance.id)"
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName as CFString),
            nil,
            nil,
            true
        )
        
        return .result(value: shortcutText)
    }
}
