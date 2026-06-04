//
//  SpeechTranscriptionService.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 03/06/26.
//

import Foundation
import Speech
import AVFoundation

struct TranscriptionResult {
    let text: String
    let isFinal: Bool
}

enum SpeechTranscriptionError: Error {
    case recognizerNotAvailable
    case onDeviceRecognitionNotSupported
    case authorizationDenied
    case recognitionFailed
}

actor SpeechTranscriptionService {

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    func requestSpeechRecognitionPermission() async throws -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func checkSpeechRecognitionPermission() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func startTranscription(
        audioStream: AsyncThrowingStream<AVAudioPCMBuffer, Error>
    ) -> AsyncStream<TranscriptionResult> {
        AsyncStream { continuation in
            Task {
                do {
                    guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                        continuation.finish()
                        return
                    }

                    guard recognizer.supportsOnDeviceRecognition else {
                        continuation.finish()
                        return
                    }

                    guard checkSpeechRecognitionPermission() else {
                        continuation.finish()
                        return
                    }

                    let request = SFSpeechAudioBufferRecognitionRequest()
                    request.requiresOnDeviceRecognition = true
                    request.shouldReportPartialResults = true

                    await setRecognitionRequest(request)

                    let task = recognizer.recognitionTask(with: request) { result, error in
                        if let result = result {
                            let transcribedText = result.bestTranscription.formattedString
                            let isFinal = result.isFinal
                            let transcriptionResult = TranscriptionResult(text: transcribedText, isFinal: isFinal)
                            continuation.yield(transcriptionResult)
                        }

                        if error != nil || result?.isFinal == true {
                            continuation.finish()
                        }
                    }

                    await setRecognitionTask(task)

                    for try await buffer in audioStream {
                        guard let currentRequest = await getRecognitionRequest() else {
                            break
                        }
                        currentRequest.append(buffer)
                    }

                    await endRecognitionRequest()

                } catch {
                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.stopTranscription()
                }
            }
        }
    }

    func stopTranscription() async {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }

    private func setRecognitionRequest(_ request: SFSpeechAudioBufferRecognitionRequest?) async {
        recognitionRequest = request
    }

    private func getRecognitionRequest() async -> SFSpeechAudioBufferRecognitionRequest? {
        return recognitionRequest
    }

    private func setRecognitionTask(_ task: SFSpeechRecognitionTask?) async {
        recognitionTask = task
    }

    private func endRecognitionRequest() async {
        recognitionRequest?.endAudio()
    }

    var isRecognizerAvailable: Bool {
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
    }
}
