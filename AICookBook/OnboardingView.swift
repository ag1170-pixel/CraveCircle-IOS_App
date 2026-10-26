//
//  OnboardingView.swift
//  CraveCircle (AICookBook)
//
//  First-run flow modeled on Osta's onboarding, re-skinned for CraveCircle:
//    welcome → goals → affirmation → per-goal explainer → when-decide → recipe-sources →
//    how-heard → cuisines → "awesome, we import from socials" → three share-sheet coachmarks →
//    kick off the real import (or jump into the app).
//
//  Cuisine picks still seed the recommender (RecommendationEngine.cuisines). The other picks are
//  stored on AppEnvironment for future personalization hooks — see completeOnboarding(cuisines:
//  goals:decisionTime:sources:hearAbout:).
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment

    @State private var step: Step = .welcome
    @State private var goals: Set<Goal> = []
    // .decisionTime step removed from the flow — kept the state nil-only so the migration path
    // doesn't need a schema change on anything that already stored the value.
    @State private var sources: Set<RecipeSource> = []
    @State private var hearAbout: HearAbout? = nil
    @State private var cuisines: Set<String> = []
    @State private var goalDetailIndex = 0   // for cycling through selected goals in .goalDetail

    private let cuisineColumns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            // Welcome owns its own hero — the small brand header would double up with the big
            // logo + wordmark in the middle, so skip the header on that step.
            if step != .welcome {
                header
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
            }

            Group {
                switch step {
                case .welcome:          welcome
                case .goals:            goalsStep
                case .goalsAffirmation: goalsAffirmation
                case .goalDetail:       goalDetail
                // .decisionTime was removed — "when do you usually decide what's for dinner" with
                // morning/lunch/evening options didn't make sense when the question is dinner.
                case .recipeSources:    recipeSourcesStep
                case .howHeard:         howHeardStep
                case .cuisinesStep:     cuisinesStep
                case .awesome:          awesome
                case .tutorialShare:    tutorialShare
                case .tutorialPanel:    tutorialPanel
                case .tutorialPickApp:  tutorialPickApp
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    // MARK: Header (brand + progress + back)

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ChefHatLogo(size: 28)
                Text("CraveCircle")
                    .font(AppFont.serif(22, weight: .bold)).italic()
                    .foregroundStyle(AppTheme.brand)
            }

            // Progress bar (continuous, like Osta). Hidden on the welcome slide.
            if step != .welcome {
                HStack(spacing: 10) {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.surface, in: Circle())
                            .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.hairline)
                            Capsule()
                                .fill(AppTheme.textPrimary)
                                .frame(width: geo.size.width * step.progress)
                                .animation(AppMotion.smooth, value: step)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    // MARK: Step 0 — welcome

    private var welcome: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            // Centered badge — big circular surface with the chef-hat logo. Matches the Figma
            // reference frame OB1 • Welcome: a grounded hero element, not just a logo floating.
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [AppTheme.brand.opacity(0.95), Color(hex: "E58BB8").opacity(0.95)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 160, height: 160)
                    .shadow(color: AppTheme.brand.opacity(0.25), radius: 20, y: 8)
                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: 112, height: 112)
                ChefHatLogo(size: 72)
            }
            VStack(spacing: 10) {
                Text("CraveCircle")
                    .font(AppFont.serif(38, weight: .bold)).italic()
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Your living cookbook. Save a reel, get a clean recipe, cook hands-free.")
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            Spacer()
            primaryButton("Let's make it yours") { advance(to: .goals) }
        }
        .padding(AppSpacing.lg)
    }

    // MARK: Step 1 — goals

    private var goalsStep: some View {
        onboardingPage(
            title: "What are your goals?",
            subtitle: "Select all that apply",
            primaryTitle: goals.isEmpty ? "Pick at least one" : "Continue",
            primaryDisabled: goals.isEmpty,
            primaryAction: { advance(to: .goalsAffirmation) }
        ) {
            VStack(spacing: 12) {
                ForEach(Goal.allCases) { goal in
                    optionRow(
                        emoji: goal.emoji,
                        label: goal.label,
                        selected: goals.contains(goal)
                    ) {
                        toggleGoal(goal)
                    }
                }
            }
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: Step 2 — "That's great!" affirmation

    private var goalsAffirmation: some View {
        return VStack(spacing: AppSpacing.lg) {
            Spacer()
            VStack(spacing: 10) {
                Text("That's great!")
                    .font(AppFont.display(30, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                // No fabricated statistics — we won't promise a success rate we haven't measured.
                Text(goals.count > 1
                     ? "We'll shape your feed around every goal you picked."
                     : "We'll shape your feed around the goal you picked.")
                    .font(AppFont.body(15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            affirmationBadge
                .padding(.vertical, AppSpacing.md)

            Text("We're here to help you with your goals 🤝")
                .font(AppFont.body(18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
            primaryButton("Show me how") { advance(to: .goalDetail) }
        }
        .padding(AppSpacing.lg)
    }

    private var affirmationBadge: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [AppTheme.brand, Color(hex: "E58BB8")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 190, height: 190)
            Circle()
                .fill(AppTheme.surface)
                .frame(width: 140, height: 140)
            Image(systemName: "fork.knife")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(AppTheme.brand)
        }
    }

    // MARK: Step 3 — per-goal explainer (one card per picked goal)

    private var goalDetail: some View {
        let picks = Goal.allCases.filter { goals.contains($0) }
        let goal = picks.indices.contains(goalDetailIndex) ? picks[goalDetailIndex] : picks.first
        let isLast = goalDetailIndex >= max(0, picks.count - 1)
        return VStack(spacing: AppSpacing.lg) {
            Spacer()
            VStack(spacing: 10) {
                Text(goal?.detailTitle ?? "Let's help you get started")
                    .font(AppFont.display(26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            goalDetailArt(goal: goal)
                .padding(.vertical, AppSpacing.sm)
            Text(goal?.detailSubtitle ?? "Small changes add up. We'll help you make them stick.")
                .font(AppFont.body(15))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
            primaryButton("Continue") {
                if isLast || picks.isEmpty {
                    advance(to: .recipeSources)
                } else {
                    Haptics.tap()
                    withAnimation(AppMotion.smooth) { goalDetailIndex += 1 }
                }
            }
        }
        .padding(AppSpacing.lg)
    }

    private func goalDetailArt(goal: Goal?) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [AppTheme.brand.opacity(0.9), Color(hex: "E58BB8").opacity(0.9)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 170, height: 170)
            Circle()
                .fill(AppTheme.surface)
                .frame(width: 120, height: 120)
            Text(goal?.emoji ?? "✨")
                .font(.system(size: 54))
        }
    }

    // MARK: Step 4 — recipe sources (previously came after decisionTime, which was removed)

    private var recipeSourcesStep: some View {
        onboardingPage(
            title: "Where do you currently get recipes from?",
            subtitle: "Select all that apply",
            primaryTitle: "Continue",
            primaryDisabled: sources.isEmpty,
            primaryAction: { advance(to: .howHeard) }
        ) {
            VStack(spacing: 12) {
                ForEach(RecipeSource.allCases) { src in
                    optionRow(emoji: src.emoji, label: src.label, selected: sources.contains(src)) {
                        toggleSource(src)
                    }
                }
            }
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: Step 6 — how did you hear

    private var howHeardStep: some View {
        onboardingPage(
            title: "How did you hear about us?",
            subtitle: nil,
            primaryTitle: "Continue",
            primaryDisabled: hearAbout == nil,
            primaryAction: { advance(to: .cuisinesStep) }
        ) {
            VStack(spacing: 12) {
                ForEach(HearAbout.allCases) { opt in
                    optionRow(emoji: opt.emoji, label: opt.label, selected: hearAbout == opt) {
                        Haptics.select()
                        withAnimation(AppMotion.snappy) { hearAbout = opt }
                    }
                }
            }
            .padding(.top, AppSpacing.md)
        }
    }

    // MARK: Step 7 — cuisines (grid)

    private var cuisinesStep: some View {
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
                LazyVGrid(columns: cuisineColumns, spacing: 10) {
                    ForEach(RecommendationEngine.cuisines, id: \.id) { c in
                        cuisineChip(id: c.id, label: c.label)
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            }

            primaryButton(cuisines.isEmpty ? "Pick at least one" : "Continue",
                          disabled: cuisines.isEmpty) {
                advance(to: .awesome)
            }
        }
        .padding(AppSpacing.lg)
    }

    private func cuisineChip(id: String, label: String) -> some View {
        let on = cuisines.contains(id)
        return Button {
            Haptics.select()
            withAnimation(AppMotion.snappy) {
                if on { cuisines.remove(id) } else { cuisines.insert(id) }
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

    // MARK: Step 8 — "Awesome!" — social imports intro

    private var awesome: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Text("Awesome!")
                    .font(AppFont.display(30, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                // Lists exactly what the importer accepts — see `ReelURL.isValid`. Pinterest is
                // supported via the generic web/photo path (pin → og:image → OCR / web importer).
                Text("CraveCircle can import cooking reels from Instagram, TikTok, YouTube, and recipe pins from Pinterest.")
                    .font(AppFont.body(15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }
            socialIconsRow
                .padding(.top, AppSpacing.md)
            phoneMockup(dim: false, chip: nil)
                .padding(.vertical, AppSpacing.sm)
            Spacer(minLength: 0)
            primaryButton("Show me how") { advance(to: .tutorialShare) }
        }
        .padding(AppSpacing.lg)
    }

    private var socialIconsRow: some View {
        // Icons must match what the importer actually accepts — see `ReelURL.isValid`.
        HStack(spacing: 14) {
            socialIcon(name: "camera.fill", color: Color(hex: "E1306C"))      // Instagram
            socialIcon(name: "music.note",  color: Color(hex: "111111"))      // TikTok
            socialIcon(name: "play.rectangle.fill", color: Color(hex: "FF0000")) // YouTube
            socialIcon(name: "pin.fill",   color: Color(hex: "E60023"))       // Pinterest
        }
    }

    private func socialIcon(name: String, color: Color) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.12))
            Image(systemName: name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 36, height: 36)
    }

    // MARK: Steps 9–11 — three share-sheet coachmarks

    private var tutorialShare: some View {
        tutorialPage(
            title: "Smart social media imports",
            chip: TutorialChip(text: "Tap here", align: .bottomCenter, yOffset: -40),
            phoneContent: .reel,
            primary: "Next"
        ) {
            advance(to: .tutorialPanel)
        }
    }

    private var tutorialPanel: some View {
        tutorialPage(
            title: "Smart social media imports",
            chip: TutorialChip(text: "Tap here", align: .bottomLeading, yOffset: -70),
            phoneContent: .sharePanel,
            primary: "Next"
        ) {
            advance(to: .tutorialPickApp)
        }
    }

    private var tutorialPickApp: some View {
        tutorialPage(
            title: "Pick CraveCircle",
            chip: TutorialChip(text: "Tap here", align: .topLeading, yOffset: 90),
            phoneContent: .appPicker,
            primary: "Try it now"
        ) {
            finishOnboarding(thenImport: true)
        }
    }

    private func tutorialPage(title: String,
                              chip: TutorialChip,
                              phoneContent: PhoneContent,
                              primary: String,
                              onPrimary: @escaping () -> Void) -> some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: 10) {
                Text(title)
                    .font(AppFont.display(26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                socialIconsRow
            }
            .padding(.top, AppSpacing.sm)

            phoneMockup(dim: true, chip: chip, content: phoneContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            primaryButton(primary, action: onPrimary)
            Button("Skip for now") {
                finishOnboarding(thenImport: false)
            }
            .font(AppFont.body(15, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(AppSpacing.lg)
    }

    // Overload used by `awesome` where no chip or dim is needed.
    private func phoneMockup(dim: Bool, chip: TutorialChip?) -> some View {
        phoneMockup(dim: dim, chip: chip, content: .reel)
    }

    private func phoneMockup(dim: Bool, chip: TutorialChip?, content: PhoneContent) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                )
            content.view
                .padding(14)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .opacity(dim ? 0.45 : 1)
            if let chip {
                chip.view
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: chip.align.alignment)
                    .padding(chip.align.padding)
                    .offset(y: chip.yOffset)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: 280)
        .aspectRatio(0.52, contentMode: .fit)
    }

    // MARK: Helpers — layout, options, buttons

    @ViewBuilder
    private func onboardingPage<Content: View>(
        title: String,
        subtitle: String?,
        primaryTitle: String,
        primaryDisabled: Bool,
        primaryAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppFont.display(26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.body(15))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.top, AppSpacing.lg)

            ScrollView(showsIndicators: false) {
                content()
            }

            primaryButton(primaryTitle, disabled: primaryDisabled, action: primaryAction)
        }
        .padding(AppSpacing.lg)
    }

    private func optionRow(emoji: String, label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(selected ? Color.white.opacity(0.9) : AppTheme.accentSoft)
                        .frame(width: 36, height: 36)
                    Text(emoji).font(.system(size: 20))
                }
                Text(label)
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundStyle(selected ? AppTheme.onAccent : AppTheme.textPrimary)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(selected ? AppTheme.accent : AppTheme.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.clear : AppTheme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
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

    // MARK: Navigation

    private func advance(to next: Step) {
        Haptics.tap()
        withAnimation(AppMotion.smooth) {
            step = next
            if next == .goalDetail { goalDetailIndex = 0 }
        }
    }

    private func goBack() {
        Haptics.tap()
        guard let prev = step.previous(goalsPicked: !goals.isEmpty) else { return }
        withAnimation(AppMotion.smooth) { step = prev }
    }

    private func finishOnboarding(thenImport: Bool) {
        Haptics.success()
        environment.completeOnboarding(
            cuisines: cuisines,
            goals: Set(goals.map(\.id)),
            decisionTime: nil,   // step removed; keep the arg so the env API doesn't move
            sources: Set(sources.map(\.id)),
            hearAbout: hearAbout?.id
        )
        if thenImport { environment.pendingImportRequest = true }
    }

    private func toggleGoal(_ g: Goal) {
        Haptics.select()
        withAnimation(AppMotion.snappy) {
            if goals.contains(g) { goals.remove(g) } else { goals.insert(g) }
        }
    }

    private func toggleSource(_ s: RecipeSource) {
        Haptics.select()
        withAnimation(AppMotion.snappy) {
            if sources.contains(s) { sources.remove(s) } else { sources.insert(s) }
        }
    }
}

// MARK: - Step model

private extension OnboardingView {
    enum Step: Hashable {
        case welcome, goals, goalsAffirmation, goalDetail
        case recipeSources, howHeard, cuisinesStep
        case awesome, tutorialShare, tutorialPanel, tutorialPickApp

        /// 0…1 progress for the top bar (welcome has no bar).
        var progress: CGFloat {
            switch self {
            case .welcome:          return 0
            case .goals:            return 0.10
            case .goalsAffirmation: return 0.18
            case .goalDetail:       return 0.28
            case .recipeSources:    return 0.46
            case .howHeard:         return 0.62
            case .cuisinesStep:     return 0.72
            case .awesome:          return 0.82
            case .tutorialShare:    return 0.88
            case .tutorialPanel:    return 0.93
            case .tutorialPickApp:  return 0.98
            }
        }

        func previous(goalsPicked: Bool) -> Step? {
            switch self {
            case .welcome:          return nil
            case .goals:            return .welcome
            case .goalsAffirmation: return .goals
            case .goalDetail:       return .goalsAffirmation
            case .recipeSources:    return goalsPicked ? .goalDetail : .goalsAffirmation
            case .howHeard:         return .recipeSources
            case .cuisinesStep:     return .howHeard
            case .awesome:          return .cuisinesStep
            case .tutorialShare:    return .awesome
            case .tutorialPanel:    return .tutorialShare
            case .tutorialPickApp:  return .tutorialPanel
            }
        }
    }
}

// MARK: - Option enums

private enum Goal: String, CaseIterable, Identifiable, Hashable {
    case improve, tryNew, healthier, organize, protein
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .improve:   return "👨‍🍳"
        case .tryNew:    return "🔍"
        case .healthier: return "🥗"
        case .organize:  return "📁"
        case .protein:   return "💪"
        }
    }

    var label: String {
        switch self {
        case .improve:   return "Improve cooking skills"
        case .tryNew:    return "Try new cuisines"
        case .healthier: return "Eat healthier"
        case .organize:  return "Organize recipes"
        case .protein:   return "Hit my protein goal"
        }
    }

    var detailTitle: String {
        switch self {
        case .improve:   return "Let's level up your cooking"
        case .tryNew:    return "Let's take you around the world"
        case .healthier: return "Let's eat lighter, together"
        case .organize:  return "Let's tidy your recipe collection"
        case .protein:   return "Let's hit that protein target"
        }
    }

    var detailSubtitle: String {
        switch self {
        case .improve:
            return "Hands-free cook mode, voice tips, and the technique behind every step."
        case .tryNew:
            return "A feed tuned to the cuisines you want to try, not the ones you already know."
        case .healthier:
            return "Nutrition on every recipe, with healthier swaps when it makes sense."
        case .organize:
            return "Collections, tags, and smart search so nothing you saved ever gets lost."
        case .protein:
            return "Protein-forward picks and macros per serving so you can plan your day."
        }
    }
}

// DecisionTime enum removed with the step — asking "when do you decide what's for dinner" with
// morning/lunch/evening options didn't make sense when the subject is dinner.

private enum RecipeSource: String, CaseIterable, Identifiable, Hashable {
    case social, websites, printed
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .social:   return "📱"
        case .websites: return "🌐"
        case .printed:  return "📓"
        }
    }

    var label: String {
        switch self {
        case .social:   return "Social media"
        case .websites: return "Recipe websites"
        case .printed:  return "Printed / handwritten"
        }
    }
}

private enum HearAbout: String, CaseIterable, Identifiable, Hashable {
    case friend, tiktok, google, instagram, appStore, other
    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .friend:    return "❤️"
        case .tiktok:    return "🎵"
        case .google:    return "🔎"
        case .instagram: return "📷"
        case .appStore:  return "🛍️"
        case .other:     return "❓"
        }
    }

    var label: String {
        switch self {
        case .friend:    return "Through a friend"
        case .tiktok:    return "TikTok"
        case .google:    return "Google Search"
        case .instagram: return "Instagram"
        case .appStore:  return "Search on App Store"
        case .other:     return "Other"
        }
    }
}

// MARK: - Tutorial chip + phone mockup content

private struct TutorialChip {
    enum Align {
        case bottomCenter, bottomLeading, topLeading
        var alignment: Alignment {
            switch self {
            case .bottomCenter:  return .bottom
            case .bottomLeading: return .bottomLeading
            case .topLeading:    return .topLeading
            }
        }
        var padding: CGFloat {
            switch self {
            case .bottomCenter:  return 24
            case .bottomLeading: return 20
            case .topLeading:    return 24
            }
        }
    }

    let text: String
    let align: Align
    let yOffset: CGFloat

    var view: some View {
        Text(text)
            .font(AppFont.body(14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [AppTheme.brand, Color(hex: "E58BB8")],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
    }
}

private enum PhoneContent {
    case reel, sharePanel, appPicker

    @ViewBuilder
    var view: some View {
        switch self {
        case .reel:        PhoneReel()
        case .sharePanel:  PhoneSharePanel()
        case .appPicker:   PhoneAppPicker()
        }
    }
}

private struct PhoneReel: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Posts").font(.system(size: 11, weight: .bold))
                    Text("cravecircle").font(.system(size: 9))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text("Follow").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.brand)
            }
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.accentSoft)
                .overlay(
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.brand.opacity(0.7))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 14) {
                Image(systemName: "heart")
                Image(systemName: "bubble.right")
                Image(systemName: "paperplane")
                Spacer()
                Image(systemName: "bookmark")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

private struct PhoneSharePanel: View {
    var body: some View {
        VStack(spacing: 8) {
            Capsule().fill(AppTheme.hairline).frame(width: 36, height: 4)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(0..<9, id: \.self) { _ in
                    VStack(spacing: 4) {
                        Circle().fill(AppTheme.accentSoft).frame(width: 36, height: 36)
                        Capsule().fill(AppTheme.hairline).frame(width: 30, height: 5)
                    }
                }
            }
            Spacer()
            HStack(spacing: 14) {
                shareIcon(name: "link", label: "Copy link")
                ZStack {
                    shareIcon(name: "square.and.arrow.up", label: "Share to…")
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.brand, lineWidth: 2)
                        .frame(width: 56, height: 68)
                }
                shareIcon(name: "plus.circle", label: "Story")
            }
        }
    }

    private func shareIcon(name: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.hairline, lineWidth: 1))
            Text(label).font(.system(size: 9)).foregroundStyle(AppTheme.textSecondary)
        }
    }
}

private struct PhoneAppPicker: View {
    var body: some View {
        VStack(spacing: 10) {
            Capsule().fill(AppTheme.hairline).frame(width: 36, height: 4)
            HStack(spacing: 10) {
                appTile(systemName: "paperplane.fill", color: Color(hex: "4F7CFF"), label: "AirDrop")
                ZStack {
                    appTile(systemName: "fork.knife", color: AppTheme.brand, label: "CraveCircle")
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.brand, lineWidth: 2)
                        .frame(width: 64, height: 82)
                }
                appTile(systemName: "message.fill", color: Color(hex: "4CD964"), label: "Messages")
                appTile(systemName: "envelope.fill", color: Color(hex: "007AFF"), label: "Mail")
            }
            VStack(spacing: 10) {
                row(icon: "eyeglasses", label: "Add to Reading List")
                row(icon: "book", label: "Add Bookmark")
                row(icon: "star", label: "Add to Favorites")
            }
            .padding(.top, AppSpacing.sm)
            Spacer()
        }
    }

    private func appTile(systemName: String, color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.15))
                .overlay(Image(systemName: systemName).font(.system(size: 20, weight: .semibold)).foregroundStyle(color))
                .frame(width: 52, height: 52)
            Text(label).font(.system(size: 9)).foregroundStyle(AppTheme.textSecondary).lineLimit(1)
        }
    }

    private func row(icon: String, label: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11))
            Spacer()
            Image(systemName: icon).font(.system(size: 12))
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }
}
