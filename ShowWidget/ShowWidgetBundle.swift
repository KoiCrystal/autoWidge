//
//  ShowWidgetBundle.swift
//  ShowWidget
//
//  Created by Jinyu Zhang on 2026/5/8.
//

import WidgetKit
import SwiftUI

@main
struct ShowWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShowWidget()
        ShowWidgetControl()
        ShowWidgetLiveActivity()
    }
}
