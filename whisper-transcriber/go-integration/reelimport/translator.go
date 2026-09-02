// LLM-based Translator for non-English target languages.
//
// Whisper only translates to English, so this handles arbitrary targets (Hindi->Marathi,
// English->Tamil, …). It calls any OpenAI-compatible chat endpoint — Ollama, vLLM, or
// OpenAI — and translates the recipe's text fields while preserving structure, numbers,
// and units. Wire it into Pipeline.Translator, or leave that nil to deliver in source language.
//
// Example (Ollama on the Homelab):
//   tr := &LLMTranslator{BaseURL: "http://ollama:11434/v1", Model: "qwen2.5:7b"}
package reelimport

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

type LLMTranslator struct {
	BaseURL string       // e.g. "http://ollama:11434/v1" or "https://api.openai.com/v1"
	Model   string       // e.g. "qwen2.5:7b"
	APIKey  string       // optional (Ollama ignores it)
	Client  *http.Client // optional; defaults to a 60s client
}

// Only the translatable fields cross the wire — servings/step indices stay in Go.
type translatable struct {
	Title       string              `json:"title"`
	Description string              `json:"description"`
	PrepTime    string              `json:"prep_time"`
	CookTime    string              `json:"cook_time"`
	Ingredients []translatableGroup `json:"ingredients"`
	Directions  []string            `json:"directions"`
}

type translatableGroup struct {
	GroupName string   `json:"group_name"`
	Items     []string `json:"items"`
}

func (t *LLMTranslator) Translate(ctx context.Context, draft Draft, sourceLang, targetLang string) (Draft, error) {
	target := languageName(targetLang)
	if target == "" {
		return draft, nil // unknown target — deliver as-is rather than guessing
	}

	payload := translatable{
		Title:       draft.Title,
		Description: draft.Description,
		PrepTime:    draft.PrepTime,
		CookTime:    draft.CookTime,
		Directions:  make([]string, len(draft.Directions)),
	}
	for _, g := range draft.Ingredients {
		payload.Ingredients = append(payload.Ingredients, translatableGroup{GroupName: g.GroupName, Items: g.Items})
	}
	for i, d := range draft.Directions {
		payload.Directions[i] = d.Text
	}

	src, _ := json.Marshal(payload)
	sys := "You are a professional culinary translator. Translate the recipe's user-facing text " +
		"into " + target + ". Keep the EXACT same JSON shape and array lengths. Preserve all numbers, " +
		"quantities, and units (e.g. '200g', '2', '8 min') unchanged. Do not add, remove, or reorder items. " +
		"Return ONLY the JSON object, no prose, no code fences."
	user := "Translate this recipe JSON to " + target + ":\n" + string(src)

	raw, err := t.chat(ctx, sys, user)
	if err != nil {
		return draft, fmt.Errorf("translate: %w", err)
	}

	var out translatable
	if err := json.Unmarshal([]byte(stripFences(raw)), &out); err != nil {
		return draft, fmt.Errorf("translate: bad model JSON: %w", err)
	}

	// Merge translations back, guarding against a model that changed array lengths.
	res := draft
	res.Title = firstNonEmpty(out.Title, draft.Title)
	res.Description = firstNonEmpty(out.Description, draft.Description)
	res.PrepTime = firstNonEmpty(out.PrepTime, draft.PrepTime)
	res.CookTime = firstNonEmpty(out.CookTime, draft.CookTime)
	if len(out.Ingredients) == len(draft.Ingredients) {
		for i := range draft.Ingredients {
			if len(out.Ingredients[i].Items) == len(draft.Ingredients[i].Items) {
				res.Ingredients[i].GroupName = out.Ingredients[i].GroupName
				res.Ingredients[i].Items = out.Ingredients[i].Items
			}
		}
	}
	if len(out.Directions) == len(draft.Directions) {
		for i := range draft.Directions {
			if s := strings.TrimSpace(out.Directions[i]); s != "" {
				res.Directions[i].Text = s
			}
		}
	}
	return res, nil
}

// ---- OpenAI-compatible chat call ----

type chatReq struct {
	Model    string    `json:"model"`
	Messages []chatMsg `json:"messages"`
	Stream   bool      `json:"stream"`
	Format   string    `json:"format,omitempty"` // Ollama: "json"
}
type chatMsg struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}
type chatResp struct {
	Choices []struct {
		Message chatMsg `json:"message"`
	} `json:"choices"`
}

func (t *LLMTranslator) chat(ctx context.Context, system, user string) (string, error) {
	client := t.Client
	if client == nil {
		client = &http.Client{Timeout: 60 * time.Second}
	}
	body, _ := json.Marshal(chatReq{
		Model:  t.Model,
		Stream: false,
		Format: "json",
		Messages: []chatMsg{
			{Role: "system", Content: system},
			{Role: "user", Content: user},
		},
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(t.BaseURL, "/")+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	if t.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+t.APIKey)
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("llm returned %d", resp.StatusCode)
	}
	var out chatResp
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", err
	}
	if len(out.Choices) == 0 {
		return "", fmt.Errorf("llm returned no choices")
	}
	return out.Choices[0].Message.Content, nil
}

// ---- helpers ----

func languageName(code string) string {
	switch norm(code) {
	case "en":
		return "English"
	case "hi":
		return "Hindi"
	case "mr":
		return "Marathi"
	case "ta":
		return "Tamil"
	case "te":
		return "Telugu"
	case "bn":
		return "Bengali"
	case "es":
		return "Spanish"
	case "fr":
		return "French"
	default:
		return ""
	}
}

func stripFences(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "```json")
	s = strings.TrimPrefix(s, "```")
	s = strings.TrimSuffix(s, "```")
	return strings.TrimSpace(s)
}

func firstNonEmpty(a, b string) string {
	if strings.TrimSpace(a) != "" {
		return a
	}
	return b
}
