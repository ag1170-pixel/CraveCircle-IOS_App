//
//  HealthProfile.swift
//  CraveCircle (AICookBook)
//
//  What the user tells us about how they eat: diet, faith rules, intolerances, allergens,
//  health conditions and daily nutrition targets.
//
//  Privacy: this stays on the phone (a per-account JSON file via AppEnvironment). It is never
//  sent to the server. It only changes what the app shows: a heads-up on recipe pages,
//  which recipes Suggested for You picks, and the "% of your day" figures on Nutrition.
//
//  Not medical advice. Matching is by ingredient wording, so the app says "check" rather
//  than "safe".
//

import Foundation

// MARK: - Choices

enum DietStyle: String, Codable, CaseIterable, Identifiable {
    case vegetarian, vegan, pescatarian, plantBased, keto, lowCarb, paleo, highProtein, mediterranean
    var id: String { rawValue }
    var title: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .pescatarian: "Pescatarian"
        case .plantBased: "Plant-based"
        case .keto: "Keto"
        case .lowCarb: "Low-carb"
        case .paleo: "Paleo"
        case .highProtein: "High-protein"
        case .mediterranean: "Mediterranean"
        }
    }
    var symbol: String {
        switch self {
        case .vegetarian: "carrot"
        case .vegan, .plantBased: "leaf"
        case .pescatarian: "fish"
        case .keto, .lowCarb: "chart.bar.xaxis"
        case .paleo: "flame"
        case .highProtein: "dumbbell"
        case .mediterranean: "sun.max"
        }
    }
}

enum FaithRule: String, Codable, CaseIterable, Identifiable {
    case halal, kosher, hinduNoBeef, jain, buddhistVegetarian
    var id: String { rawValue }
    var title: String {
        switch self {
        case .halal: "Halal"
        case .kosher: "Kosher"
        case .hinduNoBeef: "No beef"
        case .jain: "Jain"
        case .buddhistVegetarian: "Buddhist vegetarian"
        }
    }
    var symbol: String {
        switch self {
        case .halal: "moon"
        case .kosher: "star"
        case .hinduNoBeef: "hand.raised"
        case .jain, .buddhistVegetarian: "leaf.circle"
        }
    }
}

enum Intolerance: String, Codable, CaseIterable, Identifiable {
    case lactose, gluten, lowFODMAP, alcohol
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lactose: "Lactose-free"
        case .gluten: "Gluten-free"
        case .lowFODMAP: "Low-FODMAP"
        case .alcohol: "Alcohol-free"
        }
    }
    var symbol: String {
        switch self {
        case .lactose: "drop"
        case .gluten: "laurel.leading"
        case .lowFODMAP: "carrot"
        case .alcohol: "wineglass"
        }
    }
}

enum Allergen: String, Codable, CaseIterable, Identifiable {
    case peanuts, treeNuts, dairy, eggs, fish, shellfish, soy, wheat, sesame
    var id: String { rawValue }
    var title: String {
        switch self {
        case .peanuts: "Peanuts"
        case .treeNuts: "Tree nuts"
        case .dairy: "Dairy"
        case .eggs: "Eggs"
        case .fish: "Fish"
        case .shellfish: "Shellfish"
        case .soy: "Soy"
        case .wheat: "Wheat"
        case .sesame: "Sesame"
        }
    }
    var symbol: String {
        switch self {
        case .peanuts, .treeNuts: "allergens"
        case .dairy: "cup.and.saucer"
        case .eggs: "oval"
        case .fish: "fish"
        case .shellfish: "water.waves"
        case .soy: "leaf"
        case .wheat: "laurel.trailing"
        case .sesame: "circle.dotted"
        }
    }
}

enum HealthCondition: String, Codable, CaseIterable, Identifiable {
    case diabetes, prediabetes, highCholesterol, hypertension, heartDisease, kidneyDisease
    case gerd, ibs, crohns, ulcerativeColitis, celiac, gout, liverDisease, pancreatitis
    var id: String { rawValue }
    var title: String {
        switch self {
        case .diabetes: "Diabetes"
        case .prediabetes: "Prediabetes"
        case .highCholesterol: "High cholesterol"
        case .hypertension: "High blood pressure"
        case .heartDisease: "Heart disease"
        case .kidneyDisease: "Kidney disease"
        case .gerd: "Acid reflux (GERD)"
        case .ibs: "IBS"
        case .crohns: "Crohn's disease"
        case .ulcerativeColitis: "Ulcerative colitis"
        case .celiac: "Celiac disease"
        case .gout: "Gout"
        case .liverDisease: "Liver disease"
        case .pancreatitis: "Pancreatitis"
        }
    }
    var symbol: String {
        switch self {
        case .diabetes, .prediabetes: "drop.fill"
        case .highCholesterol, .heartDisease: "heart"
        case .hypertension: "gauge.with.dots.needle.33percent"
        case .kidneyDisease, .liverDisease, .pancreatitis: "cross.case"
        case .gerd: "flame"
        case .ibs, .crohns, .ulcerativeColitis: "bandage"
        case .celiac: "laurel.leading"
        case .gout: "figure.walk"
        }
    }
    /// What turning it on changes in the app. Shown before the user confirms.
    var whatChanges: String {
        switch self {
        case .diabetes, .prediabetes:
            "Recipes with added sugar, honey or syrup get a heads-up, so you can plan portions."
        case .highCholesterol:
            "Recipes rich in butter, ghee, cream or fatty processed meat get a heads-up."
        case .hypertension, .heartDisease:
            "Recipes with salty sauces and cured meats (soy sauce, bacon, ham) get a heads-up."
        case .kidneyDisease:
            "Recipes with salty sauces and cured meats get a heads-up. Ask your care team about potassium and protein limits."
        case .gerd:
            "Spicy, fried and alcohol-containing recipes get a heads-up."
        case .ibs:
            "Recipes with onion, garlic and other common triggers get a heads-up."
        case .crohns, .ulcerativeColitis:
            "Triggers differ from person to person, so nothing is hidden. Pair this with the intolerances you know you have."
        case .celiac:
            "Recipes with wheat, barley or rye are treated like an allergy: flagged, and left out of Suggested for You."
        case .gout:
            "Recipes with shellfish, anchovies, organ meat or beer get a heads-up."
        case .liverDisease:
            "Recipes containing alcohol get a heads-up."
        case .pancreatitis:
            "Recipes containing alcohol, or rich in butter, ghee or cream, get a heads-up."
        }
    }
}

// MARK: - Targets

struct NutritionTargets: Codable, Equatable {
    var calories: Int = 2000
    var carbsPercent: Int = 50
    var fatPercent: Int = 30
    var proteinPercent: Int = 20

    var totalPercent: Int { carbsPercent + fatPercent + proteinPercent }
    // 4 kcal per gram of carbs and protein, 9 per gram of fat.
    var carbsGrams: Int { calories * carbsPercent / 400 }
    var proteinGrams: Int { calories * proteinPercent / 400 }
    var fatGrams: Int { calories * fatPercent / 900 }

    static let calorieRange = 1200...4000
}

// MARK: - The user's own entries

/// A condition that isn't in our list. The user names it and lists the ingredients to watch;
/// recipes using any of them get a heads-up naming the condition.
struct CustomCondition: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var watch: [String]
}

/// Lowercased, trimmed, de-duplicated ingredient words from free text ("Garlic, onions;  leek").
func ingredientWords(from text: String) -> [String] {
    var seen = Set<String>()
    return text.split(whereSeparator: { ",;\n".contains($0) })
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty && $0.count <= 40 && seen.insert($0).inserted }
}

// MARK: - Profile

struct HealthProfile: Codable, Equatable {
    var diets: Set<DietStyle> = []
    var faith: Set<FaithRule> = []
    var intolerances: Set<Intolerance> = []
    var allergens: Set<Allergen> = []
    var conditions: Set<HealthCondition> = []
    var targets = NutritionTargets()
    /// A daily notification with the user's targets and a cooking tip (Daily targets screen).
    var targetReminder = false
    /// Ingredients the user added themselves (Diet & allergies → Your own). Treated like allergens.
    var customAvoid: [String] = []
    var customConditions: [CustomCondition] = []

    var dietCount: Int { diets.count + faith.count + intolerances.count + allergens.count + customAvoid.count }
    var conditionCount: Int { conditions.count + customConditions.count }

    init() {}

    // Every field optional on decode, so adding a choice later never wipes what was saved.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        diets = try c.decodeIfPresent(Set<DietStyle>.self, forKey: .diets) ?? []
        faith = try c.decodeIfPresent(Set<FaithRule>.self, forKey: .faith) ?? []
        intolerances = try c.decodeIfPresent(Set<Intolerance>.self, forKey: .intolerances) ?? []
        allergens = try c.decodeIfPresent(Set<Allergen>.self, forKey: .allergens) ?? []
        conditions = try c.decodeIfPresent(Set<HealthCondition>.self, forKey: .conditions) ?? []
        targets = try c.decodeIfPresent(NutritionTargets.self, forKey: .targets) ?? NutritionTargets()
        targetReminder = try c.decodeIfPresent(Bool.self, forKey: .targetReminder) ?? false
        customAvoid = try c.decodeIfPresent([String].self, forKey: .customAvoid) ?? []
        customConditions = try c.decodeIfPresent([CustomCondition].self, forKey: .customConditions) ?? []
    }
}

// MARK: - Checking a recipe

/// One reason a recipe may not suit the user. `hard` ones (allergens, diet, faith rules,
/// intolerances, celiac) keep a recipe out of Suggested for You; soft ones are a heads-up.
struct HealthFlag: Hashable {
    let text: String
    let hard: Bool
}

enum HealthCheck {
    // ponytail: wording match over ingredient lines. It catches what a recipe says, not hidden
    // ingredients in a store-bought sauce; that is why the UI says "check", never "safe".
    // Upgrade path: an ingredient database with allergen tags.

    private static let meat = ["chicken", "beef", "pork", "lamb", "mutton", "goat", "bacon", "ham", "sausage",
                               "turkey", "duck", "keema", "mince", "steak", "prosciutto", "pepperoni", "salami",
                               "chorizo", "veal", "gelatin", "lard"]
    private static let fish = ["fish", "salmon", "tuna", "cod", "anchovy", "anchovies", "sardine", "tilapia",
                               "mackerel", "trout", "haddock", "halibut", "snapper", "bass"]
    private static let shellfish = ["shrimp", "prawn", "crab", "lobster", "scallop", "mussel", "clam", "oyster",
                                    "squid", "calamari", "octopus"]
    private static let dairy = ["milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "paneer", "ghee", "curd",
                                "dahi", "khoya", "mascarpone", "ricotta", "parmesan", "parmigiano", "mozzarella",
                                "feta", "whey", "buttermilk", "condensed milk"]
    private static let notDairy = ["coconut milk", "almond milk", "oat milk", "soy milk", "rice milk",
                                   "peanut butter", "almond butter", "cashew butter", "nut butter",
                                   "cocoa butter", "coconut cream", "cream of tartar", "vegan"]
    private static let egg = ["egg", "eggs", "mayonnaise", "mayo", "meringue"]
    private static let notEgg = ["eggplant", "egg-free", "eggless"]
    private static let wheat = ["flour", "bread", "pasta", "spaghetti", "noodle", "noodles", "tortilla", "couscous",
                                "semolina", "sooji", "rava", "maida", "atta", "roti", "chapati", "naan", "paratha",
                                "breadcrumb", "breadcrumbs", "panko", "cracker", "biscuit", "wheat", "soy sauce",
                                "macaroni", "fettuccine", "rigatoni", "penne", "lasagna", "gyoza", "dumpling", "pie crust"]
    private static let notWheat = ["almond flour", "rice flour", "chickpea flour", "gram flour", "besan", "corn flour",
                                   "cornflour", "coconut flour", "oat flour", "tapioca", "rice noodle", "rice noodles",
                                   "gluten-free", "tamari", "buckwheat"]
    private static let glutenExtra = ["barley", "rye", "beer", "malt"]
    private static let peanut = ["peanut", "peanuts", "groundnut"]
    private static let treeNut = ["almond", "cashew", "walnut", "pistachio", "pecan", "hazelnut", "macadamia",
                                  "brazil nut", "pine nut", "praline", "marzipan"]
    private static let soy = ["soy", "soya", "tofu", "edamame", "miso", "tempeh", "tamari"]
    private static let sesame = ["sesame", "tahini", "til "]
    private static let alcohol = ["wine", "beer", "rum", "vodka", "whisky", "whiskey", "brandy", "sake", "mirin",
                                  "liqueur", "bourbon", "tequila", "gin ", "sherry", "marsala wine", "cognac"]
    private static let addedSugar = ["sugar", "honey", "syrup", "jaggery", "condensed milk", "molasses", "agave",
                                     "caramel", "chocolate chips", "nutella", "jam"]
    private static let richFat = ["butter", "ghee", "cream", "lard", "bacon", "sausage"]
    private static let salty = ["soy sauce", "fish sauce", "bacon", "ham", "salami", "pepperoni", "pickle",
                                "stock cube", "bouillon", "oyster sauce", "anchovy"]
    private static let spicy = ["chilli", "chili", "cayenne", "jalapeno", "jalapeño", "habanero", "sriracha",
                                "gochujang", "hot sauce", "red pepper flakes"]
    private static let fodmap = ["onion", "garlic", "honey", "kidney beans", "chickpea", "lentil", "apple", "mango",
                                 "wheat", "flour", "bread", "pasta", "milk", "cauliflower", "mushroom"]
    private static let rootsAndBulbs = ["onion", "garlic", "potato", "carrot", "beetroot", "radish", "ginger",
                                        "shallot", "leek", "turnip"]
    private static let pungent = ["onion", "garlic", "leek", "chive", "shallot", "scallion", "spring onion"]
    private static let gout = ["shrimp", "prawn", "anchovy", "anchovies", "sardine", "mussel", "liver", "kidney",
                               "beer", "scallop"]
    private static let carbHeavy = ["sugar", "flour", "rice", "pasta", "bread", "potato", "noodle", "tortilla",
                                    "oats", "corn", "honey", "syrup"]

    /// Every reason this recipe may not suit `profile`, hard ones first, without duplicates.
    static func flags(for recipe: Recipe, profile: HealthProfile) -> [HealthFlag] {
        let lines = recipe.ingredients.flatMap(\.items).map { " " + $0.lowercased() + " " }
        func has(_ words: [String], except: [String] = []) -> Bool {
            lines.contains { line in
                let cleaned = except.reduce(line) { $0.replacingOccurrences(of: $1, with: " ") }
                return words.contains { word in
                    // Whole-word match ("ham" must not hit "shampoo"); multi-word phrases match as written.
                    cleaned.range(of: "\\b\(NSRegularExpression.escapedPattern(for: word.trimmingCharacters(in: .whitespaces)))s?\\b",
                                  options: .regularExpression) != nil
                }
            }
        }
        let hasMeat = has(meat)
        let hasFish = has(fish) || has(["fish sauce"])
        let hasShellfish = has(shellfish) || has(["oyster sauce"])
        let hasDairy = has(dairy, except: notDairy)
        let hasEgg = has(egg, except: notEgg)
        let hasWheat = has(wheat, except: notWheat)
        let hasGluten = hasWheat || has(glutenExtra)
        let hasAlcohol = has(alcohol)

        var hard: [String] = []
        var soft: [String] = []

        for a in Allergen.allCases where profile.allergens.contains(a) {
            let hit: Bool = switch a {
            case .peanuts: has(peanut)
            case .treeNuts: has(treeNut, except: ["coconut"])
            case .dairy: hasDairy
            case .eggs: hasEgg
            case .fish: hasFish
            case .shellfish: hasShellfish
            case .soy: has(soy) || has(["soy sauce"])
            case .wheat: hasWheat
            case .sesame: has(sesame)
            }
            if hit { hard.append("Contains \(a.title.lowercased())") }
        }

        for d in DietStyle.allCases where profile.diets.contains(d) {
            switch d {
            case .vegetarian where hasMeat || hasFish || hasShellfish:
                hard.append("Not vegetarian")
            case .vegan where hasMeat || hasFish || hasShellfish || hasDairy || hasEgg || has(["honey"]),
                 .plantBased where hasMeat || hasFish || hasShellfish || hasDairy || hasEgg:
                hard.append("Not \(d.title.lowercased())")
            case .pescatarian where hasMeat:
                hard.append("Has meat")
            case .keto where has(carbHeavy), .lowCarb where has(carbHeavy), .paleo where has(carbHeavy) || hasDairy:
                soft.append("Carb-heavy for \(d.title.lowercased())")
            default:
                break
            }
        }

        for f in FaithRule.allCases where profile.faith.contains(f) {
            switch f {
            case .halal where has(["pork", "bacon", "ham", "lard", "prosciutto", "pepperoni", "salami", "chorizo", "gelatin"]) || hasAlcohol:
                hard.append("Not halal")
            case .kosher where has(["pork", "bacon", "ham", "lard"]) || hasShellfish || (hasMeat && hasDairy):
                hard.append("Not kosher")
            case .hinduNoBeef where has(["beef", "veal"]):
                hard.append("Contains beef")
            case .jain where hasMeat || hasFish || hasShellfish || hasEgg || has(rootsAndBulbs):
                hard.append("Not Jain")
            case .buddhistVegetarian where hasMeat || hasFish || hasShellfish || has(pungent):
                hard.append("Not Buddhist vegetarian")
            default:
                break
            }
        }

        for i in Intolerance.allCases where profile.intolerances.contains(i) {
            switch i {
            case .lactose where hasDairy: hard.append("Contains lactose")
            case .gluten where hasGluten: hard.append("Contains gluten")
            case .lowFODMAP where has(fodmap): hard.append("High-FODMAP ingredients")
            case .alcohol where hasAlcohol: hard.append("Contains alcohol")
            default: break
            }
        }

        for c in HealthCondition.allCases where profile.conditions.contains(c) {
            switch c {
            case .celiac where hasGluten:
                hard.append("Contains gluten")
            case .diabetes where has(addedSugar), .prediabetes where has(addedSugar):
                soft.append("Added sugar")
            case .highCholesterol where has(richFat), .pancreatitis where has(richFat):
                soft.append("Rich in saturated fat")
            case .hypertension where has(salty), .heartDisease where has(salty), .kidneyDisease where has(salty):
                soft.append("Salty ingredients")
            case .gerd where has(spicy) || hasAlcohol:
                soft.append("Spicy or alcohol")
            case .ibs where has(pungent):
                soft.append("Onion or garlic")
            case .gout where has(gout):
                soft.append("High-purine ingredients")
            case .liverDisease where hasAlcohol, .pancreatitis where hasAlcohol:
                soft.append("Contains alcohol")
            default:
                break
            }
        }

        // The user's own entries.
        for word in profile.customAvoid where has([word]) {
            hard.append("Contains \(word)")
        }
        for custom in profile.customConditions {
            for word in custom.watch where has([word]) {
                soft.append("Has \(word) · \(custom.name)")
            }
        }

        var seen = Set<String>()
        return (hard.map { HealthFlag(text: $0, hard: true) } + soft.map { HealthFlag(text: $0, hard: false) })
            .filter { seen.insert($0.text).inserted }
    }

    #if DEBUG
    /// Self-check for the matching rules (runs from the DEBUG preview below).
    static func selfCheck() {
        var p = HealthProfile()
        p.allergens = [.peanuts, .dairy]
        p.diets = [.vegetarian]
        let r = Recipe(id: "t", ownerId: "t", title: "t", servings: 2,
                       ingredients: [IngredientGroup(groupName: nil, items: ["2 tbsp peanut butter", "1 cup coconut milk", "200g chicken"])],
                       directions: [])
        let texts = Set(flags(for: r, profile: p).map(\.text))
        assert(texts.contains("Contains peanuts"), "peanut butter is peanuts")
        assert(!texts.contains("Contains dairy"), "coconut milk and peanut butter are not dairy")
        assert(texts.contains("Not vegetarian"), "chicken is meat")
        let eggplant = Recipe(id: "e", ownerId: "e", title: "e", servings: 2,
                              ingredients: [IngredientGroup(groupName: nil, items: ["1 eggplant", "1 tsp salt"])],
                              directions: [])
        var q = HealthProfile(); q.allergens = [.eggs]
        assert(flags(for: eggplant, profile: q).isEmpty, "eggplant is not egg")
    }
    #endif
}
