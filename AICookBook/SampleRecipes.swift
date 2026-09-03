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
    ]
}
