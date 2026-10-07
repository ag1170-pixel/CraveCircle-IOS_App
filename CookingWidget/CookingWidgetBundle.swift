//
//  CookingWidgetBundle.swift
//  CookingWidget
//
//  Entry point for the widget extension. Hosts the "recipe cooking" Live Activity.
//

import WidgetKit
import SwiftUI

@main
struct CookingWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickActionsWidget()
        CookingLiveActivity()
    }
}
