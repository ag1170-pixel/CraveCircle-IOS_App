import re
with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'r') as f:
    content = f.read()

prop = """
    var myLibraryRecipes: [Recipe] {
        recipes.filter { canDelete($0) || isSaved(recipeId: $0.id) }
    }
"""
content = re.sub(
    r'(var myPublished: \[Recipe\] \{ ownedRecipes\.filter \{ !isDraft\(recipeId: \$0\.id\) \} \})',
    r'\1\n' + prop,
    content
)
with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'w') as f:
    f.write(content)
