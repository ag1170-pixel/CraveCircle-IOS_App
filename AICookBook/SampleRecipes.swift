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
                DirectionStep(stepIndex: 1, text: "Whisk marinade. Combine buttermilk, smoked paprika, garlic powder, onion powder, cayenne, and salt in a large bowl."),
                DirectionStep(stepIndex: 2, text: "Marinate chicken. Submerge chicken thighs in the marinade, cover, and chill for at least 30 minutes."),
                DirectionStep(stepIndex: 3, text: "Prepare crispy dredge. Whisk flour, cornstarch, baking powder, and cajun seasoning in a wide shallow dish. Drizzle in 2 tbsp buttermilk marinade to create shaggy flakes."),
                DirectionStep(stepIndex: 4, text: "Dredge & rest. Press each chicken thigh firmly into the flour mixture on all sides. Rest on a plate for 5 minutes."),
                DirectionStep(stepIndex: 5, text: "Heat frying oil. Pour oil into a heavy pot and heat to 350°F (175°C)."),
                DirectionStep(stepIndex: 6, text: "Fry in batches. Cook chicken for 6–8 minutes until deeply golden brown and crispy with an internal temp of 165°F (74°C). Drain on a wire rack."),
                DirectionStep(stepIndex: 7, text: "Simmer hot honey glaze. Warm honey, butter, hot sauce, red pepper flakes, and cider vinegar in a saucepan until bubbling, then brush generously over hot chicken."),
                DirectionStep(stepIndex: 8, text: "Assemble burgers. Toss cabbage with mayo and pickle juice. Layer toasted bottom brioche, pickles, glazed crispy chicken, crunchy slaw, and top bun.")
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
        ),
        Recipe(
            id: "recipe-hyderabadi-dum-biryani",
            ownerId: "creator-sanjeev",
            title: "Royal Hyderabadi Dum Biryani",
            description: "Fragrant aged basmati rice layered with tender spiced marinated chicken, saffron-infused milk, caramelized fried onions (birista), and fresh mint, sealed and slow-cooked on dum.",
            prepTime: "40 min",
            cookTime: "45 min",
            servings: 6,
            ingredients: [
                IngredientGroup(
                    groupName: "Chicken Dum Marinade",
                    items: [
                        "800g bone-in chicken thighs & drumsticks",
                        "1 cup thick Greek yogurt (hung curd)",
                        "2 tbsp ginger-garlic paste",
                        "1 tbsp Kashmiri red chili powder",
                        "1 tsp turmeric powder",
                        "1.5 tsp shahi biryani masala",
                        "1 tsp toasted cumin powder",
                        "2 tbsp fresh lemon juice",
                        "0.5 cup chopped fresh mint leaves",
                        "0.5 cup chopped fresh cilantro",
                        "1.5 tsp kosher salt",
                        "2 tbsp mustard oil or ghee"
                    ]
                ),
                IngredientGroup(
                    groupName: "Aromatic Basmati Rice",
                    items: [
                        "2.5 cups aged long-grain basmati rice (washed & soaked 30 mins)",
                        "6 cups water",
                        "2 black cardamoms",
                        "4 green cardamoms",
                        "1-inch cinnamon stick",
                        "1 star anise",
                        "3 whole cloves",
                        "2 dried bay leaves",
                        "1 tbsp salt",
                        "1 tbsp ghee"
                    ]
                ),
                IngredientGroup(
                    groupName: "Dum Layering & Garnish",
                    items: [
                        "1 cup crispy fried onions (birista)",
                        "0.25 cup warm whole milk",
                        "1 generous pinch saffron strands",
                        "2 tbsp melted desi ghee",
                        "1 tsp kewra water or rose water",
                        "0.25 cup roasted cashew nuts",
                        "2 hard-boiled eggs (halved)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "In a heavy-bottomed pot or handi, combine chicken with yogurt, ginger-garlic paste, chili powder, turmeric, biryani masala, cumin, lemon juice, mint, cilantro, salt, and mustard oil. Marinate for at least 1 hour (or overnight in the fridge)."),
                DirectionStep(stepIndex: 2, text: "Infuse saffron strands in warm milk for 15 minutes until rich golden yellow."),
                DirectionStep(stepIndex: 3, text: "Bring 6 cups of water to a rolling boil with whole spices, salt, and ghee. Add soaked basmati rice and boil on high heat until 70% cooked (about 5–6 minutes; grains should snap when pressed). Drain immediately."),
                DirectionStep(stepIndex: 4, text: "Over the marinated chicken layer in the handi, spread half the drained rice. Top with half the fried onions, chopped mint, cilantro, and roasted cashews."),
                DirectionStep(stepIndex: 5, text: "Spread remaining rice on top. Drizzle saffron milk, melted desi ghee, and kewra water evenly over the surface. Finish with remaining birista, mint, and boiled egg halves."),
                DirectionStep(stepIndex: 6, text: "Cover tightly with aluminum foil and seal with the pot lid. Cook on medium-high heat for 10 minutes, then place the handi over a heavy flat tawa on low heat for 30 minutes on dum. Rest for 10 minutes, then gently fluff layers from the bottom and serve hot with chilled burani raita.")
            ],
            thumbnailUrl: "recipe_biryani",
            ownerUsername: "@Sanjeev.Kapoor",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 640,
                carbsG: 68,
                proteinG: 38,
                fatG: 22,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-dal-makhani",
            ownerId: "creator-sanjeev",
            title: "Creamy Restaurant Dal Makhani",
            description: "Traditional slow-cooked black urad lentils and kidney beans simmered overnight with butter, ripe tomatoes, ginger, and finished with fresh cream and kasuri methi.",
            prepTime: "20 min",
            cookTime: "1 hr 30 min",
            servings: 5,
            ingredients: [
                IngredientGroup(
                    groupName: "Lentil Base",
                    items: [
                        "1 cup whole black urad dal (soaked overnight)",
                        "0.25 cup rajma (red kidney beans, soaked overnight)",
                        "5 cups water",
                        "1 tsp salt",
                        "1 black cardamom pod"
                    ]
                ),
                IngredientGroup(
                    groupName: "Makhani Gravy & Tempering",
                    items: [
                        "4 tbsp salted white butter (makhan)",
                        "2 tbsp neutral cooking oil",
                        "1.5 cups fresh tomato puree",
                        "1.5 tbsp ginger-garlic paste",
                        "1.5 tbsp degi mirch (Kashmiri chili powder)",
                        "0.5 tsp garam masala",
                        "0.5 cup heavy whipping cream",
                        "1 tbsp crushed kasuri methi (dry fenugreek leaves)",
                        "1 tbsp butter for finishing"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Rinse soaked black lentils and rajma thoroughly. Pressure cook with 5 cups water, salt, and black cardamom for 18–20 minutes (or 5–6 whistles) until exceptionally soft."),
                DirectionStep(stepIndex: 2, text: "Using the back of a ladle or potato masher, gently mash a portion of the cooked lentils to release natural starch and create body."),
                DirectionStep(stepIndex: 3, text: "Heat 2 tbsp butter and 2 tbsp oil in a heavy pot. Add ginger-garlic paste and sauté on medium heat for 2 minutes until aromatic."),
                DirectionStep(stepIndex: 4, text: "Add Kashmiri chili powder followed immediately by fresh tomato puree. Cook on medium-low heat for 12–15 minutes until oil separates from the edges."),
                DirectionStep(stepIndex: 5, text: "Pour in boiled lentils along with their cooking liquor. Add 1 cup warm water, mix well, and simmer on the lowest heat for 45–60 minutes, stirring frequently to prevent sticking."),
                DirectionStep(stepIndex: 6, text: "Stir in remaining butter, fresh heavy cream, crushed kasuri methi, and garam masala. Simmer for another 5 minutes until velvety, rich, and dark brown. Serve hot with garlic butter naan.")
            ],
            thumbnailUrl: "recipe_dal_makhani",
            ownerUsername: "@Sanjeev.Kapoor",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 380,
                carbsG: 42,
                proteinG: 16,
                fatG: 18,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-crispy-masala-dosa",
            ownerId: "creator-priya",
            title: "Crispy South Indian Masala Dosa",
            description: "Golden paper-thin fermented rice and lentil crepe smeared with roasted red chutney, stuffed with spiced potato masala, and paired with piping hot drumstick sambar and fresh coconut chutney.",
            prepTime: "30 min",
            cookTime: "25 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Fermented Dosa Batter",
                    items: [
                        "3 cups idli/dosa parboiled rice",
                        "1 cup whole white urad dal",
                        "1 tsp fenugreek seeds (methi)",
                        "2 tbsp chana dal",
                        "1.5 tsp salt",
                        "Water as needed for grinding & fermentation",
                        "Ghee or oil for roasting"
                    ]
                ),
                IngredientGroup(
                    groupName: "Spiced Potato Masala Filling",
                    items: [
                        "4 large yellow potatoes (boiled, peeled & roughly mashed)",
                        "1 large onion (thinly sliced)",
                        "2 green chilies (chopped)",
                        "1 tsp grated fresh ginger",
                        "1 tsp mustard seeds",
                        "1 tsp urad dal",
                        "1 sprig fresh curry leaves",
                        "0.5 tsp turmeric powder",
                        "1 pinch asafoetida (hing)",
                        "2 tbsp chopped fresh cilantro",
                        "1 tbsp coconut oil"
                    ]
                ),
                IngredientGroup(
                    groupName: "Serving Accompaniments",
                    items: [
                        "1 cup fresh coconut chutney",
                        "1.5 cups hot vegetable sambar",
                        "3 tbsp spicy red chili-garlic chutney"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Heat coconut oil in a pan. Splutter mustard seeds, urad dal, curry leaves, and green chilies. Add sliced onions and ginger; sauté until soft and translucent."),
                DirectionStep(stepIndex: 2, text: "Add turmeric, hing, and salt. Stir in mashed potatoes with 3 tbsp water to maintain moisture. Simmer for 3 minutes, finish with chopped cilantro, and set aside."),
                DirectionStep(stepIndex: 3, text: "Heat a seasoned cast-iron or non-stick tawa over medium-high heat. Splash cold water and wipe down with a paper towel."),
                DirectionStep(stepIndex: 4, text: "Pour a large ladleful of fermented dosa batter into the center. Using circular spiral motions from the center outward, spread thinly into a round crepe."),
                DirectionStep(stepIndex: 5, text: "Drizzle 1 tsp ghee around the edges and over the surface. Cook on medium heat until the base turns deep golden and crisp."),
                DirectionStep(stepIndex: 6, text: "Spread 1 tsp red chutney over the center, spoon in warm potato masala, fold both sides neatly into a cylinder, and slide onto a banana leaf. Serve immediately with sambar and coconut chutney.")
            ],
            thumbnailUrl: "recipe_masala_dosa",
            ownerUsername: "@priyacooks",
            sourceLanguage: "ta",
            nutrition: RecipeNutrition(
                calories: 340,
                carbsG: 58,
                proteinG: 9,
                fatG: 9,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-punjabi-palak-paneer",
            ownerId: "creator-aditya",
            title: "Dhaba Style Palak Paneer",
            description: "Fresh tender paneer cubes nestled in a vibrant nutrient-rich spinach gravy lightly spiced with cumin, garlic, and green chilies, finished with a touch of dairy cream.",
            prepTime: "20 min",
            cookTime: "20 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Spinach Blanch & Puree",
                    items: [
                        "500g fresh baby spinach leaves (palak)",
                        "4 cups boiling water",
                        "1 bowl ice water bath (for shock blanching)",
                        "2 green chilies",
                        "1-inch ginger piece"
                    ]
                ),
                IngredientGroup(
                    groupName: "Paneer & Tadka Gravy",
                    items: [
                        "250g fresh paneer (cut into 1-inch cubes)",
                        "2 tbsp desi ghee",
                        "1 tbsp butter",
                        "1 tsp cumin seeds (jeera)",
                        "1 medium red onion (finely chopped)",
                        "1 tbsp minced garlic",
                        "1 medium tomato (finely chopped)",
                        "1 tsp coriander powder",
                        "0.5 tsp garam masala",
                        "1 tsp salt",
                        "2 tbsp fresh heavy cream",
                        "1 pinch kasuri methi"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Plunge cleaned spinach into boiling water for 90 seconds. Transfer immediately to an ice water bath to preserve the vivid emerald green hue."),
                DirectionStep(stepIndex: 2, text: "Drain cooled spinach and blend in a mixer jar with green chilies and ginger to a smooth, velvety puree."),
                DirectionStep(stepIndex: 3, text: "In a pan, melt 1 tbsp ghee and lightly sear paneer cubes for 1 minute until golden at the edges; soak in warm salted water to keep ultra-soft."),
                DirectionStep(stepIndex: 4, text: "Heat remaining ghee and butter in a kadai. Add cumin seeds and minced garlic; sauté until golden and fragrant."),
                DirectionStep(stepIndex: 5, text: "Add chopped onions and sauté until golden brown. Stir in chopped tomatoes, coriander powder, and salt; cook until soft and oil leaves the sides."),
                DirectionStep(stepIndex: 6, text: "Pour in spinach puree and simmer gently for 4–5 minutes on low heat. Stir in paneer cubes, garam masala, and crushed kasuri methi. Swirl in heavy cream and serve with warm rotis or naan.")
            ],
            thumbnailUrl: "recipe_palak_paneer",
            ownerUsername: "@Aditya.Gupta",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 320,
                carbsG: 12,
                proteinG: 18,
                fatG: 23,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-amritsari-chole-bhature",
            ownerId: "creator-deveats",
            title: "Amritsari Chole with Fluffy Bhature",
            description: "Dark, tangy, tea-infused Amritsari chickpea curry cooked with roasted anardana spices, accompanied by giant balloon-puffed golden bhature, pickled red onions, and fried green chilies.",
            prepTime: "25 min",
            cookTime: "40 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Tea-Spiced Chole",
                    items: [
                        "1.5 cups dried kabuli chickpeas (soaked 8 hours)",
                        "2 black tea bags (for authentic dark color)",
                        "1 black cardamom",
                        "1-inch cinnamon stick",
                        "1 bay leaf",
                        "1 tsp baking soda",
                        "1.5 tsp salt",
                        "4 cups water"
                    ]
                ),
                IngredientGroup(
                    groupName: "Chole Masala & Gravy",
                    items: [
                        "3 tbsp ghee or mustard oil",
                        "1.5 tbsp dried pomegranate seed powder (anardana)",
                        "1 tbsp coriander powder",
                        "1 tsp roasted cumin powder",
                        "1 tsp amchur (dry mango powder)",
                        "1 tsp red chili powder",
                        "1 tbsp ginger juliennes",
                        "2 green chilies (slit)",
                        "1 medium tomato (finely pureed)"
                    ]
                ),
                IngredientGroup(
                    groupName: "Balloon Bhature Dough",
                    items: [
                        "2 cups all-purpose flour (maida)",
                        "0.25 cup fine semolina (sooji)",
                        "0.25 cup thick yogurt",
                        "0.5 tsp baking powder",
                        "0.25 tsp baking soda",
                        "1 tsp sugar",
                        "0.5 tsp salt",
                        "Warm water for kneading",
                        "Oil for deep frying"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Combine flour, semolina, baking powder, baking soda, sugar, salt, and yogurt. Knead with warm water into a soft elastic dough. Smear with oil and rest covered with a damp cloth for 2 hours."),
                DirectionStep(stepIndex: 2, text: "Pressure cook chickpeas with tea bags, baking soda, whole spices, salt, and water for 6–7 whistles until melt-in-mouth tender. Discard tea bags."),
                DirectionStep(stepIndex: 3, text: "In a pan, heat ghee. Add tomato puree, anardana, coriander powder, cumin, amchur, and chili powder. Cook until fragrant and ghee separates."),
                DirectionStep(stepIndex: 4, text: "Add boiled chickpeas with cooking water. Mash a few chickpeas to thicken gravy and simmer for 15 minutes. Finish with ginger juliennes and slit green chilies."),
                DirectionStep(stepIndex: 5, text: "Heat deep frying oil in a kadai until smoking hot. Roll out portions of dough into smooth oval disks."),
                DirectionStep(stepIndex: 6, text: "Gently slide bhatura into hot oil; press lightly with a slotted spoon so it puffs into a full golden balloon. Flip for 15 seconds, drain, and serve immediately with hot chole and pickled onions.")
            ],
            thumbnailUrl: "recipe_chole_bhature",
            ownerUsername: "@deveats",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 580,
                carbsG: 78,
                proteinG: 19,
                fatG: 22,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-kashmiri-rogan-josh",
            ownerId: "creator-sanjeev",
            title: "Royal Kashmiri Rogan Josh",
            description: "Slow-braised tender lamb pieces steeped in an intensely aromatic crimson gravy flavored with Kashmiri red chilies, mawal (cockscomb flower/ratanjot), fennel powder, and dry ginger.",
            prepTime: "25 min",
            cookTime: "1 hr 15 min",
            servings: 5,
            ingredients: [
                IngredientGroup(
                    groupName: "Lamb & Whole Spices",
                    items: [
                        "800g bone-in tender lamb curry cut pieces",
                        "4 tbsp mustard oil (heated to smoking & cooled slightly)",
                        "2 black cardamoms",
                        "4 green cardamoms",
                        "4 whole cloves",
                        "1-inch cinnamon stick",
                        "2 bay leaves",
                        "1 tsp cumin seeds",
                        "1 pinch asafoetida (hing)"
                    ]
                ),
                IngredientGroup(
                    groupName: "Kashmiri Aromatic Gravy",
                    items: [
                        "1 cup thick yogurt (whisked smooth)",
                        "2 tbsp Kashmiri dry red chili powder (soaked in 3 tbsp warm water)",
                        "1.5 tbsp fennel seed powder (saunf)",
                        "1 tbsp dry ginger powder (sonth)",
                        "1 tsp shahi jeera",
                        "0.5 tsp ground nutmeg & mace (jaiphal-javitri)",
                        "1.5 tsp salt",
                        "2 cups warm water"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Heat mustard oil in a heavy-bottomed dutch oven until smoking point, then reduce flame to let it cool slightly."),
                DirectionStep(stepIndex: 2, text: "Add hing, cumin seeds, bay leaves, cinnamon, black cardamoms, green cardamoms, and cloves. Allow whole spices to sizzle for 30 seconds."),
                DirectionStep(stepIndex: 3, text: "Add lamb pieces and sear on high heat for 8–10 minutes until meat is lightly browned on all sides."),
                DirectionStep(stepIndex: 4, text: "Lower heat and pour in soaked Kashmiri red chili paste. Sauté continuously for 3 minutes until oil turns deep vibrant ruby red."),
                DirectionStep(stepIndex: 5, text: "Turn heat to lowest setting and gradually stir in whisked yogurt, whisking constantly to prevent curdling. Add fennel powder, dry ginger powder, and salt."),
                DirectionStep(stepIndex: 6, text: "Pour in 2 cups warm water, cover with a tight lid, and simmer on gentle low heat for 55–60 minutes until lamb is fork-tender and rich rogan (spiced oil) floats on top. Sprinkle nutmeg-mace powder and serve with steamed basmati rice.")
            ],
            thumbnailUrl: "recipe_rogan_josh",
            ownerUsername: "@Sanjeev.Kapoor",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 520,
                carbsG: 8,
                proteinG: 42,
                fatG: 36,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-delhi-samosa-chaat",
            ownerId: "creator-deveats",
            title: "Crispy Delhi Street Samosa Chaat",
            description: "Crushed golden spiced potato samosas loaded with warm tangy chickpea curry, chilled whipped yogurt, sweet tamarind-jaggery chutney, spicy mint chutney, crunchy nylon sev, and pomegranate.",
            prepTime: "20 min",
            cookTime: "15 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Crispy Samosa Base",
                    items: [
                        "4 large fresh golden potato-pea samosas (warm & crispy)",
                        "1.5 cups warm spiced chickpea curry (ragda or chole)"
                    ]
                ),
                IngredientGroup(
                    groupName: "Chutneys & Sauces",
                    items: [
                        "0.75 cup thick sweet yogurt (whisked with 1 tsp sugar)",
                        "0.5 cup tangy tamarind-date chutney (saunth)",
                        "0.5 cup spicy mint-coriander green chutney"
                    ]
                ),
                IngredientGroup(
                    groupName: "Chaat Toppings & Spices",
                    items: [
                        "0.5 cup crispy nylon sev",
                        "0.25 cup ruby fresh pomegranate arils",
                        "1 small red onion (finely diced)",
                        "1 tbsp chopped fresh cilantro",
                        "1 tsp chaat masala",
                        "0.5 tsp roasted cumin powder",
                        "0.5 tsp black salt (kala namak)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Place 1 fresh warm samosa in each serving bowl and gently break open into 3–4 large bite-sized chunks."),
                DirectionStep(stepIndex: 2, text: "Ladle generous spoonfuls of hot spiced chickpea curry directly over the crushed samosas."),
                DirectionStep(stepIndex: 3, text: "Drizzle liberally with chilled sweetened yogurt, covering the samosa chunks evenly."),
                DirectionStep(stepIndex: 4, text: "Drizzle glossy tamarind-date chutney and vibrant mint-coriander green chutney in decorative swirls."),
                DirectionStep(stepIndex: 5, text: "Dust lightly with chaat masala, roasted cumin powder, and black salt."),
                DirectionStep(stepIndex: 6, text: "Scatter finely diced red onions, crispy nylon sev, fresh cilantro, and sweet pomegranate arils on top. Serve immediately while crunchy and warm.")
            ],
            thumbnailUrl: "recipe_samosa_chaat",
            ownerUsername: "@deveats",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 410,
                carbsG: 62,
                proteinG: 11,
                fatG: 15,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-mumbai-pav-bhaji",
            ownerId: "creator-aditya",
            title: "Buttery Mumbai Chowpatty Pav Bhaji",
            description: "Spicy mashed vegetable medley slow-simmered on a giant tawa with Mumbai pav bhaji masala and lavish golden butter, served with toasted fluffy pav rolls, red onion salad, and lemon.",
            prepTime: "25 min",
            cookTime: "30 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Steamed Vegetable Medley",
                    items: [
                        "3 medium russet potatoes (peeled & cubed)",
                        "1.5 cups cauliflower florets",
                        "1 cup green peas (fresh or frozen)",
                        "0.5 cup red beetroot (steamed for natural deep red color)",
                        "1 cup water",
                        "1 tsp salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Tawa Masala & Tempering",
                    items: [
                        "5 tbsp salted Amul butter",
                        "1 tbsp vegetable oil",
                        "1 large red onion (finely chopped)",
                        "1.5 tbsp ginger-garlic paste",
                        "1 large green bell pepper (finely diced)",
                        "3 ripe red tomatoes (finely chopped)",
                        "2 tbsp authentic Mumbai pav bhaji masala",
                        "1 tbsp Kashmiri red chili powder",
                        "1 tsp kasuri methi",
                        "0.25 cup chopped fresh cilantro",
                        "1 lemon (cut into wedges)"
                    ]
                ),
                IngredientGroup(
                    groupName: "Butter-Toasted Pav",
                    items: [
                        "8 fresh soft ladi pav rolls",
                        "3 tbsp salted butter",
                        "0.5 tsp pav bhaji masala (for dusting pav)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Pressure cook potatoes, cauliflower, peas, and beetroot with 1 cup water and salt for 3 whistles until soft. Mash completely using a potato masher into a coarse puree."),
                DirectionStep(stepIndex: 2, text: "In a wide skillet or flat tawa, melt 3 tbsp butter with 1 tbsp oil. Add chopped onions and sauté for 3 minutes until translucent."),
                DirectionStep(stepIndex: 3, text: "Add ginger-garlic paste and finely diced bell peppers. Sauté on medium heat for 3 minutes until peppers are tender."),
                DirectionStep(stepIndex: 4, text: "Add tomatoes, pav bhaji masala, Kashmiri chili powder, and salt. Cook until tomatoes breakdown and butter glistens at the edges."),
                DirectionStep(stepIndex: 5, text: "Pour in mashed vegetables with 0.75 cup water. Mash vigorously on the tawa for 10 minutes while simmering until glossy and thick. Finish with crushed kasuri methi and fresh cilantro."),
                DirectionStep(stepIndex: 6, text: "Slit pav rolls horizontally. Melt butter on the hot tawa, sprinkle a pinch of pav bhaji masala and cilantro, and toast pav until golden and crisp. Serve piping hot bhaji topped with an extra slab of butter and lemon wedges.")
            ],
            thumbnailUrl: "recipe_pav_bhaji",
            ownerUsername: "@Aditya.Gupta",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 460,
                carbsG: 64,
                proteinG: 12,
                fatG: 19,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-shahi-gulab-jamun",
            ownerId: "creator-priya",
            title: "Royal Cardamom Rose Gulab Jamun",
            description: "Soft melt-in-the-mouth fried dumplings crafted from fresh mawa and chenna, soaked deep in fragrant saffron, green cardamom, and rose water sugar syrup, topped with silver vark and pistachios.",
            prepTime: "25 min",
            cookTime: "20 min",
            servings: 6,
            ingredients: [
                IngredientGroup(
                    groupName: "Jamun Dough",
                    items: [
                        "1 cup soft khoya/mawa (crumbled)",
                        "0.25 cup fresh paneer/chenna (finely grated)",
                        "3 tbsp all-purpose flour (maida)",
                        "1 tbsp fine semolina (sooji)",
                        "0.25 tsp baking powder",
                        "1 tbsp milk (if needed for binding)",
                        "Ghee or neutral oil for deep frying"
                    ]
                ),
                IngredientGroup(
                    groupName: "Aromatic Rose Saffron Syrup",
                    items: [
                        "2 cups granulated sugar",
                        "2 cups water",
                        "5 green cardamom pods (lightly crushed)",
                        "1 generous pinch saffron strands (kesar)",
                        "1 tsp rose water",
                        "1 tsp lemon juice (prevents crystallization)"
                    ]
                ),
                IngredientGroup(
                    groupName: "Royal Garnish",
                    items: [
                        "2 tbsp slivered emerald pistachios",
                        "1 tbsp dried edible rose petals",
                        "Edible silver foil (chandi vark, optional)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "In a saucepan, bring sugar, water, and crushed cardamom to a gentle boil for 6–8 minutes until a light sticky half-string syrup forms. Turn off heat, stir in saffron, rose water, and lemon juice; keep warm."),
                DirectionStep(stepIndex: 2, text: "In a wide plate, knead khoya and grated paneer thoroughly with the heel of your palm for 5 minutes until completely smooth with zero lumps."),
                DirectionStep(stepIndex: 3, text: "Add all-purpose flour, semolina, and baking powder. Gently bring together into a soft, pliable, crack-free dough without over-kneading."),
                DirectionStep(stepIndex: 4, text: "Divide dough into smooth, seamless bite-sized balls (about 18–20 pieces). Ensure surfaces are completely smooth to prevent cracking during frying."),
                DirectionStep(stepIndex: 5, text: "Heat ghee in a deep kadai over low heat (140°C / 285°F). Slide jamuns in and fry on gentle low heat, gently swirling oil without touching the balls, for 10–12 minutes until evenly deep golden brown."),
                DirectionStep(stepIndex: 6, text: "Drain hot fried jamuns and transfer directly into warm sugar syrup. Allow them to soak for at least 2 hours to expand and absorb sweetness. Garnish with slivered pistachios and silver vark before serving warm.")
            ],
            thumbnailUrl: "recipe_gulab_jamun",
            ownerUsername: "@priyacooks",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 310,
                carbsG: 52,
                proteinG: 6,
                fatG: 10,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-kerala-meen-curry",
            ownerId: "creator-priya",
            title: "Kerala Clay-Pot Fish Curry (Meen Chatti)",
            description: "Tangy fiery coastal Kerala fish curry simmered with kingfish steaks, smoky Malabar tamarind (Kudampuli), red shallots, and freshly pressed coconut milk in an authentic clay pot.",
            prepTime: "20 min",
            cookTime: "25 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Fish & Tamarind Prep",
                    items: [
                        "500g fresh Kingfish (Surmai) or Seer fish steaks",
                        "3 pieces Kudampuli (Malabar tamarind, soaked in 0.5 cup warm water)",
                        "0.5 tsp turmeric powder",
                        "1 tsp salt"
                    ]
                ),
                IngredientGroup(
                    groupName: "Coconut Curry Base & Aromatics",
                    items: [
                        "3 tbsp pure virgin coconut oil",
                        "1 tsp brown mustard seeds",
                        "0.5 tsp fenugreek seeds (methi)",
                        "1 cup peeled shallots (sambhar onions, sliced)",
                        "2 tbsp ginger juliennes",
                        "8 garlic cloves (slivered)",
                        "3 green chilies (slit lengthwise)",
                        "2 sprigs fresh green curry leaves",
                        "2 tbsp Kashmiri chili powder",
                        "1 tbsp coriander powder",
                        "1 cup thin coconut milk",
                        "0.5 cup thick coconut cream"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Tear soaked Kudampuli into small pieces and keep with its soaking water. Rub fish steaks with turmeric and half the salt; rest for 10 minutes."),
                DirectionStep(stepIndex: 2, text: "Heat coconut oil in an earthenware clay pot (meen chatti) over medium heat. Crackle mustard seeds and fenugreek seeds."),
                DirectionStep(stepIndex: 3, text: "Add sliced shallots, ginger, garlic, green chilies, and curry leaves. Sauté patiently until shallots turn soft and light golden."),
                DirectionStep(stepIndex: 4, text: "Lower heat; add Kashmiri chili powder and coriander powder diluted in 2 tbsp water to prevent burning. Sauté for 2 minutes until aromatic and oil separates."),
                DirectionStep(stepIndex: 5, text: "Pour in thin coconut milk and soaked Kudampuli with its water. Bring to a vigorous boil, then slide in the fish steaks in a single layer."),
                DirectionStep(stepIndex: 6, text: "Cover and simmer on low heat for 12–15 minutes until fish is cooked through and gravy thickens. Pour thick coconut cream on top, swirl the pot gently by the handles (do not stir with spoon), rest for 20 minutes, and serve with steaming hot Kerala matta rice.")
            ],
            thumbnailUrl: "recipe_kerala_fish_curry",
            ownerUsername: "@priyacooks",
            sourceLanguage: "ml",
            nutrition: RecipeNutrition(
                calories: 390,
                carbsG: 11,
                proteinG: 34,
                fatG: 24,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-paneer-butter-masala",
            ownerId: "creator-sanjeev",
            title: "Restaurant Paneer Butter Masala",
            description: "Melt-in-your-mouth paneer cubes simmered in a silky, mildly sweet and tangy tomato-cashew makhani gravy with butter, heavy cream, and aromatic kasuri methi.",
            prepTime: "20 min",
            cookTime: "25 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Paneer & Makhani Gravy Base",
                    items: [
                        "300g fresh paneer (cut into 1-inch cubes)",
                        "5 ripe plum tomatoes (roughly chopped)",
                        "18 whole raw cashew nuts (soaked in warm water 20 mins)",
                        "1-inch ginger piece",
                        "4 garlic cloves",
                        "2 green cardamoms",
                        "1 bay leaf",
                        "1-inch cinnamon stick"
                    ]
                ),
                IngredientGroup(
                    groupName: "Buttery Tempering & Spices",
                    items: [
                        "3 tbsp unsalted butter",
                        "1 tbsp neutral oil",
                        "1 tsp cumin seeds",
                        "1.5 tbsp Kashmiri red chili powder",
                        "1 tsp coriander powder",
                        "0.5 tsp garam masala",
                        "1 tsp sugar or honey",
                        "1 tsp salt",
                        "0.25 cup fresh heavy cream",
                        "1 tbsp crushed kasuri methi (roasted fenugreek leaves)"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "In a saucepan, boil tomatoes, soaked cashews, ginger, garlic, cardamoms, bay leaf, and cinnamon with 1 cup water for 12 minutes until tomatoes are mushy. Remove whole spices, cool, and blend to an ultra-silky puree. Strain through a sieve."),
                DirectionStep(stepIndex: 2, text: "Heat 2 tbsp butter and 1 tbsp oil in a pan. Add cumin seeds and allow them to crackle."),
                DirectionStep(stepIndex: 3, text: "Lower heat, stir in Kashmiri chili powder, and immediately pour in the strained tomato-cashew puree to preserve the bright crimson hue."),
                DirectionStep(stepIndex: 4, text: "Simmer gravy for 10 minutes on medium-low heat until oil begins to separate at the edges. Add coriander powder, garam masala, sugar, and salt."),
                DirectionStep(stepIndex: 5, text: "Gently fold in fresh paneer cubes and simmer for 4 minutes so the paneer absorbs the gravy without turning rubbery."),
                DirectionStep(stepIndex: 6, text: "Finish with remaining butter, heavy cream, and crushed kasuri methi. Swirl gently and serve immediately with hot garlic butter naan or jeera rice.")
            ],
            thumbnailUrl: "recipe_paneer_butter_masala",
            ownerUsername: "@Sanjeev.Kapoor",
            sourceLanguage: "hi",
            nutrition: RecipeNutrition(
                calories: 430,
                carbsG: 22,
                proteinG: 16,
                fatG: 32,
                estimated: false
            )
        ),
        Recipe(
            id: "recipe-chicken-chettinad",
            ownerId: "creator-aditya",
            title: "Fiery South Indian Chicken Chettinad",
            description: "Authentic Tamil Nadu specialty cooked with bone-in chicken in a freshly stone-ground dark roasted Chettinad masala of black peppercorns, star anise, fennel, and toasted coconut.",
            prepTime: "25 min",
            cookTime: "35 min",
            servings: 4,
            ingredients: [
                IngredientGroup(
                    groupName: "Freshly Roasted Chettinad Masala",
                    items: [
                        "2 tbsp coriander seeds",
                        "1 tbsp whole black peppercorns",
                        "1 tbsp fennel seeds (saunf)",
                        "1 tsp cumin seeds",
                        "1 star anise",
                        "1 piece mace (javitri)",
                        "1 stone flower (kalpasi, optional)",
                        "4 dried red chilies",
                        "0.25 cup freshly grated coconut"
                    ]
                ),
                IngredientGroup(
                    groupName: "Chicken & Curry Base",
                    items: [
                        "750g bone-in chicken curry cuts",
                        "3 tbsp cold-pressed sesame (gingelly) oil",
                        "1 cup red shallots (finely chopped)",
                        "1.5 tbsp ginger-garlic paste",
                        "2 sprigs fresh curry leaves",
                        "2 ripe tomatoes (chopped)",
                        "0.5 tsp turmeric powder",
                        "1.5 tsp salt",
                        "1.5 cups water",
                        "2 tbsp chopped fresh cilantro"
                    ]
                )
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Dry roast coriander seeds, peppercorns, fennel, cumin, star anise, mace, kalpasi, and dried red chilies in a skillet on low heat until deeply fragrant. Add grated coconut and roast until golden brown. Cool and grind with 0.25 cup water into a thick spice paste."),
                DirectionStep(stepIndex: 2, text: "Heat gingelly oil in a heavy kadai. Add curry leaves and chopped shallots; sauté until golden and caramelized."),
                DirectionStep(stepIndex: 3, text: "Add ginger-garlic paste and sauté for 2 minutes. Stir in chopped tomatoes and cook until soft and pulpy."),
                DirectionStep(stepIndex: 4, text: "Add chicken pieces, turmeric powder, and salt. Sear chicken on high heat for 6–7 minutes until meat changes color."),
                DirectionStep(stepIndex: 5, text: "Add the ground Chettinad spice paste and coat the chicken thoroughly. Pour in 1.5 cups water, bring to a boil, cover, and simmer for 20 minutes until chicken is tender."),
                DirectionStep(stepIndex: 6, text: "Remove lid and simmer on medium-high heat for 5 minutes until gravy is thick, dark brown, and oil glistens on the surface. Garnish with fresh curry leaves and cilantro, and serve with layered Malabar parottas.")
            ],
            thumbnailUrl: "recipe_chicken_chettinad",
            ownerUsername: "@Aditya.Gupta",
            sourceLanguage: "ta",
            nutrition: RecipeNutrition(
                calories: 490,
                carbsG: 14,
                proteinG: 41,
                fatG: 30,
                estimated: false
            )
        )

    ]
}
