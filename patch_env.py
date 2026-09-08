import re

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'r') as f:
    content = f.read()

# 1. Change initial state of friends, requests to empty arrays
content = re.sub(
    r'@Published private\(set\) var circleFriends: \[FriendItem\] = FriendItem\.samples',
    r'@Published private(set) var circleFriends: [FriendItem] = []',
    content
)
content = re.sub(
    r'@Published private\(set\) var incomingRequests: \[FriendRequestItem\] = FriendRequestItem\.incomingSamples',
    r'@Published private(set) var incomingRequests: [FriendRequestItem] = []',
    content
)
content = re.sub(
    r'@Published private\(set\) var outgoingRequests: \[FriendRequestItem\] = FriendRequestItem\.outgoingSamples',
    r'@Published private(set) var outgoingRequests: [FriendRequestItem] = []',
    content
)

# 2. In hydrateLocal, default collections and grocery to empty arrays instead of samples
content = re.sub(
    r'ownedCollections = LocalStore\.load\(\[CollectionItem\]\.self, from: "owned_collections\.json"\) \?\? CollectionItem\.ownedSamples',
    r'ownedCollections = LocalStore.load([CollectionItem].self, from: "owned_collections.json") ?? []',
    content
)
content = re.sub(
    r'sharedCollections = LocalStore\.load\(\[CollectionItem\]\.self, from: "shared_collections\.json"\) \?\? CollectionItem\.sharedSamples',
    r'sharedCollections = LocalStore.load([CollectionItem].self, from: "shared_collections.json") ?? []',
    content
)
content = re.sub(
    r'groceryItems = LocalStore\.load\(\[GroceryItem\]\.self, from: "grocery\.json"\) \?\? GroceryItem\.demo',
    r'groceryItems = LocalStore.load([GroceryItem].self, from: "grocery.json") ?? []',
    content
)

# 3. Add myLibraryRecipes computed property
if 'var myLibraryRecipes:' not in content:
    prop = """
    var myLibraryRecipes: [Recipe] {
        recipes.filter { canDelete($0) || isSaved(recipeId: $0.id) }
    }
"""
    content = re.sub(
        r'(var myPublished: \[Recipe\] \{\n        recipes\.filter \{ canDelete\(\$0\) && \$0\.status == \.published \}\n    \})',
        r'\1\n' + prop,
        content
    )

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'w') as f:
    f.write(content)
