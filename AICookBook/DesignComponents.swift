//
//  DesignComponents.swift
//  CraveCircle (AICookBook)
//
//  Reusable Fusion primitives: pill buttons, a custom lime segmented control,
//  checkable rows, glass overlay buttons, chips, and haptics.
//

import SwiftUI
import UIKit

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func toggle(_ on: Bool) {
        UIImpactFeedbackGenerator(style: on ? .medium : .soft).impactOccurred()
    }
}

// MARK: - Pill button

struct PillButton: View {
    enum Kind { case filled, outlined, glass }

    let title: String
    var systemImage: String? = nil
    var kind: Kind = .filled
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 15, weight: .bold)) }
                Text(title).font(AppFont.body(16, weight: .bold))
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(border)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private var foreground: Color {
        switch kind {
        case .filled: return AppTheme.onAccent
        case .outlined, .glass: return AppTheme.textPrimary
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .filled: Capsule().fill(AppTheme.accent)
        case .outlined: Capsule().fill(.clear)
        case .glass: Capsule().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder private var border: some View {
        if kind == .outlined {
            Capsule().stroke(AppTheme.hairline, lineWidth: 1.5)
        }
    }
}

/// Scale-and-dim press feedback, spring release.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(AppMotion.snappy, value: configuration.isPressed)
    }
}

// MARK: - Glass overlay icon button (over photography)

struct GlassIconButton: View {
    let systemImage: String
    var size: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 0.5))
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Custom lime segmented control

struct LimeSegmentedControl: View {
    let segments: [String]
    @Binding var selection: Int
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments.indices, id: \.self) { i in
                let isSelected = selection == i
                Button {
                    Haptics.select()
                    withAnimation(AppMotion.snappy) { selection = i }
                } label: {
                    Text(segments[i])
                        .font(AppFont.body(15, weight: .bold))
                        .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            if isSelected {
                                Capsule().fill(AppTheme.accent)
                                    .matchedGeometryEffect(id: "seg", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppTheme.surface, in: Capsule())
    }
}

// MARK: - Checkable rows

/// Ingredient row — radio circle leading, strikethrough + muted when checked.
struct IngredientRow: View {
    let text: String
    let checked: Bool
    let toggle: () -> Void

    var body: some View {
        Button {
            Haptics.toggle(!checked)
            toggle()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(checked ? AppTheme.accentInk : AppTheme.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
                Text(text)
                    .font(AppFont.body(17))
                    .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(checked, color: AppTheme.textTertiary)
                    .animation(nil, value: checked)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Direction step — mono accent number, body text, trailing checkbox.
struct DirectionRow: View {
    let index: Int
    let text: String
    let checked: Bool
    let toggle: () -> Void

    var body: some View {
        Button {
            Haptics.toggle(!checked)
            toggle()
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Text(String(format: "%02d", index))
                    .font(AppFont.mono(15, weight: .bold))
                    .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.accentInk)
                    .padding(.top, 2)
                Text(text)
                    .font(AppFont.body(17))
                    .foregroundStyle(checked ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .strikethrough(checked, color: AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(checked ? AppTheme.accentInk : AppTheme.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meta chip

struct MetaChip: View {
    var systemImage: String? = nil
    let text: String
    var emphasized: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 13, weight: .semibold))
            }
            Text(text).font(AppFont.body(14, weight: .semibold))
        }
        .foregroundStyle(emphasized ? AppTheme.onAccent : AppTheme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(emphasized ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(AppTheme.surface), in: Capsule())
    }
}

// MARK: - Creator Avatar Monogram

struct CreatorAvatarView: View {
    let handle: String?
    var size: CGFloat = 36
    var showBorder: Bool = true

    private var initials: String {
        guard let raw = handle?.replacingOccurrences(of: "@", with: "").trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "CC"
        }
        let clean = raw.replacingOccurrences(of: "_", with: ".").replacingOccurrences(of: " ", with: ".")
        let parts = clean.split(separator: ".").filter { !$0.isEmpty }
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        }
        return String(clean.prefix(2)).uppercased()
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "3A3835"), Color(hex: "1F1E1B")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(AppFont.serif(size * 0.40, weight: .bold))
                    .foregroundStyle(.white)
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.4), lineWidth: showBorder ? 1.2 : 0)
            )
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
    }
}

