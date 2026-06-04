//
//  TextProcessingService.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 03/06/26.
//

import Foundation
import NaturalLanguage
import SwiftUI

// FEATURE 1: Advanced Linguistic Highlight Filters
enum HighlightMode: String, CaseIterable, Identifiable {
    case all = "All Parts of Speech"
    case verbsOnly = "Verbs Only"
    case nounsOnly = "Nouns Only"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "textformat"
        case .verbsOnly: return "figure.run"
        case .nounsOnly: return "cube.box"
        }
    }
}

actor TextProcessingService {

    private let bionicBoldRatio: Double = 0.45

    func processText(_ rawText: String, highlightMode: HighlightMode = .all) async -> AttributedString {
        var attributedString = AttributedString(rawText)

        await applyBionicReading(to: &attributedString, rawText: rawText)
        await applyLinguisticStyling(to: &attributedString, rawText: rawText, mode: highlightMode)

        return attributedString
    }

    private func applyBionicReading(to attributedString: inout AttributedString, rawText: String) async {
        let words = rawText.split(separator: " ", omittingEmptySubsequences: true)
        var currentIndex = rawText.startIndex

        for word in words {
            guard let wordRange = rawText.range(of: String(word), range: currentIndex..<rawText.endIndex) else {
                continue
            }

            let wordLength = word.count
            let boldLength = max(1, Int(Double(wordLength) * bionicBoldRatio))

            let boldEndIndex = word.index(word.startIndex, offsetBy: boldLength)
            let boldPortion = word[word.startIndex..<boldEndIndex]

            guard let boldRange = rawText.range(of: String(boldPortion), range: wordRange) else {
                currentIndex = wordRange.upperBound
                continue
            }

            if let attributedRange = Range(boldRange, in: attributedString) {
                attributedString[attributedRange].inlinePresentationIntent = .stronglyEmphasized
            }

            currentIndex = wordRange.upperBound
        }
    }

    private func applyLinguisticStyling(to attributedString: inout AttributedString, rawText: String, mode: HighlightMode) async {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = rawText

        tagger.enumerateTags(in: rawText.startIndex..<rawText.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            guard let tag = tag else {
                return true
            }

            // Apply highlighting based on selected mode
            switch mode {
            case .all:
                // Highlight both verbs (blue) and nouns (green)
                if tag == .verb {
                    if let attributedRange = Range(tokenRange, in: attributedString) {
                        attributedString[attributedRange].foregroundColor = .blue
                    }
                } else if tag == .noun {
                    if let attributedRange = Range(tokenRange, in: attributedString) {
                        attributedString[attributedRange].foregroundColor = .green
                    }
                }

            case .verbsOnly:
                // Only highlight verbs in accessible blue
                if tag == .verb {
                    if let attributedRange = Range(tokenRange, in: attributedString) {
                        attributedString[attributedRange].foregroundColor = .blue
                    }
                }

            case .nounsOnly:
                // Only highlight nouns in accessible green
                if tag == .noun {
                    if let attributedRange = Range(tokenRange, in: attributedString) {
                        attributedString[attributedRange].foregroundColor = .green
                    }
                }
            }

            return true
        }
    }

    func addTimestamp(to text: String, at timestamp: Date) async -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: timestamp)

        return "\n[\(timeString)]\n\(text)"
    }

    func detectSilenceBreak(lastUpdate: Date, silenceThreshold: TimeInterval = 2.5) async -> Bool {
        let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceLastUpdate >= silenceThreshold
    }
}
