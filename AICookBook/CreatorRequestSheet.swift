//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: CreatorRequestSheet.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Application flow for home cooks wishing to become verified recipe creators.
//
// 2. ARCHITECTURAL ROLE:
//    Form submission sheet collecting creator portfolio links, social handles, and culinary specialties.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "CreatorRequestSheet allows aspiring creators to apply for publishing privileges directly inside the app, submitting their profile to admin review."
//
// ==============================================================================
//

//
//  CreatorRequestSheet.swift
//  CraveCircle (AICookBook)
//
//  "Become a Creator" request form — the user submits their social handle for verification.
//  An admin reviews it (AdminRequestsScreen); only on approval does their role become creator.
//

import SwiftUI

// MARK: - SwiftUI View Component
struct CreatorRequestSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var platform = "Instagram"
    @State private var handle = ""
    @State private var url = ""
    @State private var submitting = false
    @State private var done = false

    private let platforms = ["Instagram", "YouTube", "TikTok", "Facebook", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                if done {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 42)).foregroundStyle(AppTheme.accent)
                            Text("Request submitted")
                                .font(AppFont.display(20, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("We'll verify your social profile and get back to you. You can publish once an admin approves.")
                                .font(AppFont.body(14)).foregroundStyle(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                } else {
                    Section("Verify your social profile") {
                        Picker("Platform", selection: $platform) {
                            ForEach(platforms, id: \.self) { Text($0) }
                        }
                        TextField("Handle or Email ID (e.g. @name or email)", text: $handle)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                        TextField("Profile link (optional)", text: $url)
                            .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    }
                    Section {
                        Text("An admin verifies your profile before you can publish — this keeps the creator community trustworthy.")
                            .font(AppFont.body(13)).foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Become a Creator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        if done {
                            Text("Done")
                                .font(AppFont.body(14, weight: .bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(AppTheme.surfaceElevated, in: Circle())
                                .overlay(Circle().stroke(AppTheme.hairline, lineWidth: 0.8))
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(done ? "Done" : "Close")
                }
                if !done {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.success()
                            submit()
                        } label: {
                            Text("Submit")
                                .font(AppFont.body(14, weight: .bold))
                                .foregroundStyle(AppTheme.onBrand)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(
                                    handle.trimmingCharacters(in: .whitespaces).isEmpty || submitting
                                        ? AppTheme.textTertiary.opacity(0.4)
                                        : AppTheme.brand,
                                    in: Capsule()
                                )
                                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(handle.trimmingCharacters(in: .whitespaces).isEmpty || submitting)
                    }
                }
            }
        }
    }

    private func submit() {
        submitting = true
        Task {
            let safeHandle = handle.trimmingCharacters(in: .whitespaces)
            let safeUrl = url.trimmingCharacters(in: .whitespaces)
            
            // Try backend submission
            let ok = await environment.submitCreatorRequest(
                platform: platform,
                handle: safeHandle,
                url: safeUrl,
                note: nil
            )
            
            await MainActor.run {
                submitting = false
                if ok || !environment.hasRealSession {
                    // Simulate success if in dev mode (no real session), otherwise real success
                    Haptics.success()
                    withAnimation { done = true }
                    
                    // Fallback to email to ensure adityagupta2646@gmail.com gets it
                    if !ok || !environment.hasRealSession {
                        sendEmailToAdmin(platform: platform, handle: safeHandle, url: safeUrl)
                    }
                } else {
                    // Backend failed, fallback to email directly
                    sendEmailToAdmin(platform: platform, handle: safeHandle, url: safeUrl)
                    Haptics.success()
                    withAnimation { done = true }
                }
            }
            
            // Also store it in the admin sqlite database for easy list viewing
            let content = "Platform: \(platform)\nHandle/Email: \(safeHandle)\nLink: \(safeUrl)"
            try? await environment.submitFeedback(type: "creator_request", content: content, email: safeHandle, handle: environment.currentUser?.username)
        }
    }
    
    private func sendEmailToAdmin(platform: String, handle: String, url: String) {
        let subject = "Creator Request: \(handle)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "Platform: \(platform)\nHandle/Email: \(handle)\nLink: \(url)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let emailUrl = URL(string: "mailto:adityagupta2646@gmail.com?subject=\(subject)&body=\(body)") {
            UIApplication.shared.open(emailUrl)
        }
    }
}
