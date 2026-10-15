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
    # APNs device registry — maps a signed-in user to their device push tokens, so a background
    # share-import can push "recipe ready" when it finishes. Populated by POST /devices.
    c.execute('''
        CREATE TABLE IF NOT EXISTS devices (
            apns_token TEXT PRIMARY KEY,
            user_id TEXT,
            platform TEXT,
            environment TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()

init_db()

COOKIES_BROWSER = os.getenv("COOKIES_BROWSER")
# Netscape cookies.txt inside the container (mounted). Lets us authenticate Instagram /
# Facebook / YouTube / TikTok downloads without a browser profile in the container.
COOKIES_FILE = os.getenv("COOKIES_FILE", "/cookies/cookies.txt")

# OpenAI-compatible LLM endpoint on the Homelab for target-language translation.
# Defaults match the docker-compose Ollama service on the same network. Empty URL
# disables translation and delivers the recipe in the source language.
LLM_TRANSLATOR_URL = os.getenv("LLM_TRANSLATOR_URL", "http://ollama:11434/v1")
LLM_TRANSLATOR_MODEL = os.getenv("LLM_TRANSLATOR_MODEL", "qwen2.5:7b")
LLM_TRANSLATOR_KEY = os.getenv("LLM_TRANSLATOR_KEY", "")
LLM_TRANSLATOR_TIMEOUT_S = float(os.getenv("LLM_TRANSLATOR_TIMEOUT_S", "60"))

_LANG_NAMES = {
    "en": "English", "hi": "Hindi", "mr": "Marathi", "ta": "Tamil",
    "te": "Telugu", "bn": "Bengali", "es": "Spanish", "fr": "French",
}


def _norm_lang(code: Optional[str]) -> str:
    return (code or "")[:2].lower()


def recipe_text_lang(transcript: str, source_lang: str) -> str:
    """Language of the text we are about to save."""
    # ponytail: this import always calls Whisper with task=translate, so a non-empty
    # transcript is English even when source_lang is the spoken language. If that call
    # switches to task=transcribe, detect the transcript instead of assuming English.
    return "en" if (transcript or "").strip() else (source_lang or "")


def translate_recipe(parsed: dict, source_lang: str, target_lang: str) -> dict:
    """Translate title/description/times/ingredient items/direction texts into target_lang.
    Preserves structure and array lengths. Returns parsed unchanged when translation isn't
    needed (same language, unknown target) or the LLM is unreachable — the recipe still gets
    saved, just in the source language."""
    src = _norm_lang(source_lang)
    tgt = _norm_lang(target_lang)
    if not tgt or src == tgt:
        return parsed
    target_name = _LANG_NAMES.get(tgt)
    if not target_name or not LLM_TRANSLATOR_URL:
        return parsed

    payload = {
        "title": parsed.get("title", ""),
        "description": parsed.get("description", ""),
        "prep_time": parsed.get("prep_time", ""),
        "cook_time": parsed.get("cook_time", ""),
        "ingredients": [
            {"group_name": g.get("group_name", ""), "items": list(g.get("items", []))}
            for g in parsed.get("ingredients", [])
        ],
        "directions": [d.get("text", "") for d in parsed.get("directions", [])],
    }

    system = (
        f"You are a professional culinary translator. Translate the recipe's user-facing text "
        f"into {target_name}. Keep the EXACT same JSON shape and array lengths. Preserve all "
        f"numbers, quantities, and units (e.g. '200g', '2', '8 min') unchanged. Do not add, "
        f"remove, or reorder items. Return ONLY the JSON object, no prose, no code fences."
    )
    user = f"Translate this recipe JSON to {target_name}:\n{json.dumps(payload, ensure_ascii=False)}"

    body = json.dumps({
        "model": LLM_TRANSLATOR_MODEL,
        "stream": False,
        "format": "json",  # Ollama honors this; others ignore it
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }).encode("utf-8")

    url = LLM_TRANSLATOR_URL.rstrip("/") + "/chat/completions"
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    if LLM_TRANSLATOR_KEY:
        req.add_header("Authorization", f"Bearer {LLM_TRANSLATOR_KEY}")
    try:
        with urllib.request.urlopen(req, timeout=LLM_TRANSLATOR_TIMEOUT_S) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
        data = json.loads(raw)
        content = data["choices"][0]["message"]["content"]
        content = content.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        out = json.loads(content)
    except Exception as e:
        print(f"[translate] skipping ({tgt}): {e}", flush=True)
        return parsed

    res = dict(parsed)
    res["title"] = (out.get("title") or parsed.get("title") or "").strip() or parsed.get("title", "")
    res["description"] = (out.get("description") or parsed.get("description") or "").strip() or parsed.get("description", "")
    res["prep_time"] = out.get("prep_time") or parsed.get("prep_time", "")
    res["cook_time"] = out.get("cook_time") or parsed.get("cook_time", "")

    src_groups = parsed.get("ingredients", [])
    tr_groups = out.get("ingredients", [])
    if isinstance(tr_groups, list) and len(tr_groups) == len(src_groups):
        new_groups = []
        for sg, tg in zip(src_groups, tr_groups):
            src_items = sg.get("items", [])
            tr_items = tg.get("items", []) if isinstance(tg, dict) else []
            if len(tr_items) == len(src_items):
                items = [(ti.strip() or si) for si, ti in zip(src_items, tr_items)]
            else:
                items = src_items
            new_groups.append({
                "group_name": (tg.get("group_name") if isinstance(tg, dict) else "") or sg.get("group_name", ""),
                "items": items,
            })
        res["ingredients"] = new_groups

    src_dirs = parsed.get("directions", [])
    tr_dirs = out.get("directions", [])
    if isinstance(tr_dirs, list) and len(tr_dirs) == len(src_dirs):
        res["directions"] = [
            {"step_index": sd.get("step_index", i + 1), "text": (td.strip() if isinstance(td, str) and td.strip() else sd.get("text", ""))}
            for i, (sd, td) in enumerate(zip(src_dirs, tr_dirs))
        ]

    return res


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
_SECTION_ING = re.compile(r"^\s*[*_~#\[({«<✨\s]*(ingredients?|ingredientes|ingredienti|ingrédients)\s*[*_~#\])}»>\s]*[-:–—=]?\s*$", re.I)
_SECTION_DIR = re.compile(r"^\s*[*_~#\[({«<✨\s]*(directions?|method|steps?|instructions?|process|recipe|modo de preparo|preparo|preparação|preparación|pasos|preparazione|istruzioni|préparation|étapes)\s*[*_~#\])}»>\s]*[-:–—=]?\s*$", re.I)
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


# Caption tag dumps: "(panerecipe, viralreels, foodporn, ...)". Kitchen notes like
# "(optional)" or "(finely chopped)" are not dumps.
_SOCIAL_TAG = ("recipe", "reel", "viral", "blogger", "foodporn", "shorts", "foodie")


def _is_social_tag_dump(line: str) -> bool:
    s = line.strip()
    if s.count("#") >= 2:
        return True
    wrapped = len(s) >= 2 and s.startswith("(") and s.endswith(")")
    body = s[1:-1].strip() if wrapped else s
    parts = [p.strip() for p in body.split(",") if p.strip()]
    # A real ingredient has a space ("1 onion, chopped"). Tag dumps are smashed single words.
    single = [p for p in parts if " " not in p and not any(c.isdigit() for c in p)]
    if not parts or len(single) != len(parts):
        return False
    hits = sum(1 for p in parts if any(tok in p.lower() for tok in _SOCIAL_TAG))
    if hits >= 2 and len(parts) >= 4:
        return True
    return len(parts) >= 8 and (wrapped or hits >= 1)


def _without_tag_dump(line: str) -> str:
    """Drop a tag-dump row, or cut a trailing (...) dump off a real ingredient."""
    s = line.strip()
    if not s or _is_social_tag_dump(s):
        return ""
    if s.endswith(")") and "(" in s:
        inner = s[s.rfind("("):]
        if _is_social_tag_dump(inner):
            return s[:s.rfind("(")].strip(" -–—,;")
    return s


# ---------------------------------------------------------------------------
# Nutrition helpers (Phase 1): USDA-backed macros, robust grams, real servings.
# ---------------------------------------------------------------------------
# Bundled offline nutrition DB (USDA SR Legacy, public domain) — NO API, NO key, NO per-user cost.
_USDA_DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "usda_sr.json")
_USDA_DB: list | None = None
_USDA_CACHE: dict = {}  # core-name -> per-100g macros dict, or None for a confirmed miss
# Down-rank processed/branded/dish/non-flesh entries so a query lands on the generic raw food.
_PROCESSED = ("roll","breaded","battered","canned","gravy","dish","baby","infant","dessert",
              "dinner","fast food","restaurant","soup","flavored","leaves","leaf","cereal",
              "ready-to-eat","bunches","juice","powder","chips","fries","berries","strawberry",
              "vanilla","chocolate","dip","spread","stem","sprouts","glazed","honey-roasted")

_UNIT_GRAMS = {
    "kg": 1000, "g": 1, "gram": 1, "grams": 1, "gm": 1, "gms": 1, "mg": 0.001,
    "l": 1000, "litre": 1000, "liter": 1000, "ml": 1,
    "lb": 454, "lbs": 454, "pound": 454, "pounds": 454, "oz": 28, "ounce": 28, "ounces": 28,
    "cup": 200, "cups": 200, "tbsp": 15, "tablespoon": 15, "tablespoons": 15,
    "tsp": 5, "teaspoon": 5, "teaspoons": 5, "clove": 3, "cloves": 3,
    "slice": 20, "slices": 20, "can": 400, "cans": 400, "pinch": 0.5,
    "egg": 50, "eggs": 50, "roti": 45, "chapati": 45, "packet": 200, "pack": 200,
}

# Prep/adjective/unit words removed before a food lookup so "finely chopped fresh onion" -> "onion".
_PREP_WORDS = {
    "finely","roughly","freshly","fresh","chopped","sliced","diced","minced","grated","shredded",
    "ground","crushed","peeled","boneless","skinless","large","medium","small","big","ripe","raw",
    "cooked","boiled","fried","roasted","toasted","dried","frozen","canned","optional","to","taste",
    "for","garnish","garnishing","washed","cleaned","cut","into","pieces","chunks","cubes","thinly",
    "halved","whole","a","an","the","of","some","few","handful","pinch","approx","approximately",
    "or","and","with","without","your","choice","as","needed","per","required","level","heaped","room",
    "temperature","warm","cold","hot","beaten","softened","melted","extra","virgin","light","dark",
}
_PREP_WORDS |= set(_UNIT_GRAMS.keys())

_WORD_NUM = {"one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,"nine":9,
             "ten":10,"eleven":11,"twelve":12,"half":0.5,"quarter":0.25,"dozen":12,"couple":2}

# Typical grams of ONE piece for count-based items (used when no unit is written, e.g. "2 onions").
# When an ingredient has NO stated quantity, count spices/herbs as ~1 tsp and sauces/oils/aromatics
# as ~1 tbsp, instead of a full 80g (which massively over-counts a lone "paprika" or "soy sauce").
_SPICE_WORDS = {"salt","pepper","paprika","cumin","turmeric","cinnamon","cardamom","chili","chilli",
                "flakes","powder","oregano","thyme","rosemary","basil","nutmeg","cloves","masala",
                "seasoning","spice","zest","bay","coriander","parsley","mint"}
_CONDIMENT_WORDS = {"sauce","honey","vinegar","oil","mirin","syrup","juice","paste","ketchup",
                    "mustard","mayo","garlic","ginger","sake","wine"}

_PIECE_GRAMS = {
    "egg":50,"onion":110,"tomato":120,"potato":170,"garlic":3,"clove":3,"chilli":15,"chili":15,
    "capsicum":120,"carrot":60,"lemon":60,"lime":45,"banana":120,"apple":180,"bread":30,
    "roti":45,"chapati":45,"cucumber":300,"beetroot":80,"onions":110,"tomatoes":120,"potatoes":170,
    "avocado":150,
    # nuts (per nut) & whole spices (per piece) — were counted as 60g each, wildly over-counting.
    "cashew":1.5,"almond":1.2,"walnut":5,"pistachio":0.7,"peanut":0.5,"pecan":2,
    "cardamom":0.3,"bay leaf":0.2,"cinnamon":3,"star anise":1,"peppercorn":0.05,"curry leaf":0.1,
    "clove ":0.1,  # whole clove spice (trailing space avoids matching garlic "cloves")
}


def _core_name(item: str) -> str:
    """Reduce an ingredient line to just the food words for a lookup:
    'finely chopped 2 fresh onions (medium)' -> 'onions'."""
    s = re.sub(r"\([^)]*\)", " ", item.lower())          # drop parentheticals
    s = re.sub(r"[0-9¼½¾⅓⅔¹²³/.,\-]+", " ", s)           # drop numbers/fractions/punctuation
    words = [w for w in re.findall(r"[a-z]+", s) if w not in _PREP_WORDS and len(w) > 1]
    return " ".join(words[:4]).strip()


def _parse_grams(item: str) -> float:
    """Best-effort grams for one ingredient line: kg/g/ml/cups/tbsp, '1 1/2', unicode fractions,
    '2-3' ranges, word-numbers, 'to taste'/'a pinch'/'handful', and count items ('2 eggs',
    '3 onions') via typical per-piece weights."""
    s = item.lower().strip()
    s = re.sub(r"(\d+)\s*[-–—]\s*(\d+)", lambda m: str((int(m.group(1)) + int(m.group(2))) / 2), s)

    qty = None
    m = re.match(r"\s*(\d+)\s+(\d+)/(\d+)", s)                 # "1 1/2"
    if m:
        qty = int(m.group(1)) + int(m.group(2)) / int(m.group(3))
    if qty is None:
        m = re.search(r"(\d+(?:\.\d+)?)\s*/\s*(\d+)", s)       # "1/2"
        if m:
            qty = float(m.group(1)) / float(m.group(2))
    if qty is None:
        for ch, v in {"½":0.5,"¼":0.25,"¾":0.75,"⅓":1/3,"⅔":2/3}.items():
            if ch in s:
                qty = v; break
    if qty is None:
        m = re.search(r"(\d+(?:\.\d+)?)", s)
        if m:
            qty = float(m.group(1))
    if qty is None:
        for w, v in _WORD_NUM.items():
            if re.search(r"\b" + w + r"\b", s):
                qty = v; break
    has_qty = qty is not None
    if qty is None:
        qty = 1.0

    unit = next((w for w in re.findall(r"[a-z]+", s) if w in _UNIT_GRAMS), None)
    if unit:
        return qty * _UNIT_GRAMS[unit]
    if "to taste" in s or "pinch" in s:
        return 1.0
    if "handful" in s:
        return 30.0
    core = _core_name(s)
    for k, g in _PIECE_GRAMS.items():
        if k in core:
            return qty * g
    # Spices/herbs are tiny even when counted ("2 tsp paprika", "a pinch"): ~2g per unit.
    if any(w in core for w in _SPICE_WORDS):
        return qty * 2.0 if has_qty else 2.0
    # Sauces/oils/syrups/aromatics without a unit ~1 tbsp per unit.
    if any(w in s for w in _CONDIMENT_WORDS):
        return qty * 15.0 if has_qty else 15.0
    # Bare count of an unknown food ("2 buns") — a modest ~40g each (was 60g, which over-counted).
    return qty * 40.0 if has_qty else 80.0


_IFCT_DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "ifct_2017.json")


def _load_usda_db() -> list:
    """Load the bundled food datasets once: USDA SR Legacy (whole-food backbone) + IFCT 2017
    (India-accurate; NIN/ICMR). IFCT rows carry s=="ifct" and get a score bonus so Indian staples
    resolve to real Indian measurements. Empty list if missing (then only the curated table is used)."""
    global _USDA_DB
    if _USDA_DB is None:
        import json
        db = []
        for path in (_USDA_DB_PATH, _IFCT_DB_PATH):
            try:
                with open(path, encoding="utf-8") as f:
                    db.extend(json.load(f))
            except Exception:
                pass
        _USDA_DB = db
    return _USDA_DB


def _offline_lookup(core: str) -> dict | None:
    """Per-100g macros for a food from the BUNDLED USDA dataset — fully offline, no API, no key, no
    per-user cost. Scores candidates to prefer the generic 'raw' food over processed/dish entries.
    Cached; None = confirmed miss."""
    core = (core or "").strip().lower()
    if not core:
        return None
    if core in _USDA_CACHE:
        return _USDA_CACHE[core]
    db = _load_usda_db()
    tokens = core.split()
    head = tokens[-1] if tokens else ""
    # WHOLE-WORD match (so "salmon" doesn't hit "salmonberries"); fall back to the head noun.
    def has_word(d, t):
        return re.search(r"\b" + re.escape(t) + r"\b", d) is not None
    cands = [e for e in db if all(has_word(e["d"], t) for t in tokens)]
    if not cands and head:
        cands = [e for e in db if has_word(e["d"], head)]

    macro = None
    if cands:
        def score(e):
            d = e["d"]; s = -0.03 * len(d)            # prefer shorter/generic descriptions
            if e.get("s") == "ifct": s += 1.5         # prefer India-accurate IFCT 2017 on ties
            if "raw" in d: s += 3
            if d.startswith(head): s += 2
            for w in _PROCESSED:
                if w in d: s -= 2
            return s
        best = max(cands, key=score)
        macro = {"kcal": best["k"], "carbs": best["c"], "protein": best["p"], "fat": best["f"]}
    _USDA_CACHE[core] = macro
    return macro


# USDA's fuzzy search mismatches colloquial/regional terms (curd->tofu, brinjal->?), so map the
# common ones to the term USDA indexes well. Only used for items NOT in the curated table.
_USDA_SYNONYMS = {
    "capsicum": "sweet pepper", "bell pepper": "sweet pepper", "brinjal": "eggplant",
    "aubergine": "eggplant", "lady finger": "okra", "bhindi": "okra", "coriander": "cilantro",
    "dhania": "cilantro", "corn flour": "cornstarch", "curd rice": "rice",
    "spring onion": "onions spring", "green chilli": "peppers jalapeno", "green chili": "peppers jalapeno",
    # Indian staples -> IFCT 2017 names (India-accurate macros)
    "toor dal": "red gram dal", "arhar dal": "red gram dal", "tur dal": "red gram dal",
    "pigeon pea": "red gram dal", "moong dal": "green gram dal", "mung dal": "green gram dal",
    "urad dal": "black gram dal", "chana dal": "bengal gram dal", "masoor dal": "lentil dal",
    "besan": "bengal gram dal", "gram flour": "bengal gram dal",
    "atta": "wheat flour atta", "whole wheat flour": "wheat flour atta", "maida": "wheat flour refined",
    "basmati": "rice raw milled", "white rice": "rice raw milled",
}


def _usda_query(item: str) -> str:
    """Normalized query for USDA: strip prep words, then swap in a term USDA indexes well."""
    core = _core_name(item)
    for k, v in _USDA_SYNONYMS.items():
        if k in core:
            return v
    return core


def _nice_name(item: str) -> str:
    """Short, readable ingredient name for the breakdown UI ('1kg mutton, curry cut' -> 'Mutton')."""
    core = _core_name(item)
    return core.title() if core else item.strip().rstrip(",").title()


def _parse_servings(*texts: str) -> int:
    """Pull the real serving count from caption/title/steps; default 2 when unstated."""
    blob = " ".join(t for t in texts if t).lower()
    for pat in (r"serves?\s+(\d{1,2})", r"(\d{1,2})\s+servings?", r"makes?\s+(?:about\s+)?(\d{1,2})",
                r"for\s+(\d{1,2})\s+(?:people|persons?)", r"(\d{1,2})\s+portions?",
                r"yield[s]?\s+(\d{1,2})"):
        m = re.search(pat, blob)
        if m:
            n = int(m.group(1))
            if 1 <= n <= 20:
                return n
    return 2


_PER_SERVING_MARK = re.compile(r"per\s+serv(?:e|ing)s?|/\s*servings?", re.I)
_KCAL_HEADLINE = re.compile(
    r"\d+(?:\.\d+)?\s*(?:kcal|calories|cals)\s*(?:per\s+serv(?:e|ing)s?|/\s*servings?)",
    re.I,
)


def _is_kcal_serving_headline(text: str) -> bool:
    """True when the whole line is only a kcal-per-serving headline ('370 Kcal per Serving')."""
    clean = re.sub(r"[^\w\s/]", " ", text or "", flags=re.UNICODE)
    clean = re.sub(r"\s+", " ", clean).strip()
    return _KCAL_HEADLINE.fullmatch(clean) is not None


def _macro_grams(line: str, name: str) -> float | None:
    m = re.search(rf"(\d+(?:\.\d+)?)\s*g(?:rams?)?\s*(?:of\s+)?(?:{name})\b", line, re.I)
    if not m:
        m = re.search(rf"\b(?:{name})\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g(?:rams?)?\b", line, re.I)
    return float(m.group(1)) if m else None


def _stated_per_serving_nutrition(*texts: str) -> dict | None:
    """One caption line that states kcal and protein, carbs, and fat, marked per serving.

    Stored as written. Do not divide by the recipe's serving count — the card multiplies
    for the whole recipe. A lone kcal headline is not enough to override the chart.
    """
    for text in texts:
        if not text:
            continue
        for raw in text.splitlines():
            line = raw.strip()
            if not line or not _PER_SERVING_MARK.search(line):
                continue
            kcal = re.search(r"(\d+(?:\.\d+)?)\s*(?:kcal|calories|cals)\b", line, re.I)
            protein = _macro_grams(line, r"proteins?")
            carbs = _macro_grams(line, r"carbohydrates?|carbs?")
            fat = _macro_grams(line, r"fats?")
            if not kcal or protein is None or carbs is None or fat is None:
                continue
            return {
                "calories": float(kcal.group(1)),
                "carbs_g": float(carbs),
                "protein_g": float(protein),
                "fat_g": float(fat),
                "daily_calories": 2000.0,
                "estimated": False,
            }
    return None


def estimate_nutrition(ingredients: list[dict], servings: int = 2) -> dict:
    """Whole-recipe nutrition → per serving. Each ingredient's grams come from _parse_grams and its
    per-100g macros from USDA FoodData Central (with the built-in table as an offline fallback)."""
    # Per-100g. Ordered SPECIFIC → GENERIC because matching takes the first key that is a
    # substring of the ingredient line (so "buttermilk"/"coconut milk" must precede "milk").
    table = [
        ("buttermilk", {"kcal": 40, "carbs": 4.8, "protein": 3.3, "fat": 0.9}),
        ("ghee", {"kcal": 900, "carbs": 0, "protein": 0, "fat": 100}),
        ("butter", {"kcal": 717, "carbs": 0.1, "protein": 0.9, "fat": 81}),
        ("cornstarch", {"kcal": 381, "carbs": 91, "protein": 0.3, "fat": 0.1}),
        ("cornflour", {"kcal": 381, "carbs": 91, "protein": 0.3, "fat": 0.1}),
        ("paneer", {"kcal": 265, "carbs": 6, "protein": 18, "fat": 20}),
        # --- meats & seafood (were missing → main ingredient counted as 0 kcal) ---
        ("mutton", {"kcal": 165, "carbs": 0, "protein": 26, "fat": 6}),
        ("goat", {"kcal": 143, "carbs": 0, "protein": 27, "fat": 3}),
        ("lamb", {"kcal": 258, "carbs": 0, "protein": 25, "fat": 17}),
        ("keema", {"kcal": 165, "carbs": 0, "protein": 26, "fat": 6}),
        ("qeema", {"kcal": 165, "carbs": 0, "protein": 26, "fat": 6}),
        ("mince", {"kcal": 165, "carbs": 0, "protein": 26, "fat": 6}),
        ("chicken", {"kcal": 165, "carbs": 0, "protein": 31, "fat": 3.6}),
        ("bacon", {"kcal": 541, "carbs": 1.4, "protein": 37, "fat": 42}),
        ("beef", {"kcal": 250, "carbs": 0, "protein": 26, "fat": 15}),
        ("pork", {"kcal": 242, "carbs": 0, "protein": 27, "fat": 14}),
        ("prawn", {"kcal": 99, "carbs": 0.2, "protein": 24, "fat": 0.3}),
        ("shrimp", {"kcal": 99, "carbs": 0.2, "protein": 24, "fat": 0.3}),
        ("fish", {"kcal": 206, "carbs": 0, "protein": 22, "fat": 12}),
        ("egg", {"kcal": 155, "carbs": 1.1, "protein": 13, "fat": 11}),
        # --- legumes / flours / grains ---
        ("chickpea", {"kcal": 164, "carbs": 27, "protein": 9, "fat": 2.6}),
        ("chana", {"kcal": 164, "carbs": 27, "protein": 9, "fat": 2.6}),
        ("rajma", {"kcal": 127, "carbs": 23, "protein": 9, "fat": 0.5}),
        ("kidney bean", {"kcal": 127, "carbs": 23, "protein": 9, "fat": 0.5}),
        ("lentil", {"kcal": 116, "carbs": 20, "protein": 9, "fat": 0.4}),
        ("dal", {"kcal": 116, "carbs": 20, "protein": 9, "fat": 0.4}),
        ("bean", {"kcal": 127, "carbs": 23, "protein": 9, "fat": 0.5}),
        ("besan", {"kcal": 387, "carbs": 58, "protein": 22, "fat": 7}),
        ("gram flour", {"kcal": 387, "carbs": 58, "protein": 22, "fat": 7}),
        ("flour", {"kcal": 364, "carbs": 76, "protein": 10, "fat": 1}),
        ("pasta", {"kcal": 371, "carbs": 75, "protein": 13, "fat": 1.5}),
        ("macaroni", {"kcal": 371, "carbs": 75, "protein": 13, "fat": 1.5}),
        ("rice", {"kcal": 130, "carbs": 28, "protein": 2.7, "fat": 0.3}),
        # --- nuts (rich gravies) ---
        ("cashew", {"kcal": 553, "carbs": 30, "protein": 18, "fat": 44}),
        ("almond", {"kcal": 579, "carbs": 22, "protein": 21, "fat": 50}),
        ("peanut", {"kcal": 567, "carbs": 16, "protein": 26, "fat": 49}),
        # --- vegetables / aromatics ---
        ("onion", {"kcal": 40, "carbs": 9, "protein": 1.1, "fat": 0.1}),
        ("tomato", {"kcal": 18, "carbs": 3.9, "protein": 0.9, "fat": 0.2}),
        ("potato", {"kcal": 77, "carbs": 17, "protein": 2, "fat": 0.1}),
        ("ginger", {"kcal": 80, "carbs": 18, "protein": 1.8, "fat": 0.8}),
        ("garlic", {"kcal": 149, "carbs": 33, "protein": 6.4, "fat": 0.5}),
        ("spinach", {"kcal": 23, "carbs": 3.6, "protein": 2.9, "fat": 0.4}),
        # --- dairy (coconut BEFORE milk/cream so 'coconut milk' isn't read as milk) ---
        ("coconut milk", {"kcal": 230, "carbs": 6, "protein": 2.3, "fat": 24}),
        ("coconut", {"kcal": 354, "carbs": 15, "protein": 3.3, "fat": 33}),
        ("cheddar", {"kcal": 402, "carbs": 1.3, "protein": 25, "fat": 33}),
        ("mozzarella", {"kcal": 300, "carbs": 2.2, "protein": 22, "fat": 22}),
        ("parmesan", {"kcal": 431, "carbs": 3.2, "protein": 38, "fat": 29}),
        ("cheese", {"kcal": 402, "carbs": 1.3, "protein": 25, "fat": 33}),
        ("cream", {"kcal": 340, "carbs": 2.8, "protein": 2.1, "fat": 36}),
        ("curd", {"kcal": 61, "carbs": 4.7, "protein": 3.5, "fat": 3.3}),
        ("dahi", {"kcal": 61, "carbs": 4.7, "protein": 3.5, "fat": 3.3}),
        ("yogurt", {"kcal": 61, "carbs": 4.7, "protein": 3.5, "fat": 3.3}),
        ("yoghurt", {"kcal": 61, "carbs": 4.7, "protein": 3.5, "fat": 3.3}),
        ("milk", {"kcal": 62, "carbs": 4.8, "protein": 3.2, "fat": 3.3}),
        ("sugar", {"kcal": 387, "carbs": 100, "protein": 0, "fat": 0}),
        ("honey", {"kcal": 304, "carbs": 82, "protein": 0.3, "fat": 0}),
        ("salt", {"kcal": 0, "carbs": 0, "protein": 0, "fat": 0}),
        ("water", {"kcal": 0, "carbs": 0, "protein": 0, "fat": 0}),
        ("oil", {"kcal": 884, "carbs": 0, "protein": 0, "fat": 100}),
    ]

    total_kcal, total_carbs, total_protein, total_fat = 0.0, 0.0, 0.0, 0.0
    contribs = []   # per-ingredient macro contribution (whole recipe), for the tappable breakdown
    for group in ingredients:
        for item in group.get("items", []):
            if not item.strip():
                continue
            lower = item.lower()
            # Water / pasta-water / stock-water contributes ~0 kcal, and otherwise mis-matches
            # ("pasta water" -> pasta). Skip it (coconut/rose water are the rare exceptions).
            if _core_name(item).split()[-1:] == ["water"] and "coconut" not in lower and "rose" not in lower:
                continue
            grams = _parse_grams(item)
            # Curated table FIRST — hand-tuned and correct for common & Indian items (USDA's fuzzy
            # search mismatches colloquial terms, e.g. "curd" -> tofu, "mutton" -> a processed loaf).
            # USDA fills the long tail (specific vegetables/cuts the table doesn't list).
            macro = None
            for key, val in table:
                if key in lower:
                    macro = val
                    break
            if macro is None:
                macro = _offline_lookup(_usda_query(item))
            if macro:
                f = grams / 100.0
                ck, cc, cp, cfat = (macro["kcal"] * f, macro.get("carbs", 0) * f,
                                    macro.get("protein", 0) * f, macro.get("fat", 0) * f)
                total_kcal += ck; total_carbs += cc; total_protein += cp; total_fat += cfat
                contribs.append((_nice_name(item), ck, cc, cp, cfat))

    servings = max(1, servings)
    # Per-serving breakdown, biggest calorie contributor first, so the app can show "who brings the
    # protein/carbs/fat" when a macro is tapped. Only resolved ingredients appear (honest).
    contribs.sort(key=lambda c: c[1], reverse=True)
    breakdown = [{
        "name": n,
        "kcal": float(round(ck / servings)),
        "carbs_g": float(round(cc / servings, 1)),
        "protein_g": float(round(cp / servings, 1)),
        "fat_g": float(round(cfat / servings, 1)),
    } for (n, ck, cc, cp, cfat) in contribs]
    return {
        "calories": float(round(total_kcal / servings)),
        "carbs_g": float(round(total_carbs / servings, 1)),
        "protein_g": float(round(total_protein / servings, 1)),
        "fat_g": float(round(total_fat / servings, 1)),
        "daily_calories": 2000.0,
        "breakdown": breakdown,
        "estimated": True
    }


# Ingredient vocabulary for pulling items out of SPOKEN narration (many reels list ingredients only
# in the voiceover / inside steps like "add garlic, soy sauce, mirin, honey..."). Longer phrases are
# matched first and then masked out, so "soy sauce" wins over "sauce" and "chili flakes" over "chili".
_INGREDIENT_VOCAB = [
    "worcestershire sauce","apple cider vinegar","all purpose flour","ginger garlic paste",
    "red pepper flakes","smoked paprika","spring onion","green onion","green chilli","green chili",
    "red chilli","chili flakes","chilli flakes","black pepper","white pepper","lemon zest","lime zest",
    "lemon juice","lime juice","orange juice","coconut milk","condensed milk","evaporated milk",
    "heavy cream","whipping cream","sour cream","cream cheese","maple syrup","corn syrup","brown sugar",
    "powdered sugar","baking soda","baking powder","coriander powder","curry powder","garam masala",
    "bay leaf","sesame seeds","sesame oil","olive oil","vegetable oil","mustard oil","coconut oil",
    "rice vinegar","white vinegar","rice wine","cooking wine","fish sauce","oyster sauce","hoisin sauce",
    "tomato sauce","chili sauce","hot sauce","teriyaki sauce","soy sauce","bbq sauce","chicken breast",
    "chicken thigh","spring onions","bread crumbs","breadcrumbs","corn starch","cornstarch","cornflour",
    "all-purpose flour","bell pepper","capsicum",
    "soy","mirin","sake","honey","molasses","vinegar","butter","ghee","margarine","yogurt","curd",
    "paneer","parmesan","mozzarella","cheddar","cheese","cream","milk","eggs","egg","chicken","mutton",
    "lamb","goat","beef","pork","bacon","shrimp","prawn","salmon","tuna","fish","tofu","onion","garlic",
    "ginger","tomato","potato","carrot","chilli","chili","lemon","lime","cilantro","coriander","parsley",
    "mint","basil","spinach","mushroom","broccoli","cabbage","cucumber","celery","corn","peas","paprika",
    "pepper","salt","cumin","turmeric","cinnamon","cardamom","cloves","oregano","thyme","rosemary","flour",
    "sugar","sesame","rice","noodles","pasta","bread","oats","scallions",
]

# Promo / intro / CTA lines that aren't real cooking steps (common at the start/end of reels).
_INTRO_LINE = re.compile(
    r"^\s*(this is how|here'?s how|today (?:i|we)|in this (?:video|recipe|reel)|let me show|"
    r"i(?:'m| am) (?:going to|gonna) (?:show|make)|i(?:'ll| will) show|welcome|hey (?:guys|everyone|there)|"
    r"what'?s up|so today|alright(?:,| )|okay(?:,| )so|don'?t forget|make sure (?:to|you)|"
    r"follow (?:me|for)|like and subscribe|comment (?:below|down)|save this|link in bio)", re.I)

# Quantity that may precede a spoken ingredient ("2 tbsp soy sauce", "a pinch of salt").
_SPOKEN_QTY = re.compile(
    r"(\d+(?:[.,/]\d+)?|½|¼|¾|⅓|⅔|a|an|one|two|three|four|some|half)\s*"
    r"(tablespoons?|tbsp|teaspoons?|tsp|cups?|cloves?|grams?|g|kg|ml|l|ounces?|oz|pounds?|lbs?|"
    r"pinch(?:es)?|slices?|sticks?|handful|dash|cans?)?\s*(?:of\s+)?$", re.I)


def _extract_conversational_ingredients(transcript: str) -> list[str]:
    """Extract ingredients from spoken narration using the vocabulary above. Captures a quantity when
    one is spoken right before the ingredient; otherwise lists the ingredient name alone (honest — a
    narrated recipe often doesn't state amounts). Ordered by first mention, deduped, capped."""
    if not transcript.strip():
        return []
    work = " " + transcript.lower() + " "
    found = []  # (position, display)
    for name in sorted(_INGREDIENT_VOCAB, key=len, reverse=True):
        pat = re.compile(r"(?<![a-z])" + re.escape(name) + r"(?![a-z])")
        m = pat.search(work)
        if not m:
            continue
        before = work[max(0, m.start() - 22):m.start()]
        qm = _SPOKEN_QTY.search(before)
        qty = qm.group(0).strip() if qm and qm.group(0).strip() not in ("", "a", "an", "some") else ""
        found.append((m.start(), (qty + " " + name).strip()))
        work = pat.sub("   ", work)  # mask so shorter sub-phrases don't re-match ("chili" in "chili flakes")
    found.sort(key=lambda x: x[0])
    return [d for _, d in found][:30]


# On-screen text (OCR) has no "Ingredients:"/"Method:" headers, so classify line-by-line:
# a line with a quantity+unit is an ingredient; a line starting with a cooking verb is a step.
_QTY_LINE = re.compile(r"\b(\d+(?:[.,/]\d+)?|½|¼|¾|⅓|⅔)\s*(g|kg|mg|ml|l|oz|lb|lbs|cup|cups|tbsp|tbs|tblsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons|clove|cloves|slice|slices|can|cans|pinch|egg|eggs|stick|sticks|colher|colheres|xícara|cucharada|cucharadita|taza|cucchiaio|cucchiaino|cuillère)\b", re.I)
_IMPERATIVE = re.compile(r"^\s*(add|mix|stir|pour|heat|bake|cook|fry|air\s*fry|boil|simmer|whisk|combine|blend|chop|slice|dice|season|serve|fold|knead|marinate|grill|roast|preheat|drain|cover|remove|garnish|sprinkle|coat|dip|layer|spread|place|cut|melt|beat|toss|saute|saut|sear|rest|let|transfer|top|bring|reduce|flip|repeat|set|aqueça|adicione|cozinhe|frite|mexa|misture|despeje|corte|ferva|refogue|tampe|decore|sirva|asse|grelhe|escorra|tempere|polvilhe|retire|doure|prepare|coloque|deixe|retorne|finalize|caliente|añada|cocine|fría|revuelva|mezcle|vierta|hierva|saltee|tape|hornee|ase|sazone|scaldare|aggiungere|cuocere|friggere|mescolare|versare|tagliare|bollire|coprire|decorare|servire|arrostire|grigliare|scolare|condire|chauffer|ajouter|cuire|frire|remuer|verser|couper|bouillir|couvrir|décorer|égoutter|assaisonner)\b", re.I)


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
        if _is_social_tag_dump(line):
            continue
        if _CTA.search(line) or line.startswith(("http://", "https://", "►", "• http")):
            continue
        if _END_SECTIONS.match(line):
            mode = None
            continue
        # A kcal-per-serving headline is not the dish name, and a full macro line is not one either.
        if _is_kcal_serving_headline(line) or _stated_per_serving_nutrition(line):
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
            item = _without_tag_dump(_strip_marker(line))
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
        line = _without_tag_dump(_strip_marker(raw.strip()))
        if len(line) < 3 or not _is_latin(line) or _CTA.search(line) or _is_social_tag_dump(line):
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


_FOOD_WORDS = {
    # English
    "cook","cooking","recipe","fry","fried","bake","baked","boil","boiled","roast","grill","saute",
    "simmer","marinate","knead","whisk","stir","chop","dice","mince","blend","garnish","serve",
    "season","preheat","dough","batter","sauce","gravy","curry","masala","spice","spices","chilli",
    "chili","salt","sugar","flour","oil","ghee","butter","milk","cream","cheese","paneer","egg","eggs",
    "water","onion","garlic","ginger","tomato","potato","rice","dal","lentil","chicken","mutton","fish",
    "prawn","beef","pork","vegetable","veggies","bread","noodles","pasta","soup","salad","dessert",
    "cake","cookie","chocolate","honey","yogurt","curd","coriander","cumin","turmeric","pepper","lemon",
    "tsp","tbsp","teaspoon","tablespoon","cup","cups","cloves","pinch","boneless","chopped","minced",
    "grated","kadhai","pan","oven","stove","dish","meal","flavour","flavor","kitchen","ingredient","ingredients",
    # Portuguese
    "frango","cozinhar","receita","frigir","assar","ferver","grelhar","refogar","temperar",
    "farinha","azeite","manteiga","leite","creme","queijo","ovo","ovos","cebola","alho",
    "tomate","batata","arroz","sal","pimenta","colher","colheres","molho","caldo",
    # Spanish
    "cocinar","receta","hornear","hervir","asar","mezclar","servir","sazonar",
    "harina","aceite","mantequilla","leche","crema","queso","huevo","huevos","cebolla","ajo",
    "pollo","carne","cerdo","pescado","cucharada","cucharadita","taza",
    # Italian
    "cucinare","ricetta","friggere","cuocere","bollire","arrostire","mescolare","condire",
    "farina","olio","burro","latte","panna","formaggio","uovo","uova","cipolla","aglio",
    "pomodoro","manzo","maiale","pesce","cucchiaio","cucchiaino","padella",
    # French
    "cuisiner","recette","frire","cuire","bouillir","griller","assaisonner",
    "farine","huile","beurre","lait","fromage","oeuf","oeufs","oignon","ail",
    "poulet","viande","porc","poisson","casserole",
    # Hindi (transliterated)
    "pakana","sabzi","roti","chawal","daal","atta","tel","namak","mirch","haldi",
    "jeera","dhaniya","pyaaz","adrak","tamatar","aloo","murgi","gosht","machli",
}
_NON_FOOD_WORDS = {
    "fabric","cotton","polyester","spandex","denim","linen","wool","nylon","knit","henley","shirt",
    "tshirt","tee","jeans","trouser","pant","jacket","hoodie","outfit","clothing","apparel","wardrobe",
    "wear","fashion","collar","sleeve","stitch","garment","dress","shoe","sneaker","gadget","phone",
    "laptop","charger","gaming","makeup","skincare","serum","workout","dumbbell","engine","crypto","stocks",
}


def _looks_like_food(parsed: dict) -> bool:
    """True when the extracted content actually reads as a FOOD recipe — blocks non-cooking reels
    (fashion/tech/product) that still parse into 'ingredients' like '100g cotton fabric'."""
    parts = [parsed.get("title", "")]
    parts += [i for g in parsed.get("ingredients", []) for i in g.get("items", [])]
    parts += [d.get("text", "") for d in parsed.get("directions", [])]
    # Use \w to match all Unicode letters (like ã, ç, é), not just a-z
    tokens = set(re.findall(r"[^\W\d_]+", " ".join(parts).lower()))
    food = len(tokens & _FOOD_WORDS)
    non_food = len(tokens & _NON_FOOD_WORDS)
    return food >= 2 and food > non_food


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
    if _is_kcal_serving_headline(title):
        title = ""
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


def _dish_blurb(caption: str, title: str, groups: list) -> str:
    """One short line under the title. A caption sentence wins; otherwise name a few ingredients."""
    prose = _caption_prose(caption, title)
    if prose:
        return prose
    names = []
    for group in groups or []:
        for item in group.get("items") or []:
            name = _readable_ingredient(item)
            if name and name.lower() not in [n.lower() for n in names]:
                names.append(name)
            if len(names) == 3:
                break
    if not names:
        return ""
    if len(names) == 1:
        tail = names[0]
    elif len(names) == 2:
        tail = f"{names[0]} and {names[1]}"
    else:
        tail = f"{names[0]}, {names[1]}, and {names[2]}"
    return f"Made with {tail}."


def _caption_prose(caption: str, title: str) -> str:
    title_l = (title or "").strip().lower()
    for raw in (caption or "").splitlines():
        line = raw.strip()
        low = line.lower().rstrip(":")
        if low in {"ingredients", "ingredient", "directions", "direction", "method", "instructions", "steps"}:
            break
        if not line or line.startswith("#") or line.lower() == title_l:
            continue
        if _is_kcal_serving_headline(line) or _stated_per_serving_nutrition(line):
            continue
        if re.search(r"\bmakes?\s+\d+\s+servings?\b", line, re.I):
            continue
        if _QTY_LINE.search(line) and len(line) < 80:
            continue
        sentence = re.split(r"(?<=[.!?])\s+", line)[0].strip()
        if 40 <= len(sentence) <= 220 and not sentence.lower().startswith("http"):
            return sentence
    return ""


def _readable_ingredient(item: str) -> str:
    text = (item or "").strip()
    if re.search(r"\s[—–-]\s", text):
        left = re.split(r"\s+[—–-]\s+", text, maxsplit=1)[0].strip()
        if left and not re.match(r"\d", left):
            text = left
    text = re.sub(r"\([^)]*\)", "", text)
    text = re.sub(r"^[\d¼½¾⅓⅔./\s-]+", "", text)
    text = re.sub(
        r"^(g|kg|ml|cups?|tbsp|tsp|teaspoons?|tablespoons?|cloves?|pinch)\b",
        "",
        text,
        flags=re.I,
    )
    return text.strip(" -–—,;")[:48]


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

    # Union spoken ingredients so items narrated (or listed only inside steps like "add garlic, soy
    # sauce, mirin, honey...") are never lost, even when a short caption/OCR list was chosen above.
    if aud_items:
        existing = {_core_name(it) for g in groups for it in g.get("items", [])}
        extra = [it for it in aud_items if _core_name(it) and _core_name(it) not in existing]
        if extra:
            if groups:
                groups[0] = dict(groups[0], items=list(groups[0].get("items", [])) + extra)
            else:
                groups = [{"group_name": "Main Ingredients", "items": extra}]

    if not title:
        title = "Delicious Homemade Recipe"

    # Drop promo / intro / CTA lines that aren't actual cooking steps.
    directions = [d for d in directions if not _INTRO_LINE.match(d)]

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

    serving_count = _parse_servings(caption, video_title, " ".join(directions))
    # A stated per-serving macro line wins. Otherwise keep the ingredient estimate.
    nutrition = _stated_per_serving_nutrition(caption) or estimate_nutrition(groups, servings=serving_count)
    return {
        "title": title,
        "description": _dish_blurb(caption, title, groups),
        "prep_time": "",
        "cook_time": "15 min",
        "servings": serving_count,
        "ingredients": groups,
        "directions": [{"step_index": i + 1, "text": t} for i, t in enumerate(directions)],
        "nutrition": nutrition,
    }


def _check_caption_macros_stay_per_serving() -> None:
    """Fails if a stated per-serving line is replaced by the ingredient estimate or divided by servings."""
    caption = (
        "370 Kcal per Serving\n"
        "Garlic Chicken Bowl\n"
        "370 kcal | 14g protein | 52g carbs | 13g fat per Serving\n"
        "Makes 4 Servings\n"
    )
    parsed = assemble_recipe(caption, "", "", False, video_title="370 Kcal per Serving")
    n = parsed["nutrition"]
    assert n["calories"] == 370 and n["protein_g"] == 14 and n["carbs_g"] == 52 and n["fat_g"] == 13, n
    assert n["estimated"] is False, n
    assert n["calories"] not in (140, 370 / 4), n
    assert parsed["servings"] == 4
    assert parsed["title"] == "Garlic Chicken Bowl", parsed["title"]
    assert _stated_per_serving_nutrition("370 Kcal per Serving") is None
    prose = "Meet the street-food classic whose name means thick muddy chickpeas."
    assert _dish_blurb(prose + "\nIngredients:\nOnion — 1", "Chole", []).startswith("Meet the street-food")
    made = _dish_blurb("", "Shrimp", [{"items": ["200g shrimp", "1 tbsp butter", "2 garlic cloves"]}])
    assert made == "Made with shrimp, butter, and garlic cloves.", made


_check_caption_macros_stay_per_serving()


def _send_apns_push(recipe_id: str, recipe_title: str, user_id: Optional[str] = None) -> None:
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    # Target ONLY the user who shared the reel — never every registered device. If we don't know
    # who imported it (no user_id on the job), send to nobody rather than spamming everyone.
    if user_id:
        c.execute("SELECT apns_token, environment, user_id FROM devices WHERE user_id = ?", (user_id,))
    else:
        c.execute("SELECT apns_token, environment, user_id FROM devices WHERE 1 = 0")
    devices = c.fetchall()
    conn.close()

    if not devices:
        print(f"ℹ️ [APNs] No device to notify for user_id={user_id} (recipe {recipe_id})")
        return

    for token, env, uid in devices:
        print(f"🌟 [APNs Stub] Pushing 'Recipe Ready: {recipe_title}' to {uid} at {token} ({env})")
        # DORMANT: Requires Apple Developer Program (.p8 key) to send actual HTTP/2 pushes
        # payload = {"aps": {"alert": {"title": "Recipe Ready! 🍳", "body": f"Your imported reel '{recipe_title}' is ready."}, "sound": "default"}, "recipe_id": recipe_id}

def _save_reel_cover(recipe_id: str, poster_url: Optional[str], video_path: Optional[str]) -> Optional[str]:
    """Write one JPEG the app can keep. Prefer a frame from the reel, else Instagram's own cover."""
    os.makedirs(MEDIA_CACHE_DIR, exist_ok=True)
    dest = os.path.join(MEDIA_CACHE_DIR, f"{recipe_id}.jpg")
    if video_path and os.path.isfile(video_path):
        try:
            subprocess.run(
                ["ffmpeg", "-y", "-ss", "1", "-i", video_path, "-frames:v", "1",
                 "-vf", "scale='min(800,iw)':-2", "-q:v", "3", dest],
                check=True, capture_output=True, timeout=30,
            )
            if os.path.isfile(dest) and os.path.getsize(dest) > 0:
                return f"/reels/media/{recipe_id}.jpg"
        except Exception:
            pass
    if poster_url and poster_url.startswith("http"):
        try:
            req = urllib.request.Request(poster_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = resp.read()
            if data:
                with open(dest, "wb") as f:
                    f.write(data)
                return f"/reels/media/{recipe_id}.jpg"
        except Exception:
            pass
    return None


def _process_reel_import(job_id: str, url: str, target_language: str, user_id: Optional[str] = None) -> None:
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
                        # Translate natively to English for the extraction pipeline
                        r = transcribe(audio_files[0], language=None, task="translate")
                        transcript, source_lang = r.text, (r.language or "en")
                    except Exception:
                        transcript = ""

            # 3) Merge caption + audio (best per field). 
            # Our extraction heuristics (like quantities) and food gate are English-based.
            JOBS[job_id]["status"] = "extracting"
            from .translate import translate_texts
            if caption:
                t_cap = translate_texts([caption], "en")
                if t_cap: caption = t_cap[0]

            parsed = assemble_recipe(caption, transcript, "", has_speech,
                                     video_title=video_title, author=author)

            # 4) The card photo is a frame of this reel, so fetch the video after audio
            #    (never before listening). OCR that same file only when the recipe is still thin.
            cover_video = None
            need_ocr = not _recipe_is_complete(parsed)
            video_out = os.path.join(tmp, "video.%(ext)s")
            try:
                _run_ytdlp(["-f", "best[height<=720]/best", "-o", video_out], url)
                vids = [f for f in glob.glob(os.path.join(tmp, "video.*")) if not f.endswith(".json")]
                if vids:
                    cover_video = vids[0]
                    if need_ocr:
                        ocr_text = _ocr_video_frames(vids[0], tmp)
                        if ocr_text.strip():
                            t_ocr = translate_texts([ocr_text], "en")
                            if t_ocr: ocr_text = t_ocr[0]
                            parsed = assemble_recipe(caption, transcript, ocr_text, has_speech,
                                                     video_title=video_title, author=author)
            except Exception:
                pass

            # Truly nothing usable (no audio, no caption, no readable on-screen text) =>
            # fail gracefully with a clear reason instead of storing an empty recipe.
            if not _has_recipe_content(parsed):
                raise RuntimeError(
                    "This one didn't have quite enough for us to read — no spoken steps, caption, "
                    "or on-screen text. If it's a recipe, try a reel where the creator lists or "
                    "talks through the ingredients and steps."
                )

            # FOOD GATE: CraveCircle is for cooking. Block non-food reels (fashion/product) that still
            # parse into 'ingredients' — stop kindly instead of storing a fake recipe in the feed.
            if not _looks_like_food(parsed):
                raise RuntimeError(
                    "Hmm, this doesn't look like a cooking video. CraveCircle turns food & recipe "
                    "reels into recipes — try one where someone's making a dish."
                )

            # 5) Deliver into the user's preferred language. Whisper task=translate already
            #    wrote English, so compare against that text, not the spoken-language tag.
            #    A reel that is actually in another language (no English transcript yet)
            #    still goes through the LLM. source_language stays the DETECTED one so the
            #    iOS "Translated from …" badge lights up.
            text_lang = recipe_text_lang(transcript, source_lang)
            if _norm_lang(target_language) and _norm_lang(target_language) != _norm_lang(text_lang):
                JOBS[job_id]["status"] = "extracting"
                parsed = translate_recipe(parsed, text_lang, target_language)


            recipe_id = f"recipe-{uuid.uuid4().hex[:8]}"
            # Frame of the reel (ffmpeg). Instagram's poster only if that grab failed.
            # The phone copies this file locally so the card is not a bundled dish photo.
            thumbnail = _save_reel_cover(recipe_id, thumbnail, cover_video) or thumbnail
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
                "nutrition": parsed["nutrition"],
                "visibility": "everyone"
            }

            RECIPES[recipe_id] = recipe_obj
            JOBS[job_id]["recipe_id"] = recipe_id
            JOBS[job_id]["status"] = "done"
            
            _send_apns_push(recipe_id, recipe_obj.get("title", "Recipe"), user_id)

    except Exception as e:
        JOBS[job_id]["status"] = "error"
        JOBS[job_id]["error_message"] = str(e)


# MARK: - Feedback & Admin Endpoints

class DeviceRegister(BaseModel):
    apns_token: str
    platform: str
    environment: str

@app.post("/devices")
def register_device(req: DeviceRegister, authorization: Optional[str] = Header(None)):
    user_id = "unknown"
    if authorization and authorization.startswith("Bearer "):
        import base64
        import json
        token = authorization.split(" ")[1]
        parts = token.split(".")
        if len(parts) == 3:
            payload_b64 = parts[1]
            payload_b64 += "=" * ((4 - len(payload_b64) % 4) % 4)
            try:
                payload = json.loads(base64.urlsafe_b64decode(payload_b64))
                user_id = payload.get("sub", "unknown")
            except Exception:
                pass

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute(
        '''
        INSERT INTO devices (apns_token, user_id, platform, environment, updated_at)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(apns_token) DO UPDATE SET
            user_id=excluded.user_id,
            platform=excluded.platform,
            environment=excluded.environment,
            updated_at=CURRENT_TIMESTAMP
        ''',
        (req.apns_token, user_id, req.platform, req.environment)
    )
    conn.commit()
    conn.close()
    return {"status": "ok"}

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
    # Phone listens to audio first. Video is a second call, only for OCR or a cover frame.
    audio_only: bool = True

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
        if req.audio_only:
            # Audio only — the phone listens to this. Do not merge a 720p picture.
            _run_ytdlp(["-f", "bestaudio[ext=m4a]/bestaudio", "-o", out_template], req.url)
        else:
            # Picture, only when the phone still needs frames. H.264 so iOS can decode a still.
            _run_ytdlp([
                "-f", ("bestvideo[vcodec^=avc1][height<=720]+bestaudio[ext=m4a]/"
                       "best[vcodec^=avc1][height<=720]/"
                       "bestvideo[height<=720]+bestaudio/best[height<=720]/best"),
                "--merge-output-format", "mp4",
                "-o", out_template
            ], req.url)
    except Exception as e:
        kind = "audio" if req.audio_only else "video"
        raise HTTPException(status_code=400, detail=f"Failed to download {kind}: {e}")

    skip_ext = {".jpg", ".jpeg", ".json", ".part"}
    candidates = [
        c for c in glob.glob(os.path.join(MEDIA_CACHE_DIR, f"{media_id}.*"))
        if os.path.splitext(c)[1].lower() not in skip_ext
    ]
    if not candidates:
        raise HTTPException(status_code=500, detail="Download finished but file not found on disk")

    actual_file = candidates[0]
    filename = os.path.basename(actual_file)

    # Audio-only is the listen step. The phone asks for the video afterwards and keeps this
    # ffmpeg frame; the poster stays only when that grab fails.
    if not req.audio_only:
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
            pass

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
    ext = os.path.splitext(safe_name)[1].lower()
    audio_types = {
        ".m4a": "audio/mp4", ".aac": "audio/aac", ".mp3": "audio/mpeg",
        ".wav": "audio/wav", ".webm": "audio/webm", ".opus": "audio/opus",
    }
    if ext in (".jpg", ".jpeg"):
        media_type = "image/jpeg"
    elif ext in audio_types:
        media_type = audio_types[ext]
    else:
        media_type = "video/mp4"
    return FileResponse(file_path, media_type=media_type, filename=safe_name)

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
    # Who shared this reel — set by the Share Extension from the App Group. Lets the "recipe ready"
    # push target only this user's devices. Absent for anonymous/legacy callers (then: no push).
    user_id: Optional[str] = None


@app.post("/reels/import")
async def submit_reel_import(req: ImportRequest, bg: BackgroundTasks) -> dict:
    job_id = f"job-{uuid.uuid4().hex[:10]}"
    JOBS[job_id] = {
        "id": job_id,
        "status": "queued",
        "url": req.url,
        "target_language": req.target_language,
        "user_id": req.user_id,
        "recipe_id": None,
        "error_message": None
    }
    bg.add_task(_process_reel_import, job_id, req.url, req.target_language, req.user_id)
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
