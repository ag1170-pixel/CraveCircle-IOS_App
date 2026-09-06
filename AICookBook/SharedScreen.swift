import SwiftUI

struct SharedScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selection = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                HStack {
                    LimeSegmentedControl(segments: ["Received", "Sent"], selection: $selection)
                        .frame(width: 200)
                }
                .padding(.vertical, AppSpacing.sm)
                .frame(maxWidth: .infinity)
                .background(AppTheme.background)
                .overlay(alignment: .bottom) { Divider().overlay(AppTheme.separator) }
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        let records = environment.sharedLog.filter { rec in
                            if selection == 0 {
                                // Received
                                return rec.toUserId == (environment.currentUser?.id ?? "me") || rec.toUserId == "me" // hack for mock
                            } else {
                                // Sent
                                return rec.fromUserId == (environment.currentUser?.id ?? "me")
                            }
                        }
                        
                        if records.isEmpty {
                            EmptyRecipesState { }
                                .padding(.top, 40)
                        } else {
                            ForEach(records) { record in
                                if let recipe = environment.recipes.first(where: { $0.id == record.recipeId }) {
                                    SharedRecordRow(record: record, recipe: recipe)
                                    Divider().overlay(AppTheme.separator).padding(.leading, 72)
                                }
                            }
                        }
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Shared Recipes")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(AppTheme.accentInk)
    }
}

private struct SharedRecordRow: View {
    let record: SharedRecipeRecord
    let recipe: Recipe
    @EnvironmentObject private var environment: AppEnvironment
    
    var body: some View {
        Button {
            Haptics.tap()
            environment.selectRecipe(recipe)
        } label: {
            HStack(spacing: AppSpacing.md) {
                cover(recipe)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(AppFont.body(15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    
                    Text(record.fromUserId == environment.currentUser?.id ? "Sent via \(record.channel ?? "Link")" : "Received")
                        .font(AppFont.body(13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
