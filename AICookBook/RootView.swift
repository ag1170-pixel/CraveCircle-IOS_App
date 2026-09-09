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
    @State private var showingProgressDetail = false
    @State private var tab: AppTab = .home
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            Tab(value: AppTab.studio) {
                StudioScreen()
            } label: {
                Image(systemName: AppTab.studio.icon)
                    .accessibilityLabel(AppTab.studio.title)
            }
            Tab(value: AppTab.groceries) {
                GroceryScreen()
            } label: {
                Image(systemName: AppTab.groceries.icon)
                    .accessibilityLabel(AppTab.groceries.title)
            }
            Tab(value: AppTab.search) {
                NavigationStack { SearchScreen() }
            } label: {
                Image(systemName: AppTab.search.icon)
                    .accessibilityLabel(AppTab.search.title)
            }
            Tab(value: AppTab.profile) {
                ProfileScreen()
            } label: {
                Image(systemName: AppTab.profile.icon)
                    .accessibilityLabel(AppTab.profile.title)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // Swipe between tabs on top of the system glass bar: swipe left → next feature
        // (Home→Studio→Grocery→Search→Profile), right → previous. Runs simultaneously with
        // scrolls; only a decisive, clearly-horizontal swipe flips the tab, so vertical scrolls
        // and the card rails are left alone.
        .simultaneousGesture(tabSwipe())
        .overlay(alignment: .top) {
            ImportToastBanner(onOpenDetails: { showingProgressDetail = true })
                .padding(.top, 46)
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportSheet(showing: $showingImportSheet)
                .presentationDetents([.height(470)])
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

    /// Horizontal swipe to change tabs, layered over the system glass bar. Requires a decisive,
    /// clearly-horizontal drag so it doesn't trigger on vertical scrolls or the horizontal card
    /// rails inside Home/Studio/Search. Swipe left → next tab, right → previous (Instagram-style).
    private func tabSwipe() -> some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 90, abs(dx) > abs(dy) * 2.5 else { return }
                let order = AppTab.allCases
                guard let i = order.firstIndex(of: tab) else { return }
                let next = dx < 0 ? i + 1 : i - 1     // swipe left → next, right → previous
                guard order.indices.contains(next) else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { tab = order[next] }
                Haptics.select()
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
            || l.contains("list the recipe")
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

// MARK: - Home Grid

struct HomeView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selectedHomeTab = 0
    @Binding var showingImportSheet: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    Picker("Home Tab", selection: $selectedHomeTab) {
                        Text("Recipes").tag(0)
                        Text("Collections").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .padding(.bottom, 8)

                    if selectedHomeTab == 0 {
                        // Recipes grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(environment.recipes) { recipe in
                                VStack(alignment: .leading, spacing: 8) {
                                    Image("chickenRecipe")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .aspectRatio(1.0, contentMode: .fill)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(recipe.title)
                                        .font(AppFont.body(17, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(2)
                                        .padding(.leading, 4)
                                    Text(recipe.ownerUsername ?? "@unknown")
                                        .font(AppFont.body(15, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .padding(.leading, 4)
                                        .padding(.bottom, 4)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppTheme.separator, lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    environment.selectRecipe(recipe)
                                }
                            }
                        }
                        .redacted(reason: environment.recipes.isEmpty ? .placeholder : [])
                    } else {
                        // Collections placeholder grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(0..<6, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppTheme.surface)
                                        .aspectRatio(1.0, contentMode: .fit)
                                        .overlay(
                                            Image(systemName: "folder.fill")
                                                .font(.system(size: 34))
                                                .foregroundStyle(AppTheme.textTertiary)
                                        )
                                    Text("Collection \(index + 1)")
                                        .font(AppFont.body(17, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 110)
            }
            .refreshable {
                await environment.refreshRecipes()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("  AI CookBook  ")
                        .font(AppFont.body(18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: true, vertical: false)   // prevents truncation
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Text(" ")
                            .font(AppFont.body(18, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Button {
                            showingImportSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .buttonStyle(.plain)   // optional, but keeps icon clean

                        Button {
                            environment.addPreviewRecipe()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        .buttonStyle(.plain)
                        Text(" ")
                            .font(AppFont.body(18, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            }
        }
        .tint(AppTheme.textPrimary)
    }
}

// MARK: - Import Sheet

struct ImportSheetView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var showingSheet: Bool
    @State private var input = ""
    @State private var validationError: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WHAT'S COOKING!?")
                .font(AppFont.display(30))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 15)

            TextField("Enter your new findings here!", text: $input)
                .focused($isFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(12)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(AppTheme.textPrimary)
                .onAppear {
                    isFieldFocused = true
                }
            if let validationError {
                Text(validationError)
                    .font(AppFont.body(12, weight: .medium))
                    .foregroundStyle(AppTheme.destructive)
            }
            HStack {
                Button {
                    input = UIPasteboard.general.string ?? ""
                } label: {
                    Label("Paste Link", systemImage: "doc.on.clipboard")
                }
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(
                    Capsule().stroke(AppTheme.textPrimary, lineWidth: 1)
                )

                Spacer()

                Button("LETS COOK!") {
                    guard isValidInstagramReelURL(input) else {
                        validationError = "Please enter a valid Instagram reel URL."
                        return
                    }
                    validationError = nil
                    Task {
                        await environment.startImport(from: input)
                        showingSheet = false
                    }
                }
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(AppTheme.accent)
                .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingSheet = false
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .animation(nil, value: isFieldFocused)
    }

    private func isValidInstagramReelURL(_ value: String) -> Bool {
        let pattern = #"https?://(www\.)?instagram\.com/reel/[A-Za-z0-9_-]+/?(\?.*)?$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Import Progress Overlay

struct ImportProgressOverlay: View {
    let status: ImportStatus
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import in progress")
                .font(AppFont.body(16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(stages, id: \.self) { stage in
                HStack(spacing: 10) {
                    Image(systemName: icon(for: stage))
                        .foregroundStyle(color(for: stage))
                    Text(stage.displayLabel)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                }
            }
            Button("Cancel") { onCancel() }
                .foregroundStyle(AppTheme.destructive)
                .font(AppFont.body(13, weight: .semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.separator, lineWidth: 1))
    }

    private let stages: [ImportStatus] = [.downloading, .transcribing, .extracting, .done]

    private func icon(for stage: ImportStatus) -> String {
        if stage == status { return "arrow.triangle.2.circlepath.circle.fill" }
        if stages.firstIndex(of: stage).map({ $0 < (stages.firstIndex(of: status) ?? 0) }) == true { return "checkmark.circle.fill" }
        return "circle"
    }

    private func color(for stage: ImportStatus) -> Color {
        if stage == status { return AppTheme.accent }
        if stages.firstIndex(of: stage).map({ $0 < (stages.firstIndex(of: status) ?? 0) }) == true { return .green }
        return .gray
    }
}

// MARK: - Recipe Detail (Redesigned)

struct RecipeDetailView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State var recipe: Recipe
    @State private var selectedTab = 0
    @State private var checkedIngredients: Set<String> = []
    @State private var checkedSteps: Set<Int> = []
    @State private var servingsMultiplier: Double
    @State private var showServingsSlider = false
    @State private var lastHapticStep: Int = 0
    init(recipe: Recipe) {
        self.recipe = recipe
        _servingsMultiplier = State(initialValue: Double(recipe.servings ?? 1))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Square image, edge‑to‑edge, with overlays
                Image("chickenRecipe")
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        Button {
                            environment.dismissRecipeDetail()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.top, 60)
                        .padding(.leading, 16)
                    }
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.ultraThinMaterial)   // profile picture stays glass
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                )
                            Text(recipe.ownerUsername ?? "@unknown")
                                .font(AppFont.body(14, weight: .medium))
                                .foregroundStyle(.black)          // black name
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .padding(16)
                    }
                
                // Text content + segmented picker
                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.title)
                        .font(AppFont.display(28, weight: .bold))
                        .padding(.top, 15)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Prep: \(recipe.prepTime ?? "—") | Cook: \(recipe.cookTime ?? "—")")
                        .font(AppFont.body(17))
                        .foregroundStyle(AppTheme.textSecondary)
                    if let description = recipe.description {
                        Text(description)
                            .font(AppFont.body(16))
                            .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                    }
                    
                    // Servings & Share buttons
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showServingsSlider.toggle()
                            }
                        } label: {
                            Label("\(Int(servingsMultiplier)) Servings", systemImage: "fork.knife")
                                .font(AppFont.body(17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .tint(.black)
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                        ShareLink(item: shareText, subject: Text(recipe.title)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(AppFont.body(17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .foregroundStyle(AppTheme.textPrimary)
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                    
                    // Slider + reset
                    if showServingsSlider {
                        HStack(spacing: 12) {
                            Slider(value: $servingsMultiplier, in: 1...30, step: 1)
                                .tint(AppTheme.accent)
                            Button {
                                withAnimation {
                                    servingsMultiplier = Double(recipe.servings ?? 1)
                                }
                            } label: {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.glass)
                            .foregroundStyle(AppTheme.textPrimary)
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            .buttonStyle(.bordered)
                            .foregroundStyle(AppTheme.textPrimary)
                        }
                        .transition(.opacity)
                        .onChange(of: Int(servingsMultiplier)) { _, newVal in
                            let step = newVal / 3
                            if step != lastHapticStep {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                lastHapticStep = step
                            }
                        }
                    }
                    
                    Picker("", selection: $selectedTab) {
                        Text("Ingredients").tag(0)
                        Text("Directions").tag(1)
                    }
                    .pickerStyle(.segmented)
                    
                    if selectedTab == 0 {
                        ingredientsSection
                    } else {
                        directionsSection
                    }
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 30)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.background)
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: Ingredients (outlined, separated, larger text)
    
    private var shareText: String {
        """
        🍽 \(recipe.title)
        Prep: \(recipe.prepTime ?? "—") | Cook: \(recipe.cookTime ?? "—")
        
        Ingredients:
        \(recipe.ingredients.flatMap(\.items).joined(separator: "\n"))
        
        Directions:
        \(recipe.directions.map { "\($0.stepIndex). \($0.text)" }.joined(separator: "\n"))

        Open in CraveCircle: https://cravecircle.cc/recipe/\(recipe.id)
        """
    }
    
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(recipe.ingredients.flatMap(\.items), id: \.self) { item in
                Button {
                    if checkedIngredients.contains(item) { checkedIngredients.remove(item) } else { checkedIngredients.insert(item) }
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: checkedIngredients.contains(item) ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                        ingredientText(for: item, multiplier: servingsMultiplier)
                        Spacer()
                    }
                    .font(AppFont.body(20))
                    .foregroundStyle(checkedIngredients.contains(item) ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                Divider()
                    .overlay(AppTheme.separator)
            }
        }
        .padding(16)               // more room inside the container
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.separator, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
    
    private func ingredientText(for item: String, multiplier: Double) -> Text {
        let pattern = #"^([\d.,]+)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Text(item)
        }
        let range = NSRange(location: 0, length: item.utf16.count)
        if let match = regex.firstMatch(in: item, range: range),
           let quantRange = Range(match.range(at: 1), in: item),
           let restRange = Range(match.range(at: 2), in: item) {
            let quantityString = String(item[quantRange])
                .replacingOccurrences(of: ",", with: ".")
            if let original = Double(quantityString) {
                let scaled = original * multiplier
                let formatted: String
                if scaled == floor(scaled) {
                    formatted = String(Int(scaled))
                } else {
                    formatted = String(format: "%.1f", scaled)
                }
                let rest = String(item[restRange])
                return Text("\(Text(formatted).fontWeight(.semibold)) \(rest)")
            }
        }
        return Text(item)
    }
    
    // MARK: Directions (outlined, separated, larger text)
    
    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(recipe.directions, id: \.stepIndex) { step in
                Button {
                    if checkedSteps.contains(step.stepIndex) { checkedSteps.remove(step.stepIndex) } else { checkedSteps.insert(step.stepIndex) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(step.text)
                            .font(AppFont.body(20))
                            .multilineTextAlignment(.leading)
                            .strikethrough(checkedSteps.contains(step.stepIndex))
                        Spacer()
                        Image(systemName: checkedSteps.contains(step.stepIndex) ? "checkmark.square.fill" : "square")
                            .font(.title2)
                    }
                    .foregroundStyle(checkedSteps.contains(step.stepIndex) ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                Divider()
                    .overlay(AppTheme.separator)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.separator, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
        
    // MARK: - Grocery List
    
    struct GroceryListView: View {
        @EnvironmentObject private var environment: AppEnvironment
        
        var body: some View {
            NavigationStack {
                if environment.groceryItems.isEmpty {
                    VStack(spacing: 12) {
                        Text("No items in your grocery list.")
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Add ingredients from a recipe to get started.")
                            .font(AppFont.body(14))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(environment.groceryItems) { item in
                            Button {
                                Task {
                                    await environment.toggleGroceryItem(id: item.id, checked: !item.checked)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.checked ? AppTheme.accent : AppTheme.textTertiary)
                                    Text(item.ingredientName)
                                        .strikethrough(item.checked)
                                        .foregroundStyle(item.checked ? AppTheme.textTertiary : AppTheme.textPrimary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .task {
                await environment.loadGroceryList()
            }
        }
    }
    
    // MARK: - Profile
    
    struct ProfileView: View {
        @EnvironmentObject private var environment: AppEnvironment
        
        var body: some View {
            VStack(spacing: 18) {
                Text(environment.currentUser?.username ?? "Chef")
                    .font(AppFont.display(30))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(environment.currentUser?.fullName ?? "Profile preview")
                    .foregroundStyle(AppTheme.textSecondary)
                Button("Log out") {
                    environment.signOut()
                }
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 26)
                .padding(.vertical, 10)
                .background(AppTheme.accent)
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
    
    // MARK: - Placeholder
    
    struct PlaceholderTabView: View {
        let title: String
        let subtitle: String
        
        var body: some View {
            VStack(spacing: 12) {
                Text(title.uppercased())
                    .font(AppFont.display(28))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
