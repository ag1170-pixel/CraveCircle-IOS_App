"""
faster-whisper large-v3 transcriber for CraveCircle (the "Voiceprint" method).

Free, open-source (Whisper large-v3, MIT). Runs on the Homelab GPU via CTranslate2
(float16). Transcribes reel audio and detects the source language so the multi-language
feature knows what to translate from.

Two modes:
  - whole-file + VAD (default, chunk_seconds=0): highest quality — no words cut at
    arbitrary boundaries; faster-whisper segments internally.
  - hard chunks (chunk_seconds=60): the literal Voiceprint 60s-clip method, useful for
    streaming progress. Slightly lower quality at boundaries.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from functools import lru_cache

import numpy as np
from faster_whisper import WhisperModel, decode_audio

MODEL_NAME = os.getenv("WHISPER_MODEL", "small")
DEVICE = os.getenv("WHISPER_DEVICE", "auto")            # "cuda" | "cpu" | "auto"
COMPUTE_TYPE = os.getenv("WHISPER_COMPUTE_TYPE", "int8")    # float16 (GPU) | int8 (CPU)
BEAM_SIZE = int(os.getenv("WHISPER_BEAM_SIZE", "5"))
SAMPLE_RATE = 16_000


@dataclass
class Segment:
    start: float
    end: float
    text: str


@dataclass
class TranscriptResult:
    text: str
    language: str
    language_probability: float
    duration: float
    task: str
    segments: list[Segment] = field(default_factory=list)


@lru_cache(maxsize=1)
def _model() -> WhisperModel:
    """Load large-v3 once and keep it warm. Falls back CUDA->CPU if no GPU is present."""
    device = DEVICE
    compute = COMPUTE_TYPE
    if device == "auto":
        try:
            import ctranslate2
            device = "cuda" if ctranslate2.get_cuda_device_count() > 0 else "cpu"
        except Exception:
            device = "cpu"
    if device == "cpu" and compute == "float16":
        compute = "int8"   # float16 is a GPU compute type
    try:
        return WhisperModel(MODEL_NAME, device=device, compute_type=compute)
    except Exception as e:
        print(f"[Whisper] Device '{device}' init failed ({e}), falling back to CPU int8")
        return WhisperModel(MODEL_NAME, device="cpu", compute_type="int8")


def _run(audio: np.ndarray, language: str | None, task: str) -> tuple[list[Segment], object]:
    try:
        segments_iter, info = _model().transcribe(
            audio,
            language=language,          # None => auto-detect (what the multi-lang feature needs)
            task=task,                  # "transcribe" (source language) | "translate" (=> English)
            beam_size=BEAM_SIZE,
            vad_filter=True,            # drop background music / silence between speech
            vad_parameters={"min_silence_duration_ms": 500},
            condition_on_previous_text=True,
        )
        segs = [Segment(start=s.start, end=s.end, text=s.text.strip()) for s in segments_iter]
        return segs, info
    except Exception:
        segments_iter, info = _model().transcribe(
            audio,
            language=language,
            task=task,
            beam_size=BEAM_SIZE,
            vad_filter=False,
            condition_on_previous_text=True,
        )
        segs = [Segment(start=s.start, end=s.end, text=s.text.strip()) for s in segments_iter]
        return segs, info


def transcribe(
    audio_path: str,
    language: str | None = None,
    task: str = "transcribe",
    chunk_seconds: int = 0,
) -> TranscriptResult:
    """Transcribe an audio file. `language=None` auto-detects the reel's language."""
    audio = decode_audio(audio_path, sampling_rate=SAMPLE_RATE)  # ffmpeg-backed, 16k mono float32
    duration = round(len(audio) / SAMPLE_RATE, 2)

    if chunk_seconds and chunk_seconds > 0:
        return _transcribe_chunked(audio, duration, language, task, chunk_seconds)

    segs, info = _run(audio, language, task)
    return TranscriptResult(
        text=" ".join(s.text for s in segs).strip(),
        language=info.language,
        language_probability=round(float(info.language_probability), 3),
        duration=duration,
        task=task,
        segments=segs,
    )


def _transcribe_chunked(audio, duration, language, task, chunk_seconds) -> TranscriptResult:
    """The literal Voiceprint 60s-chunk method. Detect language once, reuse across chunks."""
    win = chunk_seconds * SAMPLE_RATE
    parts: list[str] = []
    all_segs: list[Segment] = []
    detected_lang = language
    detected_prob = 1.0

    for i in range(0, len(audio), win):
        clip = audio[i : i + win]
        segs, info = _run(clip, detected_lang, task)
        if detected_lang is None:           # lock language from the first chunk
            detected_lang = info.language
            detected_prob = round(float(info.language_probability), 3)
        offset = i / SAMPLE_RATE
        for s in segs:
            all_segs.append(Segment(start=s.start + offset, end=s.end + offset, text=s.text))
        parts.append(" ".join(s.text for s in segs).strip())

    return TranscriptResult(
        text=" ".join(p for p in parts if p).strip(),
        language=detected_lang or "unknown",
        language_probability=detected_prob,
        duration=duration,
        task=task,
        segments=all_segs,
    )
