"""
FastAPI server for CraveCircle: Whisper Transcriber + Reel-to-Recipe Pipeline.

Endpoints:
  GET  /health                      -> Service health & model status
  POST /transcribe                  -> Raw Whisper speech-to-text
  POST /reels/import                -> Starts async reel import job (Instagram / YouTube / TikTok)
  GET  /reels/import/{job_id}       -> Polls import status (queued -> downloading -> transcribing -> extracting -> done)
  GET  /recipes/{id}                -> Fetches structured Recipe JSON
  GET  /recipes                     -> Lists all recipes
  GET  /profile                     -> Current user profile
  GET  /grocery-list                -> Current grocery list
"""

from __future__ import annotations

import asyncio
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid
from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Header, BackgroundTasks
from fastapi.responses import HTMLResponse, FileResponse
from pydantic import BaseModel

from .transcriber import transcribe, detect_speech, MODEL_NAME, DEVICE, _model
from .translate import translate_recipe, translate_texts

app = FastAPI(title="CraveCircle Local Backend & Transcriber", version="2.0")
API_KEY = os.getenv("WHISPER_API_KEY", "")

import sqlite3

# Basic in-memory scaffolding for recipes (Preview only)
RECIPES: dict[str, dict] = {}
JOBS: dict[str, dict] = {}
GROCERY_LIST: list[dict] = []

DB_PATH = os.environ.get("DB_PATH", "/tmp/cravecircle_admin.db")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS feedback (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            user_handle TEXT,
            content TEXT,
            email TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

init_db()

COOKIES_BROWSER = os.getenv("COOKIES_BROWSER")
# Netscape cookies.txt inside the container (mounted). Lets us authenticate Instagram /
# Facebook / YouTube / TikTok downloads without a browser profile in the container.
COOKIES_FILE = os.getenv("COOKIES_FILE", "/cookies/cookies.txt")


def _friendly_ytdlp_error(stderr: str, url: str) -> str:
    """Turn a raw yt-dlp stderr into a short, user-facing reason."""
    s = (stderr or "").lower()
    if "login" in s or "cookies" in s or "empty media response" in s or "rate-limit" in s or "private" in s:
        return "This post needs a sign-in to download. It may be private, age-restricted, or the app's saved login expired."
    if "unsupported url" in s or "no video formats" in s:
        return "That link isn't a supported video. Paste a public Reel, Short, TikTok, or Facebook video link."
    if "unavailable" in s or "not found" in s or "404" in s:
        return "That video is unavailable or was removed."
    # last non-empty line of stderr, trimmed
    lines = [ln.strip() for ln in (stderr or "").splitlines() if ln.strip()]
    return (lines[-1][:180] if lines else "Couldn't fetch that video. Try another link.")


def _run_ytdlp(extra_args: list[str], url: str) -> subprocess.CompletedProcess:
    """Run yt-dlp across platforms (Instagram / Facebook / YouTube / TikTok).

    Auth order: mounted cookies.txt (preferred) -> browser profile (dev) -> anonymous.
    Raises RuntimeError with a friendly message on failure.
    """
    base = [sys.executable, "-m", "yt_dlp", "--no-warnings", "--extractor-args", "youtube:player_client=android"]

    auth: list[str] = []
    tmp_cookies_path = None
    if COOKIES_FILE and os.path.exists(COOKIES_FILE):
        try:
            with tempfile.NamedTemporaryFile(suffix=".txt", delete=False) as tf:
                tmp_cookies_path = tf.name
            shutil.copy(COOKIES_FILE, tmp_cookies_path)
            auth = ["--cookies", tmp_cookies_path]
        except Exception:
            auth = ["--cookies", COOKIES_FILE]
    elif COOKIES_BROWSER:
        auth = ["--cookies-from-browser", COOKIES_BROWSER]

    try:
        res = subprocess.run(base + auth + extra_args + [url], capture_output=True, text=True)
        if res.returncode == 0:
            return res

        # A public URL can fail *because* of stale cookies — retry once anonymously.
        if auth:
            res_anon = subprocess.run(base + extra_args + [url], capture_output=True, text=True)
            if res_anon.returncode == 0:
                return res_anon
            res = res_anon

        raise RuntimeError(_friendly_ytdlp_error(res.stderr, url))
    finally:
        if tmp_cookies_path and os.path.exists(tmp_cookies_path):
            try:
                os.remove(tmp_cookies_path)
            except Exception:
                pass


def _check_key(provided: Optional[str]) -> None:
    if API_KEY and provided != API_KEY:
        raise HTTPException(status_code=401, detail="invalid api key")


@app.on_event("startup")
def _warm() -> None:
    _model()
    _seed_initial_recipes()


def _seed_initial_recipes() -> None:
    seed_id = "recipe-butter-chicken"
    RECIPES[seed_id] = {
        "id": seed_id,
        "owner_id": "creator-ananya",
        "title": "Old Delhi Butter Chicken",
        "description": "Smoky char-grilled chicken thighs simmered in a velvety fenugreek and tomato-butter gravy.",
        "prep_time": "30 min",
        "cook_time": "25 min",
        "servings": 4,
        "ingredients": [
            {
                "group_name": "Chicken Marinade",
                "items": [
                    "600g chicken thighs, boneless",
                    "1 cup yogurt",
                    "1 tbsp ginger-garlic paste",
                    "1 tsp kashmiri chili powder",
                    "1 tsp garam masala",
                    "1 tbsp mustard oil",
                    "1 tsp salt"
                ]
            },
            {
                "group_name": "Makhani Gravy",
                "items": [
                    "50g butter",
                    "400g ripe tomatoes, pureed",
                    "2 tbsp fresh cream",
                    "1 tbsp dried fenugreek leaves (kasuri methi)",
                    "1 tbsp honey",
                    "1 tsp garam masala"
                ]
            }
        ],
        "directions": [
            { "step_index": 1, "text": "Marinate chicken in yogurt, spices, ginger-garlic paste, and mustard oil for at least 30 minutes." },
            { "step_index": 2, "text": "Pan-sear or broil the chicken pieces on high heat until charred and 80% cooked." },
            { "step_index": 3, "text": "In a separate pan, melt butter and simmer pureed tomatoes with Kashmiri chili until the oil separates." },
            { "step_index": 4, "text": "Add the charred chicken pieces, heavy cream, honey, and crushed kasuri methi." },
            { "step_index": 5, "text": "Simmer for 8–10 minutes until glossy and rich. Serve hot with naan or rice." }
        ],
        "thumbnail_url": None,
        "owner_username": "@ananyacooks",
        "source_language": "en",
        "nutrition": {
            "calories": 520.0,
            "carbs_g": 14.0,
            "protein_g": 42.0,
            "fat_g": 34.0,
            "daily_calories": 2000.0,
            "estimated": False
        }
    }


_CTA = re.compile(r"(follow|link in bio|comment below|save this|tag a|subscribe|full recipe|check out|dm me|like and|for more|let me know|share this|tap the link)", re.I)
_SECTION_ING = re.compile(r"^\s*[*_~#\[({«<✨\s]*ingredients?\s*[*_~#\])}»>\s]*[-:–—=]?\s*$", re.I)
_SECTION_DIR = re.compile(r"^\s*[*_~#\[({«<✨\s]*(directions?|method|steps?|instructions?|process|recipe)\s*[*_~#\])}»>\s]*[-:–—=]?\s*$", re.I)
_END_SECTIONS = re.compile(r"^\s*(notes?|tips?|subscribe|more recipes|follow|socials?|newsletter)\s*[-:–—=]?\s*$", re.I)
# ponytail: Heuristic — social media intro lines are chatty sentences, not dish names.
# A dish name is typically short (< 45 chars) and doesn't read like a full sentence.
_FLUFF_LINE = re.compile(r"\b(feel like|this is|one of|try this|you.ll love|best thing|game changer|obsessed|can.t stop|here.s|you need|have to|must try|so good|amazing|delicious recipe|comfort food|perfect for|life changing|heaven|hug|craving|vibe|vibes|you won.t|believe)\b", re.I)


def _is_latin(line: str) -> bool:
    letters = [c for c in line if c.isalpha()]
    if not letters: return True
    latin = sum(1 for c in letters if ord(c) < 0x250)
    return latin / len(letters) > 0.5


def _strip_marker(line: str) -> str:
    line = re.sub(r"^\s*[-•*·]\s*", "", line)
    line = re.sub(r"^\s*\d+[.)]\s+", "", line)
    return line.strip()


def estimate_nutrition(ingredients: list[dict], servings: int = 2) -> dict:
    unit_grams = {
        "kg": 1000, "g": 1, "gram": 1, "grams": 1, "mg": 0.001,
        "l": 1000, "litre": 1000, "ml": 1,
        "lb": 454, "lbs": 454, "oz": 28,
        "cup": 200, "cups": 200, "tbsp": 15, "tablespoon": 15, "tsp": 5, "teaspoon": 5,
        "clove": 5, "cloves": 5, "slice": 20, "slices": 20, "can": 400, "pinch": 0.5,
        "egg": 50, "eggs": 50, "roti": 45, "chapati": 45
    }
    table = [
        ("buttermilk", {"kcal": 40, "carbs": 4.8, "protein": 3.3, "fat": 0.9}),
        ("butter", {"kcal": 717, "carbs": 0.1, "protein": 0.9, "fat": 81}),
        ("cornstarch", {"kcal": 381, "carbs": 91, "protein": 0.3, "fat": 0.1}),
        ("paneer", {"kcal": 265, "carbs": 6, "protein": 18, "fat": 20}),
        ("chicken", {"kcal": 165, "carbs": 0, "protein": 31, "fat": 3.6}),
        ("flour", {"kcal": 364, "carbs": 76, "protein": 10, "fat": 1}),
        ("pasta", {"kcal": 371, "carbs": 75, "protein": 13, "fat": 1.5}),
        ("macaroni", {"kcal": 371, "carbs": 75, "protein": 13, "fat": 1.5}),
        ("rice", {"kcal": 130, "carbs": 28, "protein": 2.7, "fat": 0.3}),
        ("onion", {"kcal": 40, "carbs": 9, "protein": 1.1, "fat": 0.1}),
        ("tomato", {"kcal": 18, "carbs": 3.9, "protein": 0.9, "fat": 0.2}),
        ("potato", {"kcal": 77, "carbs": 17, "protein": 2, "fat": 0.1}),
        ("garlic", {"kcal": 149, "carbs": 33, "protein": 6.4, "fat": 0.5}),
        ("cheddar", {"kcal": 402, "carbs": 1.3, "protein": 25, "fat": 33}),
        ("mozzarella", {"kcal": 300, "carbs": 2.2, "protein": 22, "fat": 22}),
        ("parmesan", {"kcal": 431, "carbs": 3.2, "protein": 38, "fat": 29}),
        ("cheese", {"kcal": 402, "carbs": 1.3, "protein": 25, "fat": 33}),
        ("cream", {"kcal": 340, "carbs": 2.8, "protein": 2.1, "fat": 36}),
        ("milk", {"kcal": 62, "carbs": 4.8, "protein": 3.2, "fat": 3.3}),
        ("egg", {"kcal": 155, "carbs": 1.1, "protein": 13, "fat": 11}),
        ("sugar", {"kcal": 387, "carbs": 100, "protein": 0, "fat": 0}),
        ("honey", {"kcal": 304, "carbs": 82, "protein": 0.3, "fat": 0}),
        ("oil", {"kcal": 884, "carbs": 0, "protein": 0, "fat": 100}),
    ]

    total_kcal, total_carbs, total_protein, total_fat = 0.0, 0.0, 0.0, 0.0
    for group in ingredients:
        for item in group.get("items", []):
            lower = item.lower()
            m_num = re.search(r"(\d+(?:\.\d+)?|\d+/\d+|½|¼|¾)", lower)
            qty = 1.0
            if m_num:
                raw_num = m_num.group(1)
                if raw_num == "½": qty = 0.5
                elif raw_num == "¼": qty = 0.25
                elif raw_num == "¾": qty = 0.75
                elif "/" in raw_num:
                    num, den = raw_num.split("/")
                    qty = float(num) / float(den)
                else:
                    qty = float(raw_num)
            
            unit = None
            for w in re.findall(r"[a-z]+", lower):
                if w in unit_grams:
                    unit = w
                    break
            
            grams = qty * unit_grams[unit] if unit else (qty * 60.0 if m_num else 80.0)
            macro = None
            for key, val in table:
                if key in lower:
                    macro = val
                    break
            if macro:
                f = grams / 100.0
                total_kcal += macro["kcal"] * f
                total_carbs += macro["carbs"] * f
                total_protein += macro["protein"] * f
                total_fat += macro["fat"] * f

    servings = max(1, servings)
    return {
        "calories": float(round(total_kcal / servings)),
        "carbs_g": float(round(total_carbs / servings, 1)),
        "protein_g": float(round(total_protein / servings, 1)),
        "fat_g": float(round(total_fat / servings, 1)),
        "daily_calories": 2000.0,
        "estimated": True
    }


def _extract_conversational_ingredients(transcript: str) -> list[str]:
    known = [
        ("macaroni", "200g elbow macaroni"),
        ("pasta", "200g pasta"),
        ("butter", "2 tbsp butter"),
        ("flour", "2 tbsp flour"),
        ("milk", "2 cups milk"),
        ("cheddar", "½ cup cheddar cheese"),
        ("mozzarella", "½ cup mozzarella cheese"),
        ("parmesan", "¼ cup parmesan cheese"),
        ("cheese", "1 cup shredded cheese blend"),
        ("chicken", "300g chicken"),
        ("garlic", "2 cloves garlic"),
        ("onion", "1 onion"),
        ("cream", "¼ cup cream"),
        ("eggs", "2 eggs"),
        ("egg", "2 eggs"),
        ("seasoning", "1 tsp mixed seasonings (paprika, black pepper, oregano)"),
    ]
    lower = transcript.lower()
    items = []
    seen = set()
    for key, formatted in known:
        if key in lower and key not in seen:
            items.append(formatted)
            seen.add(key)
    return items


# On-screen text (OCR) has no "Ingredients:"/"Method:" headers, so classify line-by-line:
# a line with a quantity+unit is an ingredient; a line starting with a cooking verb is a step.
_QTY_LINE = re.compile(r"\b(\d+(?:[.,/]\d+)?|½|¼|¾|⅓|⅔)\s*(g|kg|mg|ml|l|oz|lb|lbs|cup|cups|tbsp|tbs|tblsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons|clove|cloves|slice|slices|can|cans|pinch|egg|eggs|stick|sticks)\b", re.I)
_IMPERATIVE = re.compile(r"^\s*(add|mix|stir|pour|heat|bake|cook|fry|air\s*fry|boil|simmer|whisk|combine|blend|chop|slice|dice|season|serve|fold|knead|marinate|grill|roast|preheat|drain|cover|remove|garnish|sprinkle|coat|dip|layer|spread|place|cut|melt|beat|toss|saute|saut|sear|rest|let|transfer|top|bring|reduce|flip|repeat|set)\b", re.I)


def _parse_structured_lines(text: str, capture_title: bool) -> tuple[str, list[dict], list[str]]:
    """Parse caption/on-screen text that uses Ingredients:/Method: section headers."""
    title = ""
    groups: list[dict] = []
    directions: list[str] = []
    cur = None
    mode = None

    for raw in text.splitlines():
        line = raw.strip()
        if not line or not _is_latin(line) or line.startswith(("#", "[", "(tags", "tag:")):
            continue
        if _CTA.search(line) or line.startswith(("http://", "https://", "►", "• http")):
            continue
        if _END_SECTIONS.match(line):
            mode = None
            continue

        if capture_title and not title:
            clean_t = re.sub(r"\s+", " ", re.sub(r"[^\w\s'&()\-,.]", "", line)).strip()
            if 3 <= len(clean_t) <= 60:
                # Skip chatty social media intro sentences — dish names are short & specific
                if _FLUFF_LINE.search(clean_t) or (len(clean_t) > 40 and clean_t.count(" ") > 6):
                    continue
                title = clean_t
                continue

        if _SECTION_ING.match(line):
            mode, cur = "ing", None
            continue
        if _SECTION_DIR.match(line):
            mode = "dir"
            continue
        if mode == "ing":
            if _IMPERATIVE.match(line) and len(line) > 12 and not _QTY_LINE.search(line):
                mode = "dir"
                step = _strip_marker(line)
                if step and not step.startswith(("http://", "https://")) and len(step) > 4 and not _CTA.search(step):
                    directions.append(step)
                continue
            if line.endswith(":") and len(line) < 42:
                cur = {"group_name": line[:-1].strip(), "items": []}
                groups.append(cur)
                continue
            item = _strip_marker(line)
            if item and not item.startswith(("http://", "https://")):
                if cur is None:
                    cur = {"group_name": "Main Ingredients", "items": []}
                    groups.append(cur)
                cur["items"].append(item)
        elif mode == "dir":
            step = _strip_marker(line)
            if step and not step.startswith(("http://", "https://")) and len(step) > 4 and not _CTA.search(step):
                directions.append(step)

    return title, [g for g in groups if g["items"]], directions


def _extract_from_ocr(ocr_text: str) -> tuple[list[str], list[str]]:
    """Heuristic classifier for header-less on-screen text: quantities -> ingredients,
    cooking-verb lines -> steps. De-duplicates repeated captions across frames."""
    ingredients: list[str] = []
    directions: list[str] = []
    seen_i: set[str] = set()
    seen_d: set[str] = set()
    for raw in ocr_text.splitlines():
        line = _strip_marker(raw.strip())
        if len(line) < 3 or not _is_latin(line) or _CTA.search(line):
            continue
        low = line.lower()
        if _QTY_LINE.search(line) and len(line) <= 70:
            if low not in seen_i:
                seen_i.add(low); ingredients.append(line)
        elif _IMPERATIVE.match(line) and len(line) > 10:
            if low not in seen_d:
                seen_d.add(low); directions.append(line)
    return ingredients, directions


def _enrich_short_directions(directions: list, groups: list, title: str) -> list:
    """When a creator caption only provides the final cooking step (e.g. 'Air fry for 5-6 minutes'),
    flesh out the logical prep and assembly steps from the ingredient list."""
    if len(directions) >= 3:
        return directions

    all_items = []
    for g in groups:
        all_items.extend(g.get("items", []))

    if not all_items:
        return directions

    base_items = []
    sauce_items = []
    cheese_items = []
    main_mix = []
    cleaned_names = []

    for item in all_items:
        raw_name = re.sub(r"[-–—:]?\s*\d+[\d\s\/\.,]*(?:cup|tbsp|tsp|g|kg|ml|oz|lb|slice|piece|slices|pieces)?\s*", "", item, flags=re.IGNORECASE).strip()
        raw_name = re.sub(r"^[-–—:\s]+|[-–—:\s]+$", "", raw_name).strip()
        if not raw_name:
            continue
        cleaned_names.append(raw_name)
        low = raw_name.lower()
        if any(w in low for w in ["bread", "toast", "bun", "tortilla", "wrap", "base", "crust", "rice", "pasta", "noodle"]):
            base_items.append(raw_name)
        elif any(w in low for w in ["cheese", "mozzarella", "cheddar", "parmesan"]):
            cheese_items.append(raw_name)
        elif any(w in low for w in ["butter", "ghee", "oil"]):
            pass
        elif any(w in low for w in ["sauce", "paste", "mayo", "chutney"]):
            sauce_items.append(raw_name)
        else:
            main_mix.append(raw_name)

    enriched = []
    if main_mix:
        mix_str = ", ".join(main_mix[:5])
        if sauce_items:
            mix_str += f" and {sauce_items[0]}"
        enriched.append(f"In a mixing bowl, combine {mix_str}. Mix well until evenly coated.")
    elif cleaned_names:
        enriched.append(f"In a bowl, combine and prepare {', '.join(cleaned_names[:4])}.")

    if base_items:
        enriched.append(f"Arrange the {base_items[0]}. Spread a thin layer of butter or sauce, then spoon the prepared filling generously over each.")
    elif sauce_items and not main_mix:
        enriched.append(f"Stir in the {', '.join(sauce_items)} and mix thoroughly.")

    if cheese_items:
        enriched.append(f"Top generously with {', '.join(cheese_items)}.")

    if directions:
        for d in directions:
            d_clean = re.sub(r"\s*[😍❤️🔥👏👍]+", "", d).strip()
            if d_clean and d_clean not in enriched:
                enriched.append(d_clean)
    else:
        enriched.append("Cook until golden, crisp, and heated through.")

    enriched.append("Serve hot immediately and enjoy!")
    return enriched



def _has_recipe_content(parsed: dict) -> bool:
    """True if we extracted anything usable (ingredients or at least a couple of steps)."""
    has_ing = any(g.get("items") for g in parsed.get("ingredients", []))
    has_dir = len(parsed.get("directions", [])) >= 1
    return has_ing or has_dir


def _recipe_is_complete(parsed: dict) -> bool:
    has_ing = any(g.get("items") for g in parsed.get("ingredients", []))
    has_dir = len(parsed.get("directions", [])) >= 2
    return has_ing and has_dir


def _ocr_video_frames(media_path: str, tmp: str, max_frames: int = 14) -> str:
    """Sample frames with ffmpeg and OCR them with tesseract. Returns joined on-screen text.
    Returns '' if tesseract/ffmpeg is unavailable — the caller degrades gracefully."""
    frames_dir = os.path.join(tmp, "frames")
    os.makedirs(frames_dir, exist_ok=True)
    try:
        subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", media_path,
             "-vf", "fps=1/2,scale=720:-2", "-frames:v", str(max_frames),
             os.path.join(frames_dir, "f_%03d.png")],
            capture_output=True, text=True, timeout=120,
        )
    except Exception:
        return ""

    lines: list[str] = []
    seen: set[str] = set()
    for fp in sorted(glob.glob(os.path.join(frames_dir, "f_*.png"))):
        try:
            out = subprocess.run(["tesseract", fp, "stdout", "--psm", "6"],
                                 capture_output=True, text=True, timeout=30)
        except Exception:
            return "\n".join(lines)   # tesseract missing — return whatever we have (likely '')
        for ln in out.stdout.splitlines():
            t = ln.strip()
            key = t.lower()
            if len(t) >= 3 and key not in seen:
                seen.add(key)
                lines.append(t)
    return "\n".join(lines)


def _caption_extract(caption: str, video_title: str) -> tuple[str, list, list]:
    """Extract (title, ingredient-groups, steps) from a caption — headers or header-less."""
    title = video_title.strip() if (video_title and not video_title.startswith("Video by")) else ""
    cap_title, groups, directions = _parse_structured_lines(caption, capture_title=not title)
    title = title or cap_title
    if caption.strip() and (not groups or not directions):
        items, dirs = _extract_from_ocr(caption)   # header-less heuristic
        if not groups and items:
            groups = [{"group_name": "Main Ingredients", "items": items}]
        if not directions and dirs:
            directions = dirs
    return title, groups, directions


def _has_qty(groups: list) -> bool:
    return any(_QTY_LINE.search(i) for g in groups for i in g.get("items", []))


def _transcript_steps(transcript: str) -> list:
    out = []
    for s in re.split(r"(?<=[.!?])\s+", transcript.strip()):
        s = s.strip()
        if len(s) > 12 and not _CTA.search(s):
            out.append(s)
    return out


def assemble_recipe(caption: str, transcript: str, ocr_text: str, has_speech: bool,
                    video_title: str = "", author: str = "") -> dict:
    """Best-source-per-field merge (pipeline v2).
    STEPS: prefer spoken narration when a person is genuinely cooking on-camera and it's
    substantial; else the caption; else on-screen text.
    INGREDIENTS: prefer the written caption (real quantities); else OCR; else audio-derived.
    """
    title, cap_groups, cap_dirs = _caption_extract(caption, video_title)

    # audio-derived
    aud_dirs = _transcript_steps(transcript) if transcript.strip() else []
    aud_items = _extract_conversational_ingredients(transcript) if transcript.strip() else []
    aud_groups = [{"group_name": "Main Ingredients", "items": aud_items}] if aud_items else []
    audio_is_cooking = bool(transcript.strip()) and _IMPERATIVE.search(transcript) is not None

    # ocr-derived
    ocr_items, ocr_dirs = _extract_from_ocr(ocr_text) if ocr_text.strip() else ([], [])
    ocr_groups = [{"group_name": "Main Ingredients", "items": ocr_items}] if ocr_items else []

    # STEPS — AUDIO FIRST (product spec): whenever there's genuine cooking narration, use the
    # spoken steps. Fall back to caption, then on-screen text, then any audio we have. Always
    # yields steps if any source produced them.
    if has_speech and audio_is_cooking and len(aud_dirs) >= 2:
        directions = aud_dirs
    elif cap_dirs:
        directions = cap_dirs
    elif ocr_dirs:
        directions = ocr_dirs
    else:
        directions = aud_dirs or cap_dirs or ocr_dirs or []

    # INGREDIENTS — written quantities win.
    if cap_groups and _has_qty(cap_groups):
        groups = cap_groups
    elif ocr_groups and _has_qty(ocr_groups):
        groups = ocr_groups
    elif cap_groups:
        groups = cap_groups
    elif ocr_groups:
        groups = ocr_groups
    else:
        groups = aud_groups

    if not title:
        title = "Delicious Homemade Recipe"

    if len(directions) < 3 and groups:
        directions = _enrich_short_directions(directions, groups, title)

    split_dirs = []
    for d in directions:
        parts = [p.strip() for p in re.split(r"(?<=[.!?])\s+", d) if p.strip()]
        if len(parts) > 1 and all(len(p) > 12 for p in parts):
            split_dirs.extend(parts)
        else:
            split_dirs.append(d)
    directions = split_dirs

    nutrition = estimate_nutrition(groups, servings=2)
    return {
        "title": title,
        "description": f"Extracted from @{author}'s cooking reel." if author else "Freshly extracted cooking reel recipe.",
        "prep_time": "10 min",
        "cook_time": "15 min",
        "servings": 2,
        "ingredients": groups,
        "directions": [{"step_index": i + 1, "text": t} for i, t in enumerate(directions)],
        "nutrition": nutrition,
    }


def _process_reel_import(job_id: str, url: str, target_language: str) -> None:
    JOBS[job_id]["status"] = "downloading"
    local_tmp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".tmp")
    os.makedirs(local_tmp, exist_ok=True)

    try:
        with tempfile.TemporaryDirectory(dir=local_tmp) as tmp:
            res_meta = _run_ytdlp(["--dump-json"], url)
            meta = json.loads(res_meta.stdout)

            caption = (meta.get("description") or "").strip()
            author = meta.get("uploader") or meta.get("channel") or meta.get("uploader_id") or "chef"
            thumbnail = meta.get("thumbnail")
            video_title = meta.get("title") or ""

            # PIPELINE v2 — best source per field (audio-first for steps, caption for quantities).
            transcript, source_lang, has_speech = "", "en", False

            # 1) Download AUDIO only (small & fast) to check for narration and transcribe it.
            JOBS[job_id]["status"] = "downloading"
            audio_out = os.path.join(tmp, "audio.%(ext)s")
            try:
                _run_ytdlp(["-f", "bestaudio/best", "-o", audio_out], url)
            except Exception:
                pass
            audio_files = [f for f in glob.glob(os.path.join(tmp, "audio.*")) if not f.endswith(".json")]

            # 2) VAD: is a person actually narrating, or is it just a music/B-roll bed?
            if audio_files:
                JOBS[job_id]["status"] = "transcribing"
                has_speech, _secs = detect_speech(audio_files[0])
                if has_speech:                       # only pay for Whisper when someone's talking
                    try:
                        r = transcribe(audio_files[0], language=None, task="transcribe")
                        transcript, source_lang = r.text, (r.language or "en")
                    except Exception:
                        transcript = ""

            # 3) Merge caption + audio (best per field).
            JOBS[job_id]["status"] = "extracting"
            parsed = assemble_recipe(caption, transcript, "", has_speech,
                                     video_title=video_title, author=author)

            # 4) Still thin → grab the video and OCR the on-screen text (silent recipe overlays).
            if not _recipe_is_complete(parsed):
                video_out = os.path.join(tmp, "video.%(ext)s")
                try:
                    _run_ytdlp(["-f", "best[height<=720]/best", "-o", video_out], url)
                    vids = [f for f in glob.glob(os.path.join(tmp, "video.*")) if not f.endswith(".json")]
                    if vids:
                        ocr_text = _ocr_video_frames(vids[0], tmp)
                        if ocr_text.strip():
                            parsed = assemble_recipe(caption, transcript, ocr_text, has_speech,
                                                     video_title=video_title, author=author)
                except Exception:
                    pass

            # Truly nothing usable (no audio, no caption, no readable on-screen text) =>
            # fail gracefully with a clear reason instead of storing an empty recipe.
            if not _has_recipe_content(parsed):
                raise RuntimeError(
                    "This video has no spoken steps, caption, or on-screen text we could read. "
                    "Try a reel where the creator narrates or lists the recipe."
                )

            # 5) MULTILINGUAL: translate the assembled recipe into the user's chosen language.
            # Best-effort — if it can't translate, the original recipe is kept (import never fails).
            JOBS[job_id]["status"] = "translating"
            parsed = translate_recipe(parsed, target_language)

            recipe_id = f"recipe-{uuid.uuid4().hex[:8]}"
            recipe_obj = {
                "id": recipe_id,
                "owner_id": f"creator-{author}",
                "title": parsed["title"],
                "description": parsed["description"],
                "prep_time": parsed["prep_time"],
                "cook_time": parsed["cook_time"],
                "servings": parsed["servings"],
                "ingredients": parsed["ingredients"],
                "directions": parsed["directions"],
                "thumbnail_url": thumbnail,
                "owner_username": f"@{author}" if not author.startswith("@") else author,
                "source_language": parsed.get("source_language") or source_lang,
                "source_url": url,
                "nutrition": parsed["nutrition"]
            }

            RECIPES[recipe_id] = recipe_obj
            JOBS[job_id]["recipe_id"] = recipe_id
            JOBS[job_id]["status"] = "done"

    except Exception as e:
        JOBS[job_id]["status"] = "error"
        JOBS[job_id]["error_message"] = str(e)


# MARK: - Feedback & Admin Endpoints

class FeedbackSubmit(BaseModel):
    type: str
    user_handle: Optional[str] = None
    content: str
    email: Optional[str] = None

@app.post("/feedback")
def submit_feedback(req: FeedbackSubmit):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute(
        "INSERT INTO feedback (type, user_handle, content, email) VALUES (?, ?, ?, ?)",
        (req.type, req.user_handle, req.content, req.email)
    )
    conn.commit()
    conn.close()
    return {"status": "ok"}

@app.get("/admin/feedback")
def get_all_feedback():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT * FROM feedback ORDER BY created_at DESC")
    rows = c.fetchall()
    conn.close()
    return [dict(ix) for ix in rows]

# MARK: - Grocery / Profile Endpoints

MEDIA_CACHE_DIR = "/tmp/cravecircle_media"
os.makedirs(MEDIA_CACHE_DIR, exist_ok=True)

def _clean_old_media():
    now = time.time()
    for f in glob.glob(os.path.join(MEDIA_CACHE_DIR, "*")):
        try:
            if os.path.isfile(f) and now - os.path.getmtime(f) > 3600:
                os.remove(f)
        except Exception:
            pass

class ReelDownloadRequest(BaseModel):
    url: str

class ReelDownloadResponse(BaseModel):
    media_id: str
    title: str
    caption: str
    author: str
    thumbnail: Optional[str]
    download_url: str

@app.post("/reels/download", response_model=ReelDownloadResponse)
def download_reel(req: ReelDownloadRequest, bg: BackgroundTasks):
    media_id = f"reel_{uuid.uuid4().hex[:12]}"
    out_template = os.path.join(MEDIA_CACHE_DIR, f"{media_id}.%(ext)s")
    
    try:
        res_meta = _run_ytdlp(["--dump-json"], req.url)
        meta = json.loads(res_meta.stdout)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
        
    title = meta.get("title") or "Cooking Reel"
    caption = (meta.get("description") or "").strip()
    author = meta.get("uploader") or meta.get("channel") or meta.get("uploader_id") or "chef"
    thumbnail = meta.get("thumbnail")

    try:
        _run_ytdlp([
            # Prefer H.264 (avc1) video + AAC audio: iOS AVFoundation can't decode VP9/AV1, so a VP9
            # download transcribes fine (AAC audio) but can't yield a thumbnail frame. Fall back to
            # any format only if H.264 isn't available.
            "-f", ("bestvideo[vcodec^=avc1][height<=720]+bestaudio[ext=m4a]/"
                   "best[vcodec^=avc1][height<=720]/"
                   "bestvideo[height<=720]+bestaudio/best[height<=720]/best"),
            "--merge-output-format", "mp4",
            "-o", out_template
        ], req.url)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to download video: {e}")

    candidates = glob.glob(os.path.join(MEDIA_CACHE_DIR, f"{media_id}.*"))
    if not candidates:
        raise HTTPException(status_code=500, detail="Video downloaded but file not found on disk")
        
    actual_file = candidates[0]
    filename = os.path.basename(actual_file)

    # Server-side cover frame (priority 2): ffmpeg decodes VP9/AV1 that iOS AVFoundation can't, so a
    # real frame is available for every reel regardless of codec. Prefer this over the reel's poster
    # image; if ffmpeg fails, keep the reel's own thumbnail (priority 3). The app tries its own
    # on-device frame first (priority 1) and only downloads this when that fails.
    thumb_file = os.path.join(MEDIA_CACHE_DIR, f"{media_id}.jpg")
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-ss", "1", "-i", actual_file, "-frames:v", "1",
             "-vf", "scale='min(800,iw)':-2", "-q:v", "3", thumb_file],
            check=True, capture_output=True, timeout=30,
        )
        if os.path.exists(thumb_file) and os.path.getsize(thumb_file) > 0:
            thumbnail = f"/reels/media/{media_id}.jpg"
    except Exception:
        pass  # fall back to the reel's own poster image (already in `thumbnail`)

    bg.add_task(_clean_old_media)

    return ReelDownloadResponse(
        media_id=media_id,
        title=title,
        caption=caption,
        author=author,
        thumbnail=thumbnail,
        download_url=f"/reels/media/{filename}"
    )

@app.get("/reels/media/{filename}")
def get_reel_media(filename: str):
    safe_name = os.path.basename(filename)
    file_path = os.path.join(MEDIA_CACHE_DIR, safe_name)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Media file expired or not found")
    return FileResponse(file_path, media_type="video/mp4", filename=safe_name)

@app.get("/health")
def health() -> dict:
    return {"ok": True, "service": "cravecircle-backend", "model": MODEL_NAME, "device": DEVICE}


class TranslateTextRequest(BaseModel):
    texts: list[str]
    target_language: Optional[str] = "en"


@app.post("/translate-text")
def translate_text_endpoint(req: TranslateTextRequest) -> dict:
    """Translate a list of strings into the user's language. Used by the on-device import path to
    bring a recipe transcribed/extracted on the phone into the user's chosen language. Best-effort:
    returns the originals unchanged if translation isn't needed or fails."""
    return {"texts": translate_texts(req.texts, req.target_language)}


class ImportRequest(BaseModel):
    url: str
    target_language: Optional[str] = "en"


@app.post("/reels/import")
async def submit_reel_import(req: ImportRequest, bg: BackgroundTasks) -> dict:
    job_id = f"job-{uuid.uuid4().hex[:10]}"
    JOBS[job_id] = {
        "id": job_id,
        "status": "queued",
        "url": req.url,
        "target_language": req.target_language,
        "recipe_id": None,
        "error_message": None
    }
    bg.add_task(_process_reel_import, job_id, req.url, req.target_language)
    return {"job_id": job_id, "status": "queued"}


@app.get("/reels/import/{job_id}")
async def get_import_job(job_id: str) -> dict:
    job = JOBS.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return {
        "id": job["id"],
        "status": job["status"],
        "recipe_id": job.get("recipe_id"),
        "error_message": job.get("error_message")
    }


@app.get("/recipes")
async def list_recipes(limit: int = 20, offset: int = 0) -> list[dict]:
    # Newest first, so a freshly imported reel is always in the first page the app fetches
    # (old oldest-first slicing hid new imports once there were >limit recipes).
    all_recs = list(RECIPES.values())[::-1]
    return all_recs[offset : offset + limit]


@app.get("/recipes/{recipe_id}")
async def get_recipe(recipe_id: str) -> dict:
    recipe = RECIPES.get(recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe


@app.get("/recipes")
async def get_all_recipes() -> list[dict]:
    # Return everything in memory
    return list(RECIPES.values())

@app.delete("/recipes/{recipe_id}")
async def delete_recipe(recipe_id: str):
    if recipe_id in RECIPES:
        del RECIPES[recipe_id]
        return {"status": "ok"}
    raise HTTPException(status_code=404, detail="Recipe not found")

@app.get("/profile")
async def get_profile() -> dict:
    return {
        "id": "preview-user",
        "username": "@you",
        "full_name": "CraveCircle Chef",
        "avatar_url": None
    }


@app.get("/grocery-list")
async def get_grocery_list() -> list[dict]:
    return GROCERY_LIST


@app.post("/grocery-list/{recipe_id}")
async def add_recipe_to_grocery(recipe_id: str) -> list[dict]:
    recipe = RECIPES.get(recipe_id)
    if recipe:
        for group in recipe.get("ingredients", []):
            for item in group.get("items", []):
                GROCERY_LIST.append({
                    "id": f"groc-{uuid.uuid4().hex[:6]}",
                    "ingredient_name": item,
                    "checked": False
                })
    return GROCERY_LIST



@app.get("/recipe/{recipe_id}", response_class=HTMLResponse)
async def recipe_landing_page(recipe_id: str):
    html_content = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>CraveCircle Shared Recipe</title>
        <meta property="og:title" content="View this recipe on CraveCircle">
        <meta property="og:description" content="Tap to open the recipe in the CraveCircle app.">
        <style>
            body {{ background: #1C1C1E; color: white; font-family: -apple-system, sans-serif; text-align: center; padding-top: 80px; margin: 0; }}
            .container {{ padding: 20px; }}
            .title {{ font-size: 24px; font-weight: bold; margin-bottom: 10px; }}
            .subtitle {{ color: #AEAEB2; font-size: 16px; margin-bottom: 40px; }}
            .btn {{ display: inline-block; background: #FF5A5F; color: white; text-decoration: none; padding: 16px 32px; border-radius: 30px; font-weight: bold; font-size: 18px; }}
            .hint {{ color: #8E8E93; font-size: 14px; margin-top: 24px; }}
        </style>
        <script>
            window.onload = function() {{
                var appLink = "cravecircle:/" + window.location.pathname;
                document.getElementById('openBtn').href = appLink;
                setTimeout(function() {{
                    window.location.href = appLink;
                }}, 500);
            }};
        </script>
    </head>
    <body>
        <div class="container">
            <div class="title">CraveCircle</div>
            <div class="subtitle">You've been invited to view a recipe!</div>
            <a href="#" id="openBtn" class="btn">Open in App</a>
            <div class="hint">If you have CraveCircle installed, tap the button above or accept the prompt to jump right in.</div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)
