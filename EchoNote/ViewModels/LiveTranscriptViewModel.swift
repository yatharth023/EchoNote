//
//  LiveTranscriptViewModel.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 03/06/26.
//

import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import CoreSpotlight
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class LiveTranscriptViewModel {

    var transcriptText: AttributedString = AttributedString("")
    var isRecording: Bool = false
    var isAutoScrollEnabled: Bool = true
    var showSnapToLiveButton: Bool = false
    var errorMessage: String?

    // FEATURE 1: Advanced Linguistic Highlight Filters
    var selectedHighlightMode: HighlightMode = .all

    // FEATURE 2: Audio Level Visualizer
    var currentAudioLevel: Float = 0.0

    private let audioEngineManager = AudioEngineManager()
    private let speechService = SpeechTranscriptionService()
    private let textProcessor = TextProcessingService()

    // Haptic Feedback Generators
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let errorHaptic = UINotificationFeedbackGenerator()

    private var audioStreamTask: Task<Void, Never>?
    private var transcriptionStreamTask: Task<Void, Never>?
    private var audioLevelTask: Task<Void, Never>?

    // Mark as nonisolated(unsafe) since it's just a NotificationCenter token
    // and NotificationCenter operations are thread-safe
    nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?

    // WORD-ARRAY TOKEN DIFF ARCHITECTURE
    private var rawTranscriptLedger: String = ""
    private var lastProcessedWords: [String] = []

    // Session tracking
    private var sessionStartTime: Date?
    private var modelContext: ModelContext?

    init() {
        print("✅ LiveTranscriptViewModel initialized")
        print("🔧 Using WORD-ARRAY TOKEN DIFF architecture")

        // Prepare haptic generators
        mediumHaptic.prepare()
        lightHaptic.prepare()
        errorHaptic.prepare()

        // Setup audio interruption observer
        setupInterruptionObserver()
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        print("✅ SwiftData ModelContext injected")
    }

    func startRecording() async {
        print("\n🎙️ === START RECORDING SEQUENCE ===")

        print("🔍 Step 1: Checking microphone permission...")
        let micPermissionGranted: Bool
        do {
            micPermissionGranted = try await audioEngineManager.requestMicrophonePermission()
            print(micPermissionGranted ? "✅ Microphone permission: GRANTED" : "❌ Microphone permission: DENIED")
        } catch {
            print("❌ Microphone permission request failed: \(error)")
            errorMessage = "Microphone permission request failed: \(error.localizedDescription)"
            errorHaptic.notificationOccurred(.error)
            return
        }

        guard micPermissionGranted else {
            print("❌ Recording aborted: Microphone permission denied")
            errorMessage = "Microphone permission is required to record audio."
            errorHaptic.notificationOccurred(.error)
            return
        }

        print("🔍 Step 2: Checking speech recognition permission...")
        let speechPermissionGranted: Bool
        do {
            speechPermissionGranted = try await speechService.requestSpeechRecognitionPermission()
            print(speechPermissionGranted ? "✅ Speech recognition permission: GRANTED" : "❌ Speech recognition permission: DENIED")
        } catch {
            print("❌ Speech recognition permission request failed: \(error)")
            errorMessage = "Speech recognition permission request failed: \(error.localizedDescription)"
            errorHaptic.notificationOccurred(.error)
            return
        }

        guard speechPermissionGranted else {
            print("❌ Recording aborted: Speech recognition permission denied")
            errorMessage = "Speech recognition permission is required to transcribe audio."
            errorHaptic.notificationOccurred(.error)
            return
        }

        print("🔍 Step 3: Verifying speech recognizer availability...")
        let recognizerAvailable = await speechService.isRecognizerAvailable
        print(recognizerAvailable ? "✅ Speech recognizer: AVAILABLE" : "❌ Speech recognizer: UNAVAILABLE")

        guard recognizerAvailable else {
            print("❌ Recording aborted: Speech recognizer not available on device")
            errorMessage = "On-device speech recognition is not available. Please ensure your device supports it."
            errorHaptic.notificationOccurred(.error)
            return
        }

        print("✅ Step 4: All permissions granted, initializing session...")

        // Trigger medium haptic for recording start
        mediumHaptic.impactOccurred()

        isRecording = true
        isAutoScrollEnabled = true
        showSnapToLiveButton = false
        transcriptText = AttributedString("")
        errorMessage = nil

        // Initialize session tracking
        sessionStartTime = Date()
        rawTranscriptLedger = ""
        lastProcessedWords = []

        print("📝 Session initialized at: \(sessionStartTime!)")

        print("🎵 Step 5: Starting audio stream from hardware...")
        let audioStream = await audioEngineManager.startAudioStream()
        print("✅ Audio stream started successfully")

        // Start audio level monitoring
        let audioLevelStream = await audioEngineManager.startAudioLevelStream()
        audioLevelTask = Task {
            for await level in audioLevelStream {
                await MainActor.run {
                    self.currentAudioLevel = level
                }
            }
        }

        audioStreamTask = Task {
            await processAudioStream(audioStream)
        }

        print("✅ === RECORDING STARTED SUCCESSFULLY ===\n")
    }

    func stopRecording() async {
        print("\n🛑 === STOP RECORDING SEQUENCE ===")

        // Trigger light haptic for recording stop
        lightHaptic.impactOccurred()

        guard let startTime = sessionStartTime else {
            print("⚠️ No session start time found")
            isRecording = false
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        print("📊 Session duration: \(Int(duration)) seconds")

        isRecording = false

        print("🔄 Cancelling audio level task...")
        audioLevelTask?.cancel()
        audioLevelTask = nil
        currentAudioLevel = 0.0

        print("🔄 Cancelling audio stream task...")
        audioStreamTask?.cancel()
        audioStreamTask = nil

        print("🔄 Cancelling transcription stream task...")
        transcriptionStreamTask?.cancel()
        transcriptionStreamTask = nil

        print("🔄 Stopping audio engine...")
        await audioEngineManager.stopAudioStream()

        print("🔄 Stopping speech service...")
        await speechService.stopTranscription()

        // Save session to SwiftData
        await saveSessionToDatabase(duration: duration)

        print("✅ === RECORDING STOPPED SUCCESSFULLY ===\n")
    }

    private func saveSessionToDatabase(duration: TimeInterval) async {
        guard let context = modelContext else {
            print("⚠️ No ModelContext available - session not saved")
            return
        }

        guard !rawTranscriptLedger.isEmpty else {
            print("⚠️ Empty transcript - not saving session")
            return
        }

        print("💾 Saving session to database...")

        // Generate session title from first few words
        let words = rawTranscriptLedger.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let titleWords = words.prefix(5).joined(separator: " ")
        let sessionTitle = titleWords.isEmpty ? "Untitled Session" : titleWords

        // Create session
        let session = EchoSession(
            title: sessionTitle,
            durationSeconds: duration
        )

        // Create single chunk with full transcript
        let chunk = TranscriptionChunk(
            rawText: rawTranscriptLedger,
            isFinal: true,
            session: session
        )

        context.insert(session)
        context.insert(chunk)

        do {
            try context.save()
            print("✅ Session saved successfully")
            print("   - Title: \(sessionTitle)")
            print("   - Duration: \(Int(duration))s")
            print("   - Transcript length: \(rawTranscriptLedger.count) chars")

            // FEATURE 3: Index session in Core Spotlight
            await indexSessionInSpotlight(session: session, transcriptText: rawTranscriptLedger)

        } catch {
            print("❌ Failed to save session: \(error)")
            errorMessage = "Failed to save session: \(error.localizedDescription)"
        }
    }

    private func indexSessionInSpotlight(session: EchoSession, transcriptText: String) async {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = session.title
        attributeSet.contentDescription = String(transcriptText.prefix(300))
        attributeSet.timestamp = session.createdAt

        let item = CSSearchableItem(
            uniqueIdentifier: session.spotlightUniqueIdentifier,
            domainIdentifier: EchoSession.spotlightDomainIdentifier,
            attributeSet: attributeSet
        )

        do {
            try await CSSearchableIndex.default().indexSearchableItems([item])
            print("🔍 Indexed session in Spotlight: \(session.title)")
        } catch {
            print("❌ Spotlight indexing failed: \(error)")
        }
    }

    func enableAutoScroll() {
        isAutoScrollEnabled = true
        showSnapToLiveButton = false
    }

    func disableAutoScroll() {
        isAutoScrollEnabled = false
        showSnapToLiveButton = true
    }

    func reprocessWithCurrentHighlightMode() async {
        guard !rawTranscriptLedger.isEmpty else { return }
        await updateUI()
    }

    private func setupInterruptionObserver() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            Task { @MainActor in
                await self.handleAudioInterruption(type: type)
            }
        }

        print("✅ Audio interruption observer registered")
    }

    private func handleAudioInterruption(type: AVAudioSession.InterruptionType) async {
        switch type {
        case .began:
            print("🔔 AUDIO INTERRUPTION BEGAN (incoming call/FaceTime)")

            if isRecording {
                print("⏸️ Pausing recording due to interruption...")

                // Gracefully stop recording
                await stopRecording()

                errorMessage = "Recording paused due to incoming call"
                errorHaptic.notificationOccurred(.warning)
            }

        case .ended:
            print("🔔 AUDIO INTERRUPTION ENDED")
            // User can manually restart if needed

        @unknown default:
            print("⚠️ Unknown interruption type")
        }
    }

    private func processAudioStream(_ audioStream: AsyncThrowingStream<AVAudioPCMBuffer, Error>) async {
        print("🎤 Starting transcription service...")
        let transcriptionStream = await speechService.startTranscription(audioStream: audioStream)
        print("✅ Transcription service started\n")

        transcriptionStreamTask = Task {
            var updateCount = 0

            do {
                for await result in transcriptionStream {
                    updateCount += 1
                    await processWordArrayDiff(result.text, updateNumber: updateCount)
                }
                print("⚠️ Transcription stream ended (total updates: \(updateCount))")
            } catch {
                print("❌ Transcription stream error: \(error)")
            }
        }
    }

    private func processWordArrayDiff(_ incomingText: String, updateNumber: Int) async {
        guard !incomingText.isEmpty else {
            return
        }

        let incomingWords = incomingText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let incomingCount = incomingWords.count
        let lastCount = lastProcessedWords.count

        print("\n📝 Update #\(updateNumber): \(incomingCount) words")

        // Check for utterance boundary
        if incomingCount < lastCount {
            print("   🔄 UTTERANCE BOUNDARY DETECTED")

            let currentTime = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timeString = formatter.string(from: currentTime)

            rawTranscriptLedger += "\n\n[\(timeString)]\n\n"
            lastProcessedWords = []
        }

        // Extract new words
        if incomingCount > lastCount {
            let newWordCount = incomingCount - lastCount
            let newWords = Array(incomingWords.suffix(newWordCount))

            let spacing = rawTranscriptLedger.isEmpty ? "" : " "
            rawTranscriptLedger += spacing + newWords.joined(separator: " ")

            print("   ✅ Added \(newWordCount) new words")
        }

        lastProcessedWords = incomingWords

        // Update UI
        await updateUI()
    }

    private func updateUI() async {
        // Pass selected highlight mode to text processor
        let processedText = await textProcessor.processText(rawTranscriptLedger, highlightMode: selectedHighlightMode)

        await MainActor.run {
            transcriptText = processedText
        }
    }
}
