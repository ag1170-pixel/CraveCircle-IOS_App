// Package reelimport orchestrates the reel -> recipe pipeline for go-api.
//
// This is the drop-in wiring for the "Voiceprint" method with Whisper large-v3:
//
//   queued -> downloading -> transcribing -> extracting -> done | error
//
//   1. Download the reel (caption, thumbnail, audio)                 [Downloader]
//   2. Caption-first parse                                           [CaptionParser]  <- source of truth
//   3. If the caption is incomplete, transcribe the AUDIO with       [Transcriber]    <- Whisper large-v3
//      Whisper (detects source language) and MERGE (never overwrite)
//   4. Optionally translate into the user's chosen language          [Translator]     <- LLM / NLLB / Seamless
//   5. Normalize -> Recipe (with SourceLanguage) -> upsert           [RecipeStore]
//
// Adapt the interfaces to your existing go-api implementations. The status strings match
// the iOS `ImportStatus` enum exactly so the app's polling UI just works.
package reelimport

import (
	"context"
	"errors"
	"fmt"
	"strings"

	// Adjust this import path to wherever you place transcriber_client.go in go-api.
	"aicookbook/go-api/services/transcriber"
)

// ---- Status (matches iOS ImportStatus) ----

type Status string

const (
	StatusQueued       Status = "queued"
	StatusDownloading  Status = "downloading"
	StatusTranscribing Status = "transcribing"
	StatusExtracting   Status = "extracting"
	StatusDone         Status = "done"
	StatusError        Status = "error"
)

// ---- Domain types (mirror the iOS Recipe model) ----

type IngredientGroup struct {
	GroupName string   `json:"group_name,omitempty"`
	Items     []string `json:"items"`
}

type DirectionStep struct {
	StepIndex int    `json:"step_index"`
	Text      string `json:"text"`
}

type Draft struct {
	Title       string
	Description  string
	PrepTime    string
	CookTime    string
	Servings    int
	Ingredients []IngredientGroup
	Directions  []DirectionStep
}

type Recipe struct {
	ID             string            `json:"id"`
	OwnerID        string            `json:"owner_id"`
	Title          string            `json:"title"`
	Description    string            `json:"description,omitempty"`
	PrepTime       string            `json:"prep_time,omitempty"`
	CookTime       string            `json:"cook_time,omitempty"`
	Servings       int               `json:"servings,omitempty"`
	Ingredients    []IngredientGroup `json:"ingredients"`
	Directions     []DirectionStep   `json:"directions"`
	ThumbnailURL   string            `json:"thumbnail_url,omitempty"`
	OwnerUsername  string            `json:"owner_username,omitempty"`
	SourceReel     string            `json:"source_reel,omitempty"`
	SourceLang     string            `json:"source_language,omitempty"` // <- feeds the iOS "Translated from…" badge
	SourceShortcode string            `json:"source_shortcode,omitempty"`
}

// ReelMedia is what the downloader returns.
type ReelMedia struct {
	Shortcode      string
	Caption        string
	AuthorUsername string
	ThumbnailURL   string // media-store URL (already stored)
	AudioURL       string // media-store URL or /data path to extracted 16k mono audio
}

// Job is the import_jobs row.
type Job struct {
	ID             string
	OwnerID        string
	URL            string
	TargetLanguage string // user's preferred recipe language, e.g. "en" or "hi" (may be empty)
}

// ---- Dependencies (wire your real implementations) ----

type Downloader interface {
	// Fetch downloads the reel, stores thumbnail + extracts audio to the media-store,
	// and returns their URLs plus the caption. (yt-dlp + ffmpeg live behind this.)
	Fetch(ctx context.Context, url string) (ReelMedia, error)
}

type CaptionParser interface {
	// Parse is your deterministic caption_parse.go. Also used to parse the transcript.
	Parse(text string) Draft
}

type Transcriber interface {
	TranscribeURL(ctx context.Context, sourceURL, language, task string) (*transcriber.Result, error)
}

// Translator is optional. Whisper only translates to English, so target-language
// delivery (Hindi->Marathi, English->Tamil, …) goes through this downstream step.
type Translator interface {
	Translate(ctx context.Context, draft Draft, sourceLang, targetLang string) (Draft, error)
}

type RecipeStore interface {
	// Upsert on (owner_id, source_shortcode) so worker retries don't create duplicates.
	Upsert(ctx context.Context, r Recipe) (string, error)
}

type JobStore interface {
	SetStatus(ctx context.Context, jobID string, s Status) error
	Complete(ctx context.Context, jobID, recipeID string) error
	Fail(ctx context.Context, jobID, userSafeMessage string) error
}

// ---- Pipeline ----

type Pipeline struct {
	Downloader Downloader
	Parser     CaptionParser
	Whisper    Transcriber
	Translator Translator // may be nil (then non-English targets fall back to source language)
	Recipes    RecipeStore
	Jobs       JobStore
}

// Run executes the whole job. Call this from the worker loop (SELECT … FOR UPDATE SKIP LOCKED).
func (p *Pipeline) Run(ctx context.Context, job Job) (recipeID string, err error) {
	defer func() {
		if err != nil {
			_ = p.Jobs.Fail(ctx, job.ID, userSafe(err))
		}
	}()

	// 1. Download + extract audio
	_ = p.Jobs.SetStatus(ctx, job.ID, StatusDownloading)
	media, err := p.Downloader.Fetch(ctx, job.URL)
	if err != nil {
		return "", fmt.Errorf("download: %w", err)
	}

	// 2. Caption-first parse (source of truth)
	draft := p.Parser.Parse(media.Caption)
	sourceLang := "" // unknown until Whisper runs; caption alone doesn't tell us reliably

	// 3. Escalate to Whisper only when the caption is thin (the Voiceprint rule)
	if !isComplete(draft) && media.AudioURL != "" {
		_ = p.Jobs.SetStatus(ctx, job.ID, StatusTranscribing)
		res, terr := p.Whisper.TranscribeURL(ctx, media.AudioURL, "" /*auto-detect*/, "transcribe")
		if terr != nil {
			// Transcription is best-effort: keep whatever the caption gave us rather than failing.
			// (Log terr in your telemetry.)
			_ = terr
		} else {
			sourceLang = res.Language
			transcriptDraft := p.Parser.Parse(res.Text)
			draft = merge(draft, transcriptDraft) // MERGE — caption wins, transcript fills gaps
		}
	}

	// 4. Optional: translate into the user's chosen language (Whisper can't do non-English targets)
	_ = p.Jobs.SetStatus(ctx, job.ID, StatusExtracting)
	if p.Translator != nil && shouldTranslate(sourceLang, job.TargetLanguage) {
		if translated, terr := p.Translator.Translate(ctx, draft, sourceLang, job.TargetLanguage); terr == nil {
			draft = translated
		} // else: keep source-language draft; UI still shows "Translated from…" only when langs differ
	}

	if !hasContent(draft) {
		return "", errors.New("could not extract a recipe from this reel")
	}

	// 5. Normalize -> Recipe -> upsert
	recipe := normalize(draft, media, job, sourceLang)
	id, err := p.Recipes.Upsert(ctx, recipe)
	if err != nil {
		return "", fmt.Errorf("save recipe: %w", err)
	}

	if err = p.Jobs.Complete(ctx, job.ID, id); err != nil {
		return "", fmt.Errorf("complete job: %w", err)
	}
	return id, nil
}

// ---- Merge + heuristics ----

// isComplete decides whether the caption alone is enough (skip transcription).
func isComplete(d Draft) bool {
	return countIngredients(d) >= 2 && len(d.Directions) >= 2
}

func hasContent(d Draft) bool { return countIngredients(d) >= 1 || len(d.Directions) >= 1 }

func countIngredients(d Draft) int {
	n := 0
	for _, g := range d.Ingredients {
		n += len(g.Items)
	}
	return n
}

// merge keeps the caption draft and only fills gaps from the transcript. Caption is
// source of truth; never overwrite a field the caption already provided.
func merge(caption, transcript Draft) Draft {
	out := caption
	if strings.TrimSpace(out.Title) == "" {
		out.Title = transcript.Title
	}
	if strings.TrimSpace(out.Description) == "" {
		out.Description = transcript.Description
	}
	if out.PrepTime == "" {
		out.PrepTime = transcript.PrepTime
	}
	if out.CookTime == "" {
		out.CookTime = transcript.CookTime
	}
	if out.Servings == 0 {
		out.Servings = transcript.Servings
	}
	if countIngredients(out) == 0 {
		out.Ingredients = transcript.Ingredients
	}
	if len(out.Directions) == 0 {
		out.Directions = renumber(transcript.Directions)
	}
	return out
}

func renumber(steps []DirectionStep) []DirectionStep {
	for i := range steps {
		steps[i].StepIndex = i + 1
	}
	return steps
}

func shouldTranslate(source, target string) bool {
	if target == "" {
		return false
	}
	return norm(source) != norm(target)
}

func norm(code string) string {
	if len(code) >= 2 {
		return strings.ToLower(code[:2])
	}
	return strings.ToLower(code)
}

func normalize(d Draft, media ReelMedia, job Job, sourceLang string) Recipe {
	title := strings.TrimSpace(d.Title)
	if title == "" {
		title = deriveTitle(media.Caption)
	}
	// Only record a source language when it actually differs from what we delivered —
	// that's when the iOS "Translated from…" badge should appear.
	badgeLang := ""
	if shouldTranslate(sourceLang, job.TargetLanguage) {
		badgeLang = norm(sourceLang)
	}
	return Recipe{
		OwnerID:        job.OwnerID,
		Title:          title,
		Description:    strings.TrimSpace(d.Description),
		PrepTime:       d.PrepTime,
		CookTime:       d.CookTime,
		Servings:       d.Servings,
		Ingredients:    d.Ingredients,
		Directions:     renumber(d.Directions),
		ThumbnailURL:   media.ThumbnailURL,
		OwnerUsername:  media.AuthorUsername,
		SourceReel:     job.URL,
		SourceShortcode: media.Shortcode,
		SourceLang:     badgeLang,
	}
}

func deriveTitle(caption string) string {
	line := strings.TrimSpace(strings.SplitN(caption, "\n", 2)[0])
	if len(line) > 60 {
		line = line[:60]
	}
	if line == "" {
		return "Imported Recipe"
	}
	return line
}

// userSafe strips scraper/internal detail before it reaches the app.
func userSafe(err error) string {
	switch {
	case strings.Contains(err.Error(), "download"):
		return "Couldn't fetch that reel. Check the link and try again."
	case strings.Contains(err.Error(), "extract"):
		return "Couldn't find a recipe in this reel."
	default:
		return "Something went wrong. Please try again."
	}
}
