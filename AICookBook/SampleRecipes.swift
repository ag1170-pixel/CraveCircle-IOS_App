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
            id: "recipe-hot-honey-chicken",
            ownerId: "creator-nada",
            title: "Hot Honey Crispy Chicken Burger",
            description: "Double-crunch buttermilk fried chicken drenched in chili-infused hot honey with creamy pickled slaw on toasted brioche.",
            prepTime: "20 min",
            cookTime: "15 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Buttermilk Marinade",
                    items: [
                        "4 boneless chicken thighs",
                        "1 cup buttermilk",
                        "1 tbsp smoked paprika",
                        "1 tsp garlic powder",
                        "1 tsp onion powder",
                        "1 tsp cayenne pepper",
                        "1 tsp kosher salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Crispy Dredge & Crust",
                    items: [
                        "1.5 cups all-purpose flour",
                        "0.5 cup cornstarch",
                        "1 tsp baking powder",
                        "1 tbsp cajun seasoning",
                        "Oil for deep frying"
                    ]
                ),
                IngredientGroup(
                    groupName: "Hot Honey Glaze",
                    items: [
                        "0.5 cup wildflower honey",
                        "2 tbsp unsalted butter",
                        "1 tbsp hot sauce (Frank's or Louisiana)",
                        "1 tsp crushed red pepper flakes",
                        "0.5 tsp apple cider vinegar"
                    ]
                ),
                IngredientGroup(
                    groupName: "Slaw & Assembly",
                    items: [
                        "4 brioche buns (toasted with butter)",
                        "2 cups shredded purple & green cabbage",
                        "3 tbsp mayonnaise",
                        "1 tbsp dill pickle juice",
                        "Dill pickle chips"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Whisk buttermilk, smoked paprika, garlic powder, onion powder, cayenne, and salt. Submerge chicken thighs and marinate for at least 30 minutes."),
                DirectionStep(stepIndex: 2, text: "In a wide shallow bowl, whisk flour, cornstarch, baking powder, and cajun seasoning. Drizzle 2 tbsp buttermilk marinade into the flour to create shaggy flakes."),
                DirectionStep(stepIndex: 3, text: "Dredge each chicken thigh thoroughly, pressing flour firmly into every crevice. Rest for 5 minutes while oil heats to 350°F (175°C)."),
                DirectionStep(stepIndex: 4, text: "Fry chicken in batches for 6–8 minutes until deeply golden brown and crispy (internal temp 165°F / 74°C). Drain on a wire rack."),
                DirectionStep(stepIndex: 5, text: "Warm honey, butter, hot sauce, red pepper flakes, and cider vinegar in a saucepan until bubbling. Generously brush over hot fried chicken."),
                DirectionStep(stepIndex: 6, text: "Toss cabbage with mayo and pickle juice. Layer toasted bottom bun, pickles, crispy glazed chicken, crunchy slaw, and top bun.")
            ],
            thumbnailUrl: "recipe_hot_honey_chicken",
            ownerUsername: "@nada_dl",
            sourceLanguage: "en",
            nutrition: RecipeNutrition(
                calories: 680,
                carbsG: 52,
                proteinG: 48,
                fatG: 28,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-spicy-paneer-wrap",
            ownerId: "preview-user",
            title: "Spicy Paneer Tikka Wrap",
            description: "High-protein char-grilled paneer cubes tossed in smoky tandoori masala with crunchy mint yogurt slaw in warm flaky rotis.",
            prepTime: "15 min",
            cookTime: "10 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Smoky Paneer Tikka",
                    items: [
                        "250g paneer cubes",
                        "2 tbsp Greek yogurt",
                        "1 tbsp roasted gram flour (besan)",
                        "1 tbsp ginger-garlic paste",
                        "1 tsp Kashmiri red chili powder",
                        "0.5 tsp garam masala",
                        "1 tsp mustard oil",
                        "0.5 tsp chaat masala"
                    ]
                ),
                IngredientGroup(
                    groupName: "Mint Yogurt Chutney",
                    items: [
                        "0.5 cup fresh mint leaves",
                        "0.5 cup fresh coriander",
                        "2 green chilies",
                        "0.5 cup thick Greek yogurt",
                        "1 tbsp lemon juice",
                        "0.5 tsp black salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Wrap Assembly",
                    items: [
                        "2 whole wheat rotis or parathas",
                        "1 sliced red onion",
                        "1 sliced bell pepper",
                        "1 tbsp chaat masala"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Mix yogurt, besan, ginger-garlic paste, spices, and mustard oil. Coat paneer cubes and marinate for 15 minutes."),
                DirectionStep(stepIndex: 2, text: "Blend mint, coriander, green chilies, yogurt, lemon juice, and black salt into a smooth vibrant chutney."),
                DirectionStep(stepIndex: 3, text: "Sear paneer cubes in a cast iron skillet over high heat with sliced bell peppers for 5–7 minutes until charred and golden."),
                DirectionStep(stepIndex: 4, text: "Warm rotis on the tawa. Spread mint chutney, layer smoky paneer, onion rings, peppers, sprinkle chaat masala, and roll tightly.")
            ],
            thumbnailUrl: "recipe_paneer_wrap",
            ownerUsername: "@aicookbook",
            sourceLanguage: nil,
            nutrition: RecipeNutrition(
                calories: 403,
                carbsG: 23,
                proteinG: 28,
                fatG: 23,
                estimated: false
            ),
            sourceUrl: nil
        ),
        Recipe(
            id: "recipe-tuscan-salmon",
            ownerId: "creator-kristy",
            title: "Creamy Garlic Tuscan Salmon",
            description: "Pan-seared crisp salmon fillets bathed in a rich garlic, sun-dried tomato, spinach, and parmesan cream reduction.",
            prepTime: "10 min",
            cookTime: "20 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Crispy Salmon Fillets",
                    items: [
                        "2 fresh salmon fillets (skin-on)",
                        "1 tbsp olive oil",
                        "1 tbsp unsalted butter",
                        "0.5 tsp garlic powder",
                        "Salt & cracked black pepper"
                    ]
                ),
                IngredientGroup(
                    groupName: "Tuscan Cream Sauce",
                    items: [
                        "4 cloves minced garlic",
                        "0.5 cup chopped sun-dried tomatoes (in oil)",
                        "2 cups fresh baby spinach",
                        "0.75 cup heavy cream",
                        "0.25 cup grated parmesan cheese",
                        "0.25 cup chicken or vegetable broth"
                    ]
                ),
                IngredientGroup(
                    groupName: "Garnish & Serving",
                    items: [
                        "Fresh basil ribbons",
                        "1 lemon (quartered)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Pat salmon fillets completely dry with paper towels. Season both sides with salt, pepper, and garlic powder."),
                DirectionStep(stepIndex: 2, text: "Heat olive oil and butter in a large skillet over medium-high heat. Sear salmon skin-side down for 5 minutes, flip, and cook 3 minutes more. Transfer to a plate."),
                DirectionStep(stepIndex: 3, text: "In the same skillet, saute minced garlic and sun-dried tomatoes for 1 minute until fragrant."),
                DirectionStep(stepIndex: 4, text: "Pour in broth and heavy cream. Bring to a gentle simmer for 3 minutes, then stir in parmesan and baby spinach until wilted."),
                DirectionStep(stepIndex: 5, text: "Nestle salmon fillets back into the cream sauce. Spoon sauce over the top, simmer for 1 minute, and garnish with fresh basil and lemon.")
            ],
            thumbnailUrl: "recipe_tuscan_salmon",
            ownerUsername: "@Kristy.Graver",
            sourceLanguage: "en",
            nutrition: RecipeNutrition(
                calories: 540,
                carbsG: 8,
                proteinG: 42,
                fatG: 38,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-tomato-rigatoni",
            ownerId: "creator-chefbot",
            title: "One-Pot Creamy Tomato & Basil Rigatoni",
            description: "Silky 20-minute pasta cooked directly in garlic pomodoro broth, finished with fresh buffalo mozzarella and fragrant torn basil.",
            prepTime: "10 min",
            cookTime: "18 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Pasta & Pomodoro Base",
                    items: [
                        "400g rigatoni pasta",
                        "2 tbsp extra virgin olive oil",
                        "5 cloves garlic (thinly sliced)",
                        "1 can (400g) San Marzano crushed tomatoes",
                        "3 cups vegetable or chicken stock",
                        "1 tsp dried oregano",
                        "0.5 tsp red chili flakes",
                        "1 tsp kosher salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Finishing & Cheese",
                    items: [
                        "0.5 cup heavy cream or mascarpone",
                        "125g fresh buffalo mozzarella (torn)",
                        "0.5 cup freshly grated Parmigiano-Reggiano",
                        "1 cup fresh basil leaves (torn)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Heat olive oil in a wide Dutch oven over medium heat. Sauté sliced garlic and chili flakes for 90 seconds until golden and aromatic."),
                DirectionStep(stepIndex: 2, text: "Add crushed tomatoes, oregano, salt, uncooked rigatoni, and broth. Stir well to submerge pasta."),
                DirectionStep(stepIndex: 3, text: "Bring to a boil, then reduce heat to medium-low, cover, and simmer for 12–14 minutes, stirring occasionally, until rigatoni is al dente and sauce is thick."),
                DirectionStep(stepIndex: 4, text: "Remove from heat. Stir in heavy cream and Parmigiano. Top with torn buffalo mozzarella and fresh basil, cover for 2 minutes to melt cheese, and serve.")
            ],
            thumbnailUrl: "recipe_tomato_rigatoni",
            ownerUsername: "@chefbot",
            sourceLanguage: "en",
            nutrition: RecipeNutrition(
                calories: 480,
                carbsG: 78,
                proteinG: 16,
                fatG: 12,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-chipotle-burrito-bowl",
            ownerId: "creator-aditya",
            title: "Smoky Chipotle Chicken Burrito Bowl",
            description: "Macro-balanced meal prep favorite with char-grilled chipotle chicken, fragrant cilantro-lime jasmine rice, charred corn salsa, and light lime crema.",
            prepTime: "20 min",
            cookTime: "20 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Chipotle Marinated Chicken",
                    items: [
                        "600g boneless chicken breast",
                        "2 chipotle peppers in adobo sauce (finely chopped)",
                        "1 tbsp adobo sauce",
                        "1 tbsp olive oil",
                        "1 tbsp lime juice",
                        "1 tsp cumin powder",
                        "1 tsp garlic powder",
                        "1 tsp sea salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Cilantro-Lime Jasmine Rice",
                    items: [
                        "1.5 cups uncooked jasmine rice",
                        "3 cups water",
                        "0.5 cup chopped fresh cilantro",
                        "Zest and juice of 2 limes",
                        "0.5 tsp salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Sweet Corn & Black Bean Salsa",
                    items: [
                        "1 can (400g) black beans (rinsed & drained)",
                        "1 cup sweet corn kernels (charred)",
                        "1 diced Roma tomato",
                        "0.5 diced red onion",
                        "1 diced jalapeño"
                    ]
                ),
                IngredientGroup(
                    groupName: "Smoked Paprika Crema",
                    items: [
                        "0.5 cup non-fat Greek yogurt",
                        "1 tbsp lime juice",
                        "0.5 tsp smoked paprika",
                        "1 ripe avocado (sliced)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Marinate chicken in chopped chipotles, adobo sauce, olive oil, lime juice, cumin, garlic powder, and salt for 20 minutes."),
                DirectionStep(stepIndex: 2, text: "Cook jasmine rice. Once fluffy, fold in fresh cilantro, lime zest, lime juice, and salt."),
                DirectionStep(stepIndex: 3, text: "Toss black beans, charred corn, diced tomatoes, red onions, and jalapeños with lime juice in a bowl."),
                DirectionStep(stepIndex: 4, text: "Grill chicken breast on high heat for 6–7 minutes per side until charred and cooked through. Rest 5 minutes then slice into strips."),
                DirectionStep(stepIndex: 5, text: "Whisk Greek yogurt with lime juice and smoked paprika. Assemble bowls: cilantro rice base, charred chicken, black bean salsa, sliced avocado, and a generous drizzle of crema.")
            ],
            thumbnailUrl: "recipe_chipotle_bowl",
            ownerUsername: "@Aditya.Gupta",
            sourceLanguage: "en",
            nutrition: RecipeNutrition(
                calories: 590,
                carbsG: 62,
                proteinG: 46,
                fatG: 18,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-shakshuka",
            ownerId: "creator-zaatar",
            title: "Shakshuka with Whipped Feta & Crusty Bread",
            description: "Gently poached farm eggs nestled in a deeply spiced sweet pepper and cumin-tomato sauce, topped with creamy whipped feta and za'atar.",
            prepTime: "10 min",
            cookTime: "20 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Spiced Harissa & Bell Pepper Base",
                    items: [
                        "2 tbsp extra virgin olive oil",
                        "1 medium yellow onion (diced)",
                        "1 red bell pepper (chopped)",
                        "3 cloves garlic (minced)",
                        "1 tbsp rose harissa paste",
                        "1 tsp ground cumin",
                        "1 tsp smoked paprika",
                        "1 can (400g) whole peeled plum tomatoes"
                    ]
                ),
                IngredientGroup(
                    groupName: "Poached Eggs & Feta",
                    items: [
                        "4 large farm fresh eggs",
                        "75g creamy Greek feta (crumbled)",
                        "0.25 cup chopped fresh parsley & cilantro"
                    ]
                ),
                IngredientGroup(
                    groupName: "Serving",
                    items: [
                        "1 tsp za'atar seasoning",
                        "Warm crusty sourdough bread"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Heat olive oil in a heavy cast-iron skillet over medium heat. Sauté onion and red bell pepper for 8 minutes until softened."),
                DirectionStep(stepIndex: 2, text: "Add garlic, harissa, cumin, and paprika. Cook for 1 minute until fragrant. Crush tomatoes into the skillet with their juices and simmer for 10 minutes until sauce thickens."),
                DirectionStep(stepIndex: 3, text: "Make 4 small wells in the sauce with the back of a spoon. Crack an egg into each well. Cover the skillet and cook on low heat for 5–7 minutes until egg whites are set and yolks remain runny."),
                DirectionStep(stepIndex: 4, text: "Remove from heat. Dot with crumbled feta, sprinkle fresh parsley, cilantro, and za'atar. Serve immediately with warm crusty sourdough.")
            ],
            thumbnailUrl: "recipe_shakshuka",
            ownerUsername: "@zaatarandzeal",
            sourceLanguage: "en",
            nutrition: RecipeNutrition(
                calories: 360,
                carbsG: 24,
                proteinG: 20,
                fatG: 22,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-korean-wings",
            ownerId: "creator-dev",
            title: "Crispy Air-Fryer Korean Gochujang Wings",
            description: "Ultra-crispy air-fried chicken wings tossed in a sticky, sweet, and fiery Korean chili glaze with toasted sesame and scallions.",
            prepTime: "10 min",
            cookTime: "25 min",
            servings: 3,
            ingredients: [
                IngredientGroup(
                    groupName: "Crispy Wing Prep",
                    items: [
                        "900g chicken party wings (flats & drumettes)",
                        "1 tbsp baking powder (aluminum-free)",
                        "1 tsp garlic powder",
                        "0.5 tsp ginger powder",
                        "1 tsp salt & black pepper"
                    ]
                ),
                IngredientGroup(
                    groupName: "Sticky Gochujang Glaze",
                    items: [
                        "2 tbsp Korean Gochujang paste",
                        "2 tbsp honey",
                        "1 tbsp brown sugar",
                        "2 tbsp low-sodium soy sauce",
                        "1 tbsp toasted sesame oil",
                        "2 cloves minced garlic",
                        "1 tsp grated fresh ginger"
                    ]
                ),
                IngredientGroup(
                    groupName: "Garnish",
                    items: [
                        "1 tbsp toasted white sesame seeds",
                        "2 scallions (thinly sliced)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Thoroughly pat chicken wings dry with paper towels. Toss with baking powder, garlic powder, ginger powder, salt, and pepper until evenly coated."),
                DirectionStep(stepIndex: 2, text: "Arrange wings in a single layer in the air fryer basket. Cook at 380°F (190°C) for 18 minutes, flipping halfway. Increase temp to 400°F (200°C) and cook for 6 more minutes until ultra-crispy."),
                DirectionStep(stepIndex: 3, text: "While wings cook, combine gochujang, honey, brown sugar, soy sauce, sesame oil, garlic, and ginger in a small saucepan. Simmer for 3 minutes until glossy and thick."),
                DirectionStep(stepIndex: 4, text: "Transfer hot crispy wings to a large bowl, pour warm glaze over them, and toss quickly to coat. Garnish with toasted sesame seeds and sliced scallions.")
            ],
            thumbnailUrl: "recipe_korean_wings",
            ownerUsername: "@deveats",
            sourceLanguage: "en",
            nutrition: RecipeNutrition(
                calories: 520,
                carbsG: 22,
                proteinG: 38,
                fatG: 31,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-butter-chicken",
            ownerId: "creator-sanjeev",
            title: "Authentic Butter Chicken (Murgh Makhani)",
            description: "Velvety restaurant-style tandoori chicken cooked in a rich tomato, butter, and cashew gravy infused with aromatic crushed kasuri methi.",
            prepTime: "30 min",
            cookTime: "30 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Tandoori Chicken Marinade",
                    items: [
                        "600g boneless chicken thighs (cubed)",
                        "0.5 cup thick hung curd (Greek yogurt)",
                        "1 tbsp ginger-garlic paste",
                        "1 tbsp Kashmiri chili powder",
                        "1 tsp garam masala",
                        "1 tbsp lemon juice",
                        "1 tbsp mustard oil",
                        "1 tsp salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Makhani Gravy",
                    items: [
                        "500g ripe red tomatoes (roughly chopped)",
                        "15 whole raw cashew nuts",
                        "2 green cardamom pods",
                        "1 inch cinnamon stick",
                        "3 cloves garlic & 1 inch ginger",
                        "1 tbsp Kashmiri chili powder",
                        "1 cup water"
                    ]
                ),
                IngredientGroup(
                    groupName: "Finishing & Tempering",
                    items: [
                        "3 tbsp unsalted butter",
                        "0.25 cup fresh heavy cream",
                        "1 tbsp roasted crushed Kasuri Methi (fenugreek leaves)",
                        "1 tsp honey or sugar"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Marinate chicken in yogurt, ginger-garlic paste, spices, mustard oil, and lemon juice for at least 30 minutes."),
                DirectionStep(stepIndex: 2, text: "In a saucepan, boil tomatoes, cashews, cardamom, cinnamon, ginger, garlic, Kashmiri chili powder, and water for 15 minutes until soft. Cool and blend into a silky smooth puree."),
                DirectionStep(stepIndex: 3, text: "Sear marinated chicken cubes in a hot grill pan with butter for 8–10 minutes until charred edges develop."),
                DirectionStep(stepIndex: 4, text: "Strain the tomato-cashew puree into a pot. Simmer over medium heat for 10 minutes until glossy."),
                DirectionStep(stepIndex: 5, text: "Add cooked tandoori chicken to the gravy. Stir in butter, heavy cream, honey, and crushed kasuri methi."),
                DirectionStep(stepIndex: 6, text: "Simmer gently for 5 minutes until chicken is tender and sauce clings to the spoon. Serve hot with garlic butter naan.")
            ],
            thumbnailUrl: "recipe_butter_chicken",
            ownerUsername: "@Sanjeev.Kapoor",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 620,
                carbsG: 18,
                proteinG: 44,
                fatG: 42,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-green-goddess-pasta",
            ownerId: "creator-priya",
            title: "Avocado Pesto Green Goddess Pasta",
            description: "Nutrient-packed vibrant fusilli coated in a creamy no-cook avocado, baby spinach, basil, and pistachio green goddess pesto.",
            prepTime: "10 min",
            cookTime: "12 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Green Goddess Pesto",
                    items: [
                        "1 ripe avocado",
                        "2 cups fresh baby spinach",
                        "1 cup fresh basil leaves",
                        "0.25 cup shelled pistachios or walnuts",
                        "2 cloves garlic",
                        "Zest and juice of 1 lemon",
                        "3 tbsp extra virgin olive oil",
                        "0.25 cup grated parmesan or nutritional yeast",
                        "0.5 tsp sea salt & black pepper"
                    ]
                ),
                IngredientGroup(
                    groupName: "Pasta Toss & Garnish",
                    items: [
                        "250g fusilli or campanelle pasta",
                        "0.5 cup reserved starchy pasta water",
                        "1 cup halved cherry tomatoes",
                        "1 tbsp toasted pumpkin seeds"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Boil pasta in salted water until al dente. Reserve 1/2 cup pasta cooking water before draining."),
                DirectionStep(stepIndex: 2, text: "In a food processor, blend avocado, spinach, basil, pistachios, garlic, lemon juice/zest, olive oil, parmesan, salt, and pepper into a silky bright-green pesto."),
                DirectionStep(stepIndex: 3, text: "Toss hot pasta with the green goddess sauce, adding splashes of pasta water to create a creamy coating. Fold in sweet cherry tomatoes and top with toasted pumpkin seeds.")
            ],
            thumbnailUrl: "recipe_green_pasta",
            ownerUsername: "@priyacooks",
            sourceLanguage: "en",
            nutrition: RecipeNutrition(
                calories: 450,
                carbsG: 58,
                proteinG: 14,
                fatG: 20,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-souffle-pancakes",
            ownerId: "creator-aisha",
            title: "Japanese Fluffy Soufflé Pancakes",
            description: "Cloud-like, jiggly Japanese soufflé pancakes that melt in your mouth, served with honeycomb butter, maple syrup, and fresh berries.",
            prepTime: "15 min",
            cookTime: "15 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Egg Yolk Custard Base",
                    items: [
                        "2 egg yolks",
                        "1 tbsp whole milk",
                        "1 tsp vanilla bean paste",
                        "4 tbsp cake flour (sifted)",
                        "0.5 tsp baking powder"
                    ]
                ),
                IngredientGroup(
                    groupName: "Stiff Meringue",
                    items: [
                        "3 cold egg whites",
                        "2.5 tbsp granulated sugar",
                        "0.25 tsp cream of tartar or lemon juice"
                    ]
                ),
                IngredientGroup(
                    groupName: "Toppings & Serving",
                    items: [
                        "1 tbsp butter (for pan)",
                        "2 tbsp pure maple syrup",
                        "Fresh strawberries and blueberries",
                        "Powdered sugar for dusting"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Whisk egg yolks, milk, and vanilla until pale. Sift in cake flour and baking powder, gently whisking into a smooth custard."),
                DirectionStep(stepIndex: 2, text: "In a clean glass bowl, whip cold egg whites with cream of tartar on medium until foamy. Gradually add sugar in 3 additions, whipping to glossy stiff peaks."),
                DirectionStep(stepIndex: 3, text: "Gently fold 1/3 of the meringue into the yolk mixture to lighten, then carefully fold in the remaining meringue in two batches without deflating."),
                DirectionStep(stepIndex: 4, text: "Lightly oil a non-stick pan over very low heat. Scoop 3 tall mounds of batter. Add 1 tsp water to the pan, cover tightly with a lid, and steam for 5–6 minutes."),
                DirectionStep(stepIndex: 5, text: "Add another scoop on top of each pancake, gently flip, add another tsp water, cover, and steam for 5 more minutes. Serve immediately dusted with powdered sugar, berries, and maple syrup.")
            ],
            thumbnailUrl: "recipe_souffle_pancakes",
            ownerUsername: "@aishaskitchen",
            sourceLanguage: "en",
            nutrition: RecipeNutrition(
                calories: 310,
                carbsG: 44,
                proteinG: 10,
                fatG: 11,
                estimated: false
            )
        )
        ,
        Recipe(
            id: "recipe-birria-tacos",
            ownerId: "creator-zaatar",
            title: "Birria Beef Tacos with Consomé",
            description: "Slow-braised shredded beef tucked into crispy chili-dipped corn tortillas with melted Oaxaca cheese, served with rich consomé for dipping.",
            prepTime: "25 min",
            cookTime: "45 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Braised Beef & Broth",
                    items: [
                        "700g beef chuck roast (cubed)",
                        "4 dried guajillo chilies (stemmed and seeded)",
                        "2 dried ancho chilies (stemmed and seeded)",
                        "1 medium onion (halved)",
                        "4 cloves garlic",
                        "2 cups beef broth",
                        "1 tsp ground cumin",
                        "1 tsp dried Mexican oregano",
                        "1 tsp kosher salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Tacos & Assembly",
                    items: [
                        "8 corn tortillas",
                        "200g Oaxaca or Monterey Jack cheese (shredded)",
                        "0.5 cup diced white onion",
                        "0.5 cup chopped fresh cilantro",
                        "2 fresh limes (cut into wedges)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Toast dried chilies in a dry pan for 2 minutes, then soak in hot water until softened. Blend chilies, onion, garlic, cumin, oregano, and salt with 1 cup broth until smooth."),
                DirectionStep(stepIndex: 2, text: "Sear beef cubes in a Dutch oven until browned. Pour chili puree and remaining beef broth over beef. Cover and braise on low heat for 45 minutes until fork-tender and shreddable."),
                DirectionStep(stepIndex: 3, text: "Shred beef with two forks. Skim the seasoned chili oil floating on top of the broth into a shallow bowl."),
                DirectionStep(stepIndex: 4, text: "Dip corn tortillas into the warm chili oil, then place on a hot skillet. Top with shredded cheese and braised beef, fold in half, and sear until crispy on both sides."),
                DirectionStep(stepIndex: 5, text: "Ladle warm consomé broth into bowls, top with cilantro and onion, and serve alongside hot tacos with lime wedges.")
            ],
            thumbnailUrl: "recipe_birria_tacos",
            ownerUsername: "@zaatarandzeal",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-crispy-gyoza",
            ownerId: "creator-chefbot",
            title: "Crispy Lace-Skirt Vegetable Gyoza",
            description: "Pan-fried Japanese dumplings with a golden lace skirt, packed with cabbage, shiitake mushrooms, ginger, and scallions.",
            prepTime: "20 min",
            cookTime: "10 min",
            servings: 3,
            ingredients: [
                IngredientGroup(
                    groupName: "Vegetable Filling",
                    items: [
                        "2 cups finely shredded napa cabbage",
                        "6 fresh shiitake mushrooms (finely minced)",
                        "2 stalks scallions (thinly sliced)",
                        "1 tbsp freshly grated ginger",
                        "2 cloves garlic (minced)",
                        "1 tbsp toasted sesame oil",
                        "1 tbsp low-sodium soy sauce",
                        "0.5 tsp white pepper"
                    ]
                ),
                IngredientGroup(
                    groupName: "Wrappers & Lace Skirt",
                    items: [
                        "18 round gyoza wrappers",
                        "2 tbsp neutral cooking oil",
                        "1 tsp cornstarch",
                        "0.33 cup cold water"
                    ]
                ),
                IngredientGroup(
                    groupName: "Dipping Sauce",
                    items: [
                        "2 tbsp soy sauce",
                        "1 tbsp rice vinegar",
                        "1 tsp chili oil (rayu)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Toss shredded cabbage with a pinch of salt, let sit 10 minutes, and squeeze out excess moisture. Mix with minced mushrooms, scallions, ginger, garlic, sesame oil, soy sauce, and white pepper."),
                DirectionStep(stepIndex: 2, text: "Place 1 tbsp filling in the center of each wrapper, wet the edges with water, pleat the top edge 4–5 times, and press firmly to seal."),
                DirectionStep(stepIndex: 3, text: "Whisk cornstarch and cold water in a small bowl until dissolved."),
                DirectionStep(stepIndex: 4, text: "Heat oil in a non-stick skillet over medium-high heat. Arrange dumplings in a circle and sear bottoms for 2 minutes until golden."),
                DirectionStep(stepIndex: 5, text: "Pour cornstarch slurry around the dumplings, cover with a lid immediately, and steam for 5 minutes until wrappers are translucent."),
                DirectionStep(stepIndex: 6, text: "Remove lid and let cook uncovered until the bottom slurry crisps into a golden lacy honeycomb skirt. Invert onto a plate and serve with dipping sauce.")
            ],
            thumbnailUrl: "recipe_crispy_gyoza",
            ownerUsername: "@chefbot",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-mushroom-risotto",
            ownerId: "creator-kristy",
            title: "Creamy Wild Mushroom Risotto",
            description: "Slow-stirred arborio rice with sautéed cremini, shiitake, and porcini mushrooms, finished with butter, fresh thyme, and aged parmesan.",
            prepTime: "15 min",
            cookTime: "25 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Sautéed Mushrooms",
                    items: [
                        "300g mixed wild mushrooms (cremini, shiitake, chanterelle)",
                        "2 tbsp unsalted butter",
                        "2 cloves garlic (thinly sliced)",
                        "2 sprigs fresh thyme leaves"
                    ]
                ),
                IngredientGroup(
                    groupName: "Risotto Base",
                    items: [
                        "1.5 cups arborio rice",
                        "1 small shallot (finely diced)",
                        "0.5 cup dry white wine",
                        "4 cups warm vegetable or chicken broth",
                        "2 tbsp extra virgin olive oil",
                        "0.5 cup grated parmigiano reggiano",
                        "2 tbsp cold butter (cubed)",
                        "0.5 tsp cracked black pepper"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Heat 2 tbsp butter in a pan over high heat. Sauté sliced wild mushrooms with garlic and thyme for 5–6 minutes until deeply caramelized. Season and set aside."),
                DirectionStep(stepIndex: 2, text: "In a wide heavy saucepan, heat olive oil over medium. Cook diced shallot until translucent. Add arborio rice and toast for 2 minutes until edges are pearly."),
                DirectionStep(stepIndex: 3, text: "Pour in dry white wine, stirring constantly until fully absorbed."),
                DirectionStep(stepIndex: 4, text: "Add warm broth one ladle at a time, stirring gently and allowing each ladle to absorb before adding the next, cooking for 18–20 minutes until rice is creamy yet al dente."),
                DirectionStep(stepIndex: 5, text: "Remove from heat. Vigorously beat in cold cubed butter, grated parmesan, and 3/4 of the sautéed mushrooms until glossy and flowing."),
                DirectionStep(stepIndex: 6, text: "Spoon into warm shallow bowls, top with reserved mushrooms, extra parmesan, fresh thyme, and cracked black pepper.")
            ],
            thumbnailUrl: "recipe_mushroom_risotto",
            ownerUsername: "@Kristy.Graver",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-avocado-toast",
            ownerId: "creator-priya",
            title: "Sourdough Avocado Toast with Poached Eggs",
            description: "Toasted artisan sourdough loaded with citrus mashed avocado, jammy soft-poached eggs, chili flakes, and everything bagel seasoning.",
            prepTime: "10 min",
            cookTime: "5 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Citrus Avocado Mash",
                    items: [
                        "2 ripe Haas avocados",
                        "1 tbsp fresh lemon juice",
                        "1 tbsp extra virgin olive oil",
                        "0.5 tsp flaky sea salt",
                        "0.25 tsp crushed red pepper flakes"
                    ]
                ),
                IngredientGroup(
                    groupName: "Toast & Eggs",
                    items: [
                        "2 thick slices artisan sourdough bread",
                        "2 large pasture-raised eggs",
                        "1 tbsp white vinegar (for poaching water)",
                        "1 tbsp everything bagel seasoning",
                        "0.25 cup fresh pea shoots or microgreens"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Scoop avocado flesh into a bowl. Mash with lemon juice, olive oil, sea salt, and red pepper flakes with a fork, leaving slight texture."),
                DirectionStep(stepIndex: 2, text: "Bring 3 inches of water to a gentle simmer in a small saucepan. Stir in vinegar and create a gentle vortex with a spoon."),
                DirectionStep(stepIndex: 3, text: "Crack each egg into a ramekin and gently slide into the center of the whirlpool. Poach for 3 minutes for jammy runny yolks, then transfer with a slotted spoon to a paper towel."),
                DirectionStep(stepIndex: 4, text: "Toast sourdough slices until deeply golden and crunchy."),
                DirectionStep(stepIndex: 5, text: "Mound mashed avocado generously across the toast. Crown each with a poached egg, everything bagel seasoning, and fresh microgreens.")
            ],
            thumbnailUrl: "recipe_avocado_toast",
            ownerUsername: "@priyacooks",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-thai-basil-chicken",
            ownerId: "creator-nada",
            title: "Spicy Thai Holy Basil Chicken (Pad Krapow)",
            description: "Sizzling minced chicken stir-fried with fragrant holy basil, garlic, and fiery bird's eye chilies, served over jasmine rice with a crispy fried egg.",
            prepTime: "10 min",
            cookTime: "8 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Stir Fry Ingredients",
                    items: [
                        "350g ground chicken (or finely diced thighs)",
                        "1 cup fresh Thai holy basil or Italian basil leaves",
                        "4 cloves garlic (coarsely pounded)",
                        "3 red bird's eye chilies (minced)",
                        "2 tbsp vegetable oil"
                    ]
                ),
                IngredientGroup(
                    groupName: "Savory Umami Sauce",
                    items: [
                        "1.5 tbsp oyster sauce",
                        "1 tbsp low-sodium soy sauce",
                        "1 tsp dark sweet soy sauce",
                        "1 tsp fish sauce",
                        "1 tsp raw sugar",
                        "2 tbsp water"
                    ]
                ),
                IngredientGroup(
                    groupName: "Serving Accompaniments",
                    items: [
                        "2 cups cooked jasmine rice",
                        "2 large eggs (fried crispy in oil)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "In a small bowl, stir together oyster sauce, regular soy sauce, dark soy sauce, fish sauce, sugar, and water."),
                DirectionStep(stepIndex: 2, text: "Heat 2 tbsp oil in a wok over high heat until smoking. Add pounded garlic and chilies, stir-frying for 30 seconds until intensely aromatic."),
                DirectionStep(stepIndex: 3, text: "Add minced chicken, breaking it apart with a spatula and cooking for 3–4 minutes until lightly browned."),
                DirectionStep(stepIndex: 4, text: "Pour in the sauce mixture and toss rapidly for 1 minute until sauce coats chicken and bubbles."),
                DirectionStep(stepIndex: 5, text: "Turn off the heat, add fresh basil leaves, and toss gently until just wilted from residual heat."),
                DirectionStep(stepIndex: 6, text: "Serve hot over warm jasmine rice, crowned with a Thai-style crispy fried egg with a runny yolk.")
            ],
            thumbnailUrl: "recipe_thai_basil_chicken",
            ownerUsername: "@nada_dl",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-french-onion-soup",
            ownerId: "creator-kristy",
            title: "Classic French Onion Soup Gratinée",
            description: "Deeply caramelized sweet onions simmered in rich beef broth and white wine, topped with toasted baguette and broiled bubbly gruyère.",
            prepTime: "15 min",
            cookTime: "40 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Caramelized Onion Broth",
                    items: [
                        "1kg yellow sweet onions (thinly sliced)",
                        "3 tbsp unsalted butter",
                        "1 tbsp olive oil",
                        "0.5 cup dry white wine",
                        "5 cups rich beef bone broth",
                        "2 sprigs fresh thyme",
                        "1 bay leaf",
                        "1 tsp sea salt & black pepper"
                    ]
                ),
                IngredientGroup(
                    groupName: "Gratinée Topping",
                    items: [
                        "4 thick slices French baguette (toasted)",
                        "1.5 cups shredded cave-aged Gruyère cheese",
                        "0.25 cup grated parmesan cheese"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Melt butter and oil in a large Dutch oven over medium-low heat. Add sliced onions with a pinch of salt and cook for 35–40 minutes, stirring occasionally, until deeply golden brown and sweet."),
                DirectionStep(stepIndex: 2, text: "Pour in dry white wine to deglaze the pot, scraping up all the savory fond from the bottom."),
                DirectionStep(stepIndex: 3, text: "Add beef broth, thyme sprigs, and bay leaf. Bring to a boil, reduce heat, and simmer gently for 20 minutes. Discard thyme and bay leaf."),
                DirectionStep(stepIndex: 4, text: "Ladle hot soup into oven-safe ceramic bowls placed on a baking sheet."),
                DirectionStep(stepIndex: 5, text: "Top each bowl with a slice of toasted baguette and blanket generously with shredded Gruyère and parmesan."),
                DirectionStep(stepIndex: 6, text: "Broil under high heat for 3–4 minutes until cheese is melted, bubbling, and golden-brown. Garnish with fresh thyme and serve hot.")
            ],
            thumbnailUrl: "recipe_french_onion_soup",
            ownerUsername: "@Kristy.Graver",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-falafel-bowl",
            ownerId: "creator-zaatar",
            title: "Mediterranean Crispy Falafel Mezze Bowl",
            description: "Crispy herb-packed chickpea falafels nestled over fluffy saffron rice, creamy hummus, pickled cucumbers, kalamata olives, and lemon tahini drizzle.",
            prepTime: "20 min",
            cookTime: "15 min",
            servings: 3,
            ingredients: [
                IngredientGroup(
                    groupName: "Herbed Falafel",
                    items: [
                        "1.5 cups dried chickpeas (soaked overnight, not canned)",
                        "1 small onion (chopped)",
                        "1 cup fresh parsley leaves",
                        "1 cup fresh cilantro leaves",
                        "3 cloves garlic",
                        "1 tbsp ground cumin",
                        "1 tsp ground coriander",
                        "1 tsp sea salt",
                        "1 tbsp toasted sesame seeds",
                        "Oil for shallow frying"
                    ]
                ),
                IngredientGroup(
                    groupName: "Bowl Fixings & Tahini",
                    items: [
                        "2 cups cooked turmeric basmati rice",
                        "0.75 cup classic smooth hummus",
                        "1 cup diced Persian cucumber & cherry tomatoes",
                        "0.33 cup pitted kalamata olives",
                        "0.33 cup pickled pink onions",
                        "3 tbsp creamy tahini paste",
                        "1.5 tbsp fresh lemon juice",
                        "2 tbsp ice water"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "In a food processor, pulse soaked raw chickpeas, onion, herbs, garlic, cumin, coriander, and salt until finely minced (do not puree). Stir in sesame seeds and chill for 20 minutes."),
                DirectionStep(stepIndex: 2, text: "Scoop mixture and shape into golf-ball sized rounds, flattening slightly."),
                DirectionStep(stepIndex: 3, text: "Heat 1 inch of oil to 360°F (180°C). Fry falafels in batches for 4–5 minutes until deeply golden brown and crisp on the exterior. Drain on paper towels."),
                DirectionStep(stepIndex: 4, text: "Whisk tahini paste, lemon juice, and ice water until pale, silky, and pourable."),
                DirectionStep(stepIndex: 5, text: "Build bowls: divide warm turmeric rice, dollop smooth hummus with a sprinkle of paprika, add cucumber-tomato salad, olives, pickled onions, and warm crunchy falafels."),
                DirectionStep(stepIndex: 6, text: "Drizzle generously with lemon tahini sauce and serve immediately.")
            ],
            thumbnailUrl: "recipe_falafel_bowl",
            ownerUsername: "@zaatarandzeal",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-chocolate-lava-cake",
            ownerId: "creator-aisha",
            title: "Molten Dark Chocolate Lava Cakes",
            description: "Decadent dark chocolate individual cakes with an oozing molten center, served warm with vanilla bean gelato and fresh raspberries.",
            prepTime: "15 min",
            cookTime: "12 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Cake Batter",
                    items: [
                        "100g bittersweet dark chocolate (70% chopped)",
                        "0.5 cup unsalted butter",
                        "2 large whole eggs",
                        "2 egg yolks",
                        "0.25 cup granulated sugar",
                        "1 tsp pure vanilla extract",
                        "2 tbsp all-purpose flour",
                        "0.25 tsp sea salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Serving & Garnish",
                    items: [
                        "1 tbsp cocoa powder (for dusting ramekins)",
                        "1 tbsp powdered sugar (for dusting)",
                        "2 scoops vanilla bean ice cream",
                        "0.5 cup fresh raspberries"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Preheat oven to 425°F (220°C). Butter two 6-ounce ceramic ramekins and dust inside thoroughly with cocoa powder, tapping out excess."),
                DirectionStep(stepIndex: 2, text: "Melt chopped dark chocolate and butter together in a heatproof bowl set over a pot of simmering water until glossy and smooth."),
                DirectionStep(stepIndex: 3, text: "In a separate bowl, whisk whole eggs, egg yolks, sugar, and vanilla vigorously for 2 minutes until pale and slightly frothy."),
                DirectionStep(stepIndex: 4, text: "Gently fold melted chocolate mixture into the egg mixture. Sift in flour and salt, folding just until no flour streaks remain."),
                DirectionStep(stepIndex: 5, text: "Divide batter evenly between prepared ramekins. Bake for 11–12 minutes until cake edges are firm and set, but the center jiggles."),
                DirectionStep(stepIndex: 6, text: "Rest for 1 minute, run a thin butter knife along the rim, and invert onto dessert plates. Dust with powdered sugar and serve warm with vanilla gelato and fresh raspberries.")
            ],
            thumbnailUrl: "recipe_chocolate_lava_cake",
            ownerUsername: "@aishaskitchen",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-korean-bibimbap",
            ownerId: "creator-deveats",
            title: "Sizzling Dolsot Bibimbap",
            description: "Crisp stone-bowl short-grain rice topped with seasoned beef, sautéed spinach, carrots, bean sprouts, shiitake mushrooms, egg, and spicy gochujang.",
            prepTime: "20 min",
            cookTime: "15 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Marinated Bulgogi Beef",
                    items: [
                        "200g ribeye or sirloin beef (thinly sliced)",
                        "1.5 tbsp soy sauce",
                        "1 tbsp brown sugar",
                        "1 tbsp toasted sesame oil",
                        "1 clove garlic (minced)"
                    ]
                ),
                IngredientGroup(
                    groupName: "Vegetable Toppings (Namul)",
                    items: [
                        "2 cups fresh baby spinach (blanched & seasoned with sesame)",
                        "1 cup soybean sprouts (blanched with garlic & salt)",
                        "1 medium carrot (julienned & sautéed)",
                        "4 fresh shiitake mushrooms (sliced & sautéed)",
                        "2 tbsp sesame oil"
                    ]
                ),
                IngredientGroup(
                    groupName: "Base & Sauce",
                    items: [
                        "3 cups cooked warm short-grain white rice",
                        "2 fresh egg yolks",
                        "2 tbsp Korean gochujang chili paste",
                        "1 tbsp warm water",
                        "1 tsp toasted sesame seeds"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Marinate thinly sliced beef with soy sauce, sugar, sesame oil, and garlic for 15 minutes. Stir-fry in a hot skillet for 2–3 minutes until caramelized."),
                DirectionStep(stepIndex: 2, text: "Sauté each vegetable separately with a drop of sesame oil and a pinch of salt to preserve their vibrant distinct colors and textures."),
                DirectionStep(stepIndex: 3, text: "Brush the interior of two heavy stone bowls (or cast iron skillets) with 1 tbsp sesame oil. Pack warm rice into the bottom and heat over medium flame for 5 minutes until rice sizzles and forms a crispy golden crust."),
                DirectionStep(stepIndex: 4, text: "Arrange beef, seasoned spinach, carrots, bean sprouts, and mushrooms neatly in colorful wedges over the rice."),
                DirectionStep(stepIndex: 5, text: "Place an egg yolk in the center of each bowl and sprinkle with sesame seeds."),
                DirectionStep(stepIndex: 6, text: "Mix gochujang with 1 tbsp water and sesame oil. Serve sizzling hot, stirring thoroughly right before eating.")
            ],
            thumbnailUrl: "recipe_korean_bibimbap",
            ownerUsername: "@deveats",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-tikka-masala",
            ownerId: "creator-sanjeev",
            title: "Royal Chicken Tikka Masala",
            description: "Tender tandoori-marinated chicken bites simmered in a luscious spiced tomato, cream, and fenugreek gravy, paired with garlic butter naan.",
            prepTime: "25 min",
            cookTime: "25 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Tandoori Chicken Marinade",
                    items: [
                        "600g boneless chicken breast (cut into bite-sized chunks)",
                        "0.5 cup thick plain Greek yogurt",
                        "1 tbsp ginger-garlic paste",
                        "1 tbsp Kashmiri red chili powder",
                        "1 tsp garam masala",
                        "1 tsp ground cumin",
                        "1 tbsp fresh lemon juice",
                        "1 tsp kosher salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Makhani Masala Sauce",
                    items: [
                        "2 tbsp ghee or butter",
                        "1 large yellow onion (finely diced)",
                        "1 tbsp ginger-garlic paste",
                        "2 cups crushed San Marzano canned tomatoes",
                        "0.5 cup heavy cream",
                        "1 tbsp kasuri methi (dried fenugreek leaves, crushed)",
                        "1 tsp honey or brown sugar",
                        "0.25 cup fresh cilantro (chopped)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Whisk yogurt, ginger-garlic paste, Kashmiri chili, garam masala, cumin, lemon juice, and salt. Coat chicken thoroughly and marinate 30 minutes."),
                DirectionStep(stepIndex: 2, text: "Broil chicken on a wire rack at 450°F (230°C) for 12–15 minutes until tender with charred edges."),
                DirectionStep(stepIndex: 3, text: "Melt ghee in a wide saucepan over medium heat. Sauté diced onions until lightly golden. Add ginger-garlic paste and cook 1 minute."),
                DirectionStep(stepIndex: 4, text: "Add crushed tomatoes, simmer for 10 minutes until oil separates from the masala, then blend until silky smooth."),
                DirectionStep(stepIndex: 5, text: "Return sauce to pan, stir in heavy cream, honey, and crushed kasuri methi. Add charred chicken tikka and simmer gently for 5 minutes."),
                DirectionStep(stepIndex: 6, text: "Garnish with a swirl of cream, ginger matchsticks, and fresh cilantro. Serve with warm garlic butter naan and fragrant basmati rice.")
            ],
            thumbnailUrl: "recipe_tikka_masala",
            ownerUsername: "@Sanjeev.Kapoor",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-garlic-butter-shrimp",
            ownerId: "creator-nada",
            title: "Citrus Garlic Butter Grilled Shrimp Skewers",
            description: "Char-grilled jumbo shrimp brushed with sizzled garlic butter, lemon zest, smoked paprika, and chopped flat-leaf parsley.",
            prepTime: "10 min",
            cookTime: "8 min",
            servings: 3,
            ingredients: [
                IngredientGroup(
                    groupName: "Grilled Shrimp",
                    items: [
                        "500g jumbo shrimp (peeled, deveined, tails on)",
                        "2 tbsp olive oil",
                        "1 tsp smoked paprika",
                        "0.5 tsp garlic powder",
                        "0.5 tsp sea salt & black pepper"
                    ]
                ),
                IngredientGroup(
                    groupName: "Sizzling Garlic Herb Butter",
                    items: [
                        "4 tbsp unsalted butter",
                        "4 cloves garlic (finely minced)",
                        "Zest and juice of 1 fresh lemon",
                        "2 tbsp finely chopped flat-leaf parsley",
                        "0.25 tsp red chili flakes"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Thread jumbo shrimp onto soaked bamboo skewers. Toss with olive oil, smoked paprika, garlic powder, salt, and pepper."),
                DirectionStep(stepIndex: 2, text: "In a small skillet, melt butter over medium-low heat. Sauté minced garlic for 1 minute until fragrant. Remove from heat and stir in lemon zest, lemon juice, parsley, and chili flakes."),
                DirectionStep(stepIndex: 3, text: "Heat grill or cast-iron skillet to high heat until smoking hot."),
                DirectionStep(stepIndex: 4, text: "Grill shrimp skewers for 2–3 minutes per side until pink, opaque, and kissed with char marks."),
                DirectionStep(stepIndex: 5, text: "Brush skewers generously with the warm sizzling garlic herb butter immediately off the heat."),
                DirectionStep(stepIndex: 6, text: "Serve hot with grilled lemon halves and crusty bread for dipping in the pan juices.")
            ],
            thumbnailUrl: "recipe_garlic_butter_shrimp",
            ownerUsername: "@nada_dl",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-summer-rolls",
            ownerId: "creator-priya",
            title: "Fresh Vietnamese Shrimp & Mango Summer Rolls",
            description: "Translucent rice paper wraps filled with plump poached shrimp, crisp cucumber, julienned sweet mango, vermicelli noodles, and fresh mint with peanut hoisin dip.",
            prepTime: "20 min",
            cookTime: "5 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Summer Roll Wraps",
                    items: [
                        "8 round rice paper sheets (banh trang)",
                        "16 cooked jumbo shrimp (peeled, halved lengthwise)",
                        "1 ripe mango (peeled and julienned)",
                        "1 English cucumber (cut into matchsticks)",
                        "100g thin rice vermicelli noodles (cooked and cooled)",
                        "1 cup fresh mint leaves",
                        "1 cup fresh cilantro leaves"
                    ]
                ),
                IngredientGroup(
                    groupName: "Creamy Peanut Hoisin Dip",
                    items: [
                        "0.33 cup creamy peanut butter",
                        "2 tbsp hoisin sauce",
                        "1 tbsp soy sauce",
                        "1 tbsp fresh lime juice",
                        "0.25 cup warm water",
                        "1 tbsp roasted crushed peanuts (for garnish)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Cook vermicelli noodles according to package, rinse in cold water, and drain thoroughly."),
                DirectionStep(stepIndex: 2, text: "Whisk peanut butter, hoisin sauce, soy sauce, lime juice, and warm water together until smooth and creamy. Garnish with crushed peanuts."),
                DirectionStep(stepIndex: 3, text: "Dip one rice paper sheet into a shallow bowl of warm water for 5 seconds until pliable. Lay flat on a clean cutting board."),
                DirectionStep(stepIndex: 4, text: "Layer fresh mint, cilantro, cucumber, mango, and a small nest of vermicelli across the bottom third of the sheet."),
                DirectionStep(stepIndex: 5, text: "Place 3–4 shrimp halves cut-side-down in a row above the filling so they show through the translucent wrapper."),
                DirectionStep(stepIndex: 6, text: "Fold the bottom edge over the filling, tuck in both sides tightly, and roll forward snugly. Slice diagonally and serve with peanut dip.")
            ],
            thumbnailUrl: "recipe_summer_rolls",
            ownerUsername: "@priyacooks",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-margherita-pizza",
            ownerId: "creator-kristy",
            title: "Artisan Neapolitan Margherita Pizza",
            description: "Wood-fired style airy fermented crust topped with crushed San Marzano tomatoes, torn fresh mozzarella fior di latte, and aromatic basil leaves.",
            prepTime: "20 min",
            cookTime: "10 min",
            servings: 3,
            ingredients: [
                IngredientGroup(
                    groupName: "Dough & Sauce",
                    items: [
                        "1 artisan pizza dough ball (300g, fermented)",
                        "0.75 cup crushed San Marzano canned tomatoes",
                        "1 tbsp extra virgin olive oil",
                        "0.5 tsp sea salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Cheese & Fresh Toppings",
                    items: [
                        "150g fresh mozzarella fior di latte (torn into pieces & drained)",
                        "8 fresh sweet basil leaves",
                        "1 tbsp freshly grated parmigiano reggiano",
                        "1 tbsp extra virgin olive oil (for drizzling)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Preheat oven with a pizza stone or heavy steel at 500°F (260°C) for at least 45 minutes."),
                DirectionStep(stepIndex: 2, text: "Crush San Marzano tomatoes by hand with olive oil and sea salt. Tear mozzarella and drain on paper towels to remove excess moisture."),
                DirectionStep(stepIndex: 3, text: "Stretch pizza dough on a floured surface by pressing from the center outward, leaving an airy 1-inch raised cornicione rim."),
                DirectionStep(stepIndex: 4, text: "Spread crushed tomato sauce gently over the base, leaving the crust bare. Scatter torn fresh mozzarella evenly."),
                DirectionStep(stepIndex: 5, text: "Slide onto the blazing hot pizza stone. Bake for 8–10 minutes until the crust is blistered with charred spots and cheese is bubbling."),
                DirectionStep(stepIndex: 6, text: "Finish immediately with fresh basil leaves, grated parmigiano reggiano, and a drizzle of extra virgin olive oil.")
            ],
            thumbnailUrl: "recipe_margherita_pizza",
            ownerUsername: "@Kristy.Graver",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-beef-udon",
            ownerId: "creator-deveats",
            title: "Savory Beef Udon Noodle Bowl",
            description: "Thick chewy udon noodles in a dashi broth topped with tender thinly sliced simmered beef, caramelized sweet leeks, and soft-poached egg.",
            prepTime: "10 min",
            cookTime: "12 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Simmered Sweet Beef",
                    items: [
                        "200g thinly sliced beef chuck or ribeye",
                        "1 large leek or scallion (sliced diagonally into 2-inch batons)",
                        "1 tbsp soy sauce",
                        "1 tbsp mirin",
                        "1 tbsp sake or rice wine",
                        "1 tsp brown sugar"
                    ]
                ),
                IngredientGroup(
                    groupName: "Noodles & Dashi Broth",
                    items: [
                        "2 packs fresh or frozen Sanuki udon noodles (400g)",
                        "3 cups Japanese dashi broth",
                        "2 tbsp light soy sauce",
                        "1 tbsp mirin",
                        "2 soft-poached eggs (onsen tamago)",
                        "1 tbsp sliced scallions & togarashi for garnish"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "In a skillet, combine 1 tbsp soy sauce, 1 tbsp mirin, sake, sugar, and sliced leeks. Simmer over medium heat for 3 minutes until leeks soften."),
                DirectionStep(stepIndex: 2, text: "Add thinly sliced beef, simmering for 2–3 minutes until just cooked through and glossy. Set aside."),
                DirectionStep(stepIndex: 3, text: "In a soup pot, bring dashi broth, light soy sauce, and 1 tbsp mirin to a simmer."),
                DirectionStep(stepIndex: 4, text: "Boil udon noodles in water for 1 minute until chewy and plump. Drain thoroughly and divide between two large noodle bowls."),
                DirectionStep(stepIndex: 5, text: "Ladle piping hot dashi broth over the noodles."),
                DirectionStep(stepIndex: 6, text: "Crown with the simmered sweet beef and leeks, a soft-poached egg, fresh sliced scallions, and a dusting of Japanese togarashi pepper.")
            ],
            thumbnailUrl: "recipe_beef_udon",
            ownerUsername: "@deveats",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-acai-bowl",
            ownerId: "creator-aisha",
            title: "Tropical Brazilian Açaí Power Bowl",
            description: "Thick frozen organic açaí berry blend crowned with sliced bananas, strawberries, crunchy golden granola, chia seeds, and raw honeycomb.",
            prepTime: "10 min",
            cookTime: "0 min",
            servings: 2,
            ingredients: [
                IngredientGroup(
                    groupName: "Thick Açaí Base",
                    items: [
                        "200g frozen unsweetened açaí puree packets",
                        "1 frozen ripe banana",
                        "0.5 cup frozen mixed berries",
                        "0.33 cup unsweetened almond milk",
                        "1 tbsp pure maple syrup"
                    ]
                ),
                IngredientGroup(
                    groupName: "Fresh Superfood Toppings",
                    items: [
                        "1 fresh banana (sliced)",
                        "0.5 cup fresh ripe strawberries (halved)",
                        "0.5 cup toasted almond granola",
                        "1 tbsp black chia seeds",
                        "1 tbsp unsweetened toasted coconut flakes",
                        "1 tbsp raw honeycomb or honey drizzle"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Break frozen açaí packets into pieces and place in a high-powered blender along with frozen banana, frozen berries, maple syrup, and almond milk."),
                DirectionStep(stepIndex: 2, text: "Blend on low speed, using the tamper to push ingredients into blades, until thick like soft-serve gelato (add almond milk only 1 tbsp at a time if needed)."),
                DirectionStep(stepIndex: 3, text: "Spoon the vibrant purple smoothie base into two chilled bowls, smoothing the surface with a spoon."),
                DirectionStep(stepIndex: 4, text: "Arrange sliced fresh banana, halved strawberries, and crunchy granola in neat rows across the top."),
                DirectionStep(stepIndex: 5, text: "Scatter chia seeds and toasted coconut flakes over the fruit."),
                DirectionStep(stepIndex: 6, text: "Drizzle with raw honeycomb or honey and serve immediately with spoons.")
            ],
            thumbnailUrl: "recipe_acai_bowl",
            ownerUsername: "@aishaskitchen",
            sourceLanguage: "en",
            nutrition: nil
        ),
        Recipe(
            id: "recipe-classic-tiramisu",
            ownerId: "creator-kristy",
            title: "Authentic Venetian Espresso Tiramisu",
            description: "Espresso-dipped savoiardi ladyfingers layered with airy whipped mascarpone cream, dark chocolate shavings, and dusted with Dutch cocoa.",
            prepTime: "25 min",
            cookTime: "0 min",
            servings: 6,
            ingredients: [
                IngredientGroup(
                    groupName: "Espresso Soak",
                    items: [
                        "1.5 cups freshly brewed strong espresso (cooled)",
                        "2 tbsp dark rum or amaretto (optional)",
                        "1 tbsp sugar"
                    ]
                ),
                IngredientGroup(
                    groupName: "Whipped Mascarpone Cream",
                    items: [
                        "4 large egg yolks",
                        "0.5 cup granulated sugar",
                        "450g Italian mascarpone cheese (room temperature)",
                        "1 cup heavy whipping cream (chilled)",
                        "1 tsp pure vanilla extract"
                    ]
                ),
                IngredientGroup(
                    groupName: "Assembly & Dusting",
                    items: [
                        "24 crisp Italian savoiardi ladyfingers",
                        "3 tbsp Dutch-process unsweetened cocoa powder",
                        "50g dark chocolate shavings"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "In a heatproof glass bowl over a pot of simmering water, whisk egg yolks and sugar for 5 minutes until pale, thick, and sugar has dissolved. Remove from heat and let cool."),
                DirectionStep(stepIndex: 2, text: "Gently fold room-temperature mascarpone into the yolk mixture until silky and combined."),
                DirectionStep(stepIndex: 3, text: "In a cold bowl, whip heavy cream and vanilla extract to medium-stiff peaks. Gently fold whipped cream into mascarpone mixture in two additions."),
                DirectionStep(stepIndex: 4, text: "Mix cooled espresso, rum, and sugar in a shallow dish. Quickly dip each ladyfinger for 1–2 seconds per side (do not soak)."),
                DirectionStep(stepIndex: 5, text: "Arrange a single layer of dipped ladyfingers in an 8x8 baking dish. Spread half of the mascarpone cream smoothly on top, followed by dark chocolate shavings."),
                DirectionStep(stepIndex: 6, text: "Repeat with a second layer of dipped ladyfingers and the remaining cream. Dust generously with unsweetened cocoa powder through a fine sieve, and chill for at least 4 hours (or overnight) before slicing.")
            ],
            thumbnailUrl: "recipe_classic_tiramisu",
            ownerUsername: "@Kristy.Graver",
            sourceLanguage: "en",
            nutrition: nil
        )

    ]
}
