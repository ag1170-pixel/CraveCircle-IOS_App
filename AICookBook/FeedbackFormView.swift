import SwiftUI

struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var disappointmentSelection: Int? = nil
    @State private var fansCommonality: String = ""
    @State private var improvements: String = ""
    @State private var additionalFeedback: String = ""
    
    @State private var isSubmitting = false
    @State private var showThankYou = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // Question 1
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. How disappointed would you be without this product?")
                            .font(AppFont.body(20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        VStack(spacing: 12) {
                            radioButton(id: 0, text: "Very disappointed")
                            radioButton(id: 1, text: "Somewhat disappointed")
                            radioButton(id: 2, text: "Not disappointed")
                        }
                    }
                    
                    // Question 2
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. What do our biggest product fans have in common?")
                            .font(AppFont.body(20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        TextEditor(text: $fansCommonality)
                            .font(AppFont.body(16))
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.hairline, lineWidth: 1))
                    }
                    
                    // Question 3
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. What could we improve to make you love it more?")
                            .font(AppFont.body(20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        TextEditor(text: $improvements)
                            .font(AppFont.body(16))
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.hairline, lineWidth: 1))
                    }
                    
                    // Additional Text
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Any other feedback for us?")
                            .font(AppFont.body(20, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        TextEditor(text: $additionalFeedback)
                            .font(AppFont.body(16))
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.hairline, lineWidth: 1))
                    }
                    
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Your Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        submitFeedback()
                    }
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .disabled(isSubmitting || disappointmentSelection == nil)
                }
            }
            .overlay {
                if showThankYou {
                    thankYouOverlay
                }
            }
        }
    }
    
    private func radioButton(id: Int, text: String) -> some View {
        Button {
            Haptics.select()
            disappointmentSelection = id
        } label: {
            HStack(spacing: 16) {
                Image(systemName: disappointmentSelection == id ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(disappointmentSelection == id ? AppTheme.accent : AppTheme.textTertiary)
                
                Text(text)
                    .font(AppFont.body(16, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
            }
            .padding(16)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(disappointmentSelection == id ? AppTheme.accent : AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    private var thankYouOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.accent)
                Text("Thank You!")
                    .font(AppFont.display(24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Your feedback helps us make CraveCircle better.")
                    .font(AppFont.body(16))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
            .padding(40)
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    private func submitFeedback() {
        isSubmitting = true
        Haptics.success()
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring()) {
                showThankYou = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }
}
