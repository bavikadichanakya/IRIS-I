//
//  ModelIntegrityValidator.swift
//  IRIS-I
//
//  Validates GGUF header magic and cryptographic SHA-256 digests.
//

import Foundation
import CryptoKit

public enum IntegrityError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case unreadableFile(String)
    case invalidGGUFMagic(String)
    case checksumMismatch(expected: String, actual: String)
    case emptyOrCorruptFile

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Model file not found at: \(url.path)"
        case .unreadableFile(let err):
            return "Unable to read model file: \(err)"
        case .invalidGGUFMagic(let found):
            return "Corrupted header: file does not have valid GGUF magic bytes (found: \(found))."
        case .checksumMismatch(let exp, let act):
            return "Cryptographic checksum mismatch! Expected \(exp), calculated \(act)."
        case .emptyOrCorruptFile:
            return "Model file is empty or truncated."
        }
    }
}

public actor ModelIntegrityValidator {
    public static let shared = ModelIntegrityValidator()

    // GGUF specification magic bytes: 'G', 'G', 'U', 'F' = 0x46554747 (little-endian)
    private static let ggufMagic: [UInt8] = [0x47, 0x47, 0x55, 0x46]

    public func validate(
        fileURL: URL,
        expectedSHA256: String? = nil,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw IntegrityError.fileNotFound(fileURL)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let totalSize = (attrs[.size] as? Int64) ?? 0
        guard totalSize > 1_000_000 else {
            throw IntegrityError.emptyOrCorruptFile
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        // 1. Verify GGUF magic bytes (first 4 bytes)
        let magicHeader = handle.readData(ofLength: 4)
        guard magicHeader.count == 4, [UInt8](magicHeader) == Self.ggufMagic else {
            let foundStr = magicHeader.map { String(format: "%02x", $0) }.joined()
            throw IntegrityError.invalidGGUFMagic(foundStr)
        }

        // 2. Stream and compute SHA-256
        try handle.seek(toOffset: 0)
        var hasher = SHA256()
        var processedBytes: Int64 = 0
        let chunkSize = 1024 * 1024 * 8 // 8 MB chunks for fast hashing on A19

        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: chunkSize)
            guard !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            processedBytes += Int64(chunk.count)
            let progress = min(1.0, Double(processedBytes) / Double(totalSize))
            progressHandler?(progress)
            return true
        }) {}

        let actualSHA256 = hasher.finalize().map { String(format: "%02x", $0) }.joined()

        // 3. Verify against expected checksum if configured
        if let expected = expectedSHA256, !expected.trimmingCharacters(in: .whitespaces).isEmpty {
            guard actualSHA256.caseInsensitiveCompare(expected) == .orderedSame else {
                throw IntegrityError.checksumMismatch(expected: expected, actual: actualSHA256)
            }
        }

        return actualSHA256
    }
}
