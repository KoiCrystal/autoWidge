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
    var backgroundColorName: String? // color hex
    var backgroundType: String?    // 背景类型："system" (跟随系统), "color" (自定义颜色), "image" (自定义图片)
    var backgroundImageName: String? // 共享容器中的图片文件名
    
    var fontSize: CGFloat?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - 查询与管理实例
struct WidgetInstanceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetDataSourceEntity] {
        let all = loadAllInstances()
        return identifiers.compactMap { id in
            all.first { $0.id == id }
        }
    }

    func suggestedEntities() async throws -> [WidgetDataSourceEntity] {
        loadAllInstances()
    }

    func defaultResult() async -> WidgetDataSourceEntity? {
        loadAllInstances().first
    }

    // 从共享 UserDefaults 加载全部实例
    func loadAllInstances() -> [WidgetDataSourceEntity] {
        let defaults = UserDefaults(suiteName: "group.autowidget.app2widget")
        guard let data = defaults?.data(forKey: "widgetInstances"),
              let decoded = try? JSONDecoder().decode([WidgetDataSourceEntity].self, from: data) else {
            // 首次运行时创建默认实例
            let defaultInstance = WidgetDataSourceEntity(id: "default_widget_instance_id", name: "默认小组件")
            saveInstances([defaultInstance])
            return [defaultInstance]
        }
        return decoded
    }

    func saveInstances(_ instances: [WidgetDataSourceEntity]) {
        let defaults = UserDefaults(suiteName: "group.autowidget.app2widget")
        if let data = try? JSONEncoder().encode(instances) {
            defaults?.set(data, forKey: "widgetInstances")
        }
    }
    
    func deleteInstances(withIDs ids: Set<String>) {
        var instances = loadAllInstances()

        // from offset to get id
        instances.removeAll { instance in
            ids.contains(instance.id)
        }

        saveInstances(instances)
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

// MARK: - 更新后的文本更新意图（现需指定实例）
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
        var instances = query.loadAllInstances()
        
        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[index].text = shortcutText
            instances[index].updatedAt = Date()
            query.saveInstances(instances)
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: shortcutText)
    }
}
