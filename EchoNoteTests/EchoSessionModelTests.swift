//
//  EchoSessionModelTests.swift
//  EchoNoteTests
//

import XCTest
import SwiftData
@testable import EchoNote

final class EchoSessionModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([EchoSession.self, TranscriptionChunk.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    func testCreateSession() throws {
        let session = EchoSession(title: "Test Session", durationSeconds: 60.0)
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<EchoSession>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.title, "Test Session")
        XCTAssertEqual(sessions.first?.durationSeconds, 60.0)
    }

    func testCreateSessionWithChunk() throws {
        let session = EchoSession(title: "With Chunk")
        let chunk = TranscriptionChunk(rawText: "Hello world", isFinal: true, session: session)

        context.insert(session)
        context.insert(chunk)
        try context.save()

        let descriptor = FetchDescriptor<EchoSession>()
        let sessions = try context.fetch(descriptor)
        XCTAssertEqual(sessions.first?.chunks.count, 1)
        XCTAssertEqual(sessions.first?.chunks.first?.rawText, "Hello world")
    }

    func testCascadeDelete() throws {
        let session = EchoSession(title: "Delete Me")
        let chunk = TranscriptionChunk(rawText: "Will be deleted", session: session)

        context.insert(session)
        context.insert(chunk)
        try context.save()

        context.delete(session)
        try context.save()

        let chunkDescriptor = FetchDescriptor<TranscriptionChunk>()
        let chunks = try context.fetch(chunkDescriptor)
        XCTAssertTrue(chunks.isEmpty, "Chunks should be cascade deleted")
    }

    func testSpotlightIdentifier() {
        let session = EchoSession(title: "Spotlight Test")
        let identifier = session.spotlightUniqueIdentifier

        XCTAssertTrue(identifier.hasPrefix("com.yatharth.EchoNote.sessions."))
        XCTAssertTrue(identifier.contains(session.id.uuidString))
    }

    func testSessionDefaultValues() {
        let session = EchoSession()

        XCTAssertEqual(session.title, "")
        XCTAssertEqual(session.durationSeconds, 0.0)
        XCTAssertEqual(session.isActive, false)
        XCTAssertTrue(session.chunks.isEmpty)
    }
}
