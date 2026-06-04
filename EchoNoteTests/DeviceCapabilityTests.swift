//
//  DeviceCapabilityTests.swift
//  EchoNoteTests
//

import XCTest
@testable import EchoNote

final class DeviceCapabilityTests: XCTestCase {

    func testAnalyzeReturnsValidTier() {
        let tier = DeviceCapabilityAnalyzer.analyze()

        switch tier {
        case .standard, .capable, .highEnd:
            break // Valid
        }
    }

    func testRecommendedModelIdIsValid() {
        let tier = DeviceCapabilityAnalyzer.analyze()
        let modelId = tier.recommendedModelId

        let validIds = WhisperModelInfo.allModels.map { $0.id }
        XCTAssertTrue(validIds.contains(modelId),
                      "Recommended model ID \(modelId) is not in available models")
    }

    func testAvailableStorageReturnsPositive() {
        let storage = DeviceCapabilityAnalyzer.availableStorageBytes()
        XCTAssertGreaterThan(storage, 0, "Available storage should be positive")
    }

    func testHasStorageForSmallModel() {
        let hasSpace = DeviceCapabilityAnalyzer.hasStorageFor(model: .smallEN)
        // On any dev machine, should have space for 217MB
        XCTAssertTrue(hasSpace, "Should have storage for small.en model")
    }

    func testDisplayDescriptionNotEmpty() {
        let tier = DeviceCapabilityAnalyzer.analyze()
        XCTAssertFalse(tier.displayDescription.isEmpty)
    }
}
