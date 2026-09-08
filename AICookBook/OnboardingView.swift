//
//  OnboardingView.swift
//  CraveCircle (AICookBook)
//
//  First-run flow: welcome → pick the cuisines you love → optionally import a first reel.
//  The cuisine picks seed the recommender so the feed feels personal on day one (see
//  RecommendationEngine.cuisines), instead of a wall of recipes the user never added.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment

    @State private var step = 0
    @State private var selected: Set<String> = []

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, AppSpacing.lg)

            Group {
                switch step {
                case 0: welcome
                case 1: cuisines
                default: finish
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == step ? AppTheme.accent : AppTheme.hairline)
                    .frame(width: i == step ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: step)
            }
        }
    }

    // MARK: Step 0 — welcome

    private var welcome: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ChefHatLogo(size: 72)
            VStack(spacing: 10) {
                Text("CraveCircle")
                    .font(AppFont.serif(34, weight: .bold)).italic()
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Your living cookbook. Save a reel, get a clean recipe, cook hands-free.")
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            Spacer()
            primaryButton("Let's make it yours") { advance(to: 1) }
        }
        .padding(AppSpacing.lg)
    }

    // MARK: Step 1 — cuisines

    private var cuisines: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What do you love to cook?")
                    .font(AppFont.display(26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Pick a few — we'll make your feed yours.")
                    .font(AppFont.body(15))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.top, AppSpacing.lg)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(RecommendationEngine.cuisines, id: \.id) { c in
                        cuisineChip(id: c.id, label: c.label)
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            }

            primaryButton(selected.isEmpty ? "Pick at least one" : "Continue", disabled: selected.isEmpty) {
                advance(to: 2)
            }
        }
        .padding(AppSpacing.lg)
    }

    private func cuisineChip(id: String, label: String) -> some View {
        let on = selected.contains(id)
        return Button {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if on { selected.remove(id) } else { selected.insert(id) }
            }
        } label: {
            HStack(spacing: 6) {
                if on { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                Text(label).font(AppFont.body(15, weight: .semibold))
            }
            .foregroundStyle(on ? AppTheme.onAccent : AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(on ? AppTheme.accent : AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(on ? Color.clear : AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Step 2 — first recipe

    private var finish: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            VStack(spacing: 10) {
                Text("Your feed is ready")
                    .font(AppFont.display(28, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Add your first recipe now, or explore what we've lined up for you.")
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            Spacer()
            VStack(spacing: 10) {
                primaryButton("Import your first reel") { finishOnboarding(thenImport: true) }
                Button("Explore first") { finishOnboarding(thenImport: false) }
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
        }
        .padding(AppSpacing.lg)
    }

    // MARK: Helpers

    private func advance(to s: Int) {
        Haptics.tap()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = s }
    }

    private func finishOnboarding(thenImport: Bool) {
        Haptics.success()
        environment.completeOnboarding(cuisines: selected)
        if thenImport { environment.pendingImportRequest = true }
    }

    private func primaryButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body(17, weight: .bold))
                .foregroundStyle(AppTheme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(disabled ? AppTheme.accent.opacity(0.4) : AppTheme.accent, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled)
    }
}
