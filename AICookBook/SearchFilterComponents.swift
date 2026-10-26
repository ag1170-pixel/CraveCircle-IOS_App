//
//  SearchFilterComponents.swift
//  CraveCircle (AICookBook)
//
//  Shared filter + chip UI used by the Home search bar. Lifted out of the old SearchScreen
//  when that screen was deleted during the cleanup pass; HomeScreen still binds to these
//  types directly. One file instead of five scattered `struct` declarations in a dead view.
//

import SwiftUI

/// "Why am I seeing this?" chip surfaced on suggested recipe cards.
struct SuggestionReasonChip: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles").font(.system(size: 9, weight: .semibold))
            Text(text).font(AppFont.body(11, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(AppTheme.accentInk)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(AppTheme.accent.opacity(0.12), in: Capsule())
    }
}

/// Veg vs non-veg classifier value.
enum DietMark { case veg, nonVeg }

/// The food-label mark: a green dot in a green box, or a red triangle in a red box.
struct DietMarkIcon: View {
    let mark: DietMark
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .stroke(tint, lineWidth: 1.5)
            switch mark {
            case .veg:
                Circle().fill(tint).padding(4)
            case .nonVeg:
                DietTriangle().fill(tint).padding(4)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

private struct DietTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Veg / non-veg switch: the boxed mark on the left, the knob on the right.
struct DietToggle: View {
    let mark: DietMark
    let tint: Color
    let isOn: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                DietMarkIcon(mark: mark, tint: tint)
                Capsule()
                    .fill(isOn ? tint : AppTheme.hairline)
                    .frame(width: 34, height: 20)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(AppTheme.surface)
                            .frame(width: 16, height: 16)
                            .padding(2)
                            .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Icon + title chip used in the search filter bar. Taps toggle `isOn`.
struct FilterChip: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(AppFont.body(12, weight: .semibold))
            }
            .foregroundStyle(isOn ? AppTheme.onAccent : AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isOn ? AppTheme.accent : AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(isOn ? Color.clear : AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}
