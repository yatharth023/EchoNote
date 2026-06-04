//
//  TranscriptSearchManager.swift
//  EchoNote
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class TranscriptSearchManager {

    struct Match: Equatable {
        let chunkIndex: Int
        let range: Range<String.Index>
    }

    private(set) var matches: [Match] = []
    private(set) var currentMatchIndex: Int = 0

    var query: String = "" {
        didSet {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            if trimmed != oldValue.trimmingCharacters(in: .whitespaces) {
                performSearch()
            }
        }
    }

    var totalMatches: Int { matches.count }

    var currentMatchDisplay: String {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            return "0 matches"
        }
        if matches.isEmpty {
            return "No matches found"
        }
        return "\(currentMatchIndex + 1) of \(totalMatches)"
    }

    var hasMatches: Bool { !matches.isEmpty }

    var currentMatch: Match? {
        guard hasMatches else { return nil }
        return matches[currentMatchIndex]
    }

    private var chunks: [String] = []
    private var cachedRegex: NSRegularExpression?
    private var cachedQuery: String = ""

    func setContent(_ chunks: [String]) {
        self.chunks = chunks
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            performSearch()
        }
    }

    func nextMatch() {
        guard hasMatches else { return }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
    }

    func previousMatch() {
        guard hasMatches else { return }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
    }

    func clear() {
        query = ""
        matches = []
        currentMatchIndex = 0
    }

    func highlightedText(for text: String, chunkIndex: Int) -> AttributedString {
        var attributed = AttributedString(text)
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let regex = buildRegex(for: trimmed) else {
            return attributed
        }

        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let nsMatches = regex.matches(in: text, range: fullRange)

        for nsMatch in nsMatches {
            guard let swiftRange = Range(nsMatch.range, in: text),
                  let attrRange = Range(swiftRange, in: attributed) else { continue }

            let isCurrentMatch: Bool = {
                guard let current = currentMatch else { return false }
                return current.chunkIndex == chunkIndex && current.range == swiftRange
            }()

            if isCurrentMatch {
                attributed[attrRange].backgroundColor = .orange
                attributed[attrRange].foregroundColor = .white
            } else {
                attributed[attrRange].backgroundColor = .yellow
                attributed[attrRange].foregroundColor = .black
            }
        }

        return attributed
    }

    // MARK: - Private

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            matches = []
            currentMatchIndex = 0
            return
        }

        guard let regex = buildRegex(for: trimmed) else {
            matches = []
            currentMatchIndex = 0
            return
        }

        var newMatches: [Match] = []

        for (chunkIndex, text) in chunks.enumerated() {
            let nsString = text as NSString
            let fullRange = NSRange(location: 0, length: nsString.length)
            let nsMatches = regex.matches(in: text, range: fullRange)

            for nsMatch in nsMatches {
                if let swiftRange = Range(nsMatch.range, in: text) {
                    newMatches.append(Match(chunkIndex: chunkIndex, range: swiftRange))
                }
            }
        }

        matches = newMatches
        currentMatchIndex = newMatches.isEmpty ? 0 : 0
    }

    private func buildRegex(for searchText: String) -> NSRegularExpression? {
        if searchText == cachedQuery, let cached = cachedRegex {
            return cached
        }
        let escaped = NSRegularExpression.escapedPattern(for: searchText)
        let regex = try? NSRegularExpression(pattern: escaped, options: .caseInsensitive)
        cachedQuery = searchText
        cachedRegex = regex
        return regex
    }
}
