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

// MARK: - Recipe total-time parsing (Prep + Cook merged into one figure)

final class RecipeTotalTimeTests: XCTestCase {
    func testMinutesParsing() {
        XCTAssertEqual(Recipe.minutes(from: "15 min"), 15)
        XCTAssertEqual(Recipe.minutes(from: "1 hr"), 60)
        XCTAssertEqual(Recipe.minutes(from: "2 hr 5 min"), 125)
        XCTAssertEqual(Recipe.minutes(from: "90 min"), 90)
        XCTAssertNil(Recipe.minutes(from: "quick"))
        XCTAssertNil(Recipe.minutes(from: nil))
    }

    func testFormatMinutes() {
        XCTAssertEqual(Recipe.formatMinutes(35), "35 min")
        XCTAssertEqual(Recipe.formatMinutes(60), "1 hr")
        XCTAssertEqual(Recipe.formatMinutes(95), "1 hr 35 min")
    }

    func testTotalSumsPrepAndCook() {
        XCTAssertEqual(makeRecipe(title: "x", ingredients: [], prep: "20 min", cook: "15 min").totalTimeText, "35 min")
        // only one present → that one
        XCTAssertEqual(makeRecipe(title: "x", ingredients: [], prep: "10 min").totalTimeText, "10 min")
        // neither parseable but one exists → unparsed fallback
        XCTAssertEqual(makeRecipe(title: "x", ingredients: [], prep: "a while").totalTimeText, "a while")
    }
}

// MARK: - Nutrition portioning (servings must not inflate per-serving kcal)

final class NutritionPortionTests: XCTestCase {
    func testPerServingIsConstantAcrossServings() {
        // Per serving is the dish's intrinsic value — unchanged whether you plan 1, 2, or 8 servings.
        XCTAssertEqual(RecipeNutrition.portionMultiplier(servings: 1, whole: false), 1)
        XCTAssertEqual(RecipeNutrition.portionMultiplier(servings: 8, whole: false), 1)
    }

    func testWholeRecipeScalesWithServings() {
        XCTAssertEqual(RecipeNutrition.portionMultiplier(servings: 4, whole: true), 4)
        XCTAssertEqual(RecipeNutrition.portionMultiplier(servings: 1, whole: true), 1)
    }

    func testReducingServingsDoesNotInflatePerServingDV() {
        // Regression: a sane dish must never read >100% of daily per serving just because the user
        // lowered the serving count (the old fixed-dish model produced "221% of daily").
        let n = RecipeNutrition(calories: 502, carbsG: 40, proteinG: 28, fatG: 22)
        let perServingKcal = n.calories * RecipeNutrition.portionMultiplier(servings: 1, whole: false)
        XCTAssertEqual(perServingKcal, 502)
        XCTAssertEqual(n.caloriesDVPercent, 25)   // 502 / 2000
    }
}

// MARK: - Smart search (ranked, typo-tolerant, synonym-aware, never-empty)

final class SmartSearchTests: XCTestCase {
    private let recipes = [
        makeRecipe(id: "p", title: "Paneer Butter Masala", ingredients: ["paneer", "butter", "tomato"]),
        makeRecipe(id: "c", title: "Chicken Biryani", ingredients: ["chicken", "rice", "spices"]),
        makeRecipe(id: "e", title: "Baingan Bharta", ingredients: ["eggplant", "onion", "tomato"]),
        makeRecipe(id: "t", title: "Tomato Pasta", ingredients: ["pasta", "tomato", "garlic"])
    ]

    func testRanksTitleMatchFirst() {
        let out = RecipeSearch.search(recipes, query: "pasta", filters: RecipeFilters())
        XCTAssertFalse(out.isGuess)
        XCTAssertEqual(out.recipes.first?.id, "t")
    }

    func testTypoTolerant() {
        let out = RecipeSearch.search(recipes, query: "chiken", filters: RecipeFilters())
        XCTAssertFalse(out.isGuess)
        XCTAssertEqual(out.recipes.first?.id, "c")
    }

    func testSynonymAubergineFindsEggplant() {
        let out = RecipeSearch.search(recipes, query: "aubergine", filters: RecipeFilters())
        XCTAssertFalse(out.isGuess)
        XCTAssertTrue(out.recipes.contains { $0.id == "e" })
    }

    func testStopwordsIgnored() {
        let out = RecipeSearch.search(recipes, query: "i want to eat some pasta", filters: RecipeFilters())
        XCTAssertEqual(out.recipes.first?.id, "t")
    }

    func testNeverEmptyShowsGuesses() {
        let out = RecipeSearch.search(recipes, query: "xylophone", filters: RecipeFilters())
        XCTAssertTrue(out.isGuess)
        XCTAssertFalse(out.recipes.isEmpty)
    }

    func testEmptyQueryReturnsAll() {
        let out = RecipeSearch.search(recipes, query: "", filters: RecipeFilters())
        XCTAssertEqual(out.recipes.count, recipes.count)
        XCTAssertFalse(out.isGuess)
    }
}

// MARK: - Grocery aisle categorization (powders/pastes land in the right section)

final class GroceryAisleTests: XCTestCase {
    func testPowdersAndMasalasAreSpices() {
        XCTAssertEqual(GrocerySort.aisle(for: "1 tsp garlic powder"), .spices)
        XCTAssertEqual(GrocerySort.aisle(for: "Kashmiri chili powder"), .spices)
        XCTAssertEqual(GrocerySort.aisle(for: "1 tbsp garam masala"), .spices)
        XCTAssertEqual(GrocerySort.aisle(for: "smoked paprika"), .spices)
    }

    func testBakingPowderStaysPantry() {
        XCTAssertEqual(GrocerySort.aisle(for: "10 g baking powder"), .pantry)
    }

    func testRawProduceStillProduce() {
        XCTAssertEqual(GrocerySort.aisle(for: "2 onions"), .produce)
        XCTAssertEqual(GrocerySort.aisle(for: "500g ripe red tomatoes"), .produce)
    }

    func testPasteToPantry() {
        XCTAssertEqual(GrocerySort.aisle(for: "1 tbsp ginger-garlic paste"), .pantry)
    }
}

// MARK: - Discovery refresh head (pager must leave the card on screen)

final class DiscoveryReelRefreshTests: XCTestCase {
    func testHeadDiffersWhenCurrentIsInAMultiItemList() {
        let ids = ["a", "b", "c"]
        for current in ids {
            let head = DiscoveryReelRefresh.nextHead(currentID: current, ids: ids)
            XCTAssertNotEqual(head, current)
            XCTAssertTrue(ids.contains(head ?? ""))
        }
    }

    func testHeadIsFirstWhenCurrentIsAbsentOrListHasOneItem() {
        XCTAssertEqual(DiscoveryReelRefresh.nextHead(currentID: "missing", ids: ["a", "b"]), "a")
        XCTAssertEqual(DiscoveryReelRefresh.nextHead(currentID: nil, ids: ["a", "b"]), "a")
        XCTAssertEqual(DiscoveryReelRefresh.nextHead(currentID: "only", ids: ["only"]), "only")
        XCTAssertNil(DiscoveryReelRefresh.nextHead(currentID: "a", ids: []))
    }
}
