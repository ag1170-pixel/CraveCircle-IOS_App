//
//  SampleRecipes.swift
//  CraveCircle (AICookBook)
//
//  ⭐ CONTENT FILE — bundled starter recipes. Add new recipes HERE, each with a matching
//  image in Assets.xcassets (thumbnailUrl = the imageset name). Keep the Recipe(...) shape
//  identical to the examples. App logic/models live in Models.swift — do not edit those here.
//

import Foundation

extension Recipe {
    static let placeholderRecipes: [Recipe] = [
        Recipe(
            id: "recipe-preview",
            ownerId: "creator-preview",
            title: "Cloud Fetching...",
            description: "Recipes are now securely fetched from the cloud.",
            prepTime: "0 min", cookTime: "0 min", servings: 1,
            ingredients: [], directions: [],
            thumbnailUrl: nil, ownerUsername: "@cloud"
        )
]
}
