# CraveCircle — Whisper large-v3 Transcriber

Free, self-hosted transcription for the reel-import ("Voiceprint") pipeline, using
**Whisper large-v3** (MIT) via **faster-whisper** (CTranslate2) on the Homelab GPU.

Replaces the retired transcriber container. Transcribes reel audio **and detects the
source language** — which the iOS multi-language feature uses as the translation source.

## Why this build
- `large-v3` = strongest multilingual Whisper; handles Hindi/Marathi/English **code-switching** far better than base Whisper.
- faster-whisper + `float16` on GPU = ~4× faster, ~half the VRAM of vanilla `openai-whisper`, same accuracy.
- `vad_filter` drops background music/silence common in reels.

## Deploy on the Homelab

Prereqs: NVIDIA driver + **NVIDIA Container Toolkit** on the host.

```bash
# from ~/stacks/cravecircle (place this folder as ./whisper-transcriber and merge the compose service)
docker compose up -d --build whisper-transcriber
docker compose logs -f whisper-transcriber        # first boot downloads large-v3 (~3GB) into the volume
curl localhost:8009/health                        # {"ok":true,"model":"large-v3","device":"cuda"}
```

Model weights persist in the `whisper-models` volume — they are **not** re-synced from the
old deleted AI dirs (per the vault media policy); large-v3 downloads fresh from Hugging Face.

## API

```bash
# multipart upload
curl -F audio=@clip.wav http://localhost:8009/transcribe

# by URL (media-store signed URL, or a /data path mounted into the container)
curl -X POST http://localhost:8009/transcribe -H 'Content-Type: application/json' \
  -d '{"source_url":"https://api.cravecircle.cc/media/reels/<id>/audio.m4a","language":null,"task":"transcribe","chunk_seconds":0}'
```

Response:
```json
{ "text": "…", "language": "hi", "language_probability": 0.98, "duration": 47.2, "task": "transcribe", "segments": [ … ] }
```

- `language: null` → auto-detect (what the multi-language feature needs).
- `task: "transcribe"` → text in the **source** language. `task: "translate"` → Whisper's native translation, **to English only**.
- `chunk_seconds: 0` → whole-file + VAD (**best quality** — no words cut at boundaries).
  `chunk_seconds: 60` → the literal Voiceprint 60s-clip method (use for streaming progress).

## Wire into go-api
See [`go-integration/transcriber_client.go`](go-integration/transcriber_client.go).
After download → `ffmpeg -i reel.mp4 -vn -ac 1 -ar 16000 audio.wav` → `TranscribeURL(ctx, audioURL, "", "transcribe")`.
Reaches the service in-network at `http://whisper-transcriber:8009` (no public exposure).

## Multi-language note (important)
Whisper's `translate` task only goes **to English**. For arbitrary targets (Hindi→Marathi,
English→Tamil, etc.) do: **transcribe (source) → translate downstream** (an LLM or a
translation model such as NLLB/SeamlessM4T) into the user's chosen language. This service
owns transcription + language detection; target-language translation stays a separate step.

## Security
Tailnet/Docker-network only. Set `WHISPER_API_KEY` and send it as `X-Api-Key` from go-api if
you ever expose it beyond the Docker network. Do **not** put it behind a public tunnel.

## Hardware
Tuned for GPU (`float16`). No GPU? Set `WHISPER_DEVICE=cpu` + `WHISPER_COMPUTE_TYPE=int8`
(or use whisper.cpp large-v3-q5) — slower but still free.
