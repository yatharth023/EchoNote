# EchoNote

EchoNote is an offline-first, privacy-first iOS app that provides real-time speech transcription for neurodivergent and hard-of-hearing users. All transcription runs fully on-device using WhisperKit's CoreML-accelerated Whisper models — no internet connection required, no audio data ever leaves the device.

## Features

- **Live transcription** — streams audio through WhisperKit's `AudioStreamTranscriber` with voice activity detection (VAD) and segment confirmation
- **Bionic reading** — bolds the first ~45% of each word to speed up visual scanning and comprehension
- **Linguistic highlight filters** — highlight verbs (blue), nouns (green), or both via Apple's NaturalLanguage framework (`NLTagger`)
- **Audio waveform visualizer** — animated 9-bar amplitude display driven by real-time buffer energy during recording
- **Auto-scroll with snap** — transcript follows live speech; a floating "Snap to Live Voice" button re-anchors on manual scroll
- **Session history** — all sessions persisted with SwiftData; browse, delete (swipe), and rename titles inline
- **In-session full-text search** — regex-backed search across saved transcripts with yellow/orange match highlighting and prev/next navigation
- **Core Spotlight integration** — sessions are indexed system-wide and deep-linkable directly from iOS Spotlight search
- **Model management** — bundled `openai_whisper-small.en` (~217 MB) plus downloadable Large v3 and Large v3 Turbo variants with in-app progress tracking
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
├── EchoNoteApp.swift                    # App entry, TabView, Spotlight handler, onboarding gate
├── Models/
│   ├── EchoSession.swift                # SwiftData model: session metadata + Spotlight identifiers
│   ├── TranscriptionChunk.swift         # SwiftData model: raw text segment per recording
│   └── WhisperModelInfo.swift           # Model catalog (small.en, large-v3, large-v3-turbo)
├── ViewModels/
│   └── LiveTranscriptViewModel.swift    # Core VM: WhisperKit lifecycle, session save, UI state
├── Views/
│   ├── Live/
│   │   └── LiveTranscriptView.swift     # Recording screen, waveform, highlight mode picker
│   ├── History/
│   │   ├── HistoryListView.swift        # Session list with search and swipe-to-delete
│   │   ├── SessionDetailView.swift      # Full transcript with in-session search and title edit
│   │   └── TranscriptSearchBar.swift    # Search bar UI component
│   ├── Settings/
│   │   ├── SettingsView.swift           # Accessibility options (text size, contrast, motion)
│   │   └── ModelManagementView.swift    # Download/activate Whisper model variants
│   └── Onboarding/
│       └── ModelSetupView.swift         # First-launch model load screen
└── Services/
    ├── Processing/
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

4. **Persistence** — on `stopRecording()`, the confirmed ledger is saved as an `EchoSession` + `TranscriptionChunk` pair in SwiftData. The session is then indexed via `CSSearchableIndex` for Spotlight.

5. **Search** — `TranscriptSearchManager` builds a cached `NSRegularExpression` from the query and scans all chunk strings, tracking `(chunkIndex, range)` matches. `SessionDetailView` uses `ScrollViewReader` to animate to the current match.

## Privacy

All audio processing is performed entirely on-device using CoreML. No audio, transcripts, or identifiers are transmitted over the network under any circumstances.
