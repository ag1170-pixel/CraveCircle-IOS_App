# Task for Antigravity — Add Recipe Content (recipes + real images)

**Assigned by:** Claude (architect) · **Owner of this task:** Antigravity (content/UI/assets)
**Goal:** grow the app's built-in recipe library from 10 → **~25–30 recipes**, each with a **real, high-quality food image**, so the app feels full and alive.

---

## Where the work goes (your files — don't touch logic files)
- **Recipe data:** `AICookBook/SampleRecipes.swift` — add new `Recipe(...)` entries to the `placeholderRecipes` array. **This file is yours.**
- **Images:** `AICookBook/Assets.xcassets/recipe_<slug>.imageset/` — one imageset per recipe (match the existing `recipe_*` imagesets exactly: a `Contents.json` + the image file).
- **Do NOT edit** `Models.swift`, `AppEnvironment.swift`, or any other logic file — the `Recipe` shape is fixed; just fill it in.

## The recipe shape (copy an existing entry and change the values)
```swift
Recipe(
    id: "recipe-<unique-slug>",            // unique, kebab-case
    ownerId: "creator-<handle>",           // a creator id
    title: "Dish Name",
    description: "One vivid sentence.",
    prepTime: "15 min",
    cookTime: "20 min",
    servings: 2,
    ingredients: [
        IngredientGroup(groupName: "Main", items: [
            "200g paneer",                 // ⚠️ ALWAYS include a quantity + unit
            "1 tbsp oil",
            "1 onion, sliced"
        ]),
        IngredientGroup(groupName: "Sauce", items: [ "..." ])
    ],
    directions: [
        DirectionStep(stepIndex: 1, text: "Do the first thing."),
        DirectionStep(stepIndex: 2, text: "Then the next.")
    ],
    thumbnailUrl: "recipe_<slug>",         // ⚠️ MUST equal the imageset name you add
    ownerUsername: "@handle",
    sourceLanguage: "en",
    nutrition: nil                          // nil = the app auto-estimates kcal/macros. Fine to leave nil.
)
```

## Rules that make it "just work"
1. **Every ingredient line needs a quantity + unit** (`200g`, `1 tbsp`, `2 cloves`, `1 cup`) — this is what powers the **calorie estimate** and **grocery scaling**. No bare "salt to taste" as the only form.
2. **`thumbnailUrl` must exactly match the imageset name** you create (e.g. `recipe_shakshuka` ↔ `recipe_shakshuka.imageset`).
3. **`id` must be unique.** `stepIndex` starts at 1 and increments.
4. Leave `nutrition: nil` to let the app estimate — OR provide accurate values with `estimated: false` if you have them.

## Images — quality bar (this is the visible win)
- **Real, appetizing food photography**, consistent editorial style (warm, natural light — matches the existing set).
- **≥ 1024×1024**, roughly **square** (cards crop square). Match the existing `recipe_*` imageset format (single universal image + `Contents.json`).
- Name files/imagesets `recipe_<slug>` (lowercase, underscores).
- No text/watermarks/borders baked into the image.

## Variety to aim for (fill the gaps)
Cover **breakfast, lunch, dinner, dessert, snacks, drinks**; **veg + non-veg + vegan**; and a spread of cuisines — **Indian, Italian, Mexican, East/SE Asian, Middle Eastern, American, Mediterranean**. Mix quick (≤15 min) and weekend cooks. Assign a few different `ownerUsername` creators so the feed feels social.

## Definition of done
- [ ] ~15–20 new recipes added to `SampleRecipes.swift`, each with a matching image imageset.
- [ ] `** BUILD SUCCEEDED **` (run the app — new recipes show on Home/Library, images load, a kcal number appears).
- [ ] Ingredients have quantities; directions are clear; times realistic.
- [ ] Commit with a clear message; `git pull --rebase` before pushing (shared repo — see `WORK_DIVISION.md`).

*(If you add brand-new creators, you can optionally add them to the sample creator/friends lists so their profile opens — ask Claude if unsure where.)*
