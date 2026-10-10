import re

RECIPES = """
        Recipe(
            id: "recipe-chana-masala",
            ownerId: "creator-nada",
            title: "Amritsari Chana Masala",
            description: "A spicy, tangy, and deeply flavorful Punjabi chickpea curry, cooked slowly with toasted dry spices and tea leaves for that signature dark color.",
            prepTime: "8 hours (soaking)",
            cookTime: "45 min",
            servings: 4,
            ingredients: [
                IngredientGroup(groupName: "Chickpeas", items: [
                    "2 cups white chickpeas (kabuli chana), soaked overnight",
                    "1 tea bag (for dark color)",
                    "2 bay leaves",
                    "1 black cardamom",
                    "1/2 tsp salt"
                ]),
                IngredientGroup(groupName: "Masala Paste", items: [
                    "2 tbsp oil or ghee",
                    "2 large onions, finely chopped",
                    "2 large tomatoes, pureed",
                    "1 tbsp ginger-garlic paste",
                    "1 tbsp Chole Masala powder",
                    "1/2 tsp turmeric",
                    "1 tsp coriander powder",
                    "1/2 tsp dry mango powder (amchur)"
                ])
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Pressure cook the soaked chickpeas with the tea bag, bay leaves, black cardamom, and salt for 4-5 whistles until very soft. Discard the tea bag."),
                DirectionStep(stepIndex: 2, text: "Heat oil in a deep pan. Add finely chopped onions and sauté until dark brown (this is key to the flavor)."),
                DirectionStep(stepIndex: 3, text: "Add ginger-garlic paste and sauté for 2 minutes."),
                DirectionStep(stepIndex: 4, text: "Add the tomato puree, turmeric, coriander powder, and Chole Masala. Cook until the oil separates from the edges."),
                DirectionStep(stepIndex: 5, text: "Add the boiled chickpeas along with their cooking water. Mash a few chickpeas with the back of your spoon to thicken the gravy."),
                DirectionStep(stepIndex: 6, text: "Simmer uncovered for 15-20 minutes until the gravy is thick and dark. Stir in the dry mango powder for tanginess."),
                DirectionStep(stepIndex: 7, text: "Garnish with ginger juliennes, slit green chilies, and fresh coriander. Serve piping hot with bhature or rice.")
            ],
            thumbnailUrl: "recipe_chana_masala",
            galleryUrls: ["recipe_chana_masala"],
            ownerUsername: "@nada_dl",
            sourceLanguage: nil,
            nutrition: RecipeNutrition(calories: 340, carbsG: 45, proteinG: 12, fatG: 14, estimated: true),
            sourceUrl: nil
        ),
        Recipe(
            id: "recipe-rajma-masala",
            ownerId: "creator-priya",
            title: "Punjabi Rajma Masala",
            description: "Comforting, thick, and deeply spiced kidney bean curry. A Sunday classic in North Indian homes, best enjoyed with steamed rice.",
            prepTime: "8 hours (soaking)",
            cookTime: "40 min",
            servings: 4,
            ingredients: [
                IngredientGroup(groupName: "Kidney Beans", items: [
                    "1.5 cups red kidney beans (rajma), soaked overnight",
                    "1 black cardamom",
                    "1/2 tsp salt",
                    "4 cups water"
                ]),
                IngredientGroup(groupName: "Curry Base", items: [
                    "2 tbsp ghee",
                    "1 tsp cumin seeds",
                    "1 large onion, finely grated",
                    "3 large tomatoes, pureed",
                    "1 tbsp ginger-garlic paste",
                    "1 tsp Kashmiri red chili powder",
                    "1 tsp coriander powder",
                    "1/2 tsp garam masala",
                    "1 tbsp fresh cream (optional)"
                ])
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Pressure cook the soaked kidney beans with water, black cardamom, and salt until completely soft and melting (about 4-5 whistles)."),
                DirectionStep(stepIndex: 2, text: "In a heavy-bottomed pan, heat ghee and add cumin seeds. Let them splutter."),
                DirectionStep(stepIndex: 3, text: "Add grated onions and sauté until golden brown. Add ginger-garlic paste and cook for 2 more minutes."),
                DirectionStep(stepIndex: 4, text: "Stir in the tomato puree, Kashmiri chili powder, and coriander powder. Cook until the ghee separates from the masala."),
                DirectionStep(stepIndex: 5, text: "Pour the boiled rajma along with its cooking water into the masala. Mash a few beans against the side of the pan to thicken the gravy."),
                DirectionStep(stepIndex: 6, text: "Cover and simmer on low heat for 15-20 minutes to allow the flavors to meld perfectly."),
                DirectionStep(stepIndex: 7, text: "Sprinkle garam masala and swirl in fresh cream. Garnish with coriander and serve hot with steamed basmati rice (Rajma Chawal).")
            ],
            thumbnailUrl: "recipe_rajma_masala",
            galleryUrls: ["recipe_rajma_masala"],
            ownerUsername: "@priyacooks",
            sourceLanguage: nil,
            nutrition: RecipeNutrition(calories: 280, carbsG: 40, proteinG: 14, fatG: 8, estimated: true),
            sourceUrl: nil
        ),
        Recipe(
            id: "recipe-aloo-gobi",
            ownerId: "creator-dev",
            title: "Rustic Aloo Gobi",
            description: "A dry, spiced vegetable dish made with potatoes, cauliflower, and an aromatic blend of roasted spices. A staple comfort food.",
            prepTime: "15 min",
            cookTime: "25 min",
            servings: 3,
            ingredients: [
                IngredientGroup(groupName: "Vegetables", items: [
                    "1 medium cauliflower (gobi), cut into florets",
                    "2 large potatoes (aloo), peeled and cubed",
                    "1 large onion, chopped",
                    "2 tomatoes, chopped",
                    "1 inch ginger, julienned"
                ]),
                IngredientGroup(groupName: "Spices", items: [
                    "2 tbsp oil",
                    "1 tsp cumin seeds",
                    "1/2 tsp turmeric powder",
                    "1 tsp coriander powder",
                    "1/2 tsp red chili powder",
                    "1/2 tsp garam masala",
                    "1 tsp dried mango powder (amchur)"
                ])
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Wash the cauliflower florets in warm salted water and drain completely. Pat dry."),
                DirectionStep(stepIndex: 2, text: "Heat oil in a wide pan or skillet. Pan-fry the potatoes on medium heat until they develop a golden crust (about 5-6 minutes). Remove and set aside."),
                DirectionStep(stepIndex: 3, text: "In the same oil, pan-fry the cauliflower florets until slightly golden. Remove and set aside."),
                DirectionStep(stepIndex: 4, text: "Add cumin seeds to the remaining oil. Sauté the chopped onions until translucent. Add ginger and tomatoes, cooking until tomatoes soften."),
                DirectionStep(stepIndex: 5, text: "Stir in turmeric, coriander, and chili powder. Add the fried potatoes and cauliflower back to the pan."),
                DirectionStep(stepIndex: 6, text: "Mix gently so the vegetables are coated in the spices. Cover and cook on low heat for 10 minutes until tender (do not add water)."),
                DirectionStep(stepIndex: 7, text: "Turn off the heat. Sprinkle garam masala, amchur, and fresh coriander. Serve hot with roti or paratha.")
            ],
            thumbnailUrl: "recipe_aloo_gobi",
            galleryUrls: ["recipe_aloo_gobi"],
            ownerUsername: "@deveats",
            sourceLanguage: nil,
            nutrition: RecipeNutrition(calories: 190, carbsG: 24, proteinG: 5, fatG: 10, estimated: true),
            sourceUrl: nil
        ),
        Recipe(
            id: "recipe-kadai-chicken",
            ownerId: "creator-aditya",
            title: "Authentic Kadai Chicken",
            description: "A spicy, warming, flavor-packed chicken curry cooked with freshly ground whole spices, bell peppers, and a rich tomato base.",
            prepTime: "15 min",
            cookTime: "35 min",
            servings: 4,
            ingredients: [
                IngredientGroup(groupName: "Kadai Masala (Fresh Spice Mix)", items: [
                    "1.5 tbsp coriander seeds",
                    "1 tsp cumin seeds",
                    "4 dried red chilies",
                    "1/2 tsp black peppercorns"
                ]),
                IngredientGroup(groupName: "Chicken & Gravy", items: [
                    "500g bone-in chicken pieces",
                    "2 tbsp oil or ghee",
                    "1 large onion, finely chopped",
                    "3 large tomatoes, pureed",
                    "1 green bell pepper (capsicum), cut into squares",
                    "1 onion, cut into squares (petals)",
                    "1 tbsp ginger-garlic paste",
                    "1 tbsp kasuri methi (dried fenugreek leaves)"
                ])
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Dry roast the coriander seeds, cumin, dried chilies, and black peppercorns in a pan until fragrant. Let cool, then grind into a coarse powder (Kadai Masala)."),
                DirectionStep(stepIndex: 2, text: "Heat oil in a traditional wok (kadai). Add the chopped onions and sauté until golden brown."),
                DirectionStep(stepIndex: 3, text: "Add ginger-garlic paste and sauté for 1 minute. Add the chicken pieces and fry on high heat until the meat is sealed and changes color."),
                DirectionStep(stepIndex: 4, text: "Stir in the tomato puree, salt, and half of your freshly ground Kadai Masala. Cover and cook on medium-low for 15-20 minutes until the chicken is 80% cooked."),
                DirectionStep(stepIndex: 5, text: "In a separate small pan, lightly sauté the square-cut bell peppers and onion petals in a drop of oil until slightly blistered but still crunchy."),
                DirectionStep(stepIndex: 6, text: "Add the sautéed veggies and the remaining Kadai Masala to the chicken. Stir well and simmer for 5 minutes."),
                DirectionStep(stepIndex: 7, text: "Crush the kasuri methi between your palms and sprinkle it over the curry. Garnish with ginger juliennes and serve with naan.")
            ],
            thumbnailUrl: "recipe_kadai_chicken",
            galleryUrls: ["recipe_kadai_chicken"],
            ownerUsername: "@Aditya.Gupta",
            sourceLanguage: nil,
            nutrition: RecipeNutrition(calories: 380, carbsG: 12, proteinG: 28, fatG: 22, estimated: true),
            sourceUrl: nil
        ),
        Recipe(
            id: "recipe-malai-kofta",
            ownerId: "creator-kristy",
            title: "Luxurious Malai Kofta",
            description: "The ultimate vegetarian indulgence: melt-in-the-mouth potato and paneer dumplings swimming in a rich, sweet, and creamy cashew-onion gravy.",
            prepTime: "30 min",
            cookTime: "30 min",
            servings: 4,
            ingredients: [
                IngredientGroup(groupName: "For the Koftas (Dumplings)", items: [
                    "1 cup boiled potatoes, grated",
                    "1 cup paneer, grated",
                    "2 tbsp cornflour",
                    "1/4 cup mixed nuts and raisins, finely chopped",
                    "1/2 tsp cardamom powder",
                    "Oil for deep frying"
                ]),
                IngredientGroup(groupName: "For the Gravy", items: [
                    "2 large onions, roughly chopped",
                    "15 whole cashews",
                    "2 green cardamoms",
                    "1 tsp ginger-garlic paste",
                    "1/2 cup tomato puree (optional, for slightly redder gravy)",
                    "1/4 cup fresh cream",
                    "1/2 tsp garam masala",
                    "1 tsp sugar or honey"
                ])
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Boil the chopped onions and cashews in water for 10 minutes until soft. Drain, cool, and blend into a very smooth, silky paste."),
                DirectionStep(stepIndex: 2, text: "To make the koftas, mix the grated potatoes, paneer, cornflour, salt, and cardamom powder in a bowl. Knead into a smooth dough."),
                DirectionStep(stepIndex: 3, text: "Divide the dough into small balls. Flatten each, place a pinch of chopped nuts/raisins in the center, and seal it into a round dumpling. Dust lightly with cornflour."),
                DirectionStep(stepIndex: 4, text: "Deep fry the koftas in medium-hot oil until golden brown. Drain on paper towels and set aside. (Handle gently as they are very soft)."),
                DirectionStep(stepIndex: 5, text: "Heat 2 tbsp oil in a pan. Add ginger-garlic paste and sauté. Pour in the blended onion-cashew paste and cook on low heat for 7-8 minutes, stirring continuously."),
                DirectionStep(stepIndex: 6, text: "Add tomato puree (if using), salt, and sugar. Simmer until the gravy is thick and glossy. Stir in the fresh cream and garam masala."),
                DirectionStep(stepIndex: 7, text: "Just before serving, place the fried koftas in a serving dish and pour the hot gravy over them (do not boil the koftas in the gravy or they will break). Garnish with cream and pistachios.")
            ],
            thumbnailUrl: "recipe_malai_kofta",
            galleryUrls: ["recipe_malai_kofta"],
            ownerUsername: "@Kristy.Graver",
            sourceLanguage: nil,
            nutrition: RecipeNutrition(calories: 460, carbsG: 28, proteinG: 12, fatG: 34, estimated: true),
            sourceUrl: nil
        ),
"""

path = "/Users/user38/Projects/CraveCircle.cc/AICookBook/SampleRecipes.swift"
with open(path, "r") as f:
    content = f.read()

match = re.search(r'static let placeholderRecipes: \[Recipe\] = \[', content)
if match:
    insert_pos = match.end() + 1
    new_content = content[:insert_pos] + RECIPES + content[insert_pos:]
    with open(path, "w") as f:
        f.write(new_content)
    print("Injected 5 more recipes safely.")
else:
    print("Could not find array start.")
