//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: NPSPromptSheet.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Modal presentation sheet for NPSPromptSheet.
//
// 2. ARCHITECTURAL ROLE:
//    Provides focused modal user interactions, form inputs, and state updates.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "NPSPromptSheet is presented modally to capture user input and update shared application state."
//
// ==============================================================================
//

//
//  NPSPromptSheet.swift
//  CraveCircle (AICookBook)
//
//  One-time five-star rating prompt. Offered after 10 imports or 20 distinct recipe views.
//  Writes to user_feedback with kind='nps'.
//

import SwiftUI

// MARK: - SwiftUI View Component
struct NPSPromptSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int? = nil
    @State private var text: String = ""
    @State private var submitting = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Capsule().fill(AppTheme.hairline).frame(width: 36, height: 4)
                .padding(.top, AppSpacing.sm)

            VStack(spacing: 6) {
                Text("How would you rate CraveCircle?")
                    .font(AppFont.display(20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Choose from 1 to 5 stars.")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.lg)

            scaleRow

            if let r = rating {
                Text("\(r) out of 5 stars")
                    .font(AppFont.body(13, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.12), in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if rating != nil {
                TextField(reasonPlaceholder, text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .font(AppFont.body(14))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.hairline, lineWidth: 1))
                    .padding(.horizontal, AppSpacing.lg)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 12) {
                Button {
                    environment.acknowledgeNPSPrompt(dismissed: true)
                    dismiss()
                } label: {
                    Text("Not now").font(AppFont.body(15, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    submit()
                } label: {
                    HStack(spacing: 8) {
                        if submitting { ProgressView().tint(AppTheme.onAccent) }
                        Text("Send").font(AppFont.body(15, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background((rating == nil ? AppTheme.accent.opacity(0.4) : AppTheme.accent), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(rating == nil || submitting)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .animation(.easeInOut(duration: 0.2), value: rating)
    }

    private var scaleRow: some View {
        HStack(spacing: 14) {
            ForEach(1...5, id: \.self) { n in ratingButton(n) }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func ratingButton(_ n: Int) -> some View {
        Button {
            Haptics.select()
            rating = n
        } label: {
            Image(systemName: (rating ?? 0) >= n ? "star.fill" : "star")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle((rating ?? 0) >= n ? AppTheme.accent : AppTheme.textTertiary)
                .frame(width: 44, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(n) star\(n == 1 ? "" : "s")")
    }

    private var reasonPlaceholder: String { "Anything to add? (optional)" }

    private func submit() {
        guard let r = rating else { return }
        submitting = true
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            _ = await environment.submitNPS(rating: r, text: t.isEmpty ? nil : t)
            await MainActor.run { dismiss() }
        }
    }
}
