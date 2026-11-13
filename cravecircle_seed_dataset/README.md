# CraveCircle 50 Curated Seed Recipes (Food.com Dataset)

This dataset extracts, cleans, normalizes, and structures 50 top-rated recipes from the Food.com Kaggle benchmark for CraveCircle.

## Dataset Overview
- **Total Recipes:** 50
- **Source Benchmark:** Food.com (`archive.zip` / RAW_recipes.csv & RAW_interactions.csv)
- **Quality Threshold:** Verified >= 20 user reviews, average rating >= 4.5/5
- **Formats Included:**
  - `cravecircle_50_recipes.json`: Universal JSON array matching CraveCircle models.
  - `seed_50_recipes.sql`: Ready-to-execute PostgreSQL statements for Supabase (`cravecircle.recipes`).
  - `image_generation_manifest.json`: Exact tailored culinary prompts, aspect ratio (1:1), and generation status for all 50 recipes.
  - `images/`: Original 1024×1024 food photography (source files).
  - `generate.py`: Cleans the JSON and regenerates the Swift and SQL from it.

## How it's wired into the app
- `cravecircle_50_recipes.json` is the single source of truth.
- `AICookBook/Models/FoodComSeedRecipes.swift` is generated from it and appended to
  `Recipe.placeholderRecipes`, so the 50 recipes ship as built-in feed recipes (searchable,
  openable, with nutrition) like the existing samples.
- Photos live in `AICookBook/Resources/Assets.xcassets/recipe_*.imageset`, re-encoded to
  ~280 KB each; `thumbnailUrl` is the asset name.
- `seed_50_recipes.sql` (optional) loads the same rows into `cravecircle.recipes`, owned by
  the oldest admin profile, and is safe to re-run.

To change a recipe: edit the JSON, then run from the repo root:

```bash
python3 cravecircle_seed_dataset/generate.py "$PWD"
```

To add photos for new recipes, copy the image into `Assets.xcassets` as `recipe_<name>.imageset`.

## Image Generation Progress (50 / 50 Complete — 100%)
Every single recipe image is 100% unique and generated via the custom AI food photography pipeline (1:1 square ratio, 1024×1024, warm natural directional lighting, rustic tableware, authentic garnishes, shallow depth of field). Zero placeholder duplicates.

### 50 Completed Unique AI Food Photographs:
1. `recipe_lasagna_bolognese.jpg` — Ultimate Italian Lasagna Bolognese
2. `recipe_crispy_chicken_parmesan.jpg` — Crispy Chicken Parmesan
3. `recipe_fettuccine_alfredo.jpg` — Creamy Fettuccine Alfredo
4. `recipe_gourmet_mushroom_risotto.jpg` — Gourmet Wild Mushroom Risotto
5. `recipe_carbonara.jpg` — Roman Spaghetti Carbonara
6. `recipe_chicken_gnocchi_soup.jpg` — Creamy Chicken & Gnocchi Soup
7. `recipe_artichoke_bruschetta.jpg` — Toasted Artichoke and Herb Bruschetta
8. `recipe_garden_minestrone.jpg` — Hearty Italian Garden Minestrone Soup
9. `recipe_sour_cream_enchiladas.jpg` — Creamy Sour Cream Chicken Enchiladas
10. `recipe_sizzling_steak_fajitas.jpg` — Sizzling Steak and Pepper Fajitas
11. `recipe_fresh_chunky_guacamole.jpg` — Classic Fresh Chunky Guacamole
12. `recipe_cheesy_chicken_quesadillas.jpg` — Crispy Cheesy Chicken Quesadillas
13. `recipe_fiesta_taco_casserole.jpg` — Fiesta Beef Taco Casserole
14. `recipe_fire_roasted_salsa.jpg` — Fresh Fire-Roasted Restaurant Salsa
15. `recipe_mexican_pork_carnitas.jpg` — Crispy Mexican Pork Carnitas
16. `recipe_loaded_burrito_bake.jpg` — Cheesy Loaded Burrito Bake
17. `recipe_beef_broccoli_stirfry.jpg` — Savory Beef and Broccoli Stir-Fry
18. `recipe_bangkok_pad_thai.jpg` — Traditional Bangkok Pad Thai
19. `recipe_wok_fried_rice.jpg` — Golden Wok Egg Fried Rice
20. `recipe_pork_scallion_dumplings.jpg` — Pan-Fried Pork & Scallion Dumplings
21. `recipe_coconut_chicken_curry.jpg` — Aromatic Coconut Chicken Curry
22. `recipe_scallion_egg_foo_young.jpg` — Crispy Scallion Egg Foo Young
23. `recipe_garlic_ginger_stirfry.jpg` — Garlic Ginger Chicken Stir-Fry
24. `recipe_buttermilk_pancakes.jpg` — Fluffy Golden Buttermilk Pancakes
25. `recipe_brioche_french_toast.jpg` — Golden Brioche French Toast
26. `recipe_ham_cheddar_omelet.jpg` — Baked Ham & Cheddar Omelet Roll
27. `recipe_cinnamon_banana_bread.jpg` — Classic Moist Cinnamon Banana Bread
28. `recipe_fudgy_chocolate_brownies.jpg` — Fudgy Dark Chocolate Brownies
29. `recipe_cheesecake_strawberries.jpg` — Cheesecake Stuffed Strawberries
30. `recipe_soft_chocolate_chip_cookies.jpg` — Chewy Soft-Batch Chocolate Chip Cookies
31. `recipe_golden_chicken_pot_pie.jpg` — Homestyle Golden Chicken Pot Pie
32. `recipe_bbq_pork_ribs.jpg` — Slow-Baked Fall-Off-The-Bone BBQ Ribs
33. `recipe_four_cheese_macaroni.jpg` — Creamy Four-Cheese Macaroni and Cheese
34. `recipe_slow_simmered_beef_stew.jpg` — Hearty Slow-Simmered Beef Stew
35. `recipe_sweet_spicy_chili.jpg` — Smoky Honey Sweet and Spicy Chili
36. `recipe_baked_chicken_teriyaki.jpg` — Glazed Baked Chicken Teriyaki
37. `recipe_belgian_golden_waffles.jpg` — Crispy Belgian Golden Waffles
38. `recipe_crumb_banana_muffins.jpg` — Streusel Crumb Banana Muffins
39. `recipe_bakery_blueberry_muffins.jpg` — Fresh Bakery Blueberry Muffins
40. `recipe_garden_herb_frittata.jpg` — Garden Vegetable & Herb Frittata
41. `recipe_strawberry_cream_crepes.jpg` — Sweet Crepes with Fresh Strawberry Cream
42. `recipe_almost_apple_pie.jpg` — Caramelized Dutch Apple Pie
43. `recipe_peanut_butter_cookies.jpg` — Old-Fashioned Peanut Butter Cookies
44. `recipe_whipped_shortbread.jpg` — Melt-in-Your-Mouth Whipped Shortbread
45. `recipe_boston_clam_chowder.jpg` — Creamy Boston Clam Chowder
46. `recipe_mediterranean_greek_salad.jpg` — Crisp Mediterranean Greek Village Salad
47. `recipe_cucumber_tzatziki.jpg` — Cool Cucumber Garlic Tzatziki Dip
48. `recipe_cinnamon_snickerdoodles.jpg` — Cinnamon Sugar Snickerdoodles
49. `recipe_garlic_caesar_salad.jpg` — Classic Creamy Garlic Caesar Salad
50. `recipe_roasted_pepper_hummus.jpg` — Roasted Red Pepper and Feta Hummus
