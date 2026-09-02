// Package transcriber is the go-api client for the Homelab Whisper large-v3 service.
// Drop into services/go-api (adjust the package name to match your project).
//
// Wire it into the reel-import pipeline: after downloading the reel and extracting its
// audio (ffmpeg -i reel.mp4 -vn -ac 1 -ar 16000 audio.wav), call Transcribe with the
// audio path or a media-store URL. Use the returned Language as the translation source
// for the multi-language feature.
package transcriber

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

// Base URL inside the Docker network. Configure via env; never expose publicly.
var baseURL = env("WHISPER_URL", "http://whisper-transcriber:8009")
var apiKey = os.Getenv("WHISPER_API_KEY")

type Segment struct {
	Start float64 `json:"start"`
	End   float64 `json:"end"`
	Text  string  `json:"text"`
}

type Result struct {
	Text                string    `json:"text"`
	Language            string    `json:"language"`             // detected source language (e.g. "hi")
	LanguageProbability float64   `json:"language_probability"`
	Duration            float64   `json:"duration"`
	Task                string    `json:"task"`
	Segments            []Segment `json:"segments"`
}

type request struct {
	SourceURL    string  `json:"source_url"`
	Language     *string `json:"language"`      // nil => auto-detect
	Task         string  `json:"task"`          // "transcribe" | "translate"
	ChunkSeconds int     `json:"chunk_seconds"` // 0 => whole-file+VAD (best); 60 => Voiceprint chunks
}

// TranscribeURL asks Whisper to transcribe audio reachable at sourceURL (a media-store
// signed URL, or a /data path mounted into the container). language == "" auto-detects.
func TranscribeURL(ctx context.Context, sourceURL, language string, task string) (*Result, error) {
	if task == "" {
		task = "transcribe"
	}
	var langPtr *string
	if language != "" {
		langPtr = &language
	}
	payload, _ := json.Marshal(request{SourceURL: sourceURL, Language: langPtr, Task: task, ChunkSeconds: 0})

	ctx, cancel := context.WithTimeout(ctx, 10*time.Minute) // large-v3 is thorough; give it room
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/transcribe", bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if apiKey != "" {
		req.Header.Set("X-Api-Key", apiKey)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("whisper request failed: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("whisper returned %d", resp.StatusCode)
	}

	var out Result
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode whisper response: %w", err)
	}
	return &out, nil
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
