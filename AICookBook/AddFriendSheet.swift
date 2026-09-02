//
//  AddFriendSheet.swift
//  CraveCircle (AICookBook)
//
//  Search and send friend requests to Circle connections.
//

import SwiftUI

struct AddFriendSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var sentQuery = false

    private let suggestions = [
        ("Kavita Singh", "@kavitacooks"),
        ("Marcus Vance", "@marcus_eats"),
        ("Chloe Chen", "@chloebakes"),
        ("Rohan Joshi", "@rohan_spice")
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                searchField

                if sentQuery {
                    successBanner
                }

                suggestionsSection

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppTheme.background.ignoresSafeArea())
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
                TextField("e.g. @priyacooks or chef@cravecircle.cc", text: $query)
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button {
                        Haptics.tap()
                        environment.sendFriendRequest(usernameOrEmail: query)
                        withAnimation(AppMotion.snappy) {
                            sentQuery = true
                            query = ""
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

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Suggested Cooks").sectionLabelStyle()
            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { index, cook in
                    HStack(spacing: AppSpacing.sm) {
                        Circle()
                            .fill(AppTheme.accentSoft)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(cook.0.prefix(2)).uppercased())
                                    .font(AppFont.body(14, weight: .bold))
                                    .foregroundStyle(AppTheme.accentInk)
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cook.0)
                                .font(AppFont.body(15, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(cook.1)
                                .font(AppFont.body(12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            Haptics.tap()
                            environment.sendFriendRequest(usernameOrEmail: cook.1)
                            withAnimation(AppMotion.snappy) {
                                sentQuery = true
                            }
                        } label: {
                            Text("Request")
                                .font(AppFont.body(12, weight: .bold))
                                .foregroundStyle(AppTheme.onAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.accent, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 12)

                    if index < suggestions.count - 1 {
                        Divider().overlay(AppTheme.separator).padding(.leading, 60)
                    }
                }
            }
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
    }
}
