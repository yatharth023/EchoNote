//
//  EchoSession.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 03/06/26.
//

import Foundation
import SwiftData

@Model
final class EchoSession {
    var id: UUID
    var createdAt: Date
    var title: String
    var durationSeconds: Double
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \TranscriptionChunk.session)
    var chunks: [TranscriptionChunk]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String = "",
        durationSeconds: Double = 0.0,
        isActive: Bool = false,
        chunks: [TranscriptionChunk] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.durationSeconds = durationSeconds
        self.isActive = isActive
        self.chunks = chunks
    }

    // FEATURE 3: Core Spotlight Indexing Support
    static let spotlightDomainIdentifier = "com.yatharth.EchoNote.sessions"

    var spotlightUniqueIdentifier: String {
        return "\(Self.spotlightDomainIdentifier).\(id.uuidString)"
    }

    var contentPreview: String {
        let fullText = chunks.sorted { $0.timestamp < $1.timestamp }
            .map { $0.rawText }
            .joined(separator: " ")
        let maxLength = 200
        if fullText.count > maxLength {
            return String(fullText.prefix(maxLength)) + "..."
        }
        return fullText
    }
}
