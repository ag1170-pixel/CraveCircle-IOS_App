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
key="$SUPABASE_SERVICE_ROLE_KEY"

# The service role key is a JWT: three dot-separated parts starting "eyJ". The anon key looks the
# same but can't write here, so also check the role inside it.
if [[ "$key" != eyJ*.*.* ]]; then
  echo "That doesn't look like a service role key (expected a JWT starting with eyJ)." >&2
  exit 1
fi
payload="$(printf '%s' "$key" | cut -d. -f2 | tr '_-' '/+')"
while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done
role="$(printf '%s' "$payload" | base64 -d 2>/dev/null | grep -o '"role":"[^"]*"' || true)"
if [ "$role" != '"role":"service_role"' ]; then
  echo "This key has ${role:-no role}; it must be the service_role key, not the anon key." >&2
  exit 1
fi
dir="$(cd "$(dirname "$0")" && pwd)/images"

ok=0
for img in "$dir"/recipe_*.jpg; do
  name="$(basename "$img")"
  body="$(curl -s -w $'\n%{http_code}' -X POST \
    "$base/storage/v1/object/recipe-thumbnails/$name" \
    -H "Authorization: Bearer $key" \
    -H "apikey: $key" \
    -H "Content-Type: image/jpeg" \
    -H "x-upsert: true" \
    -H "Cache-Control: max-age=31536000" \
    --data-binary "@$img")"
  code="${body##*$'\n'}"
  if [ "$code" != "200" ]; then
    echo "failed ($code) on $name: ${body%$'\n'*}" >&2
    echo "uploaded $ok before stopping." >&2
    exit 1
  fi
  ok=$((ok + 1))
done
echo "uploaded $ok"
