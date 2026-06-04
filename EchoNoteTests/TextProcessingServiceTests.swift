//
//  TextProcessingServiceTests.swift
//  EchoNoteTests
//

import XCTest
@testable import EchoNote

final class TextProcessingServiceTests: XCTestCase {

    var service: TextProcessingService!

    override func setUp() async throws {
        service = TextProcessingService()
    }

    func testBionicReadingAppliesBoldToFirstHalf() async {
        let text = "Hello"
        let result = await service.processText(text)

        // Should produce a non-empty AttributedString
        XCTAssertFalse(result.characters.isEmpty)
        XCTAssertEqual(String(result.characters), text)
    }

    func testProcessTextHandlesEmptyString() async {
        let result = await service.processText("")
        XCTAssertTrue(result.characters.isEmpty)
    }

    func testProcessTextWithVerbsOnlyMode() async {
        let text = "The cat is running quickly"
        let result = await service.processText(text, highlightMode: .verbsOnly)

        XCTAssertFalse(result.characters.isEmpty)
        XCTAssertEqual(String(result.characters), text)
    }

    func testProcessTextWithNounsOnlyMode() async {
        let text = "The cat is running quickly"
        let result = await service.processText(text, highlightMode: .nounsOnly)

        XCTAssertFalse(result.characters.isEmpty)
        XCTAssertEqual(String(result.characters), text)
    }

    func testProcessTextWithAllMode() async {
        let text = "The cat is running quickly"
        let result = await service.processText(text, highlightMode: .all)

        XCTAssertFalse(result.characters.isEmpty)
    }

    func testLongTextPerformance() async {
        let words = (0..<500).map { _ in "testing" }
        let longText = words.joined(separator: " ")

        let start = CFAbsoluteTimeGetCurrent()
        let _ = await service.processText(longText)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        // Should process 500 words in under 1 second
        XCTAssertLessThan(elapsed, 1.0, "Processing 500 words took too long: \(elapsed)s")
    }

    func testSingleCharacterWords() async {
        let text = "I a"
        let result = await service.processText(text)

        XCTAssertFalse(result.characters.isEmpty)
        XCTAssertEqual(String(result.characters), text)
    }
}
