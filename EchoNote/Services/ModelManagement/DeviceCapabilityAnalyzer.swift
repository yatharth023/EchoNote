//
//  DeviceCapabilityAnalyzer.swift
//  EchoNote
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct DeviceCapabilityAnalyzer: Sendable {

    enum DeviceTier: Sendable {
        case standard    // iPhone 12, 13 — small.en
        case capable     // iPhone 14, 15 — large-v3
        case highEnd     // iPhone 15 Pro, 16 Pro — large-v3-turbo

        var recommendedModelId: String {
            switch self {
            case .standard: return WhisperModelInfo.smallEN.id
            case .capable: return WhisperModelInfo.largeV3.id
            case .highEnd: return WhisperModelInfo.largeTurbo.id
            }
        }

        var displayDescription: String {
            switch self {
            case .standard: return "Recommended: Small (English) for best battery life"
            case .capable: return "Recommended: Large v3 for balanced performance"
            case .highEnd: return "Recommended: Large Turbo for maximum accuracy"
            }
        }
    }

    static func analyze() -> DeviceTier {
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        let ramGB = Double(totalRAM) / 1_073_741_824

        // Detect chip generation via process count + RAM heuristics
        let processorCount = ProcessInfo.processInfo.processorCount

        // iPhone 15 Pro+ has 8GB RAM and 6 performance cores
        if ramGB >= 7.5 && processorCount >= 6 {
            return .highEnd
        }

        // iPhone 14 Pro / 15 has 6GB RAM
        if ramGB >= 5.5 {
            return .capable
        }

        // iPhone 12, 13 have 4GB RAM
        return .standard
    }

    static func availableStorageBytes() -> Int64 {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ) else {
            return 0
        }
        return (attributes[.systemFreeSize] as? Int64) ?? 0
    }

    static func hasStorageFor(model: WhisperModelInfo) -> Bool {
        let available = availableStorageBytes()
        // Require 1.5x model size as buffer for extraction/processing
        return available > Int64(Double(model.sizeBytes) * 1.5)
    }
}
