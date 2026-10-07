import SwiftUI

// MARK: - Root

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Group {
            if environment.appState == .loading {
                ProgressView("Loading CraveCircle...")
                    .tint(AppTheme.textPrimary)
                    .foregroundStyle(AppTheme.textPrimary)
            } else if environment.appState == .signedOut {
                LoginView()
            } else if environment.needsOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
        .task {
            if environment.appState == .loading {
                await environment.bootstrap()
            }
        }
        .alert("Something went wrong", isPresented: .constant(environment.errorMessage != nil), actions: {
            Button("OK") { environment.errorMessage = nil }
        }, message: {
            Text(environment.errorMessage ?? "")
        })
    }
}

// MARK: - Login

struct LoginView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var loading = false
    @State private var isSignUpMode = false
    @State private var inlineMessage: String?
    @State private var isError = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && (!isSignUpMode || !confirmPassword.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                form
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: AppSpacing.md) {
            ChefHatLogo(size: 132)
            VStack(spacing: 8) {
                Text("CraveCircle")
                    .font(AppFont.serif(42, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Your living cookbook.")
                    .font(AppFont.body(17, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
        .padding(.bottom, AppSpacing.lg)
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            LimeSegmentedControl(segments: ["Log In", "Sign Up"], selection: Binding(
                get: { isSignUpMode ? 1 : 0 },
                set: { isSignUpMode = ($0 == 1); inlineMessage = nil }
            ))
            .padding(.bottom, AppSpacing.xxs)

            field("Email", text: $email, icon: "envelope", secure: false, keyboard: .emailAddress)
            field("Password", text: $password, icon: "lock", secure: true)
            if isSignUpMode {
                field("Confirm password", text: $confirmPassword, icon: "lock.rotation", secure: true)
            }

            if let inlineMessage {
                Label(inlineMessage, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(AppFont.body(13, weight: .medium))
                    .foregroundStyle(isError ? AppTheme.destructive : AppTheme.accentInk)
            }

            submitButton.padding(.top, AppSpacing.xxs)

            googleButton
                .padding(.top, AppSpacing.sm)

            Button {
                Haptics.tap()
                environment.continueAsGuest()
            } label: {
                Text("Continue as Guest")
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.clear, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .padding(.top, AppSpacing.xs)
            .disabled(loading)
        }
        .padding(AppSpacing.lg)
    }

    private var submitButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(AppTheme.onAccent) }
                Text(loading
                     ? (isSignUpMode ? "Creating account…" : "Signing in…")
                     : (isSignUpMode ? "Create Account" : "Let's Cook"))
                    .font(AppFont.body(16, weight: .bold))
            }
            .foregroundStyle(AppTheme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(AppTheme.accent, in: Capsule())
            .opacity(canSubmit && !loading ? 1 : 0.5)
        }
        .buttonStyle(PressableStyle())
        .disabled(!canSubmit || loading)
    }

    private var googleButton: some View {
        Button {
            loading = true
            inlineMessage = nil
            Task {
                await environment.signInWithGoogle()
                loading = false
            }
        } label: {
            HStack(spacing: 10) {
                Text("G")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 1))
                Text("Continue with Google")
                    .font(AppFont.body(15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .disabled(loading)
    }

    // MARK: Field builder

    @ViewBuilder
    private func field(_ placeholder: String, text: Binding<String>, icon: String, secure: Bool, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 20)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(keyboard)
                }
            }
            .font(AppFont.body(16))
            .foregroundStyle(AppTheme.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 15)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    // MARK: Actions (logic unchanged)

    private func submit() {
        loading = true
        Task {
            if isSignUpMode {
                guard password == confirmPassword else {
                    inlineMessage = "Passwords do not match."
                    isError = true
                    loading = false
                    return
                }
                do {
                    try await environment.signUp(email: email, password: password)
                    inlineMessage = "Account created. Please log in."
                    isError = false
                    isSignUpMode = false
                    confirmPassword = ""
                } catch {
                    inlineMessage = error.localizedDescription
                    isError = true
                }
            } else {
                await environment.signIn(email: email, password: password)
            }
            loading = false
        }
    }
}

// MARK: - Tab configuration

enum TabItem: String, CaseIterable {
    case home = "HOME"
    case creators = "CREATORS"
    case kitchen = "KITCHEN"
    case profile = "PROFILE"
    case search = ""

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .creators: return "person.2.fill"
        case .kitchen: return "fork.knife"
        case .profile: return "person.crop.circle"
        case .search: return "magnifyingglass"
        }
    }
}

// MARK: - Main Tab Bar

struct MainTabView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showingImportSheet = false
    @State private var showingAddGrocery = false
    @State private var showingProgressDetail = false
    @State private var tab: AppTab = .home
    @State private var ignoreSwipeFrames: [CGRect] = []

    /// Osta-style floating + button, bottom-right. Context-aware: on the Grocery tab it opens
    /// "Add item to your list"; everywhere else it opens Add-a-recipe.
    private var importFAB: some View {
        Button {
            Haptics.tap()
            if tab == .groceries { showingAddGrocery = true } else { showingImportSheet = true }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Color(hex: "EA5A38"), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)   // plain drop shadow, no coral glow
        }
        .buttonStyle(PressableStyle())
        .padding(.trailing, 22)
        .padding(.bottom, 96)
        .accessibilityLabel(tab == .groceries ? "Add grocery item" : "Add a recipe")
    }

    var body: some View {
        // Instagram's iOS 26 bar is the system UITabBar: one floating Liquid Glass
        // platter, five equal icons, selection capsule drawn by UIKit, shrinks on scroll.
        // Instagram's iOS 26 bar is the system UITabBar: one floating Liquid Glass
        // platter (the "glass bubble"), five equal icons, selection capsule drawn by UIKit,
        // shrinks on scroll. This is Gowtham's original bar, restored verbatim.
        TabView(selection: $tab) {
            Tab(value: AppTab.home) {
                HomeScreen(showingImportSheet: $showingImportSheet)
            } label: {
                Image(systemName: AppTab.home.icon)
                    .accessibilityLabel(AppTab.home.title)
            }
            Tab(value: AppTab.discover) {
                // Discover is now the full-screen recipe reel (Instagram/TikTok style, Hinge swipes).
                // The old SearchScreen stays in the repo — search lives on Home now.
                RecipeReelScreen()
            } label: {
                Image(systemName: AppTab.discover.icon)
                    .accessibilityLabel(AppTab.discover.title)
            }
            Tab(value: AppTab.groceries) {
                GroceryScreen()
            } label: {
                Image(systemName: AppTab.groceries.icon)
                    .accessibilityLabel(AppTab.groceries.title)
            }
            Tab(value: AppTab.profile) {
                ProfileScreen()
            } label: {
                Image(systemName: AppTab.profile.icon)
                    .accessibilityLabel(AppTab.profile.title)
            }
        }
        // Osta-style: Import is a floating round button, not a tab (keeps the glassy 4-icon bar).
        // Import FAB everywhere EXCEPT Discover — the reel is immersive and the FAB would cover the rail.
        .overlay(alignment: .bottomTrailing) { if tab != .discover { importFAB } }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onPreferenceChange(HorizontalScrollFrameKey.self) { frames in
            // Keep track of horizontal scroll areas (like carousels on HomeScreen)
            ignoreSwipeFrames = frames
        }
        // ponytail: swipe-to-switch-tabs. We explicitly check ignoreSwipeFrames so that
        // horizontal ScrollViews (fresh/suggested/following) aren't overridden.
        .simultaneousGesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .global)
                .onEnded { value in
                    // If swipe started inside a horizontal scroll view, ignore it to let the scroll view handle it.
                    if ignoreSwipeFrames.contains(where: { $0.contains(value.startLocation) }) { return }
                    
                    let h = value.translation.width
                    let v = value.translation.height
                    // Only act on predominantly horizontal swipes.
                    guard abs(h) > abs(v) * 1.4 else { return }
                    if h < -50, let next = tab.next {
                        Haptics.select()
                        withAnimation(.easeOut(duration: 0.25)) { tab = next }
                    } else if h > 50, let prev = tab.previous {
                        Haptics.select()
                        withAnimation(.easeOut(duration: 0.25)) { tab = prev }
                    }
                }
        )
        .overlay(alignment: .top) {
            ImportToastBanner(onOpenDetails: { showingProgressDetail = true })
                .padding(.top, 46)
        }
        .sheet(isPresented: $showingImportSheet) {
            AddRecipeSheet(showing: $showingImportSheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.background)
        }
        .sheet(isPresented: $showingAddGrocery) {
            AddGroceryItemSheet()
                .presentationDetents([.height(180), .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.background)
        }
        .onChange(of: environment.pendingImportRequest) { _, requested in
            // Onboarding asked to import a first reel — open the sheet once, then clear the flag.
            if requested {
                showingImportSheet = true
                environment.pendingImportRequest = false
            }
        }
        .sheet(isPresented: $showingProgressDetail) {
            ImportProgressScreen(reopenImport: { showingImportSheet = true })
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.background)
        }
        .onChange(of: environment.importState) { _, state in
            // When an import is cancelled/cleared (Cancel, Close, or "View Recipe"), the state goes
            // back to .idle — close the progress sheet too. Without this the sheet stays up and,
            // because .idle renders as stage-0, shows a spinner forever ("buffering + Cancel dead").
            if state == .idle { showingProgressDetail = false }
        }
        .fullScreenCover(item: Binding(
            get: { environment.selectedRecipe },
            set: { _ in environment.dismissRecipeDetail() }
        )) { recipe in
            RecipeDetailPager(start: recipe)
                .environmentObject(environment)
        }
        .sheet(isPresented: $environment.showGuestPaywall) {
            GuestWallView(
                title: "Login Required",
                message: "You've viewed 10 recipes! Please log in or sign up to continue full access."
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }

        .task {
            if environment.recipes.isEmpty {
                await environment.refreshRecipes()
            }
        }
        .onChange(of: environment.pendingTabSwitch) { _, requested in
            guard let requested else { return }
            withAnimation(.easeOut(duration: 0.25)) { tab = requested }
            environment.pendingTabSwitch = nil
        }
    }
}

// MARK: - Floating Live Import Banner (Async / Non-Blocking)

struct ImportToastBanner: View {
    @EnvironmentObject private var environment: AppEnvironment
    var onOpenDetails: () -> Void

    var body: some View {
        if environment.importState != .idle {
            HStack(spacing: 12) {
                indicatorIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(AppFont.body(14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Text(subtitleText)
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                actionButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                AppTheme.surface
                    .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderStrokeColor, lineWidth: 1.5)
            )
            .padding(.horizontal, AppSpacing.md)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture {
                handleTap()
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: environment.importState)
        }
    }

    private var isDone: Bool {
        if case .done = environment.importState { return true }
        return false
    }

    private var isError: Bool {
        if case .failed = environment.importState { return true }
        return false
    }

    private var borderStrokeColor: Color {
        if isDone { return AppTheme.accent }
        if isError { return AppTheme.destructive }
        return AppTheme.hairline
    }

    private var titleText: String {
        switch environment.importState {
        case .submitting: return "Connecting to Kitchen..."
        case .polling(_, let status):
            switch status {
            case .queued: return "Queued in kitchen"
            case .downloading: return "Getting the reel..."
            case .transcribing: return "Listening to the video..."
            case .extracting: return "Writing your recipe..."
            case .done: return "Recipe Plated! ✨"
            case .error: return "Import Failed"
            }
        case .done:
            return "Recipe Plated! ✨"
        case .failed(let msg):
            return noContent(msg) ? "No recipe found" : "Import didn't finish"
        case .idle:
            return ""
        }
    }

    /// A calm "couldn't read a recipe" outcome vs. a real error (music/caption-less reels).
    private func noContent(_ m: String) -> Bool {
        let l = m.lowercased()
        return l.contains("couldn't find") || l.contains("no spoken") || l.contains("no recipe")
            || l.contains("readable") || l.contains("on-screen text") || l.contains("narrat")
            || l.contains("list the recipe") || l.contains("cooking video") || l.contains("enough for us to read")
    }

    private var subtitleText: String {
        switch environment.importState {
        case .submitting, .polling:
            return "Cooking in background · tap for details"
        case .done:
            return "Tap to open and start cooking"
        case .failed(let msg):
            return msg
        case .idle:
            return ""
        }
    }

    @ViewBuilder private var indicatorIcon: some View {
        switch environment.importState {
        case .done:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.accentInk)
        case .failed(let msg):
            Image(systemName: noContent(msg) ? "text.magnifyingglass" : "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(noContent(msg) ? AppTheme.textSecondary : AppTheme.destructive)
        default:
            ProgressView()
                .tint(AppTheme.accentInk)
                .scaleEffect(0.9)
        }
    }

    @ViewBuilder private var actionButton: some View {
        if isDone {
            Button {
                handleTap()
            } label: {
                HStack(spacing: 5) {
                    Text("View Recipe")
                        .font(AppFont.body(13, weight: .bold))
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(AppTheme.onAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        } else if isError {
            Button {
                environment.cancelImport()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                onOpenDetails()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func handleTap() {
        switch environment.importState {
        case .done(let recipeId):
            if let rec = environment.recipes.first(where: { $0.id == recipeId }) {
                environment.selectRecipe(rec)
            } else {
                environment.openRecipe(id: recipeId)   // fetch + open if it isn't in the local list yet
            }
            environment.cancelImport()
        case .failed:
            onOpenDetails()
        default:
            onOpenDetails()
        }
    }
}

