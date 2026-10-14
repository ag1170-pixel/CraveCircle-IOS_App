#!/usr/bin/env python3
"""Self-check for translate_recipe early-exit and merge logic (no network needed).

Run:  python3 test_translate.py
"""

import os
import sys

# Skip real LLM calls; the tests here exercise the paths that don't touch the network.
os.environ.setdefault("LLM_TRANSLATOR_URL", "")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from app.main import translate_recipe, _norm_lang, recipe_text_lang  # noqa: E402


def sample() -> dict:
    return {
        "title": "Butter Chicken",
        "description": "Rich creamy curry.",
        "prep_time": "10 min",
        "cook_time": "20 min",
        "servings": 2,
        "ingredients": [
            {"group_name": "Main", "items": ["600g chicken", "2 tbsp butter"]}
        ],
        "directions": [
            {"step_index": 1, "text": "Marinate chicken."},
            {"step_index": 2, "text": "Simmer in butter sauce."},
        ],
    }


def main() -> None:
    r = sample()

    # 1. same source and target -> unchanged
    assert translate_recipe(r, "en", "en") == r, "same-language must be a no-op"

    # 2. unknown target code -> unchanged
    assert translate_recipe(r, "en", "zz") == r, "unknown target must be a no-op"

    # 3. empty target -> unchanged
    assert translate_recipe(r, "en", "") == r, "empty target must be a no-op"

    # 4. LLM disabled (URL empty) -> unchanged even if target is real
    assert translate_recipe(r, "en", "ta") == r, "no-LLM must fall back to source language"

    # 5. norm_lang: two-letter prefix, lowercased
    assert _norm_lang("EN-US") == "en"
    assert _norm_lang(None) == ""
    assert _norm_lang("Ta") == "ta"

    # Whisper task=translate already wrote English. Do not wait on Ollama to
    # translate English into English just because the spoken tag is Hindi.
    assert recipe_text_lang("Add the butter and simmer.", "hi") == "en"
    assert _norm_lang("en") == _norm_lang(recipe_text_lang("Add the butter and simmer.", "hi"))
    # No English transcript: a Hindi recipe still needs translation to English.
    assert recipe_text_lang("", "hi") == "hi"
    assert _norm_lang("en") != _norm_lang(recipe_text_lang("", "hi"))
    # English transcript, user asked for Tamil: still translate.
    assert _norm_lang("ta") != _norm_lang(recipe_text_lang("Add the butter and simmer.", "hi"))

    print("OK: translate_recipe early-exit paths all correct.")


if __name__ == "__main__":
    main()
