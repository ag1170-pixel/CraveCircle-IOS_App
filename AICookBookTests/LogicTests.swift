//
//  LogicTests.swift
//  AICookBookTests
//
//  Unit tests for the pure, on-device logic: ingredient scaling, search/filtering,
//  grocery aisle sorting + dedupe, and the recommendation engine. No UI, no network.
//

import XCTest
@testable import AICookBook

// MARK: - Helpers

private func makeRecipe(
    id: String = UUID().uuidString,
    title: String,
    ingredients: [String],
    prep: String? = nil,
    cook: String? = nil,
    proteinG: Double? = nil
) -> Recipe {
    Recipe(
        id: id,
        ownerId: "tester",
        title: title,
        description: nil,
        prepTime: prep,
        cookTime: cook,
        servings: 2,
        ingredients: [IngredientGroup(groupName: nil, items: ingredients)],
        directions: [],
        thumbnailUrl: nil,
        ownerUsername: "@tester",
        sourceLanguage: nil,
        nutrition: proteinG.map { RecipeNutrition(calories: 400, carbsG: 30, proteinG: $0, fatG: 15) },
        sourceUrl: nil
    )
}

// MARK: - IngredientScaler

final class IngredientScalerTests: XCTestCase {
    func testDoublingWholeNumber() {
        XCTAssertTrue(IngredientScaler.scale(text: "2 eggs", from: 2, to: 4).contains("4"))
    }

    func testSameServingsUnchanged() {
        XCTAssertEqual(IngredientScaler.scale(text: "1 cup flour", from: 2, to: 2), "1 cup flour")
    }

    func testScalesAttachedUnit() {
        // 240ml doubled → 480ml
        XCTAssertTrue(IngredientScaler.scale(text: "240ml milk", from: 2, to: 4).contains("480"))
    }
}

// MARK: - RecipeSearch

final class RecipeSearchTests: XCTestCase {
    func testDietClassification() {
        XCTAssertEqual(RecipeSearch.dietClass(makeRecipe(title: "Chicken Curry", ingredients: ["500g chicken", "1 onion"])), .nonVeg)
        XCTAssertEqual(RecipeSearch.dietClass(makeRecipe(title: "Paneer Butter Masala", ingredients: ["paneer", "butter", "tomato"])), .veg)
        XCTAssertEqual(RecipeSearch.dietClass(makeRecipe(title: "Aloo Sabzi", ingredients: ["potato", "oil", "salt", "cumin"])), .vegan)
    }

    func testTotalMinutes() {
        XCTAssertEqual(RecipeSearch.totalMinutes(makeRecipe(title: "x", ingredients: ["a"], prep: "15 min", cook: "20 min")), 35)
        XCTAssertEqual(RecipeSearch.totalMinutes(makeRecipe(title: "x", ingredients: ["a"], prep: "1 hr", cook: "10 min")), 70)
    }

    func testIngredientQueryMatch() {
        let recipes = [
            makeRecipe(title: "Green Pasta", ingredients: ["pasta", "spinach", "garlic"]),
            makeRecipe(title: "Paneer Wrap", ingredients: ["paneer", "tortilla"])
        ]
        let hits = RecipeSearch.apply(recipes, query: "paneer", filters: RecipeFilters())
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.title, "Paneer Wrap")
    }

    func testHighProtein() {
        XCTAssertTrue(RecipeSearch.isHighProtein(makeRecipe(title: "x", ingredients: ["rice"], proteinG: 25)))
        XCTAssertFalse(RecipeSearch.isHighProtein(makeRecipe(title: "Salad", ingredients: ["lettuce", "olive oil"], proteinG: 5)))
    }

    func testVegFilterExcludesMeat() {
        let recipes = [
            makeRecipe(title: "Chicken Bowl", ingredients: ["chicken"]),
            makeRecipe(title: "Veg Bowl", ingredients: ["chickpea", "spinach"])
        ]
        var f = RecipeFilters(); f.diet = .veg
        let out = RecipeSearch.apply(recipes, query: "", filters: f)
        XCTAssertEqual(out.map(\.title), ["Veg Bowl"])
    }
}

// MARK: - GrocerySort

final class GrocerySortTests: XCTestCase {
    func testAisleClassification() {
        XCTAssertEqual(GrocerySort.aisle(for: "2 chicken breasts"), .meatFish)
        XCTAssertEqual(GrocerySort.aisle(for: "1 onion"), .produce)
        XCTAssertEqual(GrocerySort.aisle(for: "100g butter"), .dairy)
        XCTAssertEqual(GrocerySort.aisle(for: "2 cups flour"), .pantry)
        XCTAssertEqual(GrocerySort.aisle(for: "1 tsp turmeric"), .spices)
    }

    func testCoreNameStripsQuantity() {
        XCTAssertEqual(GrocerySort.coreName("2 tbsp olive oil"), "olive oil")
        XCTAssertEqual(GrocerySort.coreName("1 cup flour"), "flour")
        XCTAssertEqual(GrocerySort.coreName("3 cloves garlic"), "garlic")
    }

    func testGroupingOrdersProduceFirst() {
        let items = [
            GroceryItem(id: "1", ingredientName: "2 cups flour", checked: false),
            GroceryItem(id: "2", ingredientName: "1 onion", checked: false)
        ]
        let grouped = GrocerySort.grouped(items)
        XCTAssertEqual(grouped.first?.aisle, .produce)
    }
}

// MARK: - RecommendationEngine

final class RecommendationEngineTests: XCTestCase {
    func testCuisineReason() {
        let r = makeRecipe(title: "Paneer Tikka Masala", ingredients: ["paneer", "garam masala"])
        XCTAssertEqual(RecommendationEngine.cuisineReason(for: r, preferredCuisines: ["indian"]), "Because you love Indian")
        XCTAssertNil(RecommendationEngine.cuisineReason(for: r, preferredCuisines: ["italian"]))
    }

    func testColdStartRanksByCuisine() {
        let indian = makeRecipe(id: "in", title: "Chicken Tikka", ingredients: ["tikka", "masala"])
        let italian = makeRecipe(id: "it", title: "Carbonara", ingredients: ["pasta", "parmesan"])
        let out = RecommendationEngine.suggestions(
            from: [italian, indian],
            history: [],
            excluding: [],
            preferredCuisines: ["indian"],
            limit: 2
        )
        XCTAssertEqual(out.first?.id, "in")
    }

    func testReasonFromHistory() {
        let cooked = makeRecipe(id: "src", title: "Paneer Tikka", ingredients: ["paneer", "yogurt"])
        let candidate = makeRecipe(id: "cand", title: "Paneer Wrap", ingredients: ["paneer", "tortilla"])
        let history = [AppEnvironment.InteractionEvent(id: "e", recipeId: "src", eventType: "cook", durationSeconds: nil, timestamp: Date())]
        let reason = RecommendationEngine.reason(for: candidate, history: history, allRecipes: [cooked, candidate])
        XCTAssertEqual(reason, "Because you cooked Paneer Tikka")
    }
}
