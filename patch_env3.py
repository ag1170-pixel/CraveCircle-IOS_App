import re
with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'r') as f:
    content = f.read()

# Fix default saved/liked
content = re.sub(
    r'@Published private\(set\) var savedRecipeIds: Set<String> = \[.*?\]',
    r'@Published private(set) var savedRecipeIds: Set<String> = []',
    content
)
content = re.sub(
    r'@Published private\(set\) var likedRecipeIds: Set<String> = \[.*?\]',
    r'@Published private(set) var likedRecipeIds: Set<String> = []',
    content
)

# Add @AppStorage for guest ID
content = re.sub(
    r'(@Published private\(set\) var recipes: \[Recipe\] = \[\] \{ didSet \{ persist\(recipes, "recipes\.json"\) \} \})',
    r'@AppStorage("guest_user_id") private var guestUserId: String = ""\n    \1',
    content
)

# Add isGuest property
content = re.sub(
    r'(var isAdmin: Bool \{ currentUser\?\.role == \.admin \})',
    r'\1\n    var isGuest: Bool { currentUser?.id.hasPrefix("guest_") == true || currentUser == nil }',
    content
)

# Update continueAsGuest
new_guest = """
    func continueAsGuest() {
        if guestUserId.isEmpty {
            guestUserId = "guest_\(Int.random(in: 1000...9999))"
        }
        currentUser = UserProfile(id: guestUserId, username: "Guest", fullName: "Guest User", avatarUrl: nil, role: .user)
        appState = .signedIn
    }
    
    func migrateGuestData(to newUserId: String) {
        // Find any recipes created by the guest and update their ownerId
        let oldGuestId = guestUserId
        guard !oldGuestId.isEmpty else { return }
        
        for i in recipes.indices {
            if recipes[i].ownerId == oldGuestId {
                recipes[i].ownerId = newUserId
            }
        }
        
        guestUserId = "" // Clear the guest id now that they are signed in
    }
"""
content = re.sub(
    r'func continueAsGuest\(\) \{\n        currentUser = nil // Guest has no profile\n        appState = \.signedIn // Or a specific guest state, but signedIn with nil user handles most things\n    \}',
    new_guest.strip(),
    content
)

with open('/Users/user38/Projects/CraveCircle.cc/AICookBook/AppEnvironment.swift', 'w') as f:
    f.write(content)
