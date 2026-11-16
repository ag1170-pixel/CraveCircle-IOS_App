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
The app keeps its original 38 built-in recipes. These 50 live in the database and reach the
app like any published recipe (Fresh in your Circle, Suggested, search).

- `cravecircle_50_recipes.json` is the single source of truth.
- `seed_50_recipes.sql` inserts them into `cravecircle.recipes`, owned by a dedicated kitchen
  account (set `seed_username` at the top). Don't use your own account: recipes you own count
  as yours and are left out of Fresh / Suggested. Safe to re-run.
- `images/` holds the photos (1024 px, ~280 KB). `thumbnail_url` is the file name without
  `.jpg`; the app loads `recipe-thumbnails/<name>.jpg` from Supabase Storage.

### Load it (once)
1. Sign up the kitchen account in the app (e.g. username `cravecircle_kitchen`).
2. Upload the photos:
   ```bash
   SUPABASE_SERVICE_ROLE_KEY=... ./cravecircle_seed_dataset/upload_images.sh
   ```
3. Paste `seed_50_recipes.sql` into the Supabase SQL editor and run it.

### Change a recipe
Edit the JSON, then regenerate the SQL and re-run it:

```bash
python3 cravecircle_seed_dataset/generate.py "$PWD"
```
