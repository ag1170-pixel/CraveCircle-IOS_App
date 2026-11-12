//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: CookingWidgetBundle.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Main entry point for all WidgetKit extensions.
//
// 2. ARCHITECTURAL ROLE:
//    Aggregates QuickActionsWidget and CookingLiveActivity into a unified WidgetBundle.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "CookingWidgetBundle exposes all our extension widgets and Live Activities to iOS through a single WidgetBundle."
//
// ==============================================================================
//

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
