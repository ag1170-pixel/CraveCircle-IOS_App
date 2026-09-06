# Full Setup Guide — Gesture Flashcards

This walks you from the zip to the app running on your iPhone, with the camera
permission step done in detail (the part that crashes the app if you skip it).

---

## Step 0 — Unzip
Double-click `GestureFlashcards.zip`. You get a `GestureFlashcards/` folder
containing a `GestureFlashcards/` source folder, `README.md`, `project.yml`,
and this guide.

---

## Path A (recommended, easiest) — let XcodeGen build the project

This auto-creates the `.xcodeproj` AND writes the camera permission for you, so
you never touch Info settings by hand.

1. Install XcodeGen once (needs Homebrew):
   ```bash
   brew install xcodegen
   ```
2. In Terminal, go into the folder that has `project.yml`:
   ```bash
   cd path/to/GestureFlashcards
   xcodegen generate
   open GestureFlashcards.xcodeproj
   ```
3. Skip to **Step 4 — Run on your iPhone** below. The camera permission is
   already set (it's baked into `project.yml`), so you can ignore Steps 2–3.

If you don't want to install XcodeGen, use **Path B**.

---

## Path B — build the Xcode project by hand

### Step 1 — Create a blank app and add the files
1. Open Xcode → **File ▸ New ▸ Project…**
2. Choose **iOS ▸ App**, click **Next**.
3. Fill in:
   - Product Name: `GestureFlashcards`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Leave Core Data / Tests unchecked.
4. Click **Next**, pick a folder, **Create**.
5. In the new project, Xcode made a `ContentView.swift` and a
   `GestureFlashcardsApp.swift`. **Delete both** (right-click → Delete → Move to
   Trash) — the zip has better versions.
6. In Finder, open the zip's inner `GestureFlashcards/` source folder. Select
   the folders **Camera, Vision, Gesture, Views, Models, Resources** and the two
   loose files **GestureFlashcardsApp.swift** and **ContentView.swift**.
7. **Drag them all into the Xcode left sidebar** (the file navigator), dropping
   them under the blue project icon.
8. In the dialog that appears, tick:
   - ✅ **Copy items if needed**
   - ✅ **Create groups**
   - ✅ your **GestureFlashcards** target (under "Add to targets")
   Click **Finish**.

### Step 2 — Add the camera usage description (the crucial step)

iOS refuses to open the camera unless your app declares *why*. Without this the
app crashes the instant it asks for the camera. Modern SwiftUI projects have no
`Info.plist` file in the sidebar, so you add it through the target settings:

1. In the left sidebar, click the **blue project icon** at the very top.
2. In the main panel, under **TARGETS**, select **GestureFlashcards**.
3. Click the **Info** tab along the top.
4. You'll see a list called **Custom iOS Target Properties** (or **Custom
   macOS/iOS Target Properties**). Hover over any row and click the small **+**
   button that appears.
5. A new editable row appears with a dropdown of key names. Type or pick:
   ```
   Privacy - Camera Usage Description
   ```
   (Its raw key name is `NSCameraUsageDescription` — Xcode shows the friendly
   label, but either works.)
6. Press **Tab** to move to the **Value** column and type:
   ```
   Used to detect your hand gestures so you can flip flashcards by swiping.
   ```
7. Press **Enter**. Done — that's the whole permission step.

> Prefer editing raw Info.plist text? The same key/value is in
> `Resources/Info-additions.plist` in the zip, ready to copy.

### Step 3 — Set the minimum iOS version
1. Still on the **GestureFlashcards** target, click the **General** tab.
2. Under **Minimum Deployments**, set **iOS 16.0** (or higher).

---

## Step 4 — Run on your iPhone (both paths)

The camera does **not** work in the Simulator, so you need a real device.

1. Plug your iPhone into the Mac with a cable. Unlock it. If asked, tap
   **Trust This Computer** on the phone.
2. In Xcode's top toolbar, click the device dropdown (next to the ▶ button) and
   pick **your iPhone** (not a Simulator).
3. **First time only — free Apple ID signing:**
   - Click the blue project icon → target **GestureFlashcards** →
     **Signing & Capabilities** tab.
   - Tick **Automatically manage signing**.
   - In **Team**, pick your Apple ID. If none is listed, click **Add an
     Account…**, sign in with your normal Apple ID (no paid developer account
     needed for running on your own phone).
   - If it complains the bundle identifier is taken, change it to something
     unique like `com.kit.gestureflashcards2`.
4. Press **⌘R** (or the ▶ button) to build and install.
5. **First launch on the phone** may show "Untrusted Developer". Fix it on the
   phone: **Settings ▸ General ▸ VPN & Device Management** → tap your Apple ID →
   **Trust**. Then tap the app icon to open it.
6. When the app opens it asks for camera access — tap **Allow**.

---

## Step 5 — Use it
- Hold the phone up, face the front camera.
- Show a flat **open palm** (the little camera box outline turns **green** and
  dots appear on your hand).
- **Sweep your open hand to the right → next card.** **Sweep left → previous.**
- A big arrow flashes and the card slides. There's a ~1 second cooldown so one
  sweep = one card.
- You can also just **swipe on the screen** with your finger to test navigation
  without using your hand.

---

## If something's off
- **App crashes immediately on launch** → the camera usage description is
  missing or misspelled. Redo **Step 2**.
- **Left/right are reversed** → open `Gesture/SwipeDetector.swift`, set
  `invertDirection = true`.
- **Swipes are too hard / too easy to trigger** → in the same file, lower or
  raise `distanceThreshold` (default `0.22`).
- **"No front camera available"** → you're on the Simulator; run on a real
  iPhone.
- **Nothing detected / no green box** → make sure your whole hand is in the
  camera box and well lit; move a bit farther back.

---

## Change the deck
Cards are numbers 1…20. Change the count in `ContentView.swift`
(`Flashcard.numbered(20)`), or replace `Models/Flashcard.swift` with your own
content.
