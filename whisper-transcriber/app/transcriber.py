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
MIN_SPEECH_SECONDS = float(os.getenv("MIN_SPEECH_SECONDS", "4.0"))  # below this = music/B-roll, not narration
_DEVICE_ENV = os.getenv("WHISPER_DEVICE")               # None → auto
_COMPUTE_ENV = os.getenv("WHISPER_COMPUTE_TYPE")           # None → float16 on GPU, int8 on CPU
DEVICE = _DEVICE_ENV or "auto"                             # "cuda" | "cpu" | "auto"
COMPUTE_TYPE = _COMPUTE_ENV or "int8"
BEAM_SIZE = int(os.getenv("WHISPER_BEAM_SIZE", "1"))
SAMPLE_RATE = 16_000


def resolve_whisper_runtime(device: str, compute: str | None, cuda_devices: int) -> tuple[str, str]:
    """Auto uses cuda/float16 when a GPU is visible. CPU int8 is the fallback.
    An explicit WHISPER_DEVICE=cpu (or cuda) keeps the operator's compute type."""
    requested = device or "auto"
    dev = "cuda" if requested == "auto" and cuda_devices > 0 else ("cpu" if requested == "auto" else requested)
    if requested == "auto" and dev == "cuda":
        comp = "float16"   # int8 in the image env is the old CPU default, not a GPU pin
    elif compute:
        comp = compute
    else:
        comp = "int8"
    if dev == "cpu" and comp == "float16":
        comp = "int8"
    return dev, comp


assert resolve_whisper_runtime("auto", None, 1) == ("cuda", "float16")
assert resolve_whisper_runtime("auto", "int8", 1) == ("cuda", "float16")
assert resolve_whisper_runtime("auto", "int8", 0) == ("cpu", "int8")
assert resolve_whisper_runtime("auto", None, 0) == ("cpu", "int8")
assert resolve_whisper_runtime("cpu", "int8", 1) == ("cpu", "int8")
assert resolve_whisper_runtime("cpu", "float16", 0) == ("cpu", "int8")


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
    """Load once and keep it warm. Auto uses the GPU when ctranslate2 sees one."""
    cuda_devices = 0
    if DEVICE == "auto":
        try:
            import ctranslate2
            cuda_devices = ctranslate2.get_cuda_device_count()
        except Exception:
            cuda_devices = 0
    device, compute = resolve_whisper_runtime(DEVICE, _COMPUTE_ENV, cuda_devices)
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


def detect_speech(audio_path: str) -> tuple[bool, float]:
    """Cheap pre-check (Silero VAD) — is there real narration, or just music/background?
    Returns (has_speech, speech_seconds). Far faster than a full transcription, so we can skip
    Whisper entirely on the many reels that are just B-roll over a music bed."""
    try:
        from faster_whisper.vad import get_speech_timestamps, VadOptions
        audio = decode_audio(audio_path, sampling_rate=SAMPLE_RATE)
        segments = get_speech_timestamps(audio, vad_options=VadOptions(min_silence_duration_ms=500))
        speech_samples = sum(int(s["end"]) - int(s["start"]) for s in segments)
        seconds = speech_samples / SAMPLE_RATE
        return (seconds >= MIN_SPEECH_SECONDS, round(seconds, 1))
    except Exception:
        return (True, 0.0)   # if VAD is unavailable, don't block transcription


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
