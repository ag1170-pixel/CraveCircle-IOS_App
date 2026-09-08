import SwiftUI

struct CommunityFeedScreen: View {
    @EnvironmentObject private var environment: AppEnvironment
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppSpacing.lg) {
                    let feed = environment.communityFeed
                    if feed.isEmpty {
                        EmptyRecipesState { }
                            .padding(.top, 40)
                    } else {
                        ForEach(feed) { recipe in
                            FeedRecipeCard(recipe: recipe) {
                                environment.selectRecipe(recipe)
                            }
                        }
                    }
                }
                .padding(AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Community Feed")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(AppTheme.accentInk)
    }
}

private struct FeedRecipeCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Avatar + Creator
                HStack(spacing: AppSpacing.sm) {
                    CreatorAvatarView(handle: recipe.ownerUsername, size: 36, showBorder: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.ownerUsername ?? "@creator")
                            .font(AppFont.body(14, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Published a recipe")
                            .font(AppFont.body(12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if recipe.visibility == .followers {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.accentInk)
                            .padding(6)
                            .background(AppTheme.accentSoft, in: Circle())
                    }
                }
                
                // Image
                cover(recipe)
                    .aspectRatio(4/3, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                
                // Title and Meta
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(AppFont.display(18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    MetaLine(recipe: recipe)
                }
            }
            .padding(AppSpacing.md)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}
