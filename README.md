# Field Capture

Offline-first SwiftUI field-capture app: create an item, capture many photos, generate five ≤700KB derivatives per photo locally, and submit eligible items to a mocked processing service. Built with SwiftUI, GRDB/SQLite, file-based image storage, and Swift Concurrency. iOS 17+, iPhone.

## Run

1. Open `field-capture.xcodeproj`, pick the **field-capture** scheme and an iOS 17+ simulator, and run.
2. GRDB is fetched automatically via Swift Package Manager — no extra setup.

Run the tests with **⌘U**, or:

```sh
xcodebuild test -scheme field-capture -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Inspecting the data

On launch (DEBUG builds) the app prints its on-disk container paths to the Xcode console — Home, Documents, the SQLite database, and the images directory:

```text
📦 App container
Home: …/data/Application/<UUID>
Documents: …/Documents
Database: …/Documents/field-capture.sqlite
Images: …/Documents/images
```

All persistent data lives under **Documents** (`field-capture.sqlite` plus an `images/` tree of originals and the five derivatives per photo). Paste the printed `Documents` path into Finder (⇧⌘G) to browse the database and image files. Image bytes are always files — never blobs in SQLite.

## How to test

> Camera capture requires a device. On the **Simulator** use the **Library** button to add photos.

- **Capture & save** — Gallery → **+** → enter a title, add photos via **Library**, **Save**. The card appears immediately as *Assets Processing*; open it to watch the five derivatives turn ready live.
- **8-hour rule** — an item is processable only once its derivatives are complete *and* it's 8 hours old. Open **Debug** (hammer icon) → **Make Eligible** to bypass the wait; the item flips to *Ready to Process*.
- **Process / fail / retry** — open a Ready item → **Process**. In **Debug**, *Force Next Failure* (one-shot) or *Simulate Offline* force a failure; the item then shows *Processing Failed* with **Retry**.
- **Done is terminal** — a successful item shows *Done* with no Process button and is never re-submitted.

## Assumptions & tradeoffs

- **Simulator camera.** The capture flow uses AVFoundation; the Simulator has no camera, so it falls back to the system photo picker.
- **≤700KB guarantee.** The generator steps JPEG quality (then dimensions) down until each derivative fits; if it can't, the derivative is marked *failed* (shown as *Assets Failed*) instead of writing an over-limit file.
- **Manual submit.** Processing is user-triggered so the distinct *Ready to Process* state exists — auto-submit would skip it.
- **Relative paths, files not blobs.** Only relative paths are stored in SQLite (absolute container paths break on reinstall); image bytes are always files.
- **Conservative recovery.** On launch, jobs interrupted mid-processing reset to *failed* (retryable; `done` is untouched) and unfinished derivatives resume. Files with no DB row are left in place — deleting them could race a concurrent save.
- **No backend, auth, or cloud** — the processing service is fully mocked locally.
