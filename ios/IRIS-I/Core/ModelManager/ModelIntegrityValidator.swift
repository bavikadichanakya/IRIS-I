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
    case unsupportedGGUFVersion(UInt32)
    case invalidTensorCount(UInt64)
    case checksumMismatch(expected: String, actual: String)
    case emptyOrCorruptFile(actualSize: Int64, requiredMin: Int64)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Model file not found at: \(url.path)"
        case .unreadableFile(let err):
            return "Unable to read model file: \(err)"
        case .invalidGGUFMagic(let found):
            return "Corrupted header: file does not have valid GGUF magic bytes (found: \(found))."
        case .unsupportedGGUFVersion(let ver):
            return "Unsupported GGUF version \(ver). Expected GGUF v2 or v3."
        case .invalidTensorCount(let count):
            return "Invalid tensor count in GGUF metadata (\(count)). Model contains no tensors."
        case .checksumMismatch(let exp, let act):
            return "Cryptographic checksum mismatch! Expected \(exp), calculated \(act)."
        case .emptyOrCorruptFile(let act, let req):
            return "Model file is truncated or too small (size: \(act) bytes, minimum required: \(req) bytes)."
        }
    }
}

public struct GGUFValidationResult: Sendable {
    public let version: UInt32
    public let tensorCount: UInt64
    public let kvCount: UInt64
    public let sha256: String
    public let fileSize: Int64

    public init(version: UInt32, tensorCount: UInt64, kvCount: UInt64, sha256: String, fileSize: Int64) {
        self.version = version
        self.tensorCount = tensorCount
        self.kvCount = kvCount
        self.sha256 = sha256
        self.fileSize = fileSize
    }
}

public actor ModelIntegrityValidator {
    public static let shared = ModelIntegrityValidator()

    // GGUF specification magic bytes: 'G', 'G', 'U', 'F' = 0x46554747 (little-endian)
    private static let ggufMagic: [UInt8] = [0x47, 0x47, 0x55, 0x46]

    public func validate(
        fileURL: URL,
        expectedSHA256: String? = nil,
        minByteSize: Int64 = 10_000_000, // 10 MB minimum for valid weights
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> GGUFValidationResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw IntegrityError.fileNotFound(fileURL)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let totalSize = (attrs[.size] as? Int64) ?? 0
        guard totalSize >= minByteSize else {
            throw IntegrityError.emptyOrCorruptFile(actualSize: totalSize, requiredMin: minByteSize)
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        // 1. Verify GGUF magic bytes (first 4 bytes)
        let magicHeader = handle.readData(ofLength: 4)
        guard magicHeader.count == 4, [UInt8](magicHeader) == Self.ggufMagic else {
            let foundStr = magicHeader.map { String(format: "%02x", $0) }.joined()
            throw IntegrityError.invalidGGUFMagic(foundStr)
        }

        // 2. Read GGUF Version (uint32, 4 bytes at offset 4)
        let versionData = handle.readData(ofLength: 4)
        guard versionData.count == 4 else {
            throw IntegrityError.emptyOrCorruptFile(actualSize: totalSize, requiredMin: minByteSize)
        }
        let version = versionData.withUnsafeBytes { $0.load(as: UInt32.self) }
        guard version >= 2 && version <= 3 else {
            throw IntegrityError.unsupportedGGUFVersion(version)
        }

        // 3. Read Tensor Count (uint64, 8 bytes at offset 8)
        let tensorCountData = handle.readData(ofLength: 8)
        guard tensorCountData.count == 8 else {
            throw IntegrityError.emptyOrCorruptFile(actualSize: totalSize, requiredMin: minByteSize)
        }
        let tensorCount = tensorCountData.withUnsafeBytes { $0.load(as: UInt64.self) }
        guard tensorCount > 0 else {
            throw IntegrityError.invalidTensorCount(tensorCount)
        }

        // 4. Read Metadata KV Count (uint64, 8 bytes at offset 16)
        let kvCountData = handle.readData(ofLength: 8)
        let kvCount: UInt64
        if kvCountData.count == 8 {
            kvCount = kvCountData.withUnsafeBytes { $0.load(as: UInt64.self) }
        } else {
            kvCount = 0
        }

        // 5. Stream and compute SHA-256
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

        // 6. Verify against expected checksum if configured
        if let expected = expectedSHA256, !expected.trimmingCharacters(in: .whitespaces).isEmpty {
            guard actualSHA256.caseInsensitiveCompare(expected) == .orderedSame else {
                throw IntegrityError.checksumMismatch(expected: expected, actual: actualSHA256)
            }
        }

        return GGUFValidationResult(
            version: version,
            tensorCount: tensorCount,
            kvCount: kvCount,
            sha256: actualSHA256,
            fileSize: totalSize
        )
    }
}
