import re
with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'r') as f:
    content = f.read()

props = """
    @AppStorage("guest_recipes_viewed") private var guestRecipesViewed = 0
    @Published var showGuestPaywall = false

    func canViewRecipe() -> Bool {
        if isGuest {
            if guestRecipesViewed >= 10 {
                showGuestPaywall = true
                return false
            }
            guestRecipesViewed += 1
        }
        return true
    }
"""

content = re.sub(
    r'(@Published private\(set\) var recipeSwipeContext: \[Recipe\]\?)',
    props + r'\n    \1',
    content
)

content = re.sub(
    r'(func selectRecipe\(_ recipe: Recipe, in context: \[Recipe\]\? = nil\) \{)',
    r'\1\n        guard canViewRecipe() else { return }',
    content
)

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'w') as f:
    f.write(content)
