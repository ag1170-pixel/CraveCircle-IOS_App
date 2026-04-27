import SwiftUI

// MARK: - Root

struct RootView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Group {
            switch environment.appState {
            case .loading:
                ProgressView("Loading AICookbook...")
                    .tint(AppTheme.textPrimary)
                    .foregroundStyle(AppTheme.textPrimary)
            case .signedOut:
                LoginView()
            case .signedIn:
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("AICOOKBOOK")
                .font(AppFont.display(34))
                .foregroundStyle(AppTheme.textPrimary)
            Picker("", selection: $isSignUpMode) {
                Text("Log In").tag(false)
                Text("Sign Up").tag(true)
            }
            .pickerStyle(.segmented)
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .padding()
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(AppTheme.textPrimary)
            SecureField("Password", text: $password)
                .textInputAutocapitalization(.never)
                .padding()
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(AppTheme.textPrimary)
            if isSignUpMode {
                SecureField("Confirm Password", text: $confirmPassword)
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            if let inlineMessage {
                Text(inlineMessage)
                    .font(AppFont.body(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Button {
                loading = true
                Task {
                    if isSignUpMode {
                        guard password == confirmPassword else {
                            inlineMessage = "Passwords do not match."
                            loading = false
                            return
                        }
                        do {
                            try await environment.signUp(email: email, password: password)
                            inlineMessage = "Account has been created. Please log in."
                            isSignUpMode = false
                            confirmPassword = ""
                        } catch {
                            inlineMessage = error.localizedDescription
                        }
                    } else {
                        await environment.signIn(email: email, password: password)
                    }
                    loading = false
                }
            } label: {
                Text(loading ? (isSignUpMode ? "Creating account..." : "Signing in...") : (isSignUpMode ? "CREATE ACCOUNT" : "LET'S COOK"))
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(Capsule())
            }
            .disabled(loading || email.isEmpty || password.isEmpty || (isSignUpMode && confirmPassword.isEmpty))
            Spacer()
        }
        .padding(24)
        .background(AppTheme.background.ignoresSafeArea())
        .onChange(of: isSignUpMode) { _, _ in
            inlineMessage = nil
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

    var body: some View {
        TabView {
            Tab("HOME", systemImage: TabItem.home.symbol) {
                HomeView(showingImportSheet: $showingImportSheet)
            }

            Tab("CREATORS", systemImage: TabItem.creators.symbol) {
                PlaceholderTabView(title: "Creators", subtitle: "Friends feed coming next.")
            }

            Tab("GROCERIES", systemImage: "basket.fill") {
                GroceryListView()
            }

            Tab("PROFILE", systemImage: TabItem.profile.symbol) {
                ProfileView()
            }

            Tab(role: .search) {
                PlaceholderTabView(title: "Search", subtitle: "Search will be added soon.")
            }
        }
        .tint(AppTheme.textPrimary)
        .tabBarMinimizeBehavior(.onScrollDown)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackgroundVisibility(.visible, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 10) {
            if case .polling(_, let status) = environment.importState {
                ImportProgressOverlay(status: status, onCancel: environment.cancelImport)
                    .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportSheetView(showingSheet: $showingImportSheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { environment.selectedRecipe },
            set: { _ in environment.dismissRecipeDetail() }
        )) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .task {
            if environment.recipes.isEmpty {
                await environment.refreshRecipes()
            }
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
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppTheme.surface)
                                        .aspectRatio(1.0, contentMode: .fit)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.system(size: 34))
                                                .foregroundStyle(AppTheme.textTertiary)
                                        )
                                    Text(recipe.title)
                                        .font(AppFont.body(17, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(2)
                                    Text(recipe.ownerUsername ?? "@unknown")
                                        .font(AppFont.body(15, weight: .medium))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
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
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingImportSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Button {
                            environment.addPreviewRecipe()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.textPrimary)
                        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("WHAT'S COOKING!?")
                .font(AppFont.display(30))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 15)

            TextField("Enter your new findings here!", text: $input)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding(12)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(AppTheme.textPrimary)
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
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background.ignoresSafeArea())
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Square image, edge‑to‑edge, with overlays
                    Rectangle()
                        .fill(AppTheme.surface)
                        .aspectRatio(1.0, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(alignment: .topLeading) {
                            Button {
                                environment.dismissRecipeDetail()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .padding(16)
                        }
                        .overlay(alignment: .bottomLeading) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(AppTheme.surface)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    )
                                Text(recipe.ownerUsername ?? "@unknown")
                                    .font(AppFont.body(14, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(16)
                        }

                    // Text content + segmented picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recipe.title)
                            .font(AppFont.display(28, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Prep: \(recipe.prepTime ?? "—") | Cook: \(recipe.cookTime ?? "—")")
                            .font(AppFont.body(13))
                            .foregroundStyle(AppTheme.textSecondary)
                        if let description = recipe.description {
                            Text(description)
                                .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }

    // MARK: Ingredients (outlined, separated, larger text)

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(recipe.ingredients, id: \.self) { group in
                if let name = group.groupName {
                    Text(name)
                        .font(AppFont.body(16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
                ForEach(group.items, id: \.self) { item in
                    Button {
                        if checkedIngredients.contains(item) { checkedIngredients.remove(item) } else { checkedIngredients.insert(item) }
                    } label: {
                        HStack {
                            Image(systemName: checkedIngredients.contains(item) ? "checkmark.circle.fill" : "circle")
                                .font(.body)
                            Text(item)
                                .font(AppFont.body(16))
                                .strikethrough(checkedIngredients.contains(item))
                            Spacer()
                        }
                        .foregroundStyle(checkedIngredients.contains(item) ? AppTheme.textTertiary : AppTheme.textPrimary)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .overlay(AppTheme.separator)
                }
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.separator, lineWidth: 1)
        )
    }

    // MARK: Directions (outlined, separated, larger text)

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(recipe.directions, id: \.stepIndex) { step in
                Button {
                    if checkedSteps.contains(step.stepIndex) { checkedSteps.remove(step.stepIndex) } else { checkedSteps.insert(step.stepIndex) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(String(format: "%02d", step.stepIndex))
                            .font(AppFont.mono(18, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                        Text(step.text)
                            .font(AppFont.body(16))
                            .multilineTextAlignment(.leading)
                            .strikethrough(checkedSteps.contains(step.stepIndex))
                        Spacer()
                        Image(systemName: checkedSteps.contains(step.stepIndex) ? "checkmark.square.fill" : "square")
                            .font(.body)
                    }
                    .foregroundStyle(checkedSteps.contains(step.stepIndex) ? AppTheme.textTertiary : AppTheme.textPrimary)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                Divider()
                    .overlay(AppTheme.separator)
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.separator, lineWidth: 1)
        )
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
