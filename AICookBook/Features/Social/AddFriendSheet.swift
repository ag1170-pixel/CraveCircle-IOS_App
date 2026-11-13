//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: AddFriendSheet.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Friend discovery and connection sheet searching users by username or email.
//
// 2. ARCHITECTURAL ROLE:
//    Search interface enabling quick follow requests and friendship confirmations via Supabase.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "AddFriendSheet makes connecting with friends simple. Typing a username queries our Supabase directory and allows adding friends to your cooking circle."
//
// ==============================================================================
//

//
//  AddFriendSheet.swift
//  CraveCircle (AICookBook)
//
//  Search and send friend requests to Circle connections.
//

import SwiftUI

// MARK: - SwiftUI View Component
struct AddFriendSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var notice: String?
    @State private var sent = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                searchField

                if sent {
                    successBanner
                } else if let notice {
                    Text(notice)
                        .font(AppFont.body(14, weight: .medium))
                        .foregroundStyle(Color(hex: "C7362A"))
                }

                Text("They need a CraveCircle account. You send a request to their username. When they accept, you can open their recipes and send a dish to them. The share link still works for anyone.")
                    .font(AppFont.body(14))
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppScreenBackground())
            .navigationTitle("Add to Circle")
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

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Enter username or email").sectionLabelStyle()
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "at")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                TextField("username", text: $query)
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button {
                        let typed = query
                        Haptics.tap()
                        Task {
                            if let message = await environment.sendFriendRequest(usernameOrEmail: typed) {
                                notice = message
                                sent = false
                                Haptics.warning()
                            } else {
                                notice = nil
                                sent = true
                                query = ""
                                Haptics.success()
                            }
                        }
                    } label: {
                        Text("Send")
                            .font(AppFont.body(14, weight: .bold))
                            .foregroundStyle(AppTheme.onAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.accent, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 52)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
    }

    private var successBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.green)
            Text("Friend request sent! It will show under Outgoing requests.")
                .font(AppFont.body(14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }

}
