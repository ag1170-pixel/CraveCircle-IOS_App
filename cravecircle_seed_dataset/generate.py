"""Clean the Food.com seed JSON in place and regenerate the Swift + SQL from it."""
import json
import re
import sys

repo = sys.argv[1]
ds = f"{repo}/cravecircle_seed_dataset"
recipes = json.load(open(f"{ds}/cravecircle_50_recipes.json"))

UNITS = r"(?:cups?|tbsp|tsp|cloves?|medium|large|small|g|kg|ml|oz|lbs?|cans?|slices?|pieces?|pinch|stalks?|sticks?)"


def cap(s):
    return s[:1].upper() + s[1:] if s else s


def tidy(s):
    s = re.sub(r"\s+([,.;:!?)])", r"\1", s)        # "garlic , onion ." -> "garlic, onion."
    s = re.sub(r"\(\s+", "(", s)
    s = re.sub(r"(\d)\s*/\s*(\d)", r"\1/\2", s)       # "1 / 2" -> "1/2"
    s = re.sub(r"(\d)\s*f\b", r"\1°F", s)             # "375f" -> "375°F"
    s = re.sub(r"\bw\s*/\s*", "with ", s)
    s = re.sub(r"(?<![\w'])i(?![\w'])", "I", s)        # lone "i" -> "I"
    s = re.sub(r"\s{2,}", " ", s).strip()
    return s


def sentences(s):
    s = tidy(s)
    return re.sub(r"(^|[.!?]\s+)([a-z])", lambda m: m.group(1) + m.group(2).upper(), s)


def ingredient(item):
    s = tidy(item)
    s = re.sub(r"^1 portion\s+", "", s)               # no real amount in the source
    s = re.sub(r"\bfresh dried\b", "dried", s)
    m = re.match(rf"^([\d./]+ {UNITS}), (.+)$", s)     # "3 cloves, minced garlic cloves"
    if m:
        qty, rest = m.groups()
        unit = qty.split(" ", 1)[1]
        rest = re.sub(rf"\s+{unit}$", "", rest)        # drop the repeated unit word
        s = f"{qty} {rest}"
    return cap(s) if not re.match(r"^[\d./]", s) else s


def duration(t):
    m = re.fullmatch(r"(\d+) min", t or "")
    if not m or int(m.group(1)) < 60:
        return t
    h, mins = divmod(int(m.group(1)), 60)
    return f"{h} hr" + (f" {mins} min" if mins else "")


MEAL = {"Breakfast/Brunch": ["breakfast"]}

for r in recipes:
    r["description"] = sentences(r.get("description") or "")
    r["prepTime"] = duration(r.get("prepTime"))
    r["cookTime"] = duration(r.get("cookTime"))
    for g in r["ingredients"]:
        g["items"] = [ingredient(i) for i in g["items"]]
    for d in r["directions"]:
        d["text"] = sentences(d["text"])
    if r.get("category") in MEAL:
        r["mealTypes"] = MEAL[r["category"]]

json.dump(recipes, open(f"{ds}/cravecircle_50_recipes.json", "w"), indent=2, ensure_ascii=False)
open(f"{ds}/cravecircle_50_recipes.json", "a").write("\n")


def sw(s):
    return json.dumps(s, ensure_ascii=False)         # valid Swift string literal (escapes " and \)


def num(x):
    return repr(float(x)).rstrip("0").rstrip(".") if float(x) != int(float(x)) else str(int(float(x)))


out = [
    "//",
    "//  FoodComSeedRecipes.swift",
    "//  CraveCircle (AICookBook)",
    "//",
    "//  50 curated Food.com recipes (>= 20 reviews, avg >= 4.5). Generated from",
    "//  cravecircle_seed_dataset/cravecircle_50_recipes.json — edit the JSON, then regenerate.",
    "//",
    "",
    "import Foundation",
    "",
    "extension Recipe {",
    "    static let foodComSeedRecipes: [Recipe] = [",
]
for r in recipes:
    n = r["nutrition"]
    out += [
        "        Recipe(",
        f"            id: {sw(r['id'])},",
        f"            ownerId: {sw(r['ownerId'])},",
        f"            title: {sw(r['title'])},",
        f"            description: {sw(r['description'])},",
        f"            prepTime: {sw(r['prepTime'])},",
        f"            cookTime: {sw(r['cookTime'])},",
        f"            servings: {r['servings']},",
        "            ingredients: [",
    ]
    for g in r["ingredients"]:
        out.append(f"                IngredientGroup(groupName: {sw(g['groupName'])}, items: [")
        out += [f"                    {sw(i)}," for i in g["items"]]
        out.append("                ]),")
    out.append("            ],")
    out.append("            directions: [")
    out += [f"                DirectionStep(stepIndex: {d['stepIndex']}, text: {sw(d['text'])})," for d in r["directions"]]
    out += [
        "            ],",
        f"            thumbnailUrl: {sw(r['thumbnailUrl'])},",
        f"            ownerUsername: {sw(r['ownerUsername'])},",
        f"            sourceLanguage: {sw(r['sourceLanguage'])},",
        f"            nutrition: RecipeNutrition(calories: {num(n['calories'])}, carbsG: {num(n['carbsG'])}, "
        f"proteinG: {num(n['proteinG'])}, fatG: {num(n['fatG'])}, estimated: {str(bool(n.get('estimated'))).lower()})"
        + ("," if r.get("mealTypes") else ""),
    ]
    if r.get("mealTypes"):
        out.append(f"            mealTypes: [{', '.join(sw(m) for m in r['mealTypes'])}]")
    out.append("        ),")
out += ["    ]", "}", ""]
open(f"{repo}/AICookBook/Models/FoodComSeedRecipes.swift", "w").write("\n".join(out))


def sq(s):
    return "'" + s.replace("'", "''") + "'"


sql = [
    "-- CraveCircle: 50 curated Food.com seed recipes. Generated from cravecircle_50_recipes.json.",
    "-- Target: cravecircle.recipes. Run in the Supabase SQL editor (service role).",
    "--",
    "-- owner_id must reference a real profile, so every row is owned by the oldest admin account.",
    "-- Re-running is safe: existing ids are left alone. thumbnail_url is an asset name bundled in",
    "-- the app (Resources/Assets.xcassets), so these covers render on any device with the app.",
    "",
    "SET search_path = cravecircle, public;",
    "",
    "DO $$",
    "DECLARE seed_owner uuid;",
    "BEGIN",
    "    SELECT id INTO seed_owner FROM cravecircle.profiles WHERE role = 'admin' ORDER BY created_at LIMIT 1;",
    "    IF seed_owner IS NULL THEN",
    "        RAISE EXCEPTION 'No admin profile found to own the seed recipes';",
    "    END IF;",
    "",
    "    INSERT INTO cravecircle.recipes (id, owner_id, title, description, prep_time, cook_time, servings,",
    "        ingredients, directions, thumbnail_url, owner_username, source_language, nutrition, visibility)",
    "    VALUES",
]
rows = []
for r in recipes:
    nut = {k: r["nutrition"][k] for k in ("calories", "carbsG", "proteinG", "fatG", "estimated")}
    rows.append(
        "        (" + ", ".join([
            sq(r["id"]), "seed_owner", sq(r["title"]), sq(r["description"]), sq(r["prepTime"]),
            sq(r["cookTime"]), str(r["servings"]),
            sq(json.dumps(r["ingredients"], ensure_ascii=False)) + "::jsonb",
            sq(json.dumps(r["directions"], ensure_ascii=False)) + "::jsonb",
            sq(r["thumbnailUrl"]), sq(r["ownerUsername"]), sq(r["sourceLanguage"]),
            sq(json.dumps(nut)) + "::jsonb", "'everyone'",
        ]) + ")"
    )
sql.append(",\n".join(rows))
sql += ["    ON CONFLICT (id) DO NOTHING;", "END $$;", ""]
open(f"{ds}/seed_50_recipes.sql", "w").write("\n".join(sql))

print("recipes:", len(recipes))
