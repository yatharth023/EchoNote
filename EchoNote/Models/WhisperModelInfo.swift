//
//  WhisperModelInfo.swift
//  EchoNote
//

import Foundation

struct WhisperModelInfo: Sendable, Identifiable {
    let id: String
    let displayName: String
    let sizeBytes: Int64
    let estimatedLatencyMs: Int
    let accuracyTier: AccuracyTier
    let recommendedDevices: [String]
    var isDownloaded: Bool
    var isActive: Bool

    enum AccuracyTier: String, Sendable {
        case standard = "Standard"
        case high = "High Accuracy"
        case ultra = "Ultra Accuracy"
    }

    var formattedSize: String {
        let megabytes = Double(sizeBytes) / 1_000_000
        if megabytes >= 1000 {
            return String(format: "%.1f GB", megabytes / 1000)
        }
        return String(format: "%.0f MB", megabytes)
    }

    static let smallEN = WhisperModelInfo(
        id: "openai_whisper-small.en",
        displayName: "Small (English)",
        sizeBytes: 217_000_000,
        estimatedLatencyMs: 800,
        accuracyTier: .standard,
        recommendedDevices: ["iPhone 12", "iPhone 13", "iPhone 14"],
        isDownloaded: false,
        isActive: false
    )

    static let largeV3 = WhisperModelInfo(
        id: "openai_whisper-large-v3_947MB",
        displayName: "Large v3",
        sizeBytes: 947_000_000,
        estimatedLatencyMs: 1500,
        accuracyTier: .high,
        recommendedDevices: ["iPhone 14 Pro", "iPhone 15"],
        isDownloaded: false,
        isActive: false
    )

    static let largeTurbo = WhisperModelInfo(
        id: "openai_whisper-large-v3_turbo_954MB",
        displayName: "Large v3 Turbo",
        sizeBytes: 954_000_000,
        estimatedLatencyMs: 2000,
        accuracyTier: .ultra,
        recommendedDevices: ["iPhone 15 Pro", "iPhone 16 Pro"],
        isDownloaded: false,
        isActive: false
    )

    static let allModels: [WhisperModelInfo] = [smallEN, largeV3, largeTurbo]
}
