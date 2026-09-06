# Gesture Flashcards (iOS, native SwiftUI + Vision)

Flip flashcards with your hand. Show an **open palm** to the front camera and
**swipe left → previous**, **swipe right → next**. Uses Apple's Vision
`VNDetectHumanHandPoseRequest` on-device (no MediaPipe, no server, no network).

This is the native iOS port of your web hand-gesture tutor. The swipe logic
mirrors the web classifier's approach (finger-extension test, temporal gating)
but runs entirely through Vision + AVFoundation.

## Requirements
- macOS with Xcode 15+
- A **real iPhone** running iOS 16+ (the Simulator has no camera, so gestures won't work there)
- iOS 16.0 deployment target

## Fastest setup — XcodeGen (optional)
```bash
brew install xcodegen
cd GestureFlashcards
xcodegen generate
open GestureFlashcards.xcodeproj
```
Then pick your iPhone as the run destination and press ⌘R.

## Manual setup (no XcodeGen)
1. Xcode → **File ▸ New ▸ Project… ▸ iOS ▸ App**. Name it `GestureFlashcards`,
   Interface **SwiftUI**, Language **Swift**.
2. Delete the auto-generated `ContentView.swift` and the `…App.swift`.
3. Drag every file under `GestureFlashcards/` in this folder into the Xcode
   project navigator (check **Copy items if needed** and your app target).
   Keep the folder groups (Camera, Vision, Gesture, Views, Models).
4. Add the camera permission string: select the **target ▸ Info** tab, add a row
   **Privacy - Camera Usage Description** with the value from
   `Resources/Info-additions.plist`. (Skipping this crashes the app on launch.)
5. Set the deployment target to iOS 16.0, select your iPhone, ⌘R.
6. On the phone: **Settings ▸ General ▸ VPN & Device Management** → trust your
   developer certificate the first time.

## How it works
- `Camera/CameraManager.swift` — front-camera `AVCaptureSession`, mirrored,
  throttled to ~20 Hz, feeds frames to Vision.
- `Vision/HandPoseProcessor.swift` — runs the hand-pose request, computes palm
  center + which fingers are extended, flags an **open palm**.
- `Gesture/SwipeDetector.swift` — the swipe brain. Only tracks while the palm is
  open (the "pose gate"), fires when the palm travels past a distance threshold
  within a time window, then enforces a cooldown so one sweep = one card.
- `Views/…` + `ContentView.swift` — the flashcard deck, camera PiP with a live
  skeleton overlay (green = open palm), and directional slide animations.

## Tuning the gesture (top of `SwipeDetector.swift`)
| Property | Default | Effect |
|---|---|---|
| `distanceThreshold` | `0.22` | Lower = swipes trigger with less motion |
| `windowSeconds` | `0.7` | How long a sweep may take |
| `cooldown` | `1.0` | Min seconds between navigations |
| `invertDirection` | `false` | Flip if left/right feel reversed |

Camera framerate for Vision is in `CameraManager.minFrameInterval`.

## The deck
Cards are just numbers (1…20) — this app is about navigating by hand, not
reading gestures. Change the count in `ContentView.swift`
(`Flashcard.numbered(20)`) or replace the model in `Models/Flashcard.swift`
with your own content.

## Notes
- A drag gesture on screen also navigates — handy for testing without a hand.
- Everything runs on-device; nothing leaves the phone.
