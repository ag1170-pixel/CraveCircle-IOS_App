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
        XCTAssertEqual(RecipeSearch.totalMinutes(makeRecipe(title: "x", ingredients: ["a"], prep: "15 min", cook: "20 min")), 20)
        XCTAssertEqual(RecipeSearch.totalMinutes(makeRecipe(title: "x", ingredients: ["a"], prep: "1 hr", cook: "10 min")), 10)
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

    func testFinishingOneDishLeavesTheRest() {
        let wrap = GroceryItem(id: "1", ingredientName: "paneer", checked: true, recipeName: "Wrap")
        let salmon = GroceryItem(id: "2", ingredientName: "salmon", checked: false, recipeName: "Salmon")
        let milk = GroceryItem(id: "3", ingredientName: "milk", checked: false, recipeName: nil)
        let items = [wrap, salmon, milk]
        XCTAssertEqual(GrocerySort.removingFinished(items, dish: "Wrap").map(\.id), ["2", "3"])
        XCTAssertTrue(GrocerySort.removingFinished(items, dish: nil).isEmpty)
        XCTAssertEqual(GrocerySort.removingFinished(items, dish: GrocerySort.handAddedLabel).map(\.id), ["1", "2"])
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

// MARK: - Recipe duration (cook time only; prep is not added)

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

    func testTotalIsCookTimeOnly() {
        XCTAssertEqual(makeRecipe(title: "x", ingredients: [], prep: "20 min", cook: "15 min").totalTimeText, "15 min")
        XCTAssertEqual(makeRecipe(title: "x", ingredients: [], prep: "10 min", cook: "1 hr 10 min").totalTimeText, "1 hr 10 min")
        XCTAssertNil(makeRecipe(title: "x", ingredients: [], prep: "10 min").totalTimeText)
        XCTAssertEqual(makeRecipe(title: "x", ingredients: [], cook: "a while").totalTimeText, "a while")
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

    func testWholeRecipeChangesTheCaloriesAndTheDailyValue() {
        let n = RecipeNutrition(calories: 952, carbsG: 112, proteinG: 34, fatG: 41)
        let one = n.shown(servings: 4, whole: false)
        let all = n.shown(servings: 4, whole: true)
        XCTAssertEqual(one.kcal, 952)
        XCTAssertEqual(one.proteinG, 34)
        XCTAssertEqual(all.kcal, 3808)
        XCTAssertEqual(all.proteinG, 136)
        XCTAssertEqual(all.carbsG, 448)
        XCTAssertEqual(all.fatG, 164)
        XCTAssertEqual(RecipeNutrition.dailyValuePercent(grams: Double(one.proteinG), reference: RecipeNutrition.proteinDailyG), 68)
        XCTAssertEqual(RecipeNutrition.dailyValuePercent(grams: Double(all.proteinG), reference: RecipeNutrition.proteinDailyG), 272)
        XCTAssertEqual(Int((Double(one.kcal) / n.dailyCalories * 100).rounded()), 48)
        XCTAssertEqual(Int((Double(all.kcal) / n.dailyCalories * 100).rounded()), 190)
    }

    func testADayRingStopsAtAFullCircle() {
        let under = RecipeNutrition.dayMark(amount: 34, reference: 50)
        XCTAssertEqual(under.percent, 68)
        XCTAssertFalse(under.over)
        XCTAssertEqual(under.fill, 0.68, accuracy: 0.001)
        let over = RecipeNutrition.dayMark(amount: 200, reference: 50)
        XCTAssertEqual(RecipeNutrition.dailyValuePercent(grams: 200, reference: 50), 400)
        XCTAssertTrue(over.over)
        XCTAssertEqual(over.percent, 100)
        XCTAssertEqual(over.fill, 1, accuracy: 0.001)
    }

    func testDailyValueMatchesTheNutritionPage() {
        // 34 g protein, 112 g carbs, 41 g fat — the page's % Daily Value column.
        XCTAssertEqual(RecipeNutrition.dailyValuePercent(grams: 34, reference: RecipeNutrition.proteinDailyG), 68)
        XCTAssertEqual(RecipeNutrition.dailyValuePercent(grams: 112, reference: RecipeNutrition.carbsDailyG), 41)
        XCTAssertEqual(RecipeNutrition.dailyValuePercent(grams: 41, reference: RecipeNutrition.fatDailyG), 53)
    }

    func testCaptionPerServingMacrosAreNotDividedByServings() throws {
        let caption = """
        370 Kcal per Serving
        Garlic Chicken Bowl
        370 kcal | 14g protein | 52g carbs | 13g fat per Serving
        Makes 4 Servings
        """
        let n = try XCTUnwrap(NutritionEstimator.statedPerServing(in: caption))
        XCTAssertEqual(n.calories, 370)
        XCTAssertEqual(n.proteinG, 14)
        XCTAssertEqual(n.carbsG, 52)
        XCTAssertEqual(n.fatG, 13)
        XCTAssertFalse(n.estimated)
        XCTAssertNotEqual(n.calories, 140.0)
        XCTAssertNotEqual(n.calories, 370 / 4)
        XCTAssertNil(NutritionEstimator.statedPerServing(in: "370 Kcal per Serving\nMakes 4 Servings"))
        XCTAssertEqual(NutritionEstimator.dishTitle(in: caption), "Garlic Chicken Bowl")
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

    func testAShortSearchDoesNotCountAsAMissingDish() {
        XCTAssertNil(SearchDemand.key("ab"))
        XCTAssertEqual(SearchDemand.key("  Butter   Chicken "), "butter chicken")
        XCTAssertEqual(SearchDemand.peopleNeeded, 10)
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

    func testUnseenPoolDropsCardsAlreadyOnScreen() {
        XCTAssertEqual(DiscoveryReelRefresh.unseenPool(shown: ["a", "b"], candidates: ["b", "c", "d"]), ["c", "d"])
        XCTAssertEqual(DiscoveryReelRefresh.unseenPool(shown: ["a"], candidates: ["a"]), ["a"])
    }

    func testMixedReelIncludesLibraryWithoutDuplicateIDs() {
        let library = makeRecipe(id: "lib", title: "My Dal", ingredients: ["dal"])
        let suggestion = makeRecipe(id: "sug", title: "Their Pasta", ingredients: ["pasta"])
        let reel = DiscoveryReelRefresh.mixedReel(
            library: [library],
            suggestions: [suggestion, library],
            ownedIDs: ["lib"],
            viewedIDs: ["lib"]
        )
        XCTAssertEqual(Set(reel.map(\.id)), Set(["lib", "sug"]))
        XCTAssertEqual(reel.count, Set(reel.map(\.id)).count)
    }
}

// MARK: - Ingredient list format

final class IngredientListFormatTests: XCTestCase {
    func testCaptionTagBlockIsDroppedAndSectionNameStays() {
        let dump = "(panerecipe, panerrecipes, butterpaneer, shahipaneer, paneermakhni, paneermakhani, reels, viralreels, viralshorts, food, foodporn, paneerlover, foodblogger, recipeoftheday, RecipeVideo, paneertikka, foodshorts, ComfortFood, indianrecipes, lunchrecipe, dinner)"
        let group = IngredientGroup(groupName: "2-3 cloves", items: [
            "1 onion, chopped",
            "Chopped coriander",
            dump
        ])
        XCTAssertEqual(group.groupName, "2-3 cloves")
        XCTAssertEqual(group.items, ["1 onion, chopped", "Chopped coriander"])
    }

    func testKitchenNotesStay() {
        let group = IngredientGroup(groupName: nil, items: [
            "1 onion (finely chopped)",
            "butter (or ghee)",
            "kasuri methi (optional)"
        ])
        XCTAssertEqual(group.items, [
            "1 onion (finely chopped)",
            "butter (or ghee)",
            "kasuri methi (optional)"
        ])
    }

    func testTrailingTagBlockIsCutOffTheIngredient() {
        let line = "Chopped coriander (panerecipe, viralreels, foodporn, foodblogger, recipeoftheday)"
        XCTAssertEqual(IngredientListFormat.cleanedItem(line), "Chopped coriander")
    }

    func testCalorieHeadlineTakesTheSpokenDishName() {
        XCTAssertEqual(
            NutritionEstimator.spokenDishName(in: "Hey. This is chole masala. Then add garam masala."),
            "Chole Masala"
        )
        var recipe = makeRecipe(title: "370 Kcal per Serving", ingredients: ["chickpeas"])
        recipe.directions = [DirectionStep(stepIndex: 1, text: "This is chole masala. Soak the chickpeas.")]
        XCTAssertEqual(NutritionEstimator.replacingCalorieHeadline(recipe).title, "Chole Masala")
        XCTAssertEqual(
            NutritionEstimator.replacingCalorieHeadline(makeRecipe(title: "Chole Masala", ingredients: ["chickpeas"])).title,
            "Chole Masala"
        )
    }

    func testShareLinkOpensTheRecipePageAndHandleDropsTheAt() {
        XCTAssertEqual(AppConfig.recipeWebLink("abc"), "https://import.cravecircle.cc/recipe/abc")
        XCTAssertEqual(AppConfig.shareHandle("  @Udit "), "Udit")
        XCTAssertEqual(AppConfig.shareHandle("udit"), "udit")
    }

    func testImportWithoutABlurbSaysWhatItIsMadeWith() {
        let line = DishBlurb.line(
            title: "Creamy Garlic Butter Shrimp with Rice",
            stored: "Extracted from @someone's cooking reel.",
            items: ["200g shrimp", "1 tbsp butter", "2 garlic cloves"]
        )
        XCTAssertEqual(line, "Made with shrimp, butter, and garlic cloves.")
        let kept = DishBlurb.line(
            title: "Butter Chicken",
            stored: "Velvety restaurant-style tandoori chicken in a tomato gravy.",
            items: ["600g chicken"]
        )
        XCTAssertEqual(kept, "Velvety restaurant-style tandoori chicken in a tomato gravy.")
    }

    func testNameDashAmountReadsAmountThenName() {
        let line = "Chickpeas / kabuli chana — 1¼ cups dried (250g)"
        let parts = IngredientListFormat.displayParts(line)
        XCTAssertEqual(parts.amount, "1¼ cups dried (250g)")
        XCTAssertEqual(parts.name, "Chickpeas / kabuli chana")
        XCTAssertEqual(IngredientListFormat.cleanedItem("kasuri methi (optional)"), "kasuri methi (optional)")
        XCTAssertFalse(IngredientListFormat.isTagDump("(optional)"))
        let group = IngredientGroup(groupName: "Main Ingredients", items: [line, "butter (optional)"])
        XCTAssertEqual(group.groupName, "Main Ingredients")
        XCTAssertEqual(group.items, [line, "butter (optional)"])
    }
}

final class TranscriptListenTests: XCTestCase {
    func testFewWordsAreNotEnough() {
        XCTAssertFalse(TranscriptListen.heardEnough("mix two cups of flour then bake"))
    }

    func testAHeardRecipeStops() {
        let line = "You need 2 cups pasta, 3 tbsp butter, 4 cloves garlic, and 1 tsp salt. Boil the pasta, slice the garlic, heat the butter, then stir and serve. "
        let text = String(repeating: line, count: 4)
        XCTAssertGreaterThanOrEqual(text.count, 400)
        XCTAssertTrue(TranscriptListen.heardEnough(text))
    }

    func testLongMonologueHitsTheCap() {
        XCTAssertTrue(TranscriptListen.heardEnough(String(repeating: "word ", count: 400)))
    }

    func testCaptionRecipeWithCoverSkipsVideo() {
        let caption = "Weeknight garlic rice\n1 cup rice\n2 tbsp oil\n1 tsp salt\nBoil the rice until tender. Heat the oil and serve warm."
        XCTAssertFalse(TranscriptListen.needsVideoDownload(transcriptCount: 8, context: caption, hasCover: true))
    }

    func testThinTranscriptWithoutARecipeStillNeedsVideo() {
        XCTAssertTrue(TranscriptListen.needsVideoDownload(transcriptCount: 8, context: "just a hello", hasCover: true))
        XCTAssertTrue(TranscriptListen.needsVideoDownload(transcriptCount: 8, context: "just a hello", hasCover: false))
    }

    func testSpokenRecipeWithCoverSkipsVideo() {
        XCTAssertFalse(TranscriptListen.needsVideoDownload(transcriptCount: 80, context: "anything", hasCover: true))
    }

    func testMissingCoverStillNeedsAFrame() {
        XCTAssertTrue(TranscriptListen.needsVideoDownload(transcriptCount: 80, context: "a full spoken recipe", hasCover: false))
    }

    func testAudioFilesAreNotReencoded() {
        XCTAssertTrue(OnDeviceTranscriber.passesThroughAudio(pathExtension: "m4a"))
        XCTAssertTrue(OnDeviceTranscriber.passesThroughAudio(pathExtension: "MP3"))
        XCTAssertFalse(OnDeviceTranscriber.passesThroughAudio(pathExtension: "mp4"))
        XCTAssertFalse(OnDeviceTranscriber.passesThroughAudio(pathExtension: "mov"))
    }
}

final class RecipeReportTests: XCTestCase {
    func testReportKeepsTheNoteAndTheRecipe() {
        let recipe = makeRecipe(id: "paneer-1", title: "Paneer Butter Masala", ingredients: ["200g paneer", "1 onion, chopped"])
        let content = RecipeReport.content(note: "Missed the cream", reporter: "@anas", reporterId: "user-1", recipe: recipe)
        let parsed = RecipeReport.parse(content)
        XCTAssertEqual(parsed?.note, "Missed the cream")
        XCTAssertEqual(parsed?.reporter, "@anas")
        XCTAssertEqual(parsed?.recipe.id, "paneer-1")
        XCTAssertEqual(parsed?.recipe.title, "Paneer Butter Masala")
        XCTAssertEqual(parsed?.recipe.ingredients.first?.items, ["200g paneer", "1 onion, chopped"])
    }
}

final class RecipeCoverFilenameTests: XCTestCase {
    func testBundledAndRemoteCoversDoNotOpenFiles() {
        XCTAssertNil(RecipeCoverImage.localCoverFilename("recipe_hot_honey_chicken"))
        XCTAssertTrue(
            RecipeCoverImage.localCoverFilenames(
                urlString: "recipe_hot_honey_chicken",
                recipeId: "recipe-hot-honey-chicken"
            ).isEmpty
        )
        let remote = "https://db.cravecircle.cc/storage/v1/object/public/recipe-thumbnails/recipe_biryani.jpg"
        XCTAssertTrue(RecipeCoverImage.localCoverFilenames(urlString: remote, recipeId: "recipe-biryani").isEmpty)
    }

    func testLocalThumbIsOneFilename() {
        XCTAssertEqual(RecipeCoverImage.localCoverFilename("thumb-abc.jpg"), "thumb-abc.jpg")
        XCTAssertEqual(
            RecipeCoverImage.localCoverFilenames(urlString: "thumb-abc.jpg", recipeId: "abc"),
            ["thumb-abc.jpg"]
        )
        XCTAssertEqual(
            RecipeCoverImage.localCoverFilename("file:///var/mobile/thumb-abc.heic"),
            "thumb-abc.heic"
        )
    }

    func testFallbackPicksOneAssetAndStaysStable() {
        XCTAssertEqual(RecipeCoverImage.fallbackAssetName(for: "Butter Chicken"), "recipe_kadai_chicken")
        let rice = RecipeCoverImage.fallbackAssetName(for: "Jeera Rice")
        let family = ["recipe_biryani", "recipe_korean_bibimbap", "recipe_mushroom_risotto", "recipe_chipotle_bowl", "recipe_falafel_bowl", "recipe_thai_basil_chicken"]
        XCTAssertTrue(family.contains(rice))
        XCTAssertEqual(RecipeCoverImage.fallbackAssetName(for: "Jeera Rice"), rice)
    }
}

final class AccountIsolationTests: XCTestCase {
    func testTwoAccountsDoNotShareALibraryAndOnlyAdminPublishes() {
        let krishna = AccountScope.fileName(userId: "krishna-id", file: "recipes.json")
        let aditya = AccountScope.fileName(userId: "aditya-id", file: "recipes.json")
        XCTAssertNotEqual(krishna, aditya)
        XCTAssertNotEqual(krishna, "recipes.json")
        XCTAssertNotEqual(
            AccountScope.fileName(userId: "krishna-id", file: "avatar.json"),
            AccountScope.fileName(userId: "aditya-id", file: "avatar.json")
        )
        XCTAssertFalse(AccountScope.mayReadLegacy(userId: "aditya-id", recordedOwner: "krishna-id"))
        XCTAssertTrue(AccountScope.mayReadLegacy(userId: "krishna-id", recordedOwner: nil))
        XCTAssertFalse(AccountScope.mayReadLegacy(userId: "guest_4", recordedOwner: nil))
        XCTAssertFalse(AccountRole.user.canPublish)
        XCTAssertFalse(AccountRole.creator.canPublish)
        XCTAssertTrue(AccountRole.admin.canPublish)
        XCTAssertFalse(UserProfile(id: "creator", role: .creator).canPublish)
        XCTAssertTrue(UserProfile(id: "admin", role: .admin).canPublish)
    }
}

final class PhotoRecipeImportTests: XCTestCase {
    func testPictureTextAndCaptionBothBecomeTheRecipe() async {
        let recipe = await RecipeExtractor.extract(
            transcript: "fry the paneer until the edges are golden",
            caption: "Spicy paneer wrap",
            ownerId: "tester",
            sourceLanguage: nil,
            onScreenText: "200g paneer\n1 tbsp oil\nHeat the oil and fry the paneer until golden."
        )
        let lines = recipe.ingredients.flatMap(\.items).joined(separator: " ").lowercased()
        let steps = recipe.directions.map(\.text).joined(separator: " ").lowercased()
        XCTAssertTrue(lines.contains("paneer") || steps.contains("paneer"))
        XCTAssertFalse(recipe.directions.isEmpty)
        XCTAssertTrue(RecipeExtractor.looksLikeFood(recipe))
    }
}

final class SearchDictationTests: XCTestCase {
    func testARevisedPhraseReplacesTheEarlierGuess() {
        var heard = DictationTranscript()
        XCTAssertEqual(heard.absorb(start: 0, text: "paneer"), "paneer")
        XCTAssertEqual(heard.absorb(start: 1.2, text: "butter"), "paneer butter")
        XCTAssertEqual(heard.absorb(start: 0.02, text: "spicy paneer"), "spicy paneer butter")
    }

    func testSiriBeatsTheRoboticVoice() {
        let siri = SpeechReader.voiceScore(identifier: "com.apple.ttsbundle.siri_female_en-US_compact", quality: .premium)
        let robot = SpeechReader.voiceScore(identifier: "com.apple.eloquence.en-US.Sandy", quality: .premium)
        let plain = SpeechReader.voiceScore(identifier: "com.apple.voice.compact.en-US.Samantha", quality: .default)
        XCTAssertGreaterThan(siri, plain)
        XCTAssertGreaterThan(plain, robot)
    }
}

final class CommentModerationTests: XCTestCase {
    func testANormalCommentIsAllowed() {
        XCTAssertFalse(CommentModeration.isBlocked("looks tasty, the raspberries are a good idea"))
        XCTAssertFalse(CommentModeration.isBlocked("add a little mustard"))
    }

    func testAbuseIsBlocked() {
        XCTAssertTrue(CommentModeration.isBlocked("muth"))
        XCTAssertTrue(CommentModeration.isBlocked("you muth mar"))
        XCTAssertFalse(CommentModeration.isBlocked("mouth watering"))
    }
}

final class CommentSyncTests: XCTestCase {
    func testASharedCommentReplacesTheDemoRows() {
        let demo = RecipeComment.defaultSamples["recipe-hot-honey-chicken"] ?? []
        let remote = RecipeComment(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            recipeId: "recipe-hot-honey-chicken",
            authorName: "A",
            authorUsername: "@a",
            text: "hello from the other phone",
            timeAgo: "",
            createdAt: Date()
        )
        XCTAssertEqual(RecipeComment.synced(remote: [remote], local: demo).map(\.text), ["hello from the other phone"])
    }

    func testAnEmptyThreadDropsTheDemoRows() {
        let demo = RecipeComment.defaultSamples["recipe-tomato-rigatoni"] ?? []
        XCTAssertFalse(demo.isEmpty)
        XCTAssertTrue(RecipeComment.synced(remote: [], local: demo).isEmpty)
    }

    func testACommentWaitingToUploadStays() {
        let pending = RecipeComment(
            recipeId: "r",
            authorName: "A",
            authorUsername: "@a",
            text: "not uploaded yet",
            timeAgo: "Just now",
            createdAt: Date()
        )
        XCTAssertEqual(RecipeComment.synced(remote: [], local: [pending]).map(\.text), ["not uploaded yet"])
    }
}

final class ActivityAlertTests: XCTestCase {
    func testANewAccountDoesNotKeepSampleAlerts() {
        let real = CircleNotificationItem(title: "Recipe shared with you", message: "Someone shared 'Chole' with you", timeAgo: "Just now", symbol: "tray.and.arrow.down.fill", isRead: false)
        let kept = CircleNotificationItem.withoutSamples(CircleNotificationItem.samples + [real])
        XCTAssertEqual(kept.map(\.message), [real.message])
        XCTAssertTrue(CircleNotificationItem.withoutSamples([]).isEmpty)
    }
}

final class DirectionLineTests: XCTestCase {
    func testAParagraphBecomesShortLines() {
        let lines = DirectionStepParser.shortLines("Heat olive oil and butter in a large skillet over medium-high heat. Sear salmon skin-side down for 5 minutes, flip, and cook 3 minutes more. Transfer to a plate.")
        XCTAssertGreaterThan(lines.count, 2)
        XCTAssertFalse(lines.contains { $0.contains(". ") })
        XCTAssertTrue(lines.contains { $0.localizedCaseInsensitiveContains("sear") })
        XCTAssertTrue(lines.contains { $0.localizedCaseInsensitiveContains("plate") })
    }
}

final class WebRecipeParserTests: XCTestCase {
    func testARecipePageBecomesADish() {
        let html = """
        <html><script type="application/ld+json">
        {"@context":"https://schema.org","@graph":[{"@type":"Recipe","name":"Rajma Chawal","image":["https://example.com/rajma.jpg"],"recipeYield":"4 servings","cookTime":"PT45M","recipeIngredient":["1 cup rajma","2 cups rice","1 cup rajma"],"recipeInstructions":[{"@type":"HowToSection","name":"Cook","itemListElement":[{"@type":"HowToStep","text":"Soak the beans."},{"@type":"HowToStep","text":"<p>Pressure cook.</p>"}]}]}]}
        </script></html>
        """
        let page = URL(string: "https://www.sharmispassions.com/rajma-chawal")!
        let recipe = WebRecipeParser.recipe(html: html, pageURL: page, ownerId: "me")
        XCTAssertEqual(recipe?.title, "Rajma Chawal")
        XCTAssertEqual(recipe?.servings, 4)
        XCTAssertEqual(recipe?.cookTime, "45 min")
        XCTAssertEqual(recipe?.ingredients.first?.items, ["1 cup rajma", "2 cups rice"])
        XCTAssertEqual(recipe?.directions.map(\.text), ["Soak the beans.", "Pressure cook."])
        XCTAssertEqual(recipe?.thumbnailUrl, "https://example.com/rajma.jpg")
        XCTAssertEqual(recipe?.sourceUrl, page.absoluteString)
        XCTAssertEqual(recipe?.visibility, .followers)
        XCTAssertEqual(recipe?.ownerUsername, "sharmispassions.com")
        XCTAssertTrue(recipe?.staysOnThisPhone == true)
        let google = URL(string: "https://www.google.com/search?q=rajma")!
        XCTAssertNil(WebRecipeParser.recipe(html: html, pageURL: google, ownerId: "me"))
        XCTAssertNil(WebRecipeParser.recipe(html: "<html>no recipe</html>", pageURL: page, ownerId: "me"))
        let relative = """
        <html><meta property="og:image" content="/photos/rajma.jpg">
        <script type="application/ld+json">{"@type":"Recipe","name":"Rajma","image":"/photos/rajma.jpg","recipeIngredient":["1 cup rajma"],"recipeInstructions":"Cook."}</script></html>
        """
        let saved = WebRecipeParser.recipe(html: relative, pageURL: page, ownerId: "me")
        XCTAssertEqual(saved?.thumbnailUrl, "https://www.sharmispassions.com/photos/rajma.jpg")
    }
}

final class CollectionMatchTests: XCTestCase {
    func testAnEmptyCollectionShowsNoRecipes() {
        let dish = Recipe(id: "a", ownerId: "me", title: "A", ingredients: [], directions: [])
        let empty = CollectionItem(name: "Later", count: 0, shared: false, imageName: "x", recipeIds: [])
        XCTAssertTrue(empty.matching(in: [dish]).isEmpty)
        let saved = CollectionItem(name: "Saved", count: 1, shared: false, imageName: "x", recipeIds: ["a"])
        XCTAssertEqual(saved.matching(in: [dish]).map(\.id), ["a"])
    }
}

final class ChecklistToggleTests: XCTestCase {
    func testToggleChecklistItemInsertsThenRemoves() {
        var ingredients: Set<String> = []
        toggleChecklistItem(&ingredients, "0:1")
        XCTAssertEqual(ingredients, ["0:1"])
        toggleChecklistItem(&ingredients, "0:1")
        XCTAssertTrue(ingredients.isEmpty)

        var steps: Set<Int> = [2]
        toggleChecklistItem(&steps, 2)
        XCTAssertFalse(steps.contains(2))
        toggleChecklistItem(&steps, 4)
        XCTAssertEqual(steps, [4])
    }
}
