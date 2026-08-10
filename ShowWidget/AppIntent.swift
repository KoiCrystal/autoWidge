//
//  AppIntent.swift
//  ShowWidget
//
//  Created by Jinyu Zhang on 2026/5/8.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}

struct UpdateWidgetTextIntent: AppIntent {
    // 在快捷指令或者siri 中添加更新小组件的操作控制
    static var title: LocalizedStringResource = "更新小组件文本"
    static var description = IntentDescription("接收快捷指令的文本输入并更新小组件显示的内容")

    // 快捷指令传入的文本结果
    @Parameter(title: "文本内容")
    var shortcutText: String

    static var parameterSummary: some ParameterSummary {
        Summary("将小组件文本设置为 \(\.$shortcutText)")
    }

    // some IntentResult & ReturnsValue<String>：定义函数的返回值类型。它既是一个标准的 Intent 执行结果（IntentResult），同时会把执行完毕后的文本（ReturnsValue<String>）传递回快捷指令流，供后续的快捷指令步骤继续使用。
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let sharedDefaults = UserDefaults(suiteName: "group.autowidget.app2widge")
        sharedDefaults?.set(shortcutText, forKey: "widgetText")
        
        // 通知系统刷新所有小组件
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result(value: shortcutText)
    }
}
