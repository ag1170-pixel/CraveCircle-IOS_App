# Deploy runbook — Whisper large-v3 + multi-language pipeline

Run these on a machine **on the Tailscale tailnet** (Homelab itself, or Anas Main), where
`cravecircle-backend` and the Homelab Supabase are reachable. Claude's sandbox has no
Tailscale, so these four steps are yours to run — they're copy-paste.

---

## 1. Deploy the Whisper service (GPU)

```bash
# on the Homelab, inside the compose project
cd ~/stacks/cravecircle
cp -r /path/to/whisper-transcriber ./whisper-transcriber      # this folder
# merge the service block from whisper-transcriber/docker-compose.yml into your stack, then:
docker compose up -d --build whisper-transcriber
docker compose logs -f whisper-transcriber                    # first boot pulls large-v3 (~3GB)
curl localhost:8009/health                                    # {"ok":true,"model":"large-v3","device":"cuda"}
```
Prereq: NVIDIA driver + **NVIDIA Container Toolkit** on the host.

## 2. Migrate the database

```bash
# apply on the Homelab Supabase Postgres (adjust connection to your setup)
psql "$SUPABASE_DB_URL" -f whisper-transcriber/migrations/0001_add_target_language.sql
# or paste the SQL into Supabase Studio -> SQL editor
```

## 3. Wire the pipeline into go-api

```bash
cd ~/GitHub\ Projects/cravecircle-backend        # your local backend clone
mkdir -p services/reelimport services/transcriber
cp /path/to/whisper-transcriber/go-integration/transcriber/transcriber_client.go services/transcriber/  # (rename dir/pkg to taste)
cp /path/to/whisper-transcriber/go-integration/reelimport/*.go services/reelimport/
```

Then implement the **5 interfaces** in `reelimport` against your real code. Skeleton to fill:

```go
// caption_parser.go — wrap your existing caption_parse.go
type captionParser struct{}
func (captionParser) Parse(text string) reelimport.Draft {
    parsed := captionparse.Parse(text)              // <- your real function
    return reelimport.Draft{ /* map fields */ }
}

// stores.go — wrap your Supabase data layer
type recipeStore struct{ db *sql.DB }
func (s recipeStore) Upsert(ctx context.Context, r reelimport.Recipe) (string, error) { /* INSERT … ON CONFLICT (owner_id, source_shortcode) DO UPDATE … RETURNING id */ }

type jobStore struct{ db *sql.DB }
func (s jobStore) SetStatus(ctx, id, status) error { /* UPDATE import_jobs SET status=$2, updated_at=now() WHERE id=$1 */ }
func (s jobStore) Complete(ctx, id, recipeID) error { /* … status='done', recipe_id=$2 … */ }
func (s jobStore) Fail(ctx, id, msg) error           { /* … status='error', error_message=$2 … */ }

// downloader.go — your yt-dlp + ffmpeg wrapper returning reelimport.ReelMedia
```

Fix the import path in `transcriber_client.go`'s reference (`aicookbook/go-api/services/transcriber`)
to your module path, then boot it in `main`:

```go
pipeline := &reelimport.Pipeline{
    Downloader: downloader{},
    Parser:     captionParser{},
    Whisper:    transcriber.Client{},                // implements TranscribeURL
    Translator: &reelimport.LLMTranslator{BaseURL: "http://ollama:11434/v1", Model: "qwen2.5:7b"}, // step 4; or nil
    Recipes:    recipeStore{db},
    Jobs:       jobStore{db},
}
go (&reelimport.Worker{DB: db, Pipeline: pipeline, Concurrency: 2}).Start(ctx)

// build & run
// go build ./... && ./go-api
```

## 4. Translator for non-English targets

Already written: `reelimport/translator.go` (`LLMTranslator`) — calls any OpenAI-compatible
endpoint. Point it at Ollama (`http://ollama:11434/v1`, `qwen2.5:7b`) or leave `Translator: nil`
to deliver recipes in their source language. Note: Ollama was retired on `non_ai`; reviving it
(or any small LLM) is required only if you want non-English translation.

---

## What's already done (iOS side, in this repo)
- App sends `target_language` with every import (`APIClient.submitImport`).
- Recipe Detail shows a **"Translated from …"** badge when `source_language` is set.
- Nothing else to change in the app.

## Verify end-to-end
1. In the app, Profile → Recipe language → pick Hindi.
2. Import a Hindi cooking reel.
3. Job flows queued → downloading → transcribing → extracting → done.
4. Recipe renders in Hindi (or English if `Translator` is nil) with the source-language badge.
