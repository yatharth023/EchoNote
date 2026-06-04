//
//  AudioEngineManager.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 03/06/26.
//

import Foundation
import AVFoundation

enum AudioEngineError: Error {
    case permissionDenied
    case engineFailedToStart
    case inputNodeUnavailable
    case audioSessionConfigurationFailed
}

actor AudioEngineManager {

    private let audioEngine: AVAudioEngine
    private var isRunning: Bool = false
    private var audioLevelContinuation: AsyncStream<Float>.Continuation?

    init() {
        self.audioEngine = AVAudioEngine()
    }

    func requestMicrophonePermission() async throws -> Bool {
        return await AVAudioApplication.requestRecordPermission()
    }

    func checkMicrophonePermission() -> Bool {
        return AVAudioApplication.shared.recordPermission == .granted
    }

    func startAudioStream() -> AsyncThrowingStream<AVAudioPCMBuffer, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard checkMicrophonePermission() else {
                        continuation.finish(throwing: AudioEngineError.permissionDenied)
                        return
                    }

                    try await configureAudioSession()

                    guard let inputNode = await getInputNode() else {
                        continuation.finish(throwing: AudioEngineError.inputNodeUnavailable)
                        return
                    }

                    let recordingFormat = inputNode.outputFormat(forBus: 0)

                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                        continuation.yield(buffer)

                        // Calculate RMS audio level
                        guard let channelData = buffer.floatChannelData?[0] else { return }
                        let frameLength = Int(buffer.frameLength)
                        guard frameLength > 0 else { return }

                        var sumOfSquares: Float = 0.0
                        for i in 0..<frameLength {
                            let sample = channelData[i]
                            sumOfSquares += sample * sample
                        }

                        let rms = sqrtf(sumOfSquares / Float(frameLength))
                        let normalizedLevel = min(1.0, max(0.0, rms * 5.0))

                        Task {
                            await self?.yieldAudioLevel(normalizedLevel)
                        }
                    }

                    try await startEngine()
                    await setRunning(true)

                    continuation.onTermination = { @Sendable [weak self] _ in
                        Task { [weak self] in
                            await self?.stopAudioStream()
                        }
                    }

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func startAudioLevelStream() -> AsyncStream<Float> {
        AsyncStream { continuation in
            self.audioLevelContinuation = continuation

            continuation.onTermination = { @Sendable [weak self] _ in
                Task {
                    await self?.clearAudioLevelContinuation()
                }
            }
        }
    }

    private func yieldAudioLevel(_ level: Float) {
        audioLevelContinuation?.yield(level)
    }

    private func clearAudioLevelContinuation() {
        audioLevelContinuation = nil
    }

    func stopAudioStream() async {
        guard isRunning else { return }

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        audioEngine.stop()

        audioLevelContinuation?.finish()
        audioLevelContinuation = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Silent deactivation failure - non-critical
        }

        isRunning = false
    }

    private func configureAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func getInputNode() async -> AVAudioInputNode? {
        return audioEngine.inputNode
    }

    private func startEngine() async throws {
        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            throw AudioEngineError.engineFailedToStart
        }
    }

    private func setRunning(_ value: Bool) async {
        isRunning = value
    }

    var isEngineRunning: Bool {
        return isRunning
    }
}
