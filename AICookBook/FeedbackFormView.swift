import SwiftUI

/// Swiggy-style "Write a letter to our CEO" — a single warm compose box. Envelope mark, a short
/// invitation, one big text field (max 2000 chars with a live counter), and a "Share message" CTA.
/// Brand: cream background, coral CTA, charcoal text.
struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment

    @State private var message = ""
    @State private var isSubmitting = false
    @State private var showThankYou = false
    @FocusState private var editorFocused: Bool

    private let limit = 2000
    private let coral = AppTheme.brand

    private var trimmed: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        header
                        editor
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)

                if showThankYou { thankYouOverlay }
            }
            .safeAreaInset(edge: .bottom) { shareButton }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textPrimary)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { editorFocused = false }
                        .font(AppFont.body(16, weight: .bold))
                        .foregroundStyle(coral)
                }
            }
            .tint(AppTheme.accentInk)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(coral)
                .frame(width: 60, height: 60)
                .background(coral.opacity(0.12), in: Circle())

            Text("Write a letter to our CEO")
                .font(AppFont.display(26, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("No thought is too small. We're here to listen. We read every word, and we care ❤️")
                .font(AppFont.body(16))
                .foregroundStyle(AppTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if message.isEmpty {
                Text("Share your thoughts...")
                    .font(AppFont.body(17))
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $message)
                .font(AppFont.body(17))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 220)
                // Cap input at the limit so the counter can never exceed it.
                .onChange(of: message) { _, new in
                    if new.count > limit { message = String(new.prefix(limit)) }
                }
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(editorFocused ? coral.opacity(0.6) : AppTheme.hairline,
                        lineWidth: editorFocused ? 1.5 : 1)
        )
        .overlay(alignment: .bottomTrailing) {
            Text("\(message.count)/\(limit)")
                .font(AppFont.body(13))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(12)
        }
    }

    private var shareButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if isSubmitting { ProgressView().tint(AppTheme.onBrand) }
                Text("Share message")
                    .font(AppFont.body(17, weight: .bold))
            }
            .foregroundStyle(AppTheme.onBrand)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(trimmed.isEmpty ? coral.opacity(0.4) : coral,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(trimmed.isEmpty || isSubmitting)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background(.ultraThinMaterial)
    }

    private var thankYouOverlay: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("💌").font(.system(size: 72))
                Text("Message on its way.")
                    .font(AppFont.display(28, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Thank you for writing to us.\nEvery word reaches our team.")
                    .font(AppFont.body(17))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func submit() {
        editorFocused = false
        isSubmitting = true
        Haptics.success()
        Task {
            do {
                try await environment.submitFeedback(type: "ceo_letter", content: trimmed,
                                                     handle: environment.currentUser?.username)
                await MainActor.run {
                    withAnimation(.spring()) { showThankYou = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { dismiss() }
                }
            } catch {
                // Keep the message so the user can retry — never silently drop what they wrote.
                print("Error submitting CEO letter: \(error)")
                await MainActor.run { isSubmitting = false }
            }
        }
    }
}
