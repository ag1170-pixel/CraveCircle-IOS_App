import re
with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/RootView.swift', 'r') as f:
    content = f.read()

sheet_code = """
        .sheet(isPresented: $environment.showGuestPaywall) {
            GuestWallView(
                title: "Login Required",
                message: "You've viewed 10 recipes! Please log in or sign up to continue full access."
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
"""

content = re.sub(
    r'(\.fullScreenCover\(item: Binding\(\n\s*get: \{ environment\.selectedRecipe \},\n\s*set: \{ _ in environment\.dismissRecipeDetail\(\) \}\n\s*\)\) \{ recipe in\n\s*RecipeDetailPager\(start: recipe\)\n\s*\.environmentObject\(environment\)\n\s*\})',
    r'\1' + sheet_code,
    content
)

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/RootView.swift', 'w') as f:
    f.write(content)
