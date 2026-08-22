//
//  AppIntent.swift
//  ShowWidget
//
//  Created by Jinyu Zhang on 2026/5/8.
//

import AppIntents
import WidgetKit

// MARK: - 小组件实例实体
struct WidgetInstanceEntity: AppEntity, Codable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "小组件实例"
    static var defaultQuery = WidgetInstanceQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - 查询与管理实例
struct WidgetInstanceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetInstanceEntity] {
        let all = loadAllInstances()
        return identifiers.compactMap { id in
            all.first { $0.id == id }
        }
    }

    func suggestedEntities() async throws -> [WidgetInstanceEntity] {
        loadAllInstances()
    }

    func defaultResult() async -> WidgetInstanceEntity? {
        loadAllInstances().first
    }

    // 从共享 UserDefaults 加载全部实例
    func loadAllInstances() -> [WidgetInstanceEntity] {
        let defaults = UserDefaults(suiteName: "group.autowidget.app2widge")
        guard let data = defaults?.data(forKey: "widgetInstances"),
              let decoded = try? JSONDecoder().decode([WidgetInstanceEntity].self, from: data) else {
            // 首次运行时创建默认实例
            let defaultInstance = WidgetInstanceEntity(id: UUID().uuidString, name: "默认小组件")
            saveInstances([defaultInstance])
            return [defaultInstance]
        }
        return decoded
    }

    func saveInstances(_ instances: [WidgetInstanceEntity]) {
        let defaults = UserDefaults(suiteName: "group.autowidget.app2widge")
        if let data = try? JSONEncoder().encode(instances) {
            defaults?.set(data, forKey: "widgetInstances")
        }
    }
}

// MARK: - 创建新实例的意图（可在快捷指令中调用）
struct CreateWidgetInstanceIntent: AppIntent {
    static var title: LocalizedStringResource = "创建新的小组件实例"
    static var description = IntentDescription("创建一个可独立更新的小组件实例")

    @Parameter(title: "实例名称")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("创建名为 \(\.$name) 的小组件实例")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<WidgetInstanceEntity> {
        let newInstance = WidgetInstanceEntity(id: UUID().uuidString, name: name)
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
    var instance: WidgetInstanceEntity?
}

// MARK: - 更新后的文本更新意图（现需指定实例）
struct UpdateWidgetTextIntent: AppIntent {
    static var title: LocalizedStringResource = "更新小组件文本"
    static var description = IntentDescription("将文本写入指定的小组件实例")

    @Parameter(title: "目标实例")
    var instance: WidgetInstanceEntity

    @Parameter(title: "文本内容")
    var shortcutText: String

    static var parameterSummary: some ParameterSummary {
        Summary("将 \(\.$instance) 的文本设置为 \(\.$shortcutText)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let defaults = UserDefaults(suiteName: "group.autowidget.app2widge")
        // 使用实例 ID 作为键的一部分，实现独立存储
        defaults?.set(shortcutText, forKey: "widgetText_\(instance.id)")
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: shortcutText)
    }
}
