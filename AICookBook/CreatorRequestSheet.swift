//
//  CreatorRequestSheet.swift
//  CraveCircle (AICookBook)
//
//  "Become a Creator" request form — the user submits their social handle for verification.
//  An admin reviews it (AdminRequestsScreen); only on approval does their role become creator.
//

import SwiftUI

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
                        TextField("Handle (e.g. @yourname)", text: $handle)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                        TextField("Profile link (optional)", text: $url)
                            .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    }
                    Section {
                        Text("An admin verifies your social profile before you can publish — this keeps the creator community trustworthy.")
                            .font(AppFont.body(13)).foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Become a Creator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(done ? "Done" : "Cancel") { dismiss() }
                }
                if !done {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") { submit() }
                            .disabled(handle.trimmingCharacters(in: .whitespaces).isEmpty || submitting)
                    }
                }
            }
        }
    }

    private func submit() {
        submitting = true
        Task {
            let ok = await environment.submitCreatorRequest(
                platform: platform,
                handle: handle.trimmingCharacters(in: .whitespaces),
                url: url.trimmingCharacters(in: .whitespaces),
                note: nil
            )
            await MainActor.run {
                submitting = false
                if ok { Haptics.success(); withAnimation { done = true } }
            }
        }
    }
}
