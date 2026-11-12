//
// ==============================================================================
// CRAVECIRCLE iOS - CODE REVIEW REFERENCE
// FILE: ImportFeedbackSheet.swift
// ==============================================================================
//
// 1. PURPOSE:
//    Modal presentation sheet for ImportFeedbackSheet.
//
// 2. ARCHITECTURAL ROLE:
//    Provides focused modal user interactions, form inputs, and state updates.
//
// 3. MENTOR EXPLANATION (15-Second Verbal Summary):
//    "ImportFeedbackSheet is presented modally to capture user input and update shared application state."
//
// ==============================================================================
//

import SwiftUI

struct ImportFeedbackTarget: Identifiable {
    let id: String
    init(_ id: String) { self.id = id }
}

// MARK: - SwiftUI View Component
struct ImportFeedbackSheet: View {
    let recipeId: String

    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var rating = 0
    @State private var note = ""
    @State private var sending = false

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text("How did that import go?")
                .font(AppFont.display(22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Your feedback helps us make recipe imports better.")
                .font(AppFont.body(14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppSpacing.sm) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = value
                    } label: {
                        Image(systemName: value <= rating ? "star.fill" : "star")
                            .font(.system(size: 28))
                            .foregroundStyle(value <= rating ? AppTheme.brand : AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value) out of 5 stars")
                }
            }

            TextField("Anything we should know? (optional)", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .font(AppFont.body(15))
                .padding(12)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Button("Skip") { finish() }
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button {
                    send()
                } label: {
                    HStack(spacing: 8) {
                        if sending { ProgressView().tint(AppTheme.onAccent) }
                        Text("Send")
                    }
                    .font(AppFont.body(15, weight: .bold))
                    .foregroundStyle(AppTheme.onAccent)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent, in: Capsule())
                }
                .disabled(rating == 0 || sending)
            }
        }
        .padding(AppSpacing.lg)
        .presentationDragIndicator(.visible)
    }

    private func send() {
        guard rating > 0, !sending else { return }
        sending = true
        Task {
            _ = await environment.submitImportFeedback(
                rating: rating,
                text: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
                recipeId: recipeId
            )
            finish()
        }
    }

    private func finish() {
        environment.acknowledgeImportFeedback()
        dismiss()
    }
}
