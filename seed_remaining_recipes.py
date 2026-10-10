import json
import os

# This script is a template to batch-generate and append the remaining 26 Indian 
# recipes into the BundledRecipes.json dataset.

DATASET_PATH = "AICookBook/BundledRecipes.json"

def load_dataset():
    if not os.path.exists(DATASET_PATH):
        return []
    with open(DATASET_PATH, 'r') as f:
        return json.load(f)

def save_dataset(data):
    with open(DATASET_PATH, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Dataset updated. Total recipes in bundle: {len(data)}")

def append_recipes(new_recipes):
    dataset = load_dataset()
    existing_ids = {r['id'] for r in dataset}
    
    added = 0
    for r in new_recipes:
        if r['id'] not in existing_ids:
            dataset.append(r)
            added += 1
            
    save_dataset(dataset)
    print(f"Appended {added} new recipes to BundledRecipes.json")

if __name__ == "__main__":
    # Example template for the next batch of recipes to be injected
    # In a production environment, this could be hooked up to an LLM API 
    # to auto-generate the JSON structures.
    batch = [
        {
            "id": "recipe-bhindi-masala",
            "ownerId": "creator-aditya",
            "title": "Punjabi Bhindi Masala",
            "description": "Dry, spiced okra stir-fry with onions and tomatoes. A North Indian staple.",
            "prepTime": "15 min",
            "cookTime": "20 min",
            "servings": 4,
            "ingredients": [
                {
                    "groupName": "Main",
                    "items": ["500g okra (bhindi), chopped", "2 onions, sliced", "1 tomato, chopped"]
                }
            ],
            "directions": [
                { "stepIndex": 1, "text": "Wash and completely dry the okra before chopping." },
                { "stepIndex": 2, "text": "Fry okra in oil until crispy. Remove and set aside." },
                { "stepIndex": 3, "text": "Sauté onions and spices. Mix okra back in and simmer." }
            ],
            "thumbnailUrl": "recipe_chipotle_bowl", 
            "ownerUsername": "@Aditya.Gupta"
        }
        # Add remaining recipes here...
    ]
    
    append_recipes(batch)
