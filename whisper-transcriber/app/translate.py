"""
Multilingual recipe translation for CraveCircle.

Turns an assembled recipe into the user's chosen language regardless of where the
content came from (audio transcript OR caption OR on-screen text). We detect the
language of the *assembled recipe text* (not the audio) because a reel can have,
say, Hindi audio but an English caption — the output language is what matters.

Engine: deep-translator's GoogleTranslator (free endpoint, `requests`-only). Chosen
over Argos Translate because Argos pulls in torch (~1GB via stanza), which would
bloat this GPU-constrained homelab. Everything here is best-effort: if detection or
translation fails, the original (untranslated) recipe is returned so an import never
breaks. Swappable for an offline engine later if fully self-hosted translation is wanted.
"""
from __future__ import annotations

import re

# App language codes (EN/HI/MR/TA/TE/BN/ES/FR) already match Google's codes, so no remap needed.
_SUPPORTED = {"en", "hi", "mr", "ta", "te", "bn", "es", "fr"}


def _detect(text: str) -> str | None:
    try:
        from langdetect import detect
        code = detect(text)
        # langdetect returns e.g. "zh-cn"; keep the base code.
        return code.split("-")[0].lower()
    except Exception:
        return None


def _looks_untranslatable(s: str) -> bool:
    """Skip pure numbers/symbols (e.g. '250') — nothing to translate, avoids wasted calls."""
    return not re.search(r"[A-Za-zऀ-෿Ѐ-ӿ]", s or "")


def _is_error_response(text: str) -> bool:
    """Google's rate-limit/error pages come back as translatable-looking text — reject them."""
    t = (text or "").lower()
    return ("error 500" in t or "server error" in t
            or "that’s an error" in t or "that's an error" in t
            or "please try again later" in t)


def translate_recipe(recipe: dict, target_language: str | None) -> dict:
    """Return a copy of `recipe` with title/description/ingredients/directions translated into
    `target_language`. No-op (returns the original) if target is missing/unsupported, the recipe is
    already in the target language, or translation fails."""
    target = (target_language or "").split("-")[0].lower()
    if target not in _SUPPORTED:
        return recipe

    # Detect the language of the actual output text (title + a few steps).
    sample_parts = [recipe.get("title", "")]
    sample_parts += [d.get("text", "") for d in recipe.get("directions", [])[:3]]
    sample = " ".join(p for p in sample_parts if p).strip()
    if not sample:
        return recipe

    source = _detect(sample)
    if not source or source == target:
        # Already in the target language (or undetectable) — record source, don't translate.
        if source:
            recipe["source_language"] = source
        return recipe

    # Collect every translatable string in a stable order, translate in ONE batched request,
    # then map the results back — far fewer network round-trips than per-string calls.
    try:
        from deep_translator import GoogleTranslator
        translator = GoogleTranslator(source="auto", target=target)
    except Exception:
        return recipe

    strings: list[str] = []
    slots: list[tuple] = []   # (kind, indices) to reassemble

    def add(kind, idx, text):
        if text and not _looks_untranslatable(text):
            slots.append((kind, idx, len(strings)))
            strings.append(text)

    add("title", None, recipe.get("title", ""))
    add("description", None, recipe.get("description", ""))
    for gi, group in enumerate(recipe.get("ingredients", [])):
        for ii, item in enumerate(group.get("items", [])):
            add("ingredient", (gi, ii), item)
    for si, step in enumerate(recipe.get("directions", [])):
        add("step", si, step.get("text", ""))

    if not strings:
        return recipe

    # Translate everything in ONE request (newline-joined) — deep-translator's translate_batch fires
    # one request PER string, which trips Google's rate limit and returns error pages as "text".
    SEP = "\n"
    joined = SEP.join(s.replace("\n", " ").strip() for s in strings)
    try:
        result = translator.translate(joined)
    except Exception:
        recipe["source_language"] = source
        return recipe

    if not result or _is_error_response(result):
        recipe["source_language"] = source
        return recipe

    translated = [p.strip() for p in result.split(SEP)]
    if len(translated) != len(strings):
        # Line count drifted (Google merged/split lines) — don't risk misaligning fields.
        recipe["source_language"] = source
        return recipe

    out = dict(recipe)
    out["ingredients"] = [dict(g, items=list(g.get("items", []))) for g in recipe.get("ingredients", [])]
    out["directions"] = [dict(d) for d in recipe.get("directions", [])]

    for kind, idx, si in slots:
        val = translated[si]
        if not val:
            continue
        if kind == "title":
            out["title"] = val
        elif kind == "description":
            out["description"] = val
        elif kind == "ingredient":
            gi, ii = idx
            out["ingredients"][gi]["items"][ii] = val
        elif kind == "step":
            out["directions"][idx]["text"] = val

    out["source_language"] = source   # so the app shows "Translated from <source>"
    return out
