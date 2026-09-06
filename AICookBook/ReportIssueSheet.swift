import SwiftUI

struct ReportIssueSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    @State private var issueText = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if showSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.green)
                        Text("Report Sent")
                            .font(AppFont.display(24, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Thanks for letting us know! We'll review the transcription for \"\(recipe.title)\".")
                            .font(AppFont.body(16))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("What's wrong with this recipe?")
                            .font(AppFont.display(24, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text("Did the AI mishear an ingredient? Did it miss a step from the video? Let us know below so we can fix it.")
                            .font(AppFont.body(16))
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        TextEditor(text: $issueText)
                            .font(AppFont.body(16))
                            .padding(12)
                            .frame(height: 150)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                            .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.hairline, lineWidth: 1))
                            .padding(.top, 8)
                        
                        Spacer()
                        
                        Button {
                            submitReport()
                        } label: {
                            HStack {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                }
                                Text("Submit Report")
                                    .font(AppFont.body(18, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(issueText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.5) : Color(hex: "EA5A38"))
                            .clipShape(Capsule())
                        }
                        .disabled(issueText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                    }
                    .padding(24)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !showSuccess {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(AppFont.body(16, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        Haptics.success()
        // Simulate network request to save report
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring()) {
                showSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }
}
