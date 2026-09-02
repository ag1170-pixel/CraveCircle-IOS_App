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
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid
from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Header, BackgroundTasks
from pydantic import BaseModel

from .transcriber import transcribe, MODEL_NAME, DEVICE, _model

app = FastAPI(title="CraveCircle Local Backend & Transcriber", version="2.0")
API_KEY = os.getenv("WHISPER_API_KEY", "")

# In-memory stores for dev & preview
JOBS: dict[str, dict] = {}
RECIPES: dict[str, dict] = {}
GROCERY_LIST: list[dict] = []

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
    if COOKIES_FILE and os.path.exists(COOKIES_FILE):
        auth = ["--cookies", COOKIES_FILE]
    elif COOKIES_BROWSER:
        auth = ["--cookies-from-browser", COOKIES_BROWSER]

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


_CTA = re.compile(r"(follow|link in bio|comment below|save this|tag a|subscribe|full recipe|check out|dm me|like and)", re.I)
_SECTION_ING = re.compile(r"^\s*ingredients?\s*:?\s*$", re.I)
_SECTION_DIR = re.compile(r"^\s*(directions?|method|steps?|instructions?)\s*:?\s*$", re.I)
_END_SECTIONS = re.compile(r"^\s*(notes?|tips?|subscribe|more recipes|follow|socials?|newsletter)\s*:?\s*$", re.I)


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
_IMPERATIVE = re.compile(r"^\s*(add|mix|stir|pour|heat|bake|cook|fry|boil|simmer|whisk|combine|blend|chop|slice|dice|season|serve|fold|knead|marinate|grill|roast|preheat|drain|cover|remove|garnish|sprinkle|coat|dip|layer|spread|place|cut|melt|beat|toss|saute|saut|sear|rest|let|transfer|top|bring|reduce|flip|repeat|set)\b", re.I)


def _parse_structured_lines(text: str, capture_title: bool) -> tuple[str, list[dict], list[str]]:
    """Parse caption/on-screen text that uses Ingredients:/Method: section headers."""
    title = ""
    groups: list[dict] = []
    directions: list[str] = []
    cur = None
    mode = None

    for raw in text.splitlines():
        line = raw.strip()
        if not line or not _is_latin(line) or line.startswith("#"):
            continue
        if _CTA.search(line) or line.startswith(("http://", "https://", "►", "• http")):
            continue
        if _END_SECTIONS.match(line):
            mode = None
            continue

        if capture_title and not title:
            clean_t = re.sub(r"\s+", " ", re.sub(r"[^\w\s'&()\-,.]", "", line)).strip()
            if 3 <= len(clean_t) <= 60:
                title = clean_t
                continue

        if _SECTION_ING.match(line):
            mode, cur = "ing", None
            continue
        if _SECTION_DIR.match(line):
            mode = "dir"
            continue
        if mode == "ing":
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
            if step and not step.startswith(("http://", "https://")) and len(step) > 4:
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


def parse_recipe_content(caption: str, transcript: str, video_title: str = "",
                         author: str = "", ocr_text: str = "") -> dict:
    title = video_title.strip() if video_title and not video_title.startswith("Video by") else ""

    cap_title, groups, directions = _parse_structured_lines(caption, capture_title=not title)
    if not title:
        title = cap_title

    # Narration (Whisper transcript) fills missing steps / ingredients.
    if not directions and transcript.strip():
        for s in re.split(r"(?<=[.!?])\s+", transcript.strip()):
            s_clean = s.strip()
            if len(s_clean) > 12 and not _CTA.search(s_clean):
                directions.append(s_clean)
    if not groups and transcript.strip():
        items = _extract_conversational_ingredients(transcript)
        if items:
            groups = [{"group_name": "Main Ingredients", "items": items}]

    # On-screen text (OCR) fallback — used when there's no caption recipe and no narration.
    if ocr_text.strip():
        ocr_title, ocr_groups, ocr_dirs = _parse_structured_lines(ocr_text, capture_title=not title)
        if not title:
            title = ocr_title
        heur_items, heur_dirs = _extract_from_ocr(ocr_text)
        if not groups:
            merged = []
            for g in ocr_groups:
                merged += g["items"]
            merged += [i for i in heur_items if i not in merged]
            if merged:
                groups = [{"group_name": "Main Ingredients", "items": merged}]
        if not directions:
            directions = ocr_dirs or heur_dirs

    if not title:
        title = "Delicious Homemade Recipe"

    nutrition = estimate_nutrition(groups, servings=2)

    return {
        "title": title,
        "description": f"Extracted from @{author}'s cooking reel." if author else "Freshly extracted cooking reel recipe.",
        "prep_time": "10 min",
        "cook_time": "15 min",
        "servings": 2,
        "ingredients": groups,
        "directions": [{"step_index": i + 1, "text": t} for i, t in enumerate(directions)],
        "nutrition": nutrition
    }


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

            # One capped-resolution video file gives us BOTH the audio (Whisper) and the
            # frames (on-screen-text OCR). Works for Instagram / Facebook / YouTube / TikTok.
            JOBS[job_id]["status"] = "transcribing"
            media_out = os.path.join(tmp, "media.%(ext)s")
            _run_ytdlp(["-f", "best[height<=720]/best", "-o", media_out], url)
            media_files = [f for f in glob.glob(os.path.join(tmp, "media.*")) if not f.endswith(".json")]
            if not media_files:
                raise RuntimeError("Couldn't download that video. Try another public link.")
            media_path = media_files[0]

            # Whisper reads the audio straight from the video via ffmpeg. If the clip has no
            # audio (music-only / silent), we simply get an empty transcript — no crash.
            try:
                r = transcribe(media_path, language=None, task="transcribe")
                transcript, source_lang = r.text, (r.language or "en")
            except Exception:
                transcript, source_lang = "", "en"

            JOBS[job_id]["status"] = "extracting"
            parsed = parse_recipe_content(caption, transcript, video_title=video_title, author=author)

            # Fallback: nothing solid from caption + narration => read ON-SCREEN text (OCR).
            # This rescues the common case of a silent reel with the recipe only on screen.
            if not _recipe_is_complete(parsed):
                ocr_text = _ocr_video_frames(media_path, tmp)
                if ocr_text.strip():
                    parsed = parse_recipe_content(caption, transcript, video_title=video_title,
                                                  author=author, ocr_text=ocr_text)

            # Truly nothing usable (no audio, no caption, no readable on-screen text) =>
            # fail gracefully with a clear reason instead of storing an empty recipe.
            if not _has_recipe_content(parsed):
                raise RuntimeError(
                    "This video has no spoken steps, caption, or on-screen text we could read. "
                    "Try a reel where the creator narrates or lists the recipe."
                )

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
                "source_language": source_lang,
                "nutrition": parsed["nutrition"]
            }

            RECIPES[recipe_id] = recipe_obj
            JOBS[job_id]["recipe_id"] = recipe_id
            JOBS[job_id]["status"] = "done"

    except Exception as e:
        JOBS[job_id]["status"] = "error"
        JOBS[job_id]["error_message"] = str(e)


# MARK: - REST API Endpoints

@app.get("/health")
def health() -> dict:
    return {"ok": True, "service": "cravecircle-backend", "model": MODEL_NAME, "device": DEVICE}


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
    all_recs = list(RECIPES.values())
    return all_recs[offset : offset + limit]


@app.get("/recipes/{recipe_id}")
async def get_recipe(recipe_id: str) -> dict:
    recipe = RECIPES.get(recipe_id)
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe


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

