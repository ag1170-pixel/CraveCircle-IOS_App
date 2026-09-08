import re

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/ProfileScreen.swift', 'r') as f:
    content = f.read()

# 1. Add showDeleteAccount state to AccountSheet
content = re.sub(
    r'(@Environment\(\\.dismiss\) private var dismiss)',
    r'\1\n    @State private var showDeleteAccount = false',
    content
)

# 2. Add Delete Account button and sheet modifier to AccountSheet
button_str = """
                Button(role: .destructive) {
                    showDeleteAccount = true
                } label: {
                    Text("Delete Account")
                        .font(AppFont.body(16, weight: .bold))
                        .foregroundStyle(AppTheme.destructive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.destructive.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .padding(.bottom, AppSpacing.sm)
"""
# find Spacer() before the end of the VStack in AccountSheet
content = re.sub(
    r'(Spacer\(\)\n            \}\n            \.padding\(AppSpacing\.lg\))',
    lambda m: f"Spacer()\n{button_str}            }}\n            .padding(AppSpacing.lg)",
    content
)

sheet_str = """
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
"""
content = re.sub(
    r'(ToolbarItem\(placement: \.cancellationAction\) \{\n                    Button\("Done"\) \{ dismiss\(\) \}\n                        \.font\(AppFont\.body\(16, weight: \.semibold\)\)\n                        \.foregroundStyle\(AppTheme\.textPrimary\)\n                \}\n            \})',
    lambda m: m.group(1) + sheet_str,
    content
)

# 3. Append DeleteAccountSheet struct at the bottom
delete_sheet_str = """

// MARK: - Delete Account Sheet

struct DeleteAccountSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\\.dismiss) private var dismiss
    @State private var deleteMode: Int = 0 // 0 = Temporary, 1 = Permanent
    @State private var reason: String = ""
    @State private var isDeleting = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("We're sorry to see you go.")
                        .font(AppFont.display(24, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    LimeSegmentedControl(segments: ["Temporary Disable", "Permanent Delete"], selection: $deleteMode)
                    
                    if deleteMode == 0 {
                        Text("Your account will be hidden from the community. You can reactivate it anytime by logging back in.")
                            .font(AppFont.body(15))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Why are you deleting your account?")
                                .font(AppFont.body(16, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text("Please tell us about any issues you faced so we can learn and improve.")
                                .font(AppFont.body(14))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            TextEditor(text: $reason)
                                .font(AppFont.body(15))
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(AppTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                                .overlay(RoundedRectangle(cornerRadius: AppRadius.card).stroke(AppTheme.hairline, lineWidth: 1))
                        }
                    }
                    
                    Spacer(minLength: 40)
                    
                    Button(role: .destructive) {
                        deleteAccount()
                    } label: {
                        HStack {
                            if isDeleting { ProgressView().tint(.white).padding(.trailing, 4) }
                            Text(deleteMode == 0 ? "Disable Account" : "Delete Permanently")
                                .font(AppFont.body(16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppTheme.destructive, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(isDeleting || (deleteMode == 1 && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    
                    if deleteMode == 1 && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Please provide a reason to permanently delete your account.")
                            .font(AppFont.body(12))
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(AppSpacing.lg)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(AppFont.body(16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }
    
    private func deleteAccount() {
        isDeleting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Haptics.success()
            isDeleting = false
            dismiss()
            environment.signOut()
        }
    }
}
"""
content += delete_sheet_str

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/ProfileScreen.swift', 'w') as f:
    f.write(content)
