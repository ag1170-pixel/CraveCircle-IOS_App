//
//  ProfileScreen.swift
//  CraveCircle (AICookBook)
//
//  Profile + settings. Home of the "Recipe language" preference — the language every
//  imported reel is delivered in. Light/cream + coral, matched to the app design.
//

import SwiftUI
#if !XTOOL_WSL
import PhotosUI
#endif

struct ProfileScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage(LanguagePrefs.key) private var langCode = LanguagePrefs.default.rawValue
    @AppStorage("custom_api_url") private var customApiUrl = "https://import.cravecircle.cc"
    @AppStorage("kitchen_cat_enabled") private var kitchenCatEnabled = true   // the playful chef-cat on Home
    @AppStorage("last_opened_shared_screen") private var lastOpenedSharedScreen: Double = 0
    
    private var unreadSharedCount: Int {
        let lastDate = Date(timeIntervalSince1970: lastOpenedSharedScreen)
        let myId = environment.currentUser?.id ?? "me"
        return environment.sharedLog.filter { 
            ($0.toUserId == myId || $0.toUserId == "me") && $0.createdAt > lastDate 
        }.count
    }
    
    @State private var showLanguagePicker = false
    @State private var showTranscribeTest = false
    @State private var showServerPicker = false
    @State private var showNotifications = false
    @State private var showAccountSheet = false
    @State private var showFeedbackForm = false
    @State private var showShared = false
    @State private var cacheCleared = false
    @State private var showEditProfile = false
    @State private var showContactOptions = false
    @State private var activeSafariURL: IdentifiableURL? = nil

    private var language: AppLanguage {
        AppLanguage(rawValue: langCode) ?? LanguagePrefs.default
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    header
                    settings
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .doodleScreenBackground()
            .scrollIndicators(.hidden)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(AppTheme.accentInk)
        // Mirror the Recipe Language into the App Group so the Share Extension (separate process)
        // imports shared reels in this language instead of always English.
        .onChange(of: langCode) { _, newValue in
            UserDefaults(suiteName: AppEnvironment.appGroupID)?.set(newValue, forKey: "shared_recipe_language")
            if let lang = AppLanguage(rawValue: newValue) {
                Task { try? await OnDeviceTranscriber.installAssetIfNeeded(localeID: lang.localeID) }
            }
        }
        .task {
            UserDefaults(suiteName: AppEnvironment.appGroupID)?.set(langCode, forKey: "shared_recipe_language")
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.background)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(selection: $langCode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.background)
        }
        .sheet(isPresented: $showTranscribeTest) {
            TranscribeTestView()
        }
        .sheet(isPresented: $showShared) {
            SharedScreen()
        }
        .sheet(isPresented: $showNotifications) {
            CircleNotificationsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $activeSafariURL) { item in
            SafariView(url: item.url)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showFeedbackForm) {
            FeedbackFormView()
        }
    }

    // MARK: Header (identity on the left, 2×2 stat grid on the right)

    private var header: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Button { showEditProfile = true } label: { avatarView }
                    .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.currentUser?.fullName ?? "Your Profile")
                        .font(AppFont.display(19, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(displayHandle)
                        .font(AppFont.body(13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Button { showEditProfile = true } label: {
                    Text("Edit Profile")
                        .font(AppFont.body(13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(AppTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 2)
            }
            .frame(width: 138, alignment: .leading)

            // 2×2 stat grid
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: AppSpacing.xs), GridItem(.flexible(), spacing: AppSpacing.xs)],
                spacing: AppSpacing.xs
            ) {
                NavigationLink { LibraryScreen() } label: { statTile("\(environment.myLibraryRecipes.count)", "Recipes") }
                NavigationLink { LibraryScreen() } label: { statTile("\(environment.likedRecipes.count)", "Liked") }
                NavigationLink { FriendsScreen() } label: { statTile("\(environment.circleFriends.count)", "Friends") }
                NavigationLink { CollectionsScreen() } label: { statTile("\(environment.ownedCollections.count + environment.sharedCollections.count)", "Collections") }
            }
            .buttonStyle(.plain)
        }
    }

    /// The user's chosen photo, or the initials avatar, with a camera badge showing it's editable.
    private var avatarView: some View {
        Group {
            if let data = environment.avatarImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
            } else {
                CreatorAvatarView(handle: environment.currentUser?.username, size: 88, showBorder: true)
            }
        }
        .overlay(Circle().stroke(AppTheme.accent, lineWidth: 2).padding(-4))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.onAccent)
                .frame(width: 28, height: 28)
                .background(AppTheme.accent, in: Circle())
                .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
        }
    }

    private var displayHandle: String {
        guard let u = environment.currentUser?.username, !u.isEmpty else { return "@cravecircle" }
        return u.hasPrefix("@") ? u : "@\(u)"
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(AppFont.body(12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    // MARK: Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Preferences").sectionLabelStyle()

            VStack(spacing: 0) {
                SettingRow(
                    icon: "globe",
                    title: "Recipe language",
                    detail: language.nativeName,
                    tint: AppTheme.accent
                ) { showLanguagePicker = true }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                SettingRow(icon: "bell.badge", title: "Notifications", detail: "On", tint: .orange) {
                    showNotifications = true
                }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                SettingRow(icon: "tray.and.arrow.down", title: "Shared with you", detail: nil, badgeCount: unreadSharedCount, tint: .pink) {
                    lastOpenedSharedScreen = Date().timeIntervalSince1970
                    showShared = true
                }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                SettingRow(icon: "person.crop.circle", title: "Account", detail: environment.currentUser?.username, tint: .blue) {
                    showAccountSheet = true
                }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                // Playful chef-cat that perches on the Home cards — toggle it off if it's distracting.
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "cat.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "EA5A38"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text("Kitchen cat")
                        .font(AppFont.body(16, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Toggle("", isOn: $kitchenCatEnabled).labelsHidden().toggleStyle(GlassToggleStyle())
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 13)

                if environment.isAdmin {
                    Divider().overlay(AppTheme.separator).padding(.leading, 56)
                    SettingRow(icon: "server.rack", title: "Kitchen Server", detail: customApiUrl.replacingOccurrences(of: "http://", with: ""), tint: .indigo) {
                        showServerPicker = true
                    }
                    Divider().overlay(AppTheme.separator).padding(.leading, 56)
                    SettingRow(icon: "waveform", title: "On-device transcription", detail: "Beta", tint: AppTheme.accent) { showTranscribeTest = true }
                }
                
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                NavigationLink {
                    LiveActivityPreviewScreen()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.onBrand)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("Preview cooking island")
                            .font(AppFont.body(16, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if environment.isAdmin {
                    Divider().overlay(AppTheme.separator).padding(.leading, 56)
                    // NavigationLink push → native back button + left-edge swipe-back.
                    NavigationLink {
                        AdminRequestsScreen()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.green, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text("Creator Requests")
                                .font(AppFont.body(16, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(AppTheme.separator).padding(.leading, 56)
                    NavigationLink {
                        AdminRecipeReportsScreen()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text("Recipe Reports")
                                .font(AppFont.body(16, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

            Text("Connects your phone to your import server for faster reel imports.")
                .font(AppFont.body(12))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.horizontal, AppSpacing.xs)

            // Standalone Clear cache button (frees the bounded image cache; confirms so it's visible).
            Button {
                URLCache.shared.removeAllCachedResponses()
                Haptics.success()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { cacheCleared = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { cacheCleared = false }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: cacheCleared ? "checkmark.circle.fill" : "trash")
                    Text(cacheCleared ? "Cache cleared" : "Clear cache")
                }
                .font(AppFont.body(15, weight: .semibold))
                .foregroundStyle(cacheCleared ? AppTheme.accent : AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(cacheCleared ? AppTheme.accent.opacity(0.5) : AppTheme.hairline, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .padding(.top, AppSpacing.xs)

            Text("Legal & Support").sectionLabelStyle()
                .padding(.top, AppSpacing.sm)

            VStack(spacing: 0) {
                SettingRow(
                    icon: "star.bubble.fill",
                    title: "Give Feedback",
                    tint: .orange
                ) {
                    showFeedbackForm = true
                }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                SettingRow(
                    icon: "envelope.fill",
                    title: "Contact Developer",
                    detail: "Aditya",
                    tint: .pink
                ) {
                    showContactOptions = true
                }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                SettingRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    tint: .teal
                ) {
                    activeSafariURL = IdentifiableURL(url: AppConfig.supportURL)
                }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                SettingRow(
                    icon: "hand.raised.shield.fill",
                    title: "Privacy Policy",
                    tint: .green
                ) {
                    activeSafariURL = IdentifiableURL(url: AppConfig.privacyPolicyURL)
                }
                Divider().overlay(AppTheme.separator).padding(.leading, 56)
                SettingRow(
                    icon: "doc.text.fill",
                    title: "Terms of Service",
                    tint: .blue
                ) {
                    activeSafariURL = IdentifiableURL(url: AppConfig.termsOfServiceURL)
                }
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

            VStack(spacing: 2) {
                Text("CraveCircle v1.0")
                    .font(AppFont.body(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Crafted for cooks & food lovers")
                    .font(AppFont.body(11))
                    .foregroundStyle(AppTheme.textTertiary)
                Text("Nutrition data: USDA FoodData Central · IFCT 2017 (NIN/ICMR)")
                    .font(AppFont.body(10))
                    .foregroundStyle(AppTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, AppSpacing.xs)

            Button(role: .destructive) {
                Haptics.tap(); environment.signOut()
            } label: {
                Text("Log out")
                    .font(AppFont.body(16, weight: .semibold))
                    .foregroundStyle(AppTheme.destructive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AppTheme.surface, in: Capsule())
                    .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .padding(.top, AppSpacing.xs)
        }
        .sheet(isPresented: $showServerPicker) {
            KitchenServerSheet(serverUrl: $customApiUrl)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.background)
        }
        .confirmationDialog("Contact Developer", isPresented: $showContactOptions, titleVisibility: .visible) {
            Button("Email: adityagupta2646@gmail.com") {
                if let url = URL(string: "mailto:adityagupta2646@gmail.com") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Call: 8218836531") {
                if let url = URL(string: "tel://8218836531") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Message: 8218836531") {
                if let url = URL(string: "sms://8218836531") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("How would you like to get in touch with Aditya?")
        }
    }
}

// MARK: - Account Sheet

struct AccountSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAccount = false

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Text("CC")
                            .font(AppFont.serif(24, weight: .bold))
                            .foregroundStyle(AppTheme.accentInk)
                    )
                VStack(spacing: 4) {
                    Text(environment.currentUser?.fullName ?? "Chef User")
                        .font(AppFont.display(20, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(environment.currentUser?.username ?? "@cravecircle")
                        .font(AppFont.body(14))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                VStack(spacing: 0) {
                    HStack {
                        Text("Member Since")
                            .font(AppFont.body(14, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("2026")
                            .font(AppFont.body(14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(AppSpacing.md)
                }
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
                
                Spacer()
                
                NavigationLink {
                    DeleteAccountScreen()
                } label: {
                    Text("Delete Account")
                        .font(AppFont.body(15, weight: .bold))
                        .foregroundStyle(AppTheme.destructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.destructive.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.lg)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(AppFont.body(16, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                }
            }
        }
    }
}

// MARK: - Setting row

struct SettingRow: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var badgeCount: Int? = nil
    var tint: Color = AppTheme.accent
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap(); action()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(AppFont.body(16, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if let badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                }
                if let detail {
                    Text(detail)
                        .font(AppFont.body(15))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language picker

struct LanguagePickerSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAccount = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recipe language")
                    .font(AppFont.display(24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Imported reels are translated and delivered in this language.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button {
                            Haptics.select()
                            selection = lang.rawValue
                            dismiss()
                        } label: {
                            HStack(spacing: AppSpacing.sm) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(lang.nativeName)
                                        .font(AppFont.body(17, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(lang.name)
                                        .font(AppFont.body(13))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                if selection == lang.rawValue {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(AppTheme.accent)
                                } else {
                                    Circle().strokeBorder(AppTheme.hairline, lineWidth: 1.5).frame(width: 22, height: 22)
                                }
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if lang != AppLanguage.allCases.last {
                            Divider().overlay(AppTheme.separator).padding(.leading, AppSpacing.lg)
                        }
                    }
                }
            }
        }
        .background(AppTheme.background)
    }
}

// MARK: - Kitchen Server Endpoint Sheet

struct KitchenServerSheet: View {
    @Binding var serverUrl: String
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAccount = false
    @State private var inputUrl: String = ""
    @State private var pingStatus: String? = nil
    @State private var isChecking: Bool = false
    @State private var isSuccess: Bool = false

    private let presets: [(name: String, icon: String, url: String, desc: String)] = [
        ("CraveCircle Server", "cloud.fill", "https://import.cravecircle.cc", "Default · works anywhere"),
        ("Homelab", "server.rack", "http://100.70.151.71:8009", "Tailscale network"),
        ("Local Wi-Fi", "laptopcomputer", "http://10.9.229.142:8000", "Same-network server")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kitchen Server Endpoint")
                            .font(AppFont.display(22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Connects your phone to your import server.")
                            .font(AppFont.body(14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    // Presets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Presets").sectionLabelStyle()
                        VStack(spacing: 0) {
                            ForEach(Array(presets.enumerated()), id: \.offset) { index, p in
                                Button {
                                    inputUrl = p.url
                                    testConnection(urlStr: p.url)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: p.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(inputUrl == p.url ? AppTheme.onAccent : AppTheme.accentInk)
                                            .frame(width: 32, height: 32)
                                            .background(inputUrl == p.url ? AppTheme.accent : AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name)
                                                .font(AppFont.body(15, weight: .semibold))
                                                .foregroundStyle(AppTheme.textPrimary)
                                            Text(p.url)
                                                .font(AppFont.body(12))
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        Spacer()
                                        if inputUrl == p.url {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppTheme.accent)
                                        }
                                    }
                                    .padding(AppSpacing.md)
                                }
                                .buttonStyle(.plain)
                                if index < presets.count - 1 {
                                    Divider().overlay(AppTheme.separator)
                                }
                            }
                        }
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
                    }

                    // Custom URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Address").sectionLabelStyle()
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                                .foregroundStyle(AppTheme.textTertiary)
                            TextField("http://100.70.151.71:8009", text: $inputUrl)
                                .font(AppFont.body(15))
                                .foregroundStyle(AppTheme.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                        }
                        .padding(AppSpacing.md)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

                        if let pingStatus {
                            HStack(spacing: 6) {
                                Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                Text(pingStatus)
                                    .font(AppFont.body(13, weight: .medium))
                            }
                            .foregroundStyle(isSuccess ? AppTheme.accentInk : AppTheme.destructive)
                            .padding(.top, 2)
                        }

                        HStack(spacing: 12) {
                            PillButton(title: isChecking ? "Testing..." : "Test Ping", systemImage: "antenna.radiowaves.left.and.right", kind: .outlined, fullWidth: true) {
                                testConnection(urlStr: inputUrl)
                            }
                            .disabled(isChecking || inputUrl.isEmpty)

                            PillButton(title: "Save & Apply", systemImage: "checkmark", kind: .filled, fullWidth: true) {
                                save()
                            }
                            .disabled(inputUrl.isEmpty)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(AppSpacing.lg)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Kitchen Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(AppFont.body(16, weight: .semibold))
                        .foregroundStyle(AppTheme.accentInk)
                }
            }
            .onAppear {
                inputUrl = serverUrl
                testConnection(urlStr: serverUrl)
            }
        }
    }

    private func testConnection(urlStr: String) {
        let clean = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: clean.hasSuffix("/") ? "\(clean)health" : "\(clean)/health") else {
            pingStatus = "Invalid URL format"
            isSuccess = false
            return
        }
        isChecking = true
        pingStatus = "Pinging \(url.host ?? "")..."

        Task {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.0
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let model = json["model"] as? String {
                        await MainActor.run {
                            pingStatus = "Connected · Model: \(model)"
                            isSuccess = true
                            isChecking = false
                            Haptics.success()
                        }
                        return
                    }
                    await MainActor.run {
                        pingStatus = "Connected · HTTP 200"
                        isSuccess = true
                        isChecking = false
                        Haptics.success()
                    }
                } else {
                    await MainActor.run {
                        pingStatus = "Server responded with HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                        isSuccess = false
                        isChecking = false
                    }
                }
            } catch {
                await MainActor.run {
                    pingStatus = "Cannot reach server: \(error.localizedDescription)"
                    isSuccess = false
                    isChecking = false
                }
            }
        }
    }

    private func save() {
        let clean = inputUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        serverUrl = clean
        UserDefaults.standard.set(clean, forKey: "custom_api_url")
        Haptics.success()
        dismiss()
    }
}

// MARK: - Identifiable URL Helper

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}


// MARK: - Delete Account Flow

struct DeleteAccountScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAccount = false
    @State private var step = 0 // 0: choice, 1: reason
    @State private var feedbackText = ""
    @State private var isDeleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if step == 0 {
                Text("Delete Account")
                    .font(AppFont.display(24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("Do you want to deactivate your account temporarily, or delete it permanently?")
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textSecondary)
                
                VStack(spacing: AppSpacing.md) {
                    Button {
                        Haptics.success()
                        environment.signOut()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Deactivate Temporarily")
                                .font(AppFont.body(16, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Your account will be hidden, but you can recover it anytime by logging back in.")
                                .font(AppFont.body(14))
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    
                    Button {
                        Haptics.tap()
                        withAnimation { step = 1 }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Delete Permanently")
                                .font(AppFont.body(16, weight: .bold))
                                .foregroundStyle(AppTheme.destructive)
                            Text("All your recipes, friends, and data will be permanently erased.")
                                .font(AppFont.body(14))
                                .foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
                        .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.destructive.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            } else {
                Text("Why are you leaving?")
                    .font(AppFont.display(24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("We're sorry to see you go. Please let us know what issues you faced so we can learn and improve.")
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textSecondary)
                
                TextEditor(text: $feedbackText)
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(8)
                    .frame(height: 120)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).stroke(AppTheme.hairline, lineWidth: 1))
                
                Spacer()
                
                Button {
                    Task {
                        isDeleting = true
                        Haptics.success()
                        // Simulate sending feedback and deleting data
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        environment.signOut()
                    }
                } label: {
                    HStack {
                        if isDeleting { ProgressView().tint(.white) }
                        Text("Confirm Deletion")
                    }
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.destructive, in: Capsule())
                    .opacity(isDeleting ? 0.6 : 1.0)
                }
                .buttonStyle(PressableStyle())
                .disabled(isDeleting)
            }
            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}


// MARK: - Delete Account Sheet

struct DeleteAccountSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var deleteMode: Int = 0 // 0 = Temporary, 1 = Permanent
    @State private var reason: String = ""
    @State private var isDeleting = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("We're sorry to see you go.")
                        .font(AppFont.display(24, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    LimeSegmentedControl(segments: ["Temporary Disable", "Permanent Delete"], selection: $deleteMode)
                    
                    if deleteMode == 0 {
                        Text("Your account will be hidden from the community. You can reactivate it anytime by logging back in.")
                            .font(AppFont.body(15))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Why are you deleting your account?")
                                .font(AppFont.body(16, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text("Please tell us about any issues you faced so we can learn and improve.")
                                .font(AppFont.body(14))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            TextEditor(text: $reason)
                                .font(AppFont.body(15))
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(AppTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.hairline, lineWidth: 1))
                        }
                    }
                    
                    Spacer(minLength: 40)
                    
                    Button(role: .destructive) {
                        deleteAccount()
                    } label: {
                        HStack {
                            if isDeleting { ProgressView().tint(.white).padding(.trailing, 4) }
                            Text(deleteMode == 0 ? "Disable Account" : "Delete Permanently")
                                .font(AppFont.body(16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppTheme.destructive, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(isDeleting || (deleteMode == 1 && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    
                    if deleteMode == 1 && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Please provide a reason to permanently delete your account.")
                            .font(AppFont.body(12))
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(AppSpacing.lg)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(AppFont.body(16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }
    
    private func deleteAccount() {
        isDeleting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Haptics.success()
            isDeleting = false
            dismiss()
            environment.signOut()
        }
    }
}

// MARK: - Edit Profile

/// Change your profile photo (Apple PhotosPicker), display name and username. The photo is stored
/// on-device; name/username are pushed to the profile row so they persist and others can see them.
struct EditProfileSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var username = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var newAvatar: Data?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        avatarPreview
                    }
                    .buttonStyle(.plain)

                    Text("Tap the photo to change it")
                        .font(AppFont.body(12))
                        .foregroundStyle(AppTheme.textTertiary)

                    field(title: "Name", text: $fullName, placeholder: "Your name")
                    field(title: "Username", text: $username, placeholder: "yourname", prefix: "@")
                }
                .padding(AppSpacing.lg)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving { ProgressView() } else { Text("Save").fontWeight(.bold) }
                    }
                    .disabled(saving)
                }
            }
            .onAppear {
                fullName = environment.currentUser?.fullName ?? ""
                let u = environment.currentUser?.username ?? ""
                username = u.hasPrefix("@") ? String(u.dropFirst()) : u
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let downsized = Self.downscaledJPEG(data) {
                        newAvatar = downsized
                    }
                }
            }
        }
    }

    private var avatarPreview: some View {
        Group {
            if let data = newAvatar ?? environment.avatarImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(width: 108, height: 108).clipShape(Circle())
            } else {
                CreatorAvatarView(handle: environment.currentUser?.username, size: 108, showBorder: true)
            }
        }
        .overlay(Circle().stroke(AppTheme.accent, lineWidth: 2).padding(-4))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.onAccent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent, in: Circle())
                .overlay(Circle().stroke(AppTheme.background, lineWidth: 2))
        }
        .padding(.top, AppSpacing.sm)
    }

    @ViewBuilder
    private func field(title: String, text: Binding<String>, placeholder: String, prefix: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.body(13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 4) {
                if let prefix {
                    Text(prefix).foregroundStyle(AppTheme.textTertiary)
                }
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(prefix == nil ? .words : .never)
                    .autocorrectionDisabled(prefix != nil)
            }
            .font(AppFont.body(16))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() async {
        saving = true
        if let newAvatar { environment.setAvatar(newAvatar) }
        await environment.updateProfile(fullName: fullName, username: username)
        saving = false
        dismiss()
    }

    /// Downscale to <=512px and JPEG-compress so the on-device avatar stays small.
    static func downscaledJPEG(_ data: Data, maxDimension: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
