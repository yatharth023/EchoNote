//
//  TranscriptionChunk.swift
//  EchoNote
//
//  Created by Yatharth Khattri on 03/06/26.
//

import Foundation
import SwiftData

@Model
final class TranscriptionChunk {
    var id: UUID
    var timestamp: Date
    var rawText: String
    var isFinal: Bool
    var offsetSeconds: Double

    var session: EchoSession?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawText: String,
        isFinal: Bool = false,
        offsetSeconds: Double = 0.0,
        session: EchoSession? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawText = rawText
        self.isFinal = isFinal
        self.offsetSeconds = offsetSeconds
        self.session = session
    }
}
