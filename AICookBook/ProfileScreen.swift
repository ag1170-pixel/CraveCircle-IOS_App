//
//  ProfileScreen.swift
//  CraveCircle (AICookBook)
//
//  Profile + settings. Home of the "Recipe language" preference — the language every
//  imported reel is delivered in. Light/cream + coral, matched to the app design.
//

import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage(LanguagePrefs.key) private var langCode = LanguagePrefs.default.rawValue
    @AppStorage("custom_api_url") private var customApiUrl = "https://api.cravecircle.cc"
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
    @State private var showContactOptions = false
    @State private var activeSafariURL: IdentifiableURL? = nil

    private var language: AppLanguage {
        AppLanguage(rawValue: langCode) ?? LanguagePrefs.default
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    identity
                    stats
                    settings
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, 120)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(AppTheme.accentInk)
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

    // MARK: Identity

    private var identity: some View {
        VStack(spacing: AppSpacing.sm) {
            CreatorAvatarView(handle: environment.currentUser?.username, size: 88, showBorder: true)
                .overlay(Circle().stroke(AppTheme.accent, lineWidth: 2).padding(-4))
            VStack(spacing: 2) {
                Text(environment.currentUser?.fullName ?? "Your Profile")
                    .font(AppFont.display(24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(environment.currentUser?.username ?? "@cravecircle")
                    .font(AppFont.body(15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: AppSpacing.xs) {
            NavigationLink { LibraryScreen() } label: { statTile("\(environment.recipes.count)", "Recipes") }
            NavigationLink { LibraryScreen() } label: { statTile("\(environment.likedRecipes.count)", "Liked") }
            NavigationLink { FriendsScreen() } label: { statTile("\(environment.circleFriends.count)", "Friends") }
            NavigationLink { CollectionsScreen() } label: { statTile("\(environment.ownedCollections.count + environment.sharedCollections.count)", "Collections") }
        }
        .buttonStyle(.plain)
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.serif(24, weight: .medium))
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
                
                if environment.isAdmin {
                    Divider().overlay(AppTheme.separator).padding(.leading, 56)
                    SettingRow(icon: "server.rack", title: "Kitchen Server", detail: customApiUrl.replacingOccurrences(of: "http://", with: ""), tint: .indigo) {
                        showServerPicker = true
                    }
                    Divider().overlay(AppTheme.separator).padding(.leading, 56)
                    SettingRow(icon: "waveform", title: "On-device transcription", detail: "Beta", tint: AppTheme.accent) { showTranscribeTest = true }
                }
                
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
                }
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))

            Text("Connects your phone to your local Mac/Homelab Whisper server for instant reel imports.")
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
    @State private var inputUrl: String = ""
    @State private var pingStatus: String? = nil
    @State private var isChecking: Bool = false
    @State private var isSuccess: Bool = false

    private let presets: [(name: String, icon: String, url: String, desc: String)] = [
        ("Homelab Whisper", "server.rack", "http://100.70.151.71:8009", "Tailscale mesh server"),
        ("Mac Workstation", "laptopcomputer", "http://10.9.229.142:8000", "Local Wi-Fi server"),
        ("Cloudflare Tunnel", "cloud.fill", "https://api.cravecircle.cc", "Zero Trust HTTPS proxy")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Kitchen Server Endpoint")
                            .font(AppFont.display(22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Connects your phone to your Whisper transcription & recipe extraction engine.")
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

