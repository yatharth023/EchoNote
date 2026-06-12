# EchoNote

EchoNote is an offline-first, privacy-first iOS app that provides real-time speech transcription for neurodivergent and hard-of-hearing users. All transcription runs fully on-device using WhisperKit's CoreML-accelerated Whisper models — no internet connection required, no audio data ever leaves the device.

## Features

- **Live transcription** — streams audio through WhisperKit's `AudioStreamTranscriber` with voice activity detection (VAD) and segment confirmation
- **Bionic reading** — bolds the first ~45% of each word to speed up visual scanning and comprehension
- **Linguistic highlight filters** — highlight verbs (blue), nouns (green), or both via Apple's NaturalLanguage framework (`NLTagger`)
- **Audio waveform visualizer** — animated 9-bar amplitude display driven by real-time buffer energy during recording
- **Auto-scroll with snap** — transcript follows live speech; a floating "Snap to Live Voice" button re-anchors on manual scroll
- **Accessibility settings** — persistent text size, high-contrast mode, reduce-motion, and auto-scroll-speed controls that propagate live to the transcript and history views via an `@Observable AppSettings` model injected through the environment
- **Session history** — all sessions persisted with SwiftData; browse, delete (swipe), and rename titles inline
- **Content-aware history search** — the History search bar matches both session titles and the full transcript text of every chunk, and renders an inline snippet preview with the matched keyword highlighted
- **In-session full-text search** — regex-backed search across saved transcripts with yellow/orange match highlighting and prev/next navigation
- **Core Spotlight integration** — sessions are indexed system-wide via `SpotlightIndexer` (bulk re-index on launch, single-session re-index on title edit, and removal on delete); tapping a Spotlight result switches to the History tab and opens that transcript directly
- **Model management** — bundled `openai_whisper-small.en` (~217 MB) plus downloadable Large v3 and Large v3 Turbo variants with in-app progress tracking; activation is optimistic (the green tick moves instantly with a small in-progress spinner) and reverts cleanly if the load fails
- **Device-aware model recommendations** — `DeviceCapabilityAnalyzer` inspects RAM and CPU core count to recommend the optimal model tier
- **Onboarding flow** — first-launch screen loads the bundled model before any recording starts
- **Haptic feedback** — medium, light, and error notification haptics tied to record/stop and error events
- **Audio interruption handling** — recording stops gracefully on phone calls, Siri, or other audio session interruptions

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI + Swift Observation (`@Observable`) |
| Persistence | SwiftData (`EchoSession`, `TranscriptionChunk`) |
| Speech Engine | WhisperKit (`AudioStreamTranscriber`, CoreML) |
| NLP | Apple NaturalLanguage (`NLTagger`, lexical class tagging) |
| System Search | CoreSpotlight (`CSSearchableIndex`) |
| Audio | AVFoundation (audio session interruption handling) |
| Concurrency | Swift structured concurrency, `@MainActor`, Swift actors |

## Requirements

- Xcode 15.3+
- iOS 17+ deployment target
- Physical iPhone (Simulator lacks microphone input for live transcription)
- ~300 MB free storage for the bundled model

## Project Structure

```
EchoNote/
├── EchoNoteApp.swift                    # App entry, TabView, Spotlight handler, onboarding gate, bulk Spotlight re-index on launch, AppSettings injection
├── Models/
│   ├── AppSettings.swift                # @Observable, UserDefaults-backed accessibility prefs (text size, high contrast, reduce motion, auto-scroll speed) exposed via environment
│   ├── EchoSession.swift                # SwiftData model: session metadata + Spotlight identifiers
│   ├── TranscriptionChunk.swift         # SwiftData model: raw text segment per recording
│   └── WhisperModelInfo.swift           # Model catalog (small.en, large-v3, large-v3-turbo)
├── ViewModels/
│   └── LiveTranscriptViewModel.swift    # Core VM: WhisperKit lifecycle, optimistic model activation, session save, UI state
├── Views/
│   ├── Live/
│   │   └── LiveTranscriptView.swift     # Recording screen, waveform, highlight mode picker (reads AppSettings)
│   ├── History/
│   │   ├── HistoryListView.swift        # Session list, content-aware search across chunks, swipe-to-delete (with Spotlight cleanup)
│   │   ├── SessionDetailView.swift      # Full transcript with in-session search, title edit (re-indexes Spotlight)
│   │   └── TranscriptSearchBar.swift    # Search bar UI component
│   ├── Settings/
│   │   ├── SettingsView.swift           # Live-bound accessibility options + preview swatch
│   │   └── ModelManagementView.swift    # Download/activate Whisper variants with instant green-tick swap and in-progress spinner
│   └── Onboarding/
│       └── ModelSetupView.swift         # First-launch model load screen
└── Services/
    ├── Processing/
    │   ├── SpotlightIndexer.swift           # Centralized CoreSpotlight index/indexAll/remove for EchoSession
    │   ├── TextProcessingService.swift      # Bionic reading + NL lexical tagging (Swift actor)
    │   └── TranscriptSearchManager.swift    # Regex search and match navigation across chunks
    └── ModelManagement/
        └── DeviceCapabilityAnalyzer.swift   # RAM/core heuristics → model tier recommendation
```

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/<your-username>/EchoNote.git
cd EchoNote
```

### 2. Download the bundled Whisper model

The `openai_whisper-small.en` CoreML model (~217 MB) is excluded from the repository. Download it before building:

```bash
pip install huggingface_hub   # skip if already installed
huggingface-cli download argmaxinc/whisperkit-coreml \
  --include "openai_whisper-small.en/*" \
  --local-dir ./BundledModels/openai_whisper-small.en
```

The model folder is referenced as a folder reference inside the Xcode project and is copied into the app bundle at build time.

### 3. Build and run

```bash
open EchoNote.xcodeproj
```

Select a physical iPhone as the run destination (⌘R). The first launch triggers the onboarding screen, which loads the bundled model before you can start recording.

### 4. (Optional) Download additional models in-app

Larger models — **Large v3** (~947 MB) and **Large v3 Turbo** (~954 MB) — can be downloaded in **Settings → Model Management** after first launch. These are fetched directly from Hugging Face via WhisperKit's download API and stored on-device. The Settings screen also shows a device recommendation based on available RAM.

## How It Works

1. **Recording** — `LiveTranscriptViewModel` creates an `AudioStreamTranscriber` from WhisperKit components (`AudioEncoder`, `FeatureExtractor`, `SegmentSeeker`, `TextDecoder`, `Tokenizer`, `AudioProcessor`). A background `Task` runs the stream; state changes are published to the main actor via a callback.

2. **Transcription state** — confirmed segments (finalized by the model) accumulate in `confirmedTranscriptText`; unconfirmed (in-flight) segments appear transiently. Both are joined and passed to `TextProcessingService`.

3. **Text processing** — `TextProcessingService` (a Swift actor) applies two passes: bionic bold emphasis via `AttributedString`, then foreground color annotation using `NLTagger` for the selected `HighlightMode`.

4. **Persistence** — on `stopRecording()`, the confirmed ledger is saved as an `EchoSession` + `TranscriptionChunk` pair in SwiftData. The session is then handed to `SpotlightIndexer.index(session:)`, which writes a `CSSearchableItem` with the title, a 200-char content preview, the creation timestamp, and tokenized keywords.

5. **Search**
    - **In-session search** — `TranscriptSearchManager` builds a cached `NSRegularExpression` from the query and scans all chunk strings, tracking `(chunkIndex, range)` matches. `SessionDetailView` uses `ScrollViewReader` to animate to the current match.
    - **History tab search** — `HistoryListView.filteredSessions` matches the query against every session's title *and* the `rawText` of every chunk it owns. Each row renders a contextual snippet (±40 chars around the hit) with the keyword highlighted.
    - **System Spotlight** — `EchoNoteApp.reindexAllSessionsInSpotlight()` runs on launch via `SpotlightIndexer.indexAll(_:)` so previously-saved sessions stay searchable from iOS Spotlight. Title edits re-index a single item; deletes remove it. Tapping a Spotlight hit hits `onContinueUserActivity(CSSearchableItemActionType)`, switches to the History tab, and pushes `SessionDetailView` for the matched UUID.

6. **Accessibility settings** — `AppSettings` is an `@Observable` class created once in `EchoNoteApp`, injected via `.environment(settings)`, and persists every change to `UserDefaults`. Views read it with `@Environment(AppSettings.self)` and apply `transcriptFont`, `transcriptForeground`/`transcriptBackground`, and `scrollAnimation` — so adjusting a slider in Settings instantly retitles fonts, colors, and animation curves throughout the app.

7. **Model activation** — `activateModel(_:)` resolves the model path *before* mutating state, then optimistically flips `activeModelId` to the tapped model so the green tick moves instantly. The actual `WhisperKit(...)` load happens in the background; if it throws, the previous active model and `WhisperKit` instance are restored. While loading, `ModelManagementView` shows a small `ProgressView` beside the green tick.

## Privacy

All audio processing is performed entirely on-device using CoreML. No audio, transcripts, or identifiers are transmitted over the network under any circumstances.
