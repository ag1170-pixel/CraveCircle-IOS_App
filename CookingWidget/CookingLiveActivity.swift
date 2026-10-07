//
//  CookingLiveActivity.swift
//  CookingWidget
//
//  The "recipe cooking" Live Activity — Dynamic Island (compact / minimal / expanded) + Lock Screen.
//  Brand-styled for the island's always-black surface: cream text + CraveCircle coral accent
//  (charcoal, the app's action color, is invisible here, so coral carries the identity). Minimal,
//  iOS-native. Stage-based: each import stage swaps the glyph, label and progress — ActivityKit
//  can't run continuous animations, so this is the lively-but-legal approach.
//

import SwiftUI
import WidgetKit
import ActivityKit

// Brand tokens for the dark system surface.
private enum DI {
    static let coral     = Color(red: 0xEA / 255, green: 0x5A / 255, blue: 0x38 / 255)
    static let cream     = Color(red: 0xF6 / 255, green: 0xF3 / 255, blue: 0xEC / 255)
    static let coralSoft = Color(red: 0xEA / 255, green: 0x5A / 255, blue: 0x38 / 255).opacity(0.18)
}

extension CookingImportAttributes.ContentState.Stage {
    /// Determinate progress per stage (ActivityKit won't animate a ring continuously, so we advance
    /// it on each stage update — honest and brand-tintable).
    var progress: Double {
        switch self {
        case .downloading:  0.20
        case .transcribing: 0.55
        case .extracting:   0.85
        case .done:         1.0
        case .failed:       0.0
        }
    }
}

/// Where a tap goes: the finished recipe when done, otherwise the in-app import progress.
private func cookingDeepLink(_ s: CookingImportAttributes.ContentState) -> URL {
    if s.stage == .done, let id = s.recipeId, !id.isEmpty {
        return URL(string: "cravecircle://recipe/\(id)")!
    }
    return URL(string: "cravecircle://import")!
}

struct CookingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookingImportAttributes.self) { context in
            // Lock Screen / banner
            CookingLockScreenView(state: context.state)
                .widgetURL(cookingDeepLink(context.state))
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    stageGlyph(s, size: 22, frame: 40)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if s.stage == .done {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3).foregroundStyle(DI.coral)
                    } else if s.stage != .failed {
                        Text("\(Int(s.stage.progress * 100))%")
                            .font(.caption).monospacedDigit()
                            .foregroundStyle(DI.cream.opacity(0.7))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.recipeTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DI.cream).lineLimit(1)
                        Text(s.stage.label)
                            .font(.caption).foregroundStyle(DI.cream.opacity(0.7)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if s.stage == .done {
                        Label("Tap to open your recipe", systemImage: "chevron.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(DI.coral)
                    } else if s.stage == .failed {
                        Text(s.message ?? "Try again from the app")
                            .font(.caption).foregroundStyle(DI.cream.opacity(0.7)).lineLimit(2)
                    } else {
                        ProgressView(value: s.stage.progress).tint(DI.coral)
                    }
                }
            } compactLeading: {
                Image(systemName: "fork.knife").foregroundStyle(DI.coral)
            } compactTrailing: {
                if s.stage == .done {
                    Image(systemName: "checkmark").foregroundStyle(DI.coral)
                } else {
                    Image(systemName: s.stage.symbol).foregroundStyle(DI.cream)
                }
            } minimal: {
                Image(systemName: s.stage == .done ? "checkmark" : "fork.knife")
                    .foregroundStyle(DI.coral)
            }
            .widgetURL(cookingDeepLink(s))
            .keylineTint(DI.coral)
        }
    }

    private func stageGlyph(_ s: CookingImportAttributes.ContentState, size: CGFloat, frame: CGFloat) -> some View {
        Image(systemName: s.stage.symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(DI.coral)
            .frame(width: frame, height: frame)
            .background(DI.coralSoft, in: Circle())
    }
}

// MARK: - Lock Screen / banner card

struct CookingLockScreenView: View {
    let state: CookingImportAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.stage.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DI.coral)
                .frame(width: 44, height: 44)
                .background(DI.coralSoft, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(state.recipeTitle)
                    .font(.headline).foregroundStyle(DI.cream).lineLimit(1)
                Text(state.stage.label)
                    .font(.subheadline).foregroundStyle(DI.cream.opacity(0.7)).lineLimit(1)
                if !state.stage.isTerminal {
                    ProgressView(value: state.stage.progress).tint(DI.coral)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 4)

            if state.stage == .done {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(DI.coral)
            }
        }
        .padding(14)
        .activityBackgroundTint(Color.black)
        .activitySystemActionForegroundColor(DI.cream)
    }
}
