#!/usr/bin/env python3
"""
Local reel-extraction test — run on your Mac, no backend / no auth / no Homelab needed.

Given a reel URL it does exactly what the pipeline's core does:
  1. yt-dlp  -> pull the caption + metadata
  2. yt-dlp  -> download + extract the audio
  3. Whisper -> transcribe the audio and detect the language
Then it prints the caption and the transcript side by side, so you can see the raw
material the recipe parser would work from.

Setup (one time):
    brew install ffmpeg
    python3 -m pip install -U yt-dlp faster-whisper

Run:
    python3 test_local.py "https://www.instagram.com/reel/XXXXXXXXX/"

Notes:
  - On a Mac (no NVIDIA GPU) this runs on CPU. large-v3 is accurate but slow on CPU;
    for a quick smoke test set a smaller model:  WHISPER_MODEL=small python3 test_local.py <url>
  - Some reels are private/region-locked; yt-dlp will error on those.
"""

import os
import re
import sys
import glob
import json
import tempfile
import subprocess


def sh(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=True, text=True, **kw)


# Instagram blocks anonymous downloads; set COOKIES_BROWSER=safari|chrome|brave|firefox
# to reuse your logged-in browser session.
COOKIES_BROWSER = os.getenv("COOKIES_BROWSER")
YTDLP = [
    sys.executable, "-m", "yt_dlp", "--no-warnings",
    "--extractor-args", "youtube:player_client=android"
]
if COOKIES_BROWSER:
    YTDLP += ["--cookies-from-browser", COOKIES_BROWSER]


_CTA = re.compile(r"(follow|link in bio|comment below|save this|tag a|subscribe|full recipe|check out|dm me|like and)", re.I)
_SECTION_ING = re.compile(r"^\s*ingredients?\s*:?\s*$", re.I)
_SECTION_DIR = re.compile(r"^\s*(directions?|method|steps?|instructions?)\s*:?\s*$", re.I)


def _is_latin(line: str) -> bool:
    """True while the line is mostly Latin script — used to stop at the Arabic section."""
    letters = [c for c in line if c.isalpha()]
    if not letters:
        return True
    latin = sum(1 for c in letters if ord(c) < 0x250)
    return latin / len(letters) > 0.5


def _strip_marker(line: str) -> str:
    """Remove a leading list marker ('- ', '• ', '1.', '2)') but KEEP quantities like '300 ml' or '1 egg'."""
    line = re.sub(r"^\s*[-•*·]\s*", "", line)
    line = re.sub(r"^\s*\d+[.)]\s+", "", line)   # only strips a number that is followed by . or )
    return line.strip()


def estimate_nutrition(ingredients: list[dict], servings: int = 2) -> dict:
    """Computes nutrition and physical calorie-burn equivalents."""
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
            # quantity
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
            
            # unit
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
    serving_kcal = round(total_kcal / servings)
    serving_carbs = round(total_carbs / servings, 1)
    serving_protein = round(total_protein / servings, 1)
    serving_fat = round(total_fat / servings, 1)

    # Activity burn times for 70kg / 154lb person
    weight_kg = 70
    activities = [
        ("Running (6 mph / 10 km/h)", 9.8),
        ("Cycling (moderate 12-14 mph)", 8.0),
        ("HIIT / Circuit Training", 8.5),
        ("Brisk Walking (3.5 mph)", 4.3),
        ("Swimming (moderate)", 7.0),
        ("Jump Rope", 11.0)
    ]
    burn_plan = {}
    for act_name, met in activities:
        cal_per_min = (met * 3.5 * weight_kg) / 200
        mins = round(serving_kcal / cal_per_min) if cal_per_min > 0 else 0
        burn_plan[act_name] = f"{mins} mins"

    return {
        "per_serving": {
            "calories_kcal": serving_kcal,
            "carbs_g": serving_carbs,
            "protein_g": serving_protein,
            "fat_g": serving_fat
        },
        "total_batch": {
            "calories_kcal": round(total_kcal),
            "carbs_g": round(total_carbs, 1),
            "protein_g": round(total_protein, 1),
            "fat_g": round(total_fat, 1)
        },
        "kcal_burn_equivalent_for_1_serving_70kg": burn_plan
    }


def parse_recipe(caption: str, transcript: str, video_title: str = "") -> dict:
    """Deterministic caption-first parser (the Python twin of caption_parse.go)."""
    title = video_title.strip() if video_title else ""
    groups: list[dict] = []
    directions: list[str] = []
    cur = None
    mode = None  # None | "ing" | "dir"

    _END_SECTIONS = re.compile(r"^\s*(notes?|tips?|subscribe|more recipes|follow|socials?|newsletter)\s*:?\s*$", re.I)

    for raw in caption.splitlines():
        line = raw.strip()
        if not line:
            continue
        if not _is_latin(line):
            break  # reached a non-English section (e.g. Arabic) — stop for an English target
        if line.startswith("#") or all(w.startswith("#") for w in line.split()):
            continue  # hashtag line
        if _CTA.search(line) or line.startswith(("http://", "https://", "►", "• http")):
            continue  # engagement CTA or raw link
        if _END_SECTIONS.match(line):
            mode = None  # stop parsing ingredients or directions on reaching notes / links
            continue

        if not title:  # first meaningful line is the title if no video_title provided
            clean_t = re.sub(r"\s+", " ", re.sub(r"[^\w\s'&()\-,.]", "", line)).strip()
            if len(clean_t) <= 60:
                title = clean_t
                continue

        if _SECTION_ING.match(line):
            mode, cur = "ing", None
            continue
        if _SECTION_DIR.match(line):
            mode = "dir"
            continue
        if mode == "ing":
            if line.endswith(":") and len(line) < 42:  # a group header
                cur = {"group_name": line[:-1].strip(), "items": []}
                groups.append(cur)
                continue
            item = _strip_marker(line)
            if item and not item.startswith(("http://", "https://")):
                if cur is None:
                    cur = {"group_name": "", "items": []}
                    groups.append(cur)
                cur["items"].append(item)
        elif mode == "dir":
            step = _strip_marker(line)
            if step and not step.startswith(("http://", "https://")) and len(step) > 4:
                directions.append(step)

    # Caption had no written steps? Fall back to the audio transcript, split into steps.
    if not directions and transcript.strip():
        for s in re.split(r"(?<=[.!?])\s+", transcript.strip()):
            if len(s.strip()) > 12:
                directions.append(s.strip())

    cleaned_groups = [g for g in groups if g["items"]]
    nutrition = estimate_nutrition(cleaned_groups, servings=2)

    return {
        "title": title or "Imported Recipe",
        "ingredients": cleaned_groups,
        "directions": [{"step_index": i + 1, "text": t} for i, t in enumerate(directions)],
        "steps_source": "caption" if directions and not transcript.strip() else ("transcript" if directions else "none"),
        "nutrition": nutrition
    }


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: python3 test_local.py <reel-url>")
        return 2
    url = sys.argv[1]
    model_name = os.getenv("WHISPER_MODEL", "large-v3")

    try:
        from faster_whisper import WhisperModel
    except ImportError:
        print("Missing deps. Run:  python3 -m pip install -U yt-dlp faster-whisper  &&  brew install ffmpeg")
        return 1

    local_tmp = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".tmp")
    os.makedirs(local_tmp, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=local_tmp) as tmp:
        # 1) Caption + metadata (cheap — often already contains the recipe)
        print("→ fetching caption + metadata …")
        try:
            meta = json.loads(sh(YTDLP + ["--dump-json", url], capture_output=True).stdout)
        except subprocess.CalledProcessError as e:
            print("yt-dlp could not read that URL (Instagram likely requires login).")
            if e.stderr:
                print("\n--- yt-dlp said ---\n" + e.stderr.strip()[-700:])
            print("\nFix: log into Instagram in your browser, then re-run with its cookies, e.g.:")
            print('  COOKIES_BROWSER=chrome WHISPER_MODEL=small python3 '
                  '~/Projects/CraveCircle.cc/whisper-transcriber/test_local.py "<url>"')
            print("Or test a public YouTube Short / TikTok URL instead (usually no login needed).")
            return 1
        caption = (meta.get("description") or "").strip()
        author = meta.get("uploader") or meta.get("channel") or "?"

        # 2) Download the audio track as-is (no ffmpeg needed — faster-whisper/PyAV decodes it)
        print("→ downloading audio …")
        sh(YTDLP + ["-f", "bestaudio/best", "-o", os.path.join(tmp, "media.%(ext)s"), url])
        media = glob.glob(os.path.join(tmp, "media.*"))
        if not media:
            print("no media downloaded from that reel.")
            return 1
        audio_path = media[0]

        # 3) Transcribe + detect language (Whisper large-v3 or small)
        print(f"→ transcribing with Whisper {model_name} (CPU) …\n")
        model = WhisperModel(model_name, device="auto", compute_type="int8")
        segments, info = model.transcribe(audio_path, vad_filter=True, beam_size=5)
        transcript = " ".join(s.text.strip() for s in segments).strip()

    bar = "=" * 60
    print(bar)
    print(f"CREATOR:  @{author}")
    print(f"LANGUAGE: {info.language}  (confidence {info.language_probability:.2f})")
    print(bar)
    print("CAPTION (source of truth):\n")
    print(caption or "(no caption)")
    print("\n" + bar)
    print("AUDIO TRANSCRIPT (fills gaps the caption misses):\n")
    print(transcript or "(no speech detected)")
    print("\n" + bar)
    print("PARSED RECIPE  (what caption_parse.go produces — the object the app shows):\n")
    recipe = parse_recipe(caption, transcript, meta.get("title", ""))
    print(json.dumps(recipe, indent=2, ensure_ascii=False))
    print(bar)
    ing = sum(len(g["items"]) for g in recipe["ingredients"])
    print(f"→ {ing} ingredients in {len(recipe['ingredients'])} group(s), "
          f"{len(recipe['directions'])} step(s) (source: {recipe['steps_source']}).")
    if recipe.get("nutrition"):
        cal = recipe["nutrition"]["per_serving"]["calories_kcal"]
        print(f"→ Nutrition: ~{cal} kcal/serving | Kcal Burn: {recipe['nutrition']['kcal_burn_equivalent_for_1_serving_70kg'].get('Running (6 mph / 10 km/h)', 'N/A')} running")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
