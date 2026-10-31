//
//  ShowWidgetBundle.swift
//  ShowWidget
//
//  Created by Zhaomin Wu & Jinyu Zhang on 2026/5/8.
//

import WidgetKit
import SwiftUI

@main
struct ShowWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShowWidget()
        ShowWidgetLiveActivity()
    }
}
