//
//  Auto_WidgetApp.swift
//  Auto Widget
//
//  Created by Jinyu Zhang & Zhaomin Wu on 2026/5/8.
//

import SwiftUI
import WidgetKit

@main
struct Auto_WidgetApp: App {
    
    init() {
            let mytext = "I love wzm"

            let sharedDefaults = UserDefaults(
                suiteName: "group.autowidget.app2widge"
            )

            sharedDefaults?.set(
                mytext,
                forKey: "widgetText"
            )

            WidgetCenter.shared.reloadAllTimelines()
        }
    
    var body: some Scene {
        WindowGroup {
            ContentView()

        }
    }
}
