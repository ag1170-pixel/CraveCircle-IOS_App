//
//  View+DoodleBackground.swift
//  CraveCircle (AICookBook)
//
//  Attach the static food-doodle wallpaper behind a screen's content.
//

import SwiftUI

extension View {
    /// Static food-doodle wallpaper behind this screen's content.
    func doodleScreenBackground() -> some View {
        background(DoodleWallpaper())
    }
}
