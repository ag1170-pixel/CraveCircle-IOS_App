import re

RECIPES = """
        Recipe(
            id: "recipe-dal-tadka",
            ownerId: "creator-priya",
            title: "Authentic Dal Tadka",
            description: "A comforting bowl of yellow lentils tempered with ghee, cumin, garlic, and whole red chilies. The ultimate Indian comfort food.",
            prepTime: "10 min",
            cookTime: "25 min",
            servings: 4,
            ingredients: [
                IngredientGroup(groupName: "Lentils", items: [
                    "1 cup yellow moong dal (split green gram)",
                    "1/2 cup toor dal (split pigeon peas)",
                    "3 cups water",
                    "1/2 tsp turmeric powder",
                    "1 tsp salt"
                ]),
                IngredientGroup(groupName: "Tadka (Tempering)", items: [
                    "2 tbsp ghee",
                    "1 tsp cumin seeds",
                    "4 cloves garlic, finely chopped",
                    "2 whole dried red chilies",
                    "1/2 tsp Kashmiri red chili powder",
                    "A pinch of asafoetida (hing)"
                ]),
                IngredientGroup(groupName: "Garnish", items: [
                    "2 tbsp fresh coriander leaves, chopped"
                ])
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Wash both dals together until water runs clear. Soak for 15 minutes."),
                DirectionStep(stepIndex: 2, text: "In a pressure cooker, add the soaked dal, 3 cups of water, turmeric, and salt. Cook for 3 whistles on medium heat."),
                DirectionStep(stepIndex: 3, text: "Let the pressure release naturally. Mash the cooked dal lightly with a spoon. If it's too thick, add a little hot water."),
                DirectionStep(stepIndex: 4, text: "For the tempering (tadka), heat ghee in a small pan. Add cumin seeds and let them splutter."),
                DirectionStep(stepIndex: 5, text: "Add chopped garlic and sauté until golden brown. Add whole red chilies and asafoetida."),
                DirectionStep(stepIndex: 6, text: "Turn off the heat. Quickly stir in the Kashmiri red chili powder (do not burn it) and pour the sizzling tadka over the cooked dal."),
                DirectionStep(stepIndex: 7, text: "Garnish with fresh coriander and serve hot with steamed rice or garlic naan.")
            ],
            thumbnailUrl: "recipe_dal_tadka",
            galleryUrls: ["recipe_dal_tadka"],
            ownerUsername: "@priyacooks",
            sourceLanguage: nil,
            nutrition: RecipeNutrition(calories: 220, carbsG: 32, proteinG: 12, fatG: 7, estimated: true),
            sourceUrl: nil
        ),
        Recipe(
            id: "recipe-shahi-paneer",
            ownerId: "creator-dev",
            title: "Royal Shahi Paneer",
            description: "A rich and creamy Mughlai dish made with soft paneer cubes cooked in a luxurious cashew, saffron, and cream gravy.",
            prepTime: "15 min",
            cookTime: "30 min",
            servings: 4,
            ingredients: [
                IngredientGroup(groupName: "Main", items: [
                    "400g paneer, cut into triangles or cubes",
                    "1 large onion, roughly chopped",
                    "2 large tomatoes, roughly chopped",
                    "15 whole cashews, soaked in warm water",
                    "1 inch ginger, chopped",
                    "4 cloves garlic"
                ]),
                IngredientGroup(groupName: "Spices & Gravy", items: [
                    "2 tbsp ghee or butter",
                    "1 tsp shahi jeera (caraway seeds)",
                    "2 green cardamoms",
                    "1/2 tsp turmeric powder",
                    "1 tsp coriander powder",
                    "1/2 tsp garam masala",
                    "1/4 cup fresh cream",
                    "A few strands of saffron soaked in 2 tbsp warm milk",
                    "Salt to taste"
                ])
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Boil the chopped onions, tomatoes, ginger, garlic, and soaked cashews in 1 cup of water until soft (about 10 minutes). Let it cool completely."),
                DirectionStep(stepIndex: 2, text: "Blend the boiled mixture into a very smooth, fine paste. Strain it through a sieve for a silky texture."),
                DirectionStep(stepIndex: 3, text: "Heat ghee in a pan. Add shahi jeera and green cardamoms. Let them sizzle for a few seconds."),
                DirectionStep(stepIndex: 4, text: "Pour the strained paste into the pan. Cook on low heat for 8-10 minutes, stirring continuously so the cashews don't stick."),
                DirectionStep(stepIndex: 5, text: "Add turmeric, coriander powder, and salt. Mix well and cook until the ghee starts separating from the edges."),
                DirectionStep(stepIndex: 6, text: "Stir in the saffron milk and fresh cream. Add the paneer pieces and simmer gently for 3-4 minutes."),
                DirectionStep(stepIndex: 7, text: "Sprinkle garam masala. Garnish with a drizzle of cream and crushed nuts. Serve hot with naan or paratha.")
            ],
            thumbnailUrl: "recipe_shahi_paneer",
            galleryUrls: ["recipe_shahi_paneer"],
            ownerUsername: "@deveats",
            sourceLanguage: nil,
            nutrition: RecipeNutrition(calories: 450, carbsG: 18, proteinG: 16, fatG: 38, estimated: true),
            sourceUrl: nil
        ),
        Recipe(
            id: "recipe-matar-paneer",
            ownerId: "creator-aditya",
            title: "Classic Matar Paneer",
            description: "A popular North Indian curry featuring soft paneer and sweet green peas in a spicy, tangy tomato gravy.",
            prepTime: "15 min",
            cookTime: "25 min",
            servings: 4,
            ingredients: [
                IngredientGroup(groupName: "Main", items: [
                    "250g paneer, cubed",
                    "1 cup green peas (fresh or frozen)",
                    "2 large tomatoes, pureed",
                    "1 large onion, finely chopped",
                    "1 tbsp ginger-garlic paste"
                ]),
                IngredientGroup(groupName: "Spices", items: [
                    "2 tbsp oil or ghee",
                    "1 tsp cumin seeds",
                    "1 tsp Kashmiri red chili powder",
                    "1/2 tsp turmeric powder",
                    "1 tsp coriander powder",
                    "1/2 tsp garam masala",
                    "1 tsp kasuri methi (dried fenugreek leaves)",
                    "Salt to taste"
                ])
            ],
            directions: [
                DirectionStep(stepIndex: 1, text: "Lightly pan-fry the paneer cubes in 1 tsp of oil until golden brown. Soak them in warm water to keep them soft."),
                DirectionStep(stepIndex: 2, text: "Heat the remaining oil/ghee in a pan. Add cumin seeds and let them crackle."),
                DirectionStep(stepIndex: 3, text: "Add finely chopped onions and sauté until golden brown. Stir in the ginger-garlic paste and cook for 2 minutes."),
                DirectionStep(stepIndex: 4, text: "Add the tomato puree along with turmeric, chili powder, coriander powder, and salt. Cook until the oil separates from the masala."),
                DirectionStep(stepIndex: 5, text: "Add the green peas and 1/2 cup of water. Cover and simmer for 5-7 minutes until the peas are tender."),
                DirectionStep(stepIndex: 6, text: "Drain the paneer cubes and add them to the gravy. Sprinkle garam masala and crushed kasuri methi. Simmer for 2 more minutes."),
                DirectionStep(stepIndex: 7, text: "Garnish with fresh coriander leaves. Serve hot with roti, paratha, or jeera rice.")
            ],
            thumbnailUrl: "recipe_matar_paneer",
            galleryUrls: ["recipe_matar_paneer"],
            ownerUsername: "@Aditya.Gupta",
            sourceLanguage: nil,
            nutrition: RecipeNutrition(calories: 320, carbsG: 15, proteinG: 14, fatG: 24, estimated: true),
            sourceUrl: nil
        ),
"""

path = "/Users/user38/Projects/CraveCircle.cc/AICookBook/SampleRecipes.swift"
with open(path, "r") as f:
    content = f.read()

# Find the end of the array `static let placeholderRecipes: [Recipe] = [`
# We will insert our RECIPES at the top of this array.
# The array starts with `static let placeholderRecipes: [Recipe] = [`
match = re.search(r'static let placeholderRecipes: \[Recipe\] = \[', content)
if match:
    insert_pos = match.end() + 1
    new_content = content[:insert_pos] + RECIPES + content[insert_pos:]
    with open(path, "w") as f:
        f.write(new_content)
    print("Injected 3 new recipes successfully.")
else:
    print("Could not find array start.")
