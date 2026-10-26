# Apple alignment — why CraveCircle sits on top of what Apple just launched

> This is for the mentor review. We want to be explicit about the fact that
> CraveCircle is not an app that "could someday use Apple AI" — it is a native
> iOS app built on top of the specific frameworks Apple is pushing right now.

---

## 1. The short version

Apple's recent iOS 26 launch has made three bets:

1. **AI runs on your device, not on a stranger's server.**
2. **Hands-free, voice-first experiences for the home — especially the kitchen.**
3. **Structured, "guided" AI output that apps can actually render — not raw text.**

CraveCircle is a working product that uses all three.

Where other recipe apps upload your reel to OpenAI, we read it on the phone.
Where other recipe apps give you a block of text to scroll, we give you a
voice-driven flashcard. Where other recipe apps leave you to copy-paste into a
grocery list, we schedule the cook, remind you 30 min before, and group your
groceries by aisle.

---

## 2. What Apple shipped that we ride on

### 2.1 Foundation Models framework (on-device LLM)

Apple exposes an on-device large language model (around a 3-billion-parameter
transformer) to developers in iOS 26 through the `FoundationModels` framework.
The headline feature is **guided generation**: you can ask the model to produce
a value of a specific Swift type, and the framework enforces the structure.

- Where other apps call GPT-4 to extract a recipe from a transcript, we hand the
  transcript to the on-device model and ask it to produce a `Recipe` struct —
  ingredients grouped by section, directions ordered, times parsed.
- No API key, no network round-trip, no per-request cost, no privacy exposure.
  See `AICookBook/RecipeExtractor.swift` — the whole extraction is behind
  `#if canImport(FoundationModels)`.
- On a device without Apple Intelligence we fall back to a heuristic parser so
  the import still works. The heuristic is honest about being less polished.

### 2.2 SpeechAnalyzer / SpeechTranscriber (Neural Engine transcription)

iOS 26's `SpeechAnalyzer` lets us transcribe audio on the Neural Engine without
shipping a Whisper model. We feed it the reel's audio file; it hands us back
clean timestamped transcription.

- Our `AICookBook/OnDeviceTranscriber.swift` is a 100-line wrapper over
  `SpeechAnalyzer` + `SpeechTranscriber`.
- Audio never leaves the phone.

### 2.3 Vision framework (OCR)

Vision is the long-standing framework for text and image recognition on-device.
We use it in two places:

- **Import from photo** — pick a cookbook photo or a Pinterest screenshot; Vision
  recognises the text; the Foundation Models framework structures it.
- **Discover reel on-screen text** — read "SALT 2 tsp" captions out of a cooking
  video for the recipe.

### 2.4 Hands-free voice (SFSpeechRecognizer + AVAudioEngine)

Apple ships SFSpeechRecognizer with built-in acoustic noise cancellation and
hardware beam-forming. We bind that into a wake-word pattern ("Hey Crave") and
sustain-mode listening while the flashcards are up.

- `AICookBook/VoiceCommandController.swift` — on-device, zero network.
- Honors Reduce Motion and VoiceOver, pauses when the user is screen-reading.

### 2.5 ActivityKit — Live Activity for the import progress banner

The import pipeline runs in a few phases (downloading → listening →
transcribing → extracting → done). We surface this on the Dynamic Island as a
Live Activity so the user can leave the app and come back.

### 2.6 UserNotifications — scheduled cook reminders

When a user plans a meal, we schedule a local `UNNotificationRequest` 30 minutes
before the planned cook time, with the recipe title in the payload. Tapping the
notification jumps straight into Cook Mode. All on-device.

---

## 3. The pattern Apple seems to be chasing

Apple has been showing, both at WWDC and in subsequent demos, a direction we
read as:

> **"Private, on-device AI that lives on the kitchen counter — hands-free,
> glanceable, Siri-aware, and useful without being a social feed."**

Think of the way recipe cards show up in Smart Stacks, the way the Home
app has been edging toward richer home-moment surfaces, the way Visual
Intelligence reads physical objects (ingredients included), and the way
Apple Intelligence suggests actions on your lock screen.

CraveCircle is **a complete product that fits that direction**:

- The one surface Apple hasn't shipped as a first-party app is the one we built:
  **turn a shared reel into a cookable, scalable, nutritious recipe, offline, and
  guide the user through it with voice.**
- We don't compete with Apple's platform work — we are the kind of third-party
  app Apple's platform work exists to enable. The platform gives us
  transcription + an LLM + voice + notifications; we spend our time on the
  product (editorial, social, grocery, nutrition).

---

## 4. Why that matters for the review

Three concrete claims the reviewers can verify:

1. **Open `AICookBook/RecipeExtractor.swift`** — it imports `FoundationModels`
   and uses guided generation with a `@Generable Recipe` type. That is Apple's
   recommended pattern verbatim.
2. **Open `AICookBook/OnDeviceTranscriber.swift`** — it uses
   `SpeechAnalyzer(modules: [transcriber])` on-device, exactly the shape Apple
   shows in the iOS 26 docs.
3. **Open `AICookBook/VoiceCommandController.swift` + `FloatingVoiceAssistantView.swift`**
   — a working wake-word implementation with the Apple-blessed audio session
   setup.

Nothing is "coming soon". Nothing requires a cloud component we haven't built.
The app runs on an iPhone 17 Pro simulator without a network connection and the
import still works via the heuristic parser.

---

## 5. What this means for the Mac App Store / Vision Pro

Because we built on Apple frameworks rather than our own ML or a server-side
LLM, our port surfaces are small:

- **iPad** — mostly ships for free; some screens need landscape layout work.
- **macOS Catalyst** — same story.
- **visionOS** — the hands-free Cook Mode is already the natural visionOS
  interaction model. Flashcards become a floating window; "Hey Crave" works
  identically.

Not promising these in v1 — but the engineering debt to get there is low because
Apple's frameworks already span them.

---

## 6. One honest caveat

The on-device Foundation Models framework is new. On devices without Apple
Intelligence (iPhone 15 and earlier) the extraction falls back to a smaller
heuristic parser. We're explicit about this in the import UI — the user sees
"Extracting with Apple Intelligence" or "Extracting (basic)" based on
capability. This is also why our App Store description says "about 30 seconds"
not "30 seconds" — the time scales with the hardware.

---

For details on specific files see the inline comments in `AICookBook/`.
Questions: `help@cravecircle.cc` or open an issue on the repo.
