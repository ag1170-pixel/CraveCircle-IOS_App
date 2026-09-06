//
//  ImportProgressScreen.swift
//  CraveCircle (AICookBook)
//
//  The Voiceprint pipeline, visualized. A reel becomes a recipe in four stages:
//  fetch caption/thumbnail → transcribe audio in ~60s chunks → extract recipe → ready.
//  Editorial, dark-first, lime accent. Honors Reduce Motion.
//

import SwiftUI

private enum ImportStage: Int, CaseIterable {
    case fetch, transcribe, extract, ready

    var title: String {
        switch self {
        case .fetch: return "Fetching reel"
        case .transcribe: return "Transcribing audio"
        case .extract: return "Extracting recipe"
        case .ready: return "Recipe ready"
        }
    }
    var subtitle: String {
        switch self {
        case .fetch: return "Caption, thumbnail & metadata"
        case .transcribe: return "In 60-second chunks"
        case .extract: return "Ingredients & steps"
        case .ready: return "Tap to open"
        }
    }
    var icon: String {
        switch self {
        case .fetch: return "arrow.down.circle"
        case .transcribe: return "waveform"
        case .extract: return "list.bullet.rectangle"
        case .ready: return "checkmark.seal.fill"
        }
    }
}

struct ImportProgressScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    var reopenImport: () -> Void
    // Demo overrides for previews / screenshots (nil in production).
    var demoStatus: ImportStatus? = nil
    var demoError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, AppSpacing.lg)
            .padding(.horizontal, AppSpacing.lg)

            headline
                .padding(.top, AppSpacing.md)
                .padding(.horizontal, AppSpacing.lg)

            VStack(spacing: 0) {
                ForEach(ImportStage.allCases, id: \.rawValue) { stage in
                    StageRow(
                        stage: stage,
                        state: state(for: stage),
                        isLast: stage == .ready,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)

            Spacer()
            footer.padding(AppSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AppTheme.background.ignoresSafeArea())
    }

    // MARK: Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isError ? (isNoContent ? "No recipe to read here" : "Import didn't finish")
                          : (isDone ? "It's ready" : "Cooking it up"))
                .font(AppFont.display(32, weight: .heavy))
                .foregroundStyle(AppTheme.textPrimary)
                .contentTransition(.numericText())
            Text(isError
                 ? (errorMessage ?? "That link didn't work — try another cooking reel.")
                 : (isDone ? "Your recipe is plated and waiting." : "Turning the reel into a recipe you can cook."))
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Footer actions

    @ViewBuilder private var footer: some View {
        if isError {
            VStack(spacing: AppSpacing.xs) {
                PillButton(title: isNoContent ? "Try another link" : "Try again",
                           systemImage: isNoContent ? "link" : "arrow.clockwise",
                           kind: .filled, fullWidth: true) {
                    environment.cancelImport(); reopenImport()
                }
                PillButton(title: "Close", kind: .outlined, fullWidth: true) {
                    environment.cancelImport()
                }
            }
        } else if isDone {
            PillButton(title: "Open recipe", systemImage: "arrow.right", kind: .filled, fullWidth: true) {
                let state = environment.importState
                dismiss() // This dismisses the progress sheet
                environment.cancelImport() // clear banner
                if case .done(let recipeId) = state {
                    if let rec = environment.recipes.first(where: { $0.id == recipeId }) {
                        // Give the sheet time to dismiss before triggering fullScreenCover
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            environment.selectRecipe(rec)
                        }
                    }
                }
            }
        } else {
            PillButton(title: "Cancel", kind: .outlined, fullWidth: true) {
                environment.cancelImport()
            }
        }
    }

    // MARK: State derivation

    private var currentStatus: ImportStatus {
        if let demoStatus { return demoStatus }
        switch environment.importState {
        case .submitting: return .queued
        case .polling(_, let s): return s
        case .done: return .done
        default: return .downloading
        }
    }
    private var isError: Bool {
        if demoError != nil { return true }
        if case .failed = environment.importState { return true }
        return false
    }
    private var isDone: Bool {
        if demoError != nil { return false }
        if demoStatus == .done { return true }
        if case .done = environment.importState { return true }
        return false
    }
    private var errorMessage: String? {
        if let demoError { return demoError }
        if case .failed(let m) = environment.importState { return m }
        return nil
    }
    /// A "we couldn't read a recipe here" outcome (vs. a real connection/system error) — this is
    /// normal for music-only / caption-less reels, so we present it calmly, not as a failure.
    private var isNoContent: Bool {
        guard let m = errorMessage?.lowercased() else { return false }
        return m.contains("couldn't find") || m.contains("no spoken") || m.contains("no recipe")
            || m.contains("readable") || m.contains("on-screen text") || m.contains("narrat")
            || m.contains("list the recipe")
    }

    private func currentIndex() -> Int {
        switch currentStatus {
        case .queued, .downloading: return 0
        case .transcribing: return 1
        case .extracting: return 2
        case .done: return 3
        case .error: return 1
        }
    }

    private func state(for stage: ImportStage) -> StageState {
        let cur = currentIndex()
        if isDone { return .done }
        if isError { return stage.rawValue == cur ? .failed : (stage.rawValue < cur ? .done : .pending) }
        if stage.rawValue < cur { return .done }
        if stage.rawValue == cur { return .active }
        return .pending
    }
}

// MARK: - Stage state + row

enum StageState { case pending, active, done, failed }

private struct StageRow: View {
    let stage: ImportStage
    let state: StageState
    let isLast: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(spacing: 4) {
                indicator
                if !isLast {
                    Rectangle()
                        .fill(state == .done ? AppTheme.accent : AppTheme.separator)
                        .frame(width: 2, height: connectorHeight)
                }
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(stage.title)
                    .font(AppFont.body(17, weight: .semibold))
                    .foregroundStyle(titleColor)
                Text(stage.subtitle)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textTertiary)
                if stage == .transcribe && state == .active {
                    ChunkBar(reduceMotion: reduceMotion).padding(.top, 8)
                }
            }
            .padding(.bottom, isLast ? 0 : AppSpacing.md)
            Spacer(minLength: 0)
        }
    }

    private var connectorHeight: CGFloat {
        stage == .transcribe && state == .active ? 62 : 30
    }

    private var titleColor: Color {
        switch state {
        case .pending: return AppTheme.textTertiary
        case .failed: return AppTheme.destructive
        default: return AppTheme.textPrimary
        }
    }

    @ViewBuilder private var indicator: some View {
        switch state {
        case .done:
            ZStack {
                Circle().fill(AppTheme.accent).frame(width: 30, height: 30)
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.onAccent)
            }
        case .active:
            PulsingDot(icon: stage.icon, reduceMotion: reduceMotion)
        case .failed:
            ZStack {
                Circle().fill(AppTheme.destructive).frame(width: 30, height: 30)
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            }
        case .pending:
            Circle().strokeBorder(AppTheme.separator, lineWidth: 2).frame(width: 30, height: 30)
                .overlay(Image(systemName: stage.icon).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary))
        }
    }
}

// MARK: - Active pulsing indicator

private struct PulsingDot: View {
    let icon: String
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().fill(AppTheme.accent.opacity(0.22))
                .frame(width: 30, height: 30)
                .scaleEffect(reduceMotion ? 1 : (pulse ? 1.5 : 1))
                .opacity(reduceMotion ? 1 : (pulse ? 0 : 0.9))
            Circle().fill(AppTheme.accent).frame(width: 30, height: 30)
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.onAccent)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

// MARK: - Chunked audio bar (the Voiceprint 60s-chunk visualization)

private struct ChunkBar: View {
    let reduceMotion: Bool
    private let count = 6
    @State private var active = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= active ? AppTheme.accent : AppTheme.surface)
                    .frame(height: 6)
                    .overlay(
                        Capsule().stroke(AppTheme.hairline.opacity(i <= active ? 0 : 1), lineWidth: 1)
                    )
                    .animation(.easeInOut(duration: 0.3), value: active)
            }
        }
        .frame(maxWidth: 220)
        .task {
            guard !reduceMotion else { active = count - 1; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(520))
                active = (active + 1) % (count + 1)
            }
        }
    }
}
