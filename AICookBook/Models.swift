import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String
    var username: String?
    var fullName: String?
    var avatarUrl: String?
}

enum ImportStatus: String, Codable {
    case queued
    case downloading
    case transcribing
    case extracting
    case done
    case error

    var displayLabel: String {
        switch self {
        case .queued: return "Queued"
        case .downloading: return "Downloading reel"
        case .transcribing: return "Transcribing audio"
        case .extracting: return "Extracting recipe"
        case .done: return "Done"
        case .error: return "Failed"
        }
    }

    var isTerminal: Bool {
        self == .done || self == .error
    }
}

struct ImportSubmitResponse: Codable {
    let jobId: String
    let poll: String?
    let status: ImportStatus?
}

struct ImportJob: Codable, Identifiable {
    let id: String
    let status: ImportStatus
    let errorMessage: String?
    let recipeId: String?
}

struct Recipe: Codable, Identifiable, Hashable {
    let id: String
    let ownerId: String
    var title: String
    var description: String?
    var prepTime: String?
    var cookTime: String?
    var ingredients: [IngredientGroup]
    var directions: [DirectionStep]
    var thumbnailUrl: String?
    var ownerUsername: String?
}

struct IngredientGroup: Codable, Hashable {
    var groupName: String?
    var items: [String]
}

struct DirectionStep: Codable, Hashable {
    var stepIndex: Int
    var text: String
}

extension Recipe {
    static let placeholderRecipes: [Recipe] = [
        Recipe(
            id: "preview-1",
            ownerId: "preview-user",
            title: "Spicy Paneer Wrap",
            description: "High-protein paneer wrap with smoky masala and mint yogurt.",
            prepTime: "12 min",
            cookTime: "8 min",
            ingredients: [IngredientGroup(groupName: "Wrap", items: ["2 rotis", "200g paneer", "onion slices"])],
            directions: [DirectionStep(stepIndex: 1, text: "Pan-sear paneer"), DirectionStep(stepIndex: 2, text: "Assemble wrap")],
            thumbnailUrl: nil,
            ownerUsername: "@aicookbook"
        ),
        Recipe(
            id: "preview-2",
            ownerId: "preview-user",
            title: "One Pot Tomato Pasta",
            description: "Quick comfort meal with garlic, tomato, and basil.",
            prepTime: "10 min",
            cookTime: "18 min",
            ingredients: [IngredientGroup(groupName: "Main", items: ["250g pasta", "tomato puree", "garlic"])],
            directions: [DirectionStep(stepIndex: 1, text: "Saute garlic"), DirectionStep(stepIndex: 2, text: "Boil pasta in sauce")],
            thumbnailUrl: nil,
            ownerUsername: "@chefbot"
        )
    ]
}
