# Product Requirement Document (PRD) — EchoNote (iOS Mobile)

## 1. Product Vision & Value Proposition
EchoNote is a 100% offline-first, mobile accessibility utility designed to eliminate visual reading friction for neurodivergent (ADHD, Dyslexia) or hard-of-hearing users during real-time auditory intake. It ingests microphone sound feeds and converts them into structured, highly legible, auto-scrolling Visual AttributedString timelines directly on device hardware.

## 2. Technical Scope & Boundaries
* **Target OS Platform:** iOS 17.0+ (Strict Mobile Only).
* **Hardware Targets:** iPhone Devices (Requires physical Microphone & Taptic Engine validation).
* **Network Constraint:** Completely Offline-Enforced (`requiresOnDeviceRecognition = true`). Absolute local air-gapped security model.

## 3. System Architecture Blueprint
To ensure seamless frame-rendering efficiency across 120Hz ProMotion screens, EchoNote decouples audio streaming loops from presenting interfaces using Actor-isolated background contexts:

              ┌─────────────────────────────────────────┐
              │          View Layer (SwiftUI)           │
              │   - Renders formatted typography        │
              │   - Monitors UI-driven text-lock state  │
              └────────────────────┬────────────────────┘
                                   │
                                   ▼
              ┌─────────────────────────────────────────┐
              │       ViewModel (@MainActor, App)       │
              │   - Translates states to views          │
              │   - Communicates via identifiers        │
              └────────────────────┬────────────────────┘
                                   │
                                   ▼
    ┌──────────────────────────────────────────────────────────────┐
    │                 Background Actor Engines                     │
    │  Isolated contexts running tasks off the main thread         │
    └───────┬──────────────────────┬──────────────────────┬────────┘
            │                      │                      │
            ▼                      ▼                      ▼
┌──────────────────────┐┌──────────────────────┐┌──────────────────────┐
│ AudioEngineManager   ││SpeechTranscription   ││TextProcessingService │
│ (AVAudioEngine       ││(SFSpeechRecognizer   ││(NLTokenizer /        │
│ Hardware Taps)       ││On-Device Engine)     ││Bionic Reading Layer) │
└──────────────────────┘└──────────────────────┘└──────────────────────┘
                                                          │
                                                          ▼
                                                ┌──────────────────┐
                                                │ SwiftData Storage│
                                                │ (Persisted via   │
                                                │Background Context)
                                                └──────────────────┘

## 4. Folder Directory Structure
All codebase architectural files must map strictly into the following workspace groups:

EchoNote/
├── Core/
│   ├── Architecture/         # Global Protocol definitions & Typealiases
│   └── Theme/                # Accessible color tokens, HIG compliance standards
├── Models/
│   ├── EchoSession.swift     # SwiftData persistent schema container
│   └── AudioChunk.swift      # Segment token structures
├── Services/
│   ├── AudioEngine/          # Core Hardware Audio Tap (AVAudioEngine)
│   ├── Speech/               # On-Device Transcription Service (Speech framework)
│   └── Processing/           # Real-time NLP Engine & Bionic Typography Decorators
└── Views/
├── Live/                 # Recording room visualizers, Text-Lock stream views
├── History/              # SwiftData Query logs, Historical session search
└── Shared/               # HIG-compliant accessible control buttons

## 5. Comprehensive Feature Modules

### Module 1: Hardware Ingestion & Security Permissions
* **REQ-1.1:** System MUST request user validation across dual framework permission tokens (`AVAudioSession` Recording context and `SFSpeechRecognizer` Transcription authorization).
* **REQ-1.2:** If authorizations are missing or withdrawn, the interface MUST present an explicit modal fallback outlining steps to re-engage permissions via system settings.
* **REQ-1.3:** `AVAudioEngine` input nodes MUST stream audio raw PCM bytes into memory via non-blocking background task loops.

### Module 2: The Structured Scannability Core Engine
* **REQ-2.1 (Bionic Core):** The processor MUST construct a runtime text filter. It must parse words individually and apply heavy font styling weights (`.fontWeight(.bold)`) across the initial 40% to 50% character index length of every individual target word.
* **REQ-2.2 (Linguistic Parsing):** The engine MUST route incoming text data segments via Apple's `NLTokenizer` (Natural Language Framework) to track and accent functional part-of-speech keywords (e.g., action verbs colored in accessible blue tags).
* **REQ-2.3 (Timeline Injection):** The engine MUST auto-inject structural timestamp records into the viewport when incoming phrase updates pause beyond a 2.5-second silence interval threshold.

### Module 3: Active Viewport Control & Auto-Scroll
* **REQ-3.1:** Text rendering fields MUST comply cleanly with maximum global **Dynamic Type** specifications, allowing content layouts to expand up to XXL sizes without line truncation.
* **REQ-3.2:** Visual viewports MUST monitor inputs utilizing a specialized `ScrollViewReader` that dynamically anchors down to the absolute latest text payload update event.
* **REQ-3.3 (User Override Control):** If a user performs an intentional swipe or drag gesture up the timeline, the viewport auto-anchoring rule MUST instantly disengage. A prominent floating interface asset ("Snap to Live Voice") MUST render into view to re-lock anchoring properties safely.

### Module 4: SwiftData Local Layer
* **REQ-4.1:** Session transcript records MUST persist securely on hardware iron utilizing an explicit `@Model` class definition.
* **REQ-4.2:** Data references traveling into processing engines MUST be encapsulated via unique `PersistentIdentifier` pointers rather than moving model objects directly across Actor isolation rings.

### Module 5: Hardware Resiliency & System Interruption Safety
* **REQ-5.1:** The app MUST establish listeners tracking `AVAudioSession.interruptionNotification`. Upon incoming cellular calls or unexpected hardware resource conflicts, the ingestion track MUST gracefully pause, store active streams, and safely flush memory logs.
* **REQ-5.2:** Interface status alterations (Start, Terminate, Pause) MUST execute distinct physical haptic impulses via `UIImpactFeedbackGenerator`.

---

## 6. Development Milestones & Target Deliverables
Claude must implement this specification sequentially. No work on a subsequent milestone may begin until the current active phase builds and executes without error in Xcode.

### 📍 Milestone 1: Data Architecture & Storage Core
* **Deliverables:** Define local structural storage containers and configure schema initializers.
* **Requirements:** Build `EchoSession.swift` and `TranscriptionChunk.swift` with full SwiftData annotations (`@Model`). Establish cascading dependencies from sessions down to text segment pieces. Implement structural initialization wrappers.

### 📍 Milestone 2: Hardware Audio Ingestion Wrapper
* **Deliverables:** Complete low-level audio engineering taps and permission fallback layers.
* **Requirements:** Build `AudioEngineManager.swift` as a thread-isolated background `actor`. Safely encapsulate `AVAudioSession` microphonic resource permissions. Expose an `AsyncThrowingStream` publishing raw audio PCM byte buffers synchronously away from the UI thread.

### 📍 Milestone 3: Air-Gapped Speech Recognition Engine
* **Deliverables:** Establish localized speech-to-text string conversion pipeline.
* **Requirements:** Build `SpeechTranscriptionService.swift` on an isolated `actor`. Accept Milestone 2's PCM buffer streams and pipeline them into an instances of `SFSpeechAudioBufferRecognitionRequest`. Force `requiresOnDeviceRecognition = true` to assert strict offline execution. 

### 📍 Milestone 4: Typography Scannability Processing Service
* **Deliverables:** Implement the real-time Bionic formatting filter and on-device NLP parsers.
* **Requirements:** Build `TextProcessingService.swift` to consume flat strings and output UI-ready `AttributedString` entities. Wire up `NLTokenizer` to isolate part-of-speech components (e.g., action verbs) alongside structural text transformation code that applies heavy weights to the first half of individual spoken words.

### 📍 Milestone 5: Accessibility Viewport & Lock-Scroll Engine
* **Deliverables:** Assemble main interface screens, dynamic type checking, and auto-scroll viewport locking handlers.
* **Requirements:** Build `LiveTranscriptView.swift` and `LiveTranscriptViewModel.swift`. Implement an active `ScrollViewReader` timeline tracking sound events. Integrate automated detachment parameters: immediately un-anchor tracking upon a physical user manual swipe up, and render a floating "Snap to Live Voice" asset to restore lock states safely.

### 📍 Milestone 6: SwiftData Logs, System Interruptions & Haptic Polish
* **Deliverables:** Integrate historical logs interface, system interruption observers, and haptic engine tuning.
* **Requirements:** Build `HistoryListView.swift` using SwiftData's `@Query` parameters paired with local text search filtering predicates. Set up system listeners capturing `AVAudioSession.interruptionNotification` to freeze audio streams gracefully when a cell phone call interrupts execution. Inject precise, tactile user feedback across the system using `UIImpactFeedbackGenerator`.