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
import WhisperKit
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class LiveTranscriptViewModel {

    // MARK: - Published State

    var transcriptText: AttributedString = AttributedString("")
    var isRecording: Bool = false
    var isAutoScrollEnabled: Bool = true
    var showSnapToLiveButton: Bool = false
    var errorMessage: String?
    var modelState: ModelLoadingState = .notLoaded

    // Feature 1: Linguistic Highlight Filters
    var selectedHighlightMode: HighlightMode = .all

    // Feature 2: Audio Level Visualizer
    var currentAudioLevel: Float = 0.0

    // The ID of the currently loaded model
    var activeModelId: String?

    // Transcript display
    var confirmedTranscriptText: String = ""
    var unconfirmedTranscriptText: String = ""

    enum ModelLoadingState: Equatable {
        case notLoaded
        case downloading
        case loading
        case ready
        case error(String)

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    // MARK: - Private Services

    private let textProcessor = TextProcessingService()

    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let errorHaptic = UINotificationFeedbackGenerator()

    // MARK: - WhisperKit

    private var whisperKit: WhisperKit?
    private var streamTranscriber: AudioStreamTranscriber?
    private var transcriptionTask: Task<Void, Never>?

    // MARK: - State

    nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?

    private var rawTranscriptLedger: String = ""
    private var sessionStartTime: Date?
    private var modelContext: ModelContext?

    // MARK: - Init

    init() {
        mediumHaptic.prepare()
        lightHaptic.prepare()
        errorHaptic.prepare()
        setupInterruptionObserver()
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    private static let bundledModelName = "openai_whisper-small.en"
    private static let installedModelsKey = "echoNote.installedModels"
    private static let modelPathsKey = "echoNote.modelPaths"

    var downloadingModelId: String?
    var downloadProgress: Double = 0

    var installedModelIds: Set<String> {
        var ids = Set(UserDefaults.standard.stringArray(forKey: Self.installedModelsKey) ?? [])
        ids.insert(Self.bundledModelName)
        return ids
    }

    func downloadAndActivateModel(_ modelId: String) async {
        guard downloadingModelId == nil else { return }

        downloadingModelId = modelId
        downloadProgress = 0

        do {
            let modelFolder = try await WhisperKit.download(
                variant: modelId,
                progressCallback: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress.fractionCompleted
                    }
                }
            )

            let modelPath = modelFolder.path
            saveModelPath(modelId, path: modelPath)
            markModelInstalled(modelId)

            let whisper = try await WhisperKit(
                modelFolder: modelPath,
                verbose: true,
                prewarm: false,
                load: true,
                download: false
            )

            self.whisperKit = whisper
            activeModelId = modelId
            modelState = .ready
            downloadProgress = 1.0
            print("✅ Downloaded and activated model: \(modelId)")
        } catch {
            print("❌ Model download failed: \(error)")
        }

        downloadingModelId = nil
    }

    func activateModel(_ modelId: String) async {
        if modelId == Self.bundledModelName {
            activeModelId = nil
            modelState = .notLoaded
            await loadWhisperModel()
        } else {
            guard let modelPath = getModelPath(modelId) else {
                print("❌ No stored path for model: \(modelId)")
                return
            }

            modelState = .loading
            do {
                let whisper = try await WhisperKit(
                    modelFolder: modelPath,
                    verbose: true,
                    prewarm: false,
                    load: true,
                    download: false
                )
                self.whisperKit = whisper
                activeModelId = modelId
                modelState = .ready
                print("✅ Activated model: \(modelId)")
            } catch {
                modelState = .error(error.localizedDescription)
                print("❌ Failed to activate model: \(error)")
            }
        }
    }

    private func markModelInstalled(_ modelId: String) {
        var installed = UserDefaults.standard.stringArray(forKey: Self.installedModelsKey) ?? []
        if !installed.contains(modelId) {
            installed.append(modelId)
            UserDefaults.standard.set(installed, forKey: Self.installedModelsKey)
        }
    }

    private func saveModelPath(_ modelId: String, path: String) {
        var paths = UserDefaults.standard.dictionary(forKey: Self.modelPathsKey) as? [String: String] ?? [:]
        paths[modelId] = path
        UserDefaults.standard.set(paths, forKey: Self.modelPathsKey)
    }

    private func getModelPath(_ modelId: String) -> String? {
        let paths = UserDefaults.standard.dictionary(forKey: Self.modelPathsKey) as? [String: String] ?? [:]
        return paths[modelId]
    }

    func loadWhisperModel() async {
        guard modelState == .notLoaded || modelState.isError else { return }

        modelState = .loading

        guard let modelFolder = locateBundledModel() else {
            modelState = .error("Bundled speech model not found. Please reinstall the app.")
            return
        }

        do {
            let whisper = try await WhisperKit(
                modelFolder: modelFolder,
                verbose: true,
                prewarm: false,
                load: true,
                download: false
            )

            self.whisperKit = whisper
            activeModelId = Self.bundledModelName
            modelState = .ready
            print("✅ WhisperKit model loaded from bundle")
        } catch {
            modelState = .error(error.localizedDescription)
            print("❌ WhisperKit load failed: \(error)")
        }
    }

    private func locateBundledModel() -> String? {
        let fm = FileManager.default

        // Strategy 1: Folder name with dot — Bundle API may split on "." so try both
        if let path = Bundle.main.path(forResource: Self.bundledModelName, ofType: nil) {
            print("📂 Found model via path(forResource:ofType:nil): \(path)")
            return path
        }

        // Strategy 2: The ".en" is treated as the extension
        if let path = Bundle.main.path(forResource: "openai_whisper-small", ofType: "en") {
            print("📂 Found model via path(forResource:ofType:en): \(path)")
            return path
        }

        // Strategy 3: Direct path in resource bundle
        if let resourceURL = Bundle.main.resourceURL {
            let modelURL = resourceURL.appendingPathComponent(Self.bundledModelName)
            if fm.fileExists(atPath: modelURL.path) {
                print("📂 Found model via resourceURL: \(modelURL.path)")
                return modelURL.path
            }
        }

        // Strategy 4: Xcode may have flattened .mlmodelc files to the bundle root
        // Check if AudioEncoder.mlmodelc exists at bundle root level
        if let resourcePath = Bundle.main.resourcePath {
            let audioEncoderPath = (resourcePath as NSString).appendingPathComponent("AudioEncoder.mlmodelc")
            if fm.fileExists(atPath: audioEncoderPath) {
                print("📂 Found model files at bundle root: \(resourcePath)")
                return resourcePath
            }
        }

        // Strategy 5: url(forResource:withExtension:subdirectory:)
        if let url = Bundle.main.url(forResource: "AudioEncoder", withExtension: "mlmodelc", subdirectory: Self.bundledModelName) {
            let modelDir = url.deletingLastPathComponent().path
            print("📂 Found model via subdirectory: \(modelDir)")
            return modelDir
        }

        // Debug: list bundle contents
        if let resourcePath = Bundle.main.resourcePath {
            let contents = (try? fm.contentsOfDirectory(atPath: resourcePath)) ?? []
            print("❌ Model not found. Bundle root contains \(contents.count) items:")
            for item in contents.sorted() {
                print("   - \(item)")
            }
        }

        return nil
    }


    func startRecording() async {
        // Ensure model is loaded
        if modelState != .ready {
            await loadWhisperModel()
        }

        guard modelState == .ready, let whisper = whisperKit, let tokenizer = whisper.tokenizer else {
            errorMessage = "Speech model is not ready. Please try again."
            errorHaptic.notificationOccurred(.error)
            return
        }

        mediumHaptic.impactOccurred()

        // Reset state
        isRecording = true
        isAutoScrollEnabled = true
        showSnapToLiveButton = false
        transcriptText = AttributedString("")
        confirmedTranscriptText = ""
        unconfirmedTranscriptText = ""
        errorMessage = nil
        rawTranscriptLedger = ""
        sessionStartTime = Date()
        currentAudioLevel = 0.0

        // Create AudioStreamTranscriber with WhisperKit components
        let options = DecodingOptions(
            task: .transcribe,
            language: "en",
            temperature: 0.0,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: false
        )

        let transcriber = AudioStreamTranscriber(
            audioEncoder: whisper.audioEncoder,
            featureExtractor: whisper.featureExtractor,
            segmentSeeker: whisper.segmentSeeker,
            textDecoder: whisper.textDecoder,
            tokenizer: tokenizer,
            audioProcessor: whisper.audioProcessor,
            decodingOptions: options,
            requiredSegmentsForConfirmation: 2,
            silenceThreshold: 0.3,
            useVAD: true,
            stateChangeCallback: { [weak self] oldState, newState in
                Task { @MainActor [weak self] in
                    self?.handleStateChange(oldState: oldState, newState: newState)
                }
            }
        )

        self.streamTranscriber = transcriber

        // Start streaming in background task
        transcriptionTask = Task {
            do {
                try await transcriber.startStreamTranscription()
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = "Transcription error: \(error.localizedDescription)"
                        self.isRecording = false
                    }
                }
            }
        }
    }

    func stopRecording() async {
        lightHaptic.impactOccurred()

        guard let startTime = sessionStartTime else {
            isRecording = false
            return
        }

        let duration = Date().timeIntervalSince(startTime)
        isRecording = false
        currentAudioLevel = 0.0

        // Stop transcription
        await streamTranscriber?.stopStreamTranscription()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        streamTranscriber = nil

        // Save session
        await saveSessionToDatabase(duration: duration)
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

    // MARK: - WhisperKit State Callback

    private func handleStateChange(
        oldState: AudioStreamTranscriber.State,
        newState: AudioStreamTranscriber.State
    ) {
        // Update audio level from buffer energy
        if let lastEnergy = newState.bufferEnergy.last {
            currentAudioLevel = min(1.0, max(0.0, lastEnergy * 5.0))
        }

        // Extract confirmed segments (permanent)
        let confirmedText = newState.confirmedSegments
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Extract unconfirmed segments (transient)
        let unconfirmedText = newState.unconfirmedSegments
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Update ledger with confirmed text
        if !confirmedText.isEmpty && confirmedText != confirmedTranscriptText {
            confirmedTranscriptText = confirmedText
            rawTranscriptLedger = confirmedText
        }

        unconfirmedTranscriptText = unconfirmedText

        // Update UI
        Task {
            await updateUI()
        }
    }

    // MARK: - UI Update

    private func updateUI() async {
        let displayText: String
        if unconfirmedTranscriptText.isEmpty {
            displayText = rawTranscriptLedger
        } else {
            displayText = rawTranscriptLedger +
                (rawTranscriptLedger.isEmpty ? "" : " ") +
                unconfirmedTranscriptText
        }

        guard !displayText.isEmpty else { return }

        let processedText = await textProcessor.processText(
            displayText,
            highlightMode: selectedHighlightMode
        )

        transcriptText = processedText
    }

    // MARK: - Database Save

    private func saveSessionToDatabase(duration: TimeInterval) async {
        guard let context = modelContext else { return }
        guard !rawTranscriptLedger.isEmpty else { return }

        let words = rawTranscriptLedger
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let titleWords = words.prefix(5).joined(separator: " ")
        let sessionTitle = titleWords.isEmpty ? "Untitled Session" : titleWords

        let session = EchoSession(title: sessionTitle, durationSeconds: duration)
        let chunk = TranscriptionChunk(
            rawText: rawTranscriptLedger,
            isFinal: true,
            session: session
        )

        context.insert(session)
        context.insert(chunk)

        do {
            try context.save()
            await indexSessionInSpotlight(session: session)
        } catch {
            print("❌ Failed to save session: \(error)")
        }
    }

    private func indexSessionInSpotlight(session: EchoSession) async {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = session.title
        attributeSet.contentDescription = String(rawTranscriptLedger.prefix(300))
        attributeSet.timestamp = session.createdAt

        let item = CSSearchableItem(
            uniqueIdentifier: session.spotlightUniqueIdentifier,
            domainIdentifier: EchoSession.spotlightDomainIdentifier,
            attributeSet: attributeSet
        )

        try? await CSSearchableIndex.default().indexSearchableItems([item])
    }

    // MARK: - Audio Interruption

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
                if type == .began && self.isRecording {
                    await self.stopRecording()
                    self.errorMessage = "Recording stopped due to interruption"
                    self.errorHaptic.notificationOccurred(.warning)
                }
            }
        }
    }
}
