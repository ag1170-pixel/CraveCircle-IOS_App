#!/usr/bin/env bash
# Upload the 50 seed photos to the public `recipe-thumbnails` bucket, as <name>.jpg at the
# bucket root (where the app looks for a cover named e.g. "recipe_carbonara").
#
# Usage (from the repo root):
#   SUPABASE_SERVICE_ROLE_KEY=... ./cravecircle_seed_dataset/upload_images.sh
# Optional: SUPABASE_URL (defaults to https://db.cravecircle.cc). Re-running overwrites.
set -euo pipefail

: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY (Supabase service role key)}"
base="${SUPABASE_URL:-https://db.cravecircle.cc}"
dir="$(cd "$(dirname "$0")" && pwd)/images"

ok=0; fail=0
for img in "$dir"/recipe_*.jpg; do
  name="$(basename "$img")"
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$base/storage/v1/object/recipe-thumbnails/$name" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
    -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
    -H "Content-Type: image/jpeg" \
    -H "x-upsert: true" \
    -H "Cache-Control: max-age=31536000" \
    --data-binary "@$img")
  if [ "$code" = "200" ]; then ok=$((ok + 1)); else fail=$((fail + 1)); echo "failed ($code): $name"; fi
done
echo "uploaded $ok, failed $fail"
