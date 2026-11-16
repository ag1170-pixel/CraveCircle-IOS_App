"""Clean the Food.com seed JSON in place and regenerate the SQL from it."""
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


# Full public URL. Bump PHOTO_VERSION after re-uploading a photo: Cloudflare caches per URL
# (including "not found" answers), so a new version is the way to get fresh images.
PHOTO_BASE = "https://db.cravecircle.cc/storage/v1/object/public/recipe-thumbnails"
PHOTO_VERSION = 1


def sq(s):
    return "'" + s.replace("'", "''") + "'"


sql = [
    "-- CraveCircle: 50 curated Food.com seed recipes. Generated from cravecircle_50_recipes.json.",
    "-- Target: cravecircle.recipes. Run in the Supabase SQL editor.",
    "--",
    "-- Owner: the profile whose username is set below. Use a dedicated kitchen account, NOT your",
    "-- own: recipes you own count as yours (Your Library) and are left out of Fresh / Suggested.",
    "-- Photos: thumbnail_url is the full public URL in the recipe-thumbnails bucket, with ?v=N",
    "-- to get past Cloudflare's cache (upload with upload_images.sh first).",
    "-- Safe to re-run: existing ids only get their photo URL and nutrition refreshed.",
    "",
    "SET search_path = cravecircle, public;",
    "",
    "DO $$",
    "DECLARE",
    "    seed_username text := 'aicookbook';   -- house creator account that owns the built-in samples",
    "    seed_owner uuid;",
    "BEGIN",
    "    SELECT id INTO seed_owner FROM cravecircle.profiles WHERE username = seed_username;",
    "    IF seed_owner IS NULL THEN",
    "        RAISE EXCEPTION 'No profile with username %. Sign up that account in the app first.', seed_username;",
    "    END IF;",
    "",
    "    INSERT INTO cravecircle.recipes (id, owner_id, title, description, prep_time, cook_time, servings,",
    "        ingredients, directions, thumbnail_url, owner_username, source_language, nutrition, visibility)",
    "    VALUES",
]
rows = []
for r in recipes:
    # dailyCalories is required by older app builds' decoder; leaving it out broke their whole feed.
    nut = {k: r["nutrition"][k] for k in ("calories", "carbsG", "proteinG", "fatG", "estimated")}
    nut["dailyCalories"] = 2000
    rows.append(
        "        (" + ", ".join([
            sq(r["id"]), "seed_owner", sq(r["title"]), sq(r["description"]), sq(r["prepTime"]),
            sq(r["cookTime"]), str(r["servings"]),
            sq(json.dumps(r["ingredients"], ensure_ascii=False)) + "::jsonb",
            sq(json.dumps(r["directions"], ensure_ascii=False)) + "::jsonb",
            sq(f"{PHOTO_BASE}/{r['thumbnailUrl']}.jpg?v={PHOTO_VERSION}"), sq(r["ownerUsername"]), sq(r["sourceLanguage"]),
            sq(json.dumps(nut)) + "::jsonb", "'everyone'",
        ]) + ")"
    )
sql.append(",\n".join(rows))
sql += ["    ON CONFLICT (id) DO UPDATE SET thumbnail_url = EXCLUDED.thumbnail_url, nutrition = EXCLUDED.nutrition;", "END $$;", ""]
open(f"{ds}/seed_50_recipes.sql", "w").write("\n".join(sql))

print("recipes:", len(recipes))
