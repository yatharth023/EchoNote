//
//  WhisperModelInfoTests.swift
//  EchoNoteTests
//

import XCTest
@testable import EchoNote

final class WhisperModelInfoTests: XCTestCase {

    func testAllModelsHaveUniqueIds() {
        let ids = WhisperModelInfo.allModels.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "Model IDs should be unique")
    }

    func testAllModelsHavePositiveSize() {
        for model in WhisperModelInfo.allModels {
            XCTAssertGreaterThan(model.sizeBytes, 0, "\(model.displayName) should have positive size")
        }
    }

    func testFormattedSizeReturnsReadableString() {
        let small = WhisperModelInfo.smallEN
        XCTAssertTrue(small.formattedSize.contains("MB") || small.formattedSize.contains("GB"))

        let large = WhisperModelInfo.largeTurbo
        XCTAssertFalse(large.formattedSize.isEmpty)
    }

    func testSmallModelProperties() {
        let model = WhisperModelInfo.smallEN
        XCTAssertEqual(model.id, "openai_whisper-small.en")
        XCTAssertEqual(model.accuracyTier, .standard)
        XCTAssertFalse(model.isDownloaded)
        XCTAssertFalse(model.isActive)
    }

    func testLargeV3ModelProperties() {
        let model = WhisperModelInfo.largeV3
        XCTAssertEqual(model.accuracyTier, .high)
        XCTAssertGreaterThan(model.sizeBytes, WhisperModelInfo.smallEN.sizeBytes)
    }

    func testLargeTurboModelProperties() {
        let model = WhisperModelInfo.largeTurbo
        XCTAssertEqual(model.accuracyTier, .ultra)
        XCTAssertGreaterThan(model.sizeBytes, WhisperModelInfo.largeV3.sizeBytes)
    }

    func testEstimatedLatencyIncreases() {
        let small = WhisperModelInfo.smallEN.estimatedLatencyMs
        let medium = WhisperModelInfo.largeV3.estimatedLatencyMs
        let large = WhisperModelInfo.largeTurbo.estimatedLatencyMs

        XCTAssertLessThan(small, medium)
        XCTAssertLessThan(medium, large)
    }
}
