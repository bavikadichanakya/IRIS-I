//
//  ModelIntegrityQuarantineTests.swift
//  IRIS_ITests
//
//  Verifies that corrupted or checksum-mismatched models are never promoted
//  and are safely isolated into the quarantine directory.
//

import XCTest
@testable import IRIS_I

final class ModelIntegrityQuarantineTests: XCTestCase {

    func testQuarantineRouting() throws {
        let storage = ModelStorageManager.shared
        let testFilename = "corrupted_model_test.gguf"
        let stagingURL = storage.stagingURL(for: testFilename)

        // Create a dummy staged artifact
        let dummyBytes = Data(repeating: 0x41, count: 1024)
        try dummyBytes.write(to: stagingURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagingURL.path))

        // Quarantine the file
        let quarantinedURL = try storage.quarantine(stagingURL: stagingURL, filename: testFilename)

        // Verify it was moved out of staging and into quarantine
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagingURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: quarantinedURL.path))
        XCTAssertEqual(quarantinedURL.deletingLastPathComponent(), storage.quarantineDirectory)

        // Cleanup
        try? FileManager.default.removeItem(at: quarantinedURL)
    }

    func testModelCatalogIntegrity() {
        let catalog = ModelCatalog.shared

        // Verify specialized 0.8B profile exists and is properly configured
        let spec08B = catalog.specialized0_8B
        XCTAssertEqual(spec08B.id, "iris-specialized-qwen-0.8b")
        XCTAssertEqual(spec08B.parameterScale, .zeroPointEightB)
        XCTAssertEqual(spec08B.modelFamily, .qwen3_5)
        XCTAssertEqual(spec08B.chatTemplate, .chatML)

        // Verify allProfiles contains specialized0_8B and baseline3B
        XCTAssertTrue(catalog.allProfiles.contains { $0.id == spec08B.id })
        XCTAssertTrue(catalog.allProfiles.contains { $0.id == catalog.baseline3B.id })
        XCTAssertFalse(spec08B.isConfigured, "Specialized 0.8B must remain unconfigured until verified checkpoint is released.")
        XCTAssertNil(spec08B.verifiedDownloadURL, "Must not point to an unrelated download URL.")
        XCTAssertTrue(catalog.baseline3B.isConfigured, "Baseline 3B must have verified SHA256 and verified download URL.")
    }
}

