"""
Multilingual recipe translation for CraveCircle.

Turns an assembled recipe into the user's chosen language regardless of where the
content came from (audio transcript OR caption OR on-screen text). We detect the
language of the *assembled recipe text* (not the audio) because a reel can have,
say, Hindi audio but an English caption — the output language is what matters.

Engine: Google's keyless `translate_a/single` endpoint via `requests` (auto-detects the source,
so no langdetect needed to translate), with deep-translator's GoogleTranslator as a fallback and a
per-string pass to guarantee alignment. Chosen over Argos Translate because Argos pulls in torch
(~1GB via stanza), which would bloat this GPU-constrained homelab. Everything is best-effort: if
translation fails, the original (untranslated) text is returned so an import never breaks.
"""
from __future__ import annotations

import re

# App language codes already match Google's codes, so no remap needed.
_SUPPORTED = {"en", "hi", "mr", "ta", "te", "bn", "es", "fr", "it", "pt"}


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


def _gtx_translate(text: str, target: str) -> str | None:
    """Translate via Google's keyless `translate_a/single` endpoint using ONLY the standard library
    (urllib) — no `requests`, no `deep_translator`, no `langdetect` needed.

    Preferred over deep-translator's page scraping: it auto-detects the source (sl=auto), is the
    endpoint most libraries use, and is far less likely to be blocked from a server IP. Returns the
    translated string, or None on any failure."""
    if not text.strip():
        return None
    try:
        import json
        from urllib.parse import urlencode
        from urllib.request import Request, urlopen
        qs = urlencode({"client": "gtx", "sl": "auto", "tl": target, "dt": "t", "q": text})
        req = Request("https://translate.googleapis.com/translate_a/single?" + qs,
                      headers={"User-Agent": "Mozilla/5.0"})
        with urlopen(req, timeout=12) as resp:
            if resp.status != 200:
                return None
            data = json.loads(resp.read().decode("utf-8"))
        # data[0] is a list of [translatedSegment, originalSegment, ...]; join the translated bits
        # (segments carry their own newlines, so concatenation reproduces the line structure).
        segments = data[0] or []
        out = "".join(seg[0] for seg in segments if seg and seg[0] is not None)
        return out or None
    except Exception:
        return None


def _deep_translate(text: str, target: str) -> str | None:
    """Auto-detect fallback engine: deep-translator's GoogleTranslator (page scraping). Google
    endpoints rate-limit server IPs hard, so this is a last resort. None on failure."""
    try:
        from deep_translator import GoogleTranslator
        out = GoogleTranslator(source="auto", target=target).translate(text)
        return out or None
    except Exception:
        return None


def _mymemory(text: str, source: str, target: str) -> str | None:
    """Primary engine: MyMemory's free, keyless REST API — reliable from server IPs (unlike Google's
    unofficial endpoints). Needs an explicit source language. Set MYMEMORY_EMAIL to lift the daily
    word limit. None on failure or when the API returns a warning instead of a translation."""
    try:
        import os, json
        from urllib.parse import urlencode
        from urllib.request import Request, urlopen
        params = {"q": text, "langpair": f"{source}|{target}"}
        email = os.environ.get("MYMEMORY_EMAIL")
        if email:
            params["de"] = email
        req = Request("https://api.mymemory.translated.net/get?" + urlencode(params),
                      headers={"User-Agent": "Mozilla/5.0"})
        with urlopen(req, timeout=12) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        t = ((data.get("responseData") or {}).get("translatedText") or "").strip()
        up = t.upper()
        if not t or "MYMEMORY WARNING" in up or "INVALID" in up or "QUERY LENGTH" in up:
            return None
        return t
    except Exception:
        return None


# Script → best-guess source language, so we can translate even when langdetect is unavailable.
# Covers the primary non-Latin audiences; Latin scripts fall through to langdetect / auto engines.
_SCRIPTS = [("hi", 0x0900, 0x097F), ("bn", 0x0980, 0x09FF),
            ("ta", 0x0B80, 0x0BFF), ("te", 0x0C00, 0x0C7F)]


def _script_source(text: str) -> str | None:
    for ch in text:
        o = ord(ch)
        for code, lo, hi in _SCRIPTS:
            if lo <= o <= hi:
                return code
    return None


def _detect_source(text: str) -> str | None:
    """Source language for MyMemory: langdetect first, then a Unicode-script guess (so Hindi/Bengali/
    Tamil/Telugu still work if langdetect is missing). None → let the auto-detect engines try."""
    return _detect(text) or _script_source(text)


def _translate_one(text: str, target: str, source: str | None) -> str | None:
    """Translate a single string. MyMemory first (needs a source — use the detected one, else assume
    English for Latin text), then the Google auto-detect engines. None if all fail."""
    text = text.strip()
    if not text:
        return None
    src = source or "en"
    if src != target:
        t = _mymemory(text, src, target)
        if t:
            return t
    return _gtx_translate(text, target) or _deep_translate(text, target)


def _translate_list(strings: list[str], target: str) -> list[str] | None:
    """Translate a list into `target`, preserving order AND count via per-string translation (exact
    alignment). Detects one shared source for the whole list (recipes are single-language). Returns a
    same-length list, or None if nothing could be translated (caller then keeps the originals)."""
    sample = " ".join(s for s in strings[:4] if s).strip()
    source = _detect_source(sample)
    out: list[str] = []
    any_ok = False
    for s in strings:
        t = _translate_one(s, target, source)
        if t and not _is_error_response(t) and t.strip().lower() != s.strip().lower():
            out.append(t.strip()); any_ok = True
        else:
            out.append(s)
    return out if any_ok else None


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
    if source and source == target:
        # Confidently already in the target language — record it, nothing to translate.
        recipe["source_language"] = source
        return recipe
    # If source is unknown (langdetect missing/failed) we still translate — the endpoint auto-detects.

    # Collect every translatable string in a stable order, translate together, map results back.
    strings: list[str] = []
    slots: list[tuple] = []   # (kind, indices, string-index) to reassemble

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

    translated = _translate_list(strings, target)
    if translated is None:
        if source:
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

    if source:
        out["source_language"] = source   # so the app shows "Translated from <source>"
    return out


def translate_texts(texts: list[str], target_language: str | None) -> list[str]:
    """Translate a flat list of strings into `target_language`, preserving order and count.
    Detects the source from the combined text; if it already matches the target, is unsupported,
    or anything fails, the ORIGINAL list is returned unchanged (best-effort, never raises)."""
    target = (target_language or "").split("-")[0].lower()
    if target not in _SUPPORTED or not texts:
        return texts

    # Only skip when CONFIDENT it's already the target language. If detection is unavailable
    # (langdetect missing/failed → source None), still translate — the endpoint auto-detects.
    sample = " ".join(t for t in texts[:4] if t).strip()
    source = _detect(sample)
    if source and source == target:
        return texts

    # Only translate strings with real letters; keep pure numbers/symbols as-is.
    idxs = [i for i, t in enumerate(texts) if t and not _looks_untranslatable(t)]
    if not idxs:
        return texts

    translated = _translate_list([texts[i] for i in idxs], target)
    if translated is None:
        return texts

    out = list(texts)
    for slot, i in enumerate(idxs):
        if translated[slot]:
            out[i] = translated[slot]
    return out
