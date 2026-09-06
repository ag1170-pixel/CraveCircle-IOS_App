import SwiftUI

struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPage = 0
    @State private var disappointmentSelection: Int? = nil
    @State private var fansCommonality: String = ""
    @State private var improvements: String = ""
    @State private var additionalFeedback: String = ""
    
    @State private var isSubmitting = false
    @State private var showThankYou = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                TabView(selection: $currentPage) {
                    disappointmentCard.tag(0)
                    commonalityCard.tag(1)
                    improvementsCard.tag(2)
                    additionalCard.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                .ignoresSafeArea(.keyboard)
                
                // Progress indicator at top
                VStack {
                    ProgressView(value: Double(currentPage + 1), total: 4.0)
                        .tint(AppTheme.accent)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    Spacer()
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            .overlay {
                if showThankYou {
                    thankYouOverlay
                }
            }
        }
    }
    
    // MARK: - Cards
    
    private var disappointmentCard: some View {
        cardContainer {
            Text("How disappointed would you be if you could no longer use CraveCircle?")
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                selectionPill(id: 0, text: "Very disappointed", emoji: "😭")
                selectionPill(id: 1, text: "Somewhat disappointed", emoji: "😕")
                selectionPill(id: 2, text: "Not disappointed", emoji: "🤷‍♂️")
            }
            .padding(.top, 24)
            
            Spacer()
            nextButton(disabled: disappointmentSelection == nil)
        }
    }
    
    private var commonalityCard: some View {
        cardContainer {
            Text("What do you think our biggest fans have in common?")
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            TextEditor(text: $fansCommonality)
                .font(AppFont.body(18))
                .padding(12)
                .frame(maxHeight: 200)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.accent.opacity(0.3), lineWidth: 2))
                .padding(.top, 24)
            
            Spacer()
            nextButton(disabled: fansCommonality.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
    
    private var improvementsCard: some View {
        cardContainer {
            Text("What could we improve to make you love it even more?")
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            TextEditor(text: $improvements)
                .font(AppFont.body(18))
                .padding(12)
                .frame(maxHeight: 200)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.accent.opacity(0.3), lineWidth: 2))
                .padding(.top, 24)
            
            Spacer()
            nextButton(disabled: improvements.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
    
    private var additionalCard: some View {
        cardContainer {
            Text("Any other magic you'd like to see?")
                .font(AppFont.display(24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            TextEditor(text: $additionalFeedback)
                .font(AppFont.body(18))
                .padding(12)
                .frame(maxHeight: 200)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.hairline, lineWidth: 1))
                .padding(.top, 24)
            
            Spacer()
            
            Button {
                submitFeedback()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView().tint(AppTheme.onAccent)
                    }
                    Text("Submit Feedback")
                        .font(AppFont.body(18, weight: .bold))
                }
                .foregroundStyle(AppTheme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.accent)
                .clipShape(Capsule())
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(isSubmitting)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Components
    
    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 60)
            content()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func selectionPill(id: Int, text: String, emoji: String) -> some View {
        Button {
            Haptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                disappointmentSelection = id
            }
            // Auto-advance after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { currentPage += 1 }
            }
        } label: {
            HStack(spacing: 16) {
                Text(emoji).font(.system(size: 28))
                Text(text)
                    .font(AppFont.body(18, weight: .semibold))
                    .foregroundStyle(disappointmentSelection == id ? AppTheme.onAccent : AppTheme.textPrimary)
                Spacer()
                if disappointmentSelection == id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(disappointmentSelection == id ? AppTheme.accent : AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(disappointmentSelection == id ? .clear : AppTheme.hairline, lineWidth: 1))
            .scaleEffect(disappointmentSelection == id ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private func nextButton(disabled: Bool) -> some View {
        Button {
            withAnimation { currentPage += 1 }
        } label: {
            Text("Next")
                .font(AppFont.body(18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(disabled ? Color.gray.opacity(0.5) : Color.black)
                .clipShape(Capsule())
        }
        .disabled(disabled)
        .padding(.bottom, 20)
    }
    
    private var thankYouOverlay: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("🎉")
                    .font(.system(size: 80))
                Text("You're a legend.")
                    .font(AppFont.display(32, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Your feedback went straight to our vault.\nWe'll use it to make CraveCircle even better.")
                    .font(AppFont.body(18))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private func submitFeedback() {
        isSubmitting = true
        Haptics.success()
        // Here we would actually save to the DB, which will later be fetched to Obsidian
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring()) {
                showThankYou = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                dismiss()
            }
        }
    }
}
