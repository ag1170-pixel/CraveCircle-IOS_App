//
//  LiveActivityPreviewScreen.swift
//  CraveCircle (AICookBook)
//
//  An IN-APP preview of the "recipe cooking" Live Activity — so you can see the Dynamic Island +
//  Lock Screen design and motion without a reel import (and without an Apple Developer Program).
//  Renders the same stages, brand art and transitions as the real widget; auto-cycles for the demo.
//

import SwiftUI

struct LiveActivityPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage: CookingImportAttributes.ContentState.Stage = .downloading
    @State private var playing = true

    private let coral = AppTheme.brand
    private let cream = Color(hex: "F6F3EC")
    private let order: [CookingImportAttributes.ContentState.Stage] = [.downloading, .transcribing, .extracting, .done]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                Text("A preview of how a reel import will appear on your Dynamic Island and Lock Screen. It cycles through the stages automatically.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)

                section("Dynamic Island — compact") { compactIsland }
                section("Dynamic Island — expanded") { expandedIsland }
                section("Lock Screen") { lockCard }

                controls
            }
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Cooking Island")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loop() }
    }

    // MARK: Sections

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .font(AppFont.label(11, weight: .bold)).tracking(0.8)
                .foregroundStyle(AppTheme.textTertiary)
            content()
        }
    }

    // Compact island: a black pill with the glyph on the left and a % / check on the right.
    private var compactIsland: some View {
        HStack {
            glyph(size: 26)
            Spacer()
            trailingStatus
        }
        .padding(.horizontal, 14)
        .frame(width: 210, height: 44)
        .background(Color.black, in: Capsule())
    }

    // Expanded island: glyph + title + stage + progress, on the black island surface.
    private var expandedIsland: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                glyph(size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("New recipe").font(AppFont.body(16, weight: .bold)).foregroundStyle(cream)
                    Text(stage.label).font(AppFont.body(13)).foregroundStyle(cream.opacity(0.7))
                        .contentTransition(.opacity)
                }
                Spacer()
                trailingStatus
            }
            bottomRow
        }
        .padding(16)
        .frame(maxWidth: 360)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .padding(.horizontal, AppSpacing.md)
    }

    private var lockCard: some View {
        HStack(spacing: 12) {
            glyph(size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("New recipe").font(AppFont.body(16, weight: .bold)).foregroundStyle(cream)
                Text(stage.label).font(AppFont.body(13)).foregroundStyle(cream.opacity(0.7))
                if stage != .done {
                    ProgressView(value: stage.progress).tint(coral).padding(.top, 2)
                }
            }
            Spacer(minLength: 4)
            if stage == .done {
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(coral)
            }
        }
        .padding(16)
        .frame(maxWidth: 360)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, AppSpacing.md)
    }

    @ViewBuilder private var bottomRow: some View {
        if stage == .done {
            Label("Tap to open your recipe", systemImage: "chevron.right")
                .font(AppFont.body(13, weight: .semibold)).foregroundStyle(coral)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ProgressView(value: stage.progress).tint(coral)
        }
    }

    @ViewBuilder private var trailingStatus: some View {
        if stage == .done {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(coral).font(.title3)
        } else {
            Text("\(Int(stage.progress * 100))%")
                .font(AppFont.body(13)).monospacedDigit().foregroundStyle(cream.opacity(0.7))
                .contentTransition(.numericText())
        }
    }

    private func glyph(size: CGFloat) -> some View {
        // Float (bob up/down) while cooking; hold still once the dish is Ready.
        let floats = stage != .done && stage != .failed && !reduceMotion
        return Group {
            if let name = stage.artImage, UIImage(named: name) != nil {
                Image(name).resizable().scaledToFit()
            } else {
                Image(systemName: stage.symbol).resizable().scaledToFit()
                    .foregroundStyle(coral).padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
        .modifier(FloatingBob(active: floats))
        .id(stage)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.72), value: stage)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: 8) {
                ForEach(order, id: \.self) { s in
                    Button {
                        playing = false
                        withAnimation(AppMotion.smooth) { stage = s }
                        Haptics.tap()
                    } label: {
                        Text(chipLabel(s))
                            .font(AppFont.body(13, weight: .semibold))
                            .foregroundStyle(stage == s ? AppTheme.onAccent : AppTheme.textPrimary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(stage == s ? AppTheme.accent : AppTheme.surface, in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: stage == s ? 0 : 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Button {
                playing.toggle(); Haptics.tap()
            } label: {
                Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                    .font(AppFont.body(14, weight: .semibold))
                    .foregroundStyle(AppTheme.accentInk)
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 4)
        }
        .padding(.top, AppSpacing.sm)
    }

    private func chipLabel(_ s: CookingImportAttributes.ContentState.Stage) -> String {
        switch s {
        case .downloading: "Reel"
        case .transcribing: "Listen"
        case .extracting: "Write"
        case .done: "Ready"
        case .failed: "Error"
        }
    }

    // Auto-advance through the stages for the demo.
    private func loop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.8))
            if Task.isCancelled { break }
            guard playing else { continue }
            withAnimation(reduceMotion ? nil : AppMotion.smooth) {
                let i = order.firstIndex(of: stage) ?? 0
                stage = order[(i + 1) % order.count]
            }
        }
    }
}

/// Gentle hover: bobs the view up and down forever while `active`, holding still otherwise.
private struct FloatingBob: ViewModifier {
    let active: Bool
    @State private var up = false
    func body(content: Content) -> some View {
        content
            .offset(y: active ? (up ? -5 : 5) : 0)
            .animation(active ? .easeInOut(duration: 0.95).repeatForever(autoreverses: true) : .default,
                       value: up)
            .onAppear { if active { up = true } }
    }
}

#Preview {
    LiveActivityPreviewScreen()
}
