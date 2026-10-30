//
//  ModelIntegrityTests.swift
//  IRIS-ITests
//
//  Unit tests verifying GGUF header validation and SHA-256 checksum rejection.
//

import XCTest
#if canImport(IRIS_ICore)
@testable import IRIS_ICore
#elseif canImport(IRIS_I)
@testable import IRIS_I
#endif

final class ModelIntegrityTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testValidGGUFHeaderPassesValidation() async throws {
        let fileURL = tempDirectory.appendingPathComponent("valid_test.gguf")

        // Create a mock file with exact GGUF magic bytes: 'G', 'G', 'U', 'F' (0x47, 0x47, 0x55, 0x46)
        var data = Data([0x47, 0x47, 0x55, 0x46])
        var version: UInt32 = 3
        var tensorCount: UInt64 = 100
        var kvCount: UInt64 = 10
        data.append(Data(bytes: &version, count: 4))
        data.append(Data(bytes: &tensorCount, count: 8))
        data.append(Data(bytes: &kvCount, count: 8))
        // Pad with 1.2 MB of dummy data to satisfy test size requirement
        data.append(Data(repeating: 0x2A, count: 1_200_000))
        try data.write(to: fileURL)

        let validator = ModelIntegrityValidator()
        let result = try await validator.validate(fileURL: fileURL, minByteSize: 1_000_000)

        XCTAssertEqual(result.version, 3, "GGUF version should be 3")
        XCTAssertEqual(result.tensorCount, 100, "Tensor count should match")
        XCTAssertFalse(result.sha256.isEmpty, "Should calculate SHA-256 successfully")
        XCTAssertEqual(result.sha256.count, 64, "SHA-256 must be 64 hex characters")
    }

    func testCorruptedGGUFHeaderIsRejected() async throws {
        let fileURL = tempDirectory.appendingPathComponent("corrupt_test.gguf")

        // Invalid magic header: 'B', 'A', 'D', '!'
        var data = Data([0x42, 0x41, 0x44, 0x21])
        data.append(Data(repeating: 0x00, count: 1_200_000))
        try data.write(to: fileURL)

        let validator = ModelIntegrityValidator()

        do {
            _ = try await validator.validate(fileURL: fileURL, minByteSize: 1_000_000)
            XCTFail("Should have thrown IntegrityError.invalidGGUFMagic")
        } catch let IntegrityError.invalidGGUFMagic(found) {
            XCTAssertEqual(found, "42414421")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAlteredChecksumIsRejected() async throws {
        let fileURL = tempDirectory.appendingPathComponent("checksum_test.gguf")

        var data = Data([0x47, 0x47, 0x55, 0x46])
        var version: UInt32 = 3
        var tensorCount: UInt64 = 50
        var kvCount: UInt64 = 5
        data.append(Data(bytes: &version, count: 4))
        data.append(Data(bytes: &tensorCount, count: 8))
        data.append(Data(bytes: &kvCount, count: 8))
        data.append(Data(repeating: 0x11, count: 1_200_000))
        try data.write(to: fileURL)

        let validator = ModelIntegrityValidator()
        let wrongHash = "0000000000000000000000000000000000000000000000000000000000000000"

        do {
            _ = try await validator.validate(fileURL: fileURL, expectedSHA256: wrongHash, minByteSize: 1_000_000)
            XCTFail("Should have thrown IntegrityError.checksumMismatch")
        } catch let IntegrityError.checksumMismatch(expected, actual) {
            XCTAssertEqual(expected, wrongHash)
            XCTAssertNotEqual(actual, wrongHash)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
