//
//  NPSPromptSheet.swift
//  CraveCircle (AICookBook)
//
//  Quarterly Net Promoter Score prompt. Fires after the user's 10th cook and at most once
//  every 90 days. 0-10 scale (clamped to 1-10 server-side), optional reason, bucket label
//  (Detractor / Passive / Promoter) revealed after a tap so the user knows what their rating
//  means. Writes to cravecircle.user_feedback with kind='nps'.
//

import SwiftUI

struct NPSPromptSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int? = nil
    @State private var text: String = ""
    @State private var submitting = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Capsule().fill(AppTheme.hairline).frame(width: 36, height: 4)
                .padding(.top, AppSpacing.sm)

            VStack(spacing: 6) {
                Text("How likely are you to recommend CraveCircle to a friend?")
                    .font(AppFont.display(20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("0 = not at all, 10 = absolutely. One tap.")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.lg)

            scaleRow

            // Bucket label — appears after tap so the user understands the shape of the signal
            // they're giving. Keeps it human instead of a cold number.
            if let r = rating {
                Text(bucketLabel(r))
                    .font(AppFont.body(13, weight: .bold))
                    .foregroundStyle(bucketColor(r))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(bucketColor(r).opacity(0.12), in: Capsule())
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

    /// 0-10 scale laid out as two rows so the buttons stay thumb-friendly on iPhone SE.
    private var scaleRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0...5, id: \.self) { n in ratingButton(n) }
            }
            HStack(spacing: 6) {
                ForEach(6...10, id: \.self) { n in ratingButton(n) }
            }
            HStack {
                Text("Not likely").font(AppFont.body(11)).foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Text("Very likely").font(AppFont.body(11)).foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.horizontal, AppSpacing.md)
    }

    private func ratingButton(_ n: Int) -> some View {
        Button {
            Haptics.select()
            rating = n
        } label: {
            Text("\(n)")
                .font(AppFont.body(15, weight: .bold))
                .foregroundStyle(rating == n ? AppTheme.onAccent : AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(rating == n ? bucketColor(n) : AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var reasonPlaceholder: String {
        guard let r = rating else { return "Anything to add? (optional)" }
        if r <= 6 { return "What's getting in the way? (optional)" }
        if r <= 8 { return "What would make it a 10? (optional)" }
        return "What do you love most? (optional)"
    }

    /// Standard NPS buckets: 0-6 Detractors, 7-8 Passives, 9-10 Promoters.
    private func bucketLabel(_ n: Int) -> String {
        if n <= 6 { return "Detractor" }
        if n <= 8 { return "Passive" }
        return "Promoter"
    }
    private func bucketColor(_ n: Int) -> Color {
        if n <= 6 { return .red }
        if n <= 8 { return .orange }
        return .green
    }

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
