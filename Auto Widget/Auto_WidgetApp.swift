//
//  Auto_WidgetApp.swift
//  Auto Widget
//
//  Created by Zhaomin Wu & Jinyu Zhang on 2026/5/8.
//

import SwiftUI
import WidgetKit

@main
struct Auto_WidgetApp: App {
    
    init() {
        // 💡 启动时注册所有自定义字体
        CustomFontManager.shared.registerAllFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
