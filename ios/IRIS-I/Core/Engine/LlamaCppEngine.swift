//
//  LlamaCppEngine.swift
//  IRIS-I
//
//  In-process llama.cpp engine with Metal GPU acceleration for Apple A19 (iPhone 17).
//  Pinned to upstream llama.cpp b4500 C API.
//

import Foundation

public actor LlamaCppEngine: ModelEngineProtocol {
    public let isMockEngine: Bool = false

    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var currentManifest: ModelManifest?
    private var currentContextSize: Int = 2048

    private var isCancelled: Bool = false
    private var lastTelemetry: InferenceTelemetry = .zero

    public init() {
        llama_backend_init()
    }

    deinit {
        if let ctx = context { llama_free(ctx) }
        if let mdl = model { llama_model_free(mdl) }
        llama_backend_free()
    }

    public var isLoaded: Bool {
        model != nil && context != nil
    }

    public var loadedManifest: ModelManifest? {
        currentManifest
    }

    public var activeContextSize: Int {
        currentContextSize
    }

    public func load(
        manifest: ModelManifest,
        fileURL: URL,
        contextSize: Int,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        // Clear any previous model/context first
        if isLoaded {
            await unload()
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw EngineError.failedToLoadModel(fileURL.path)
        }

        progress?(0.1)

        // 1. Model Parameters (llama.cpp b4500)
        var mparams = llama_model_default_params()
        mparams.use_mmap = true
        mparams.use_mlock = false

        #if targetEnvironment(simulator)
        mparams.n_gpu_layers = 0 // Simulator has no native Metal GPU compute for GGUF
        #else
        mparams.n_gpu_layers = 99 // Offload all transformer layers to Apple A19 Metal GPU
        #endif

        progress?(0.3)

        // 2. Load Model File
        let loadedModel = fileURL.path.withCString { cPath in
            llama_model_load_from_file(cPath, mparams)
        }

        guard let loadedModel else {
            throw EngineError.failedToLoadModel("llama_model_load_from_file failed for: \(fileURL.lastPathComponent)")
        }
        self.model = loadedModel

        progress?(0.7)

        // 3. Context Parameters (llama.cpp b4500)
        var cparams = llama_context_default_params()
        cparams.n_ctx = UInt32(contextSize)
        cparams.n_batch = 512
        cparams.n_ubatch = 128
        let nThreads = max(1, min(6, ProcessInfo.processInfo.activeProcessorCount - 2))
        cparams.n_threads = Int32(nThreads)
        cparams.n_threads_batch = Int32(nThreads)
        cparams.type_k = GGML_TYPE_Q8_0
        cparams.type_v = GGML_TYPE_Q8_0

        // Use canonical llama_init_from_model (non-deprecated in b4500)
        guard let loadedContext = llama_init_from_model(loadedModel, cparams) else {
            llama_model_free(loadedModel)
            self.model = nil
            throw EngineError.failedToCreateContext(contextSize)
        }

        self.context = loadedContext
        self.currentManifest = manifest
        self.currentContextSize = contextSize

        progress?(1.0)
    }

    public func unload() async {
        if let ctx = context {
            llama_free(ctx)
            self.context = nil
        }
        if let mdl = model {
            llama_model_free(mdl)
            self.model = nil
        }
        self.currentManifest = nil
        self.currentContextSize = 0
    }

    public func cancel() async {
        self.isCancelled = true
    }

    public func generateStream(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        self.isCancelled = false

        return AsyncThrowingStream { continuation in
            Task {
                guard let model = self.model, let context = self.context else {
                    continuation.finish(throwing: EngineError.uninitialized)
                    return
                }

                guard let vocab = llama_model_get_vocab(model) else {
                    continuation.finish(throwing: EngineError.tokenizationFailed)
                    return
                }

                let startTime = Date()
                var firstTokenTime: Date?
                var generatedCount = 0

                // 1. Tokenize Prompt via llama_tokenize(vocab, ...)
                let utf8Bytes = Array(prompt.utf8)
                let maxPromptTokens = Int32(utf8Bytes.count + 16)
                var promptTokens = [llama_token](repeating: 0, count: Int(maxPromptTokens))

                let promptTokenCount = prompt.withCString { cStr in
                    llama_tokenize(vocab, cStr, Int32(utf8Bytes.count), &promptTokens, maxPromptTokens, true, true)
                }

                guard promptTokenCount > 0 else {
                    continuation.finish(throwing: EngineError.tokenizationFailed)
                    return
                }

                guard promptTokenCount < Int32(self.currentContextSize) else {
                    continuation.finish(throwing: EngineError.contextWindowExceeded(current: Int(promptTokenCount), max: self.currentContextSize))
                    return
                }

                // 2. Clear KV Cache before prompt evaluation
                llama_kv_cache_clear(context)

                // 3. Initialize Batch and Sampler Chain
                var batch = llama_batch_init(max(promptTokenCount, 512), 0, 1)
                defer { llama_batch_free(batch) }

                let sparams = llama_sampler_chain_default_params()
                guard let sampler = llama_sampler_chain_init(sparams) else {
                    continuation.finish(throwing: EngineError.uninitialized)
                    return
                }
                defer { llama_sampler_free(sampler) }

                llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature))
                llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 1...UInt32.max)))

                // Add prompt tokens to batch
                self.batchClear(&batch)
                for i in 0..<promptTokenCount {
                    let isLast = (i == promptTokenCount - 1)
                    self.batchAdd(&batch, token: promptTokens[Int(i)], pos: llama_pos(i), seqId: 0, logits: isLast)
                }

                if llama_decode(context, batch) != 0 {
                    continuation.finish(throwing: EngineError.failedToCreateContext(Int(promptTokenCount)))
                    return
                }

                var currentPos = promptTokenCount
                var temporaryInvalidChars: [CChar] = []

                // 4. Autoregressive Generation Loop
                for _ in 0..<maxTokens {
                    if self.isCancelled {
                        continuation.finish(throwing: EngineError.generationCancelled)
                        return
                    }

                    // Sample next token using official sampler API
                    let sampledToken = llama_sampler_sample(sampler, context, batch.n_tokens - 1)

                    // Check End-Of-Generation (b4500 official)
                    if llama_vocab_is_eog(vocab, sampledToken) || sampledToken == llama_vocab_eos(vocab) {
                        if !temporaryInvalidChars.isEmpty {
                            let trailing = String(cString: temporaryInvalidChars + [0])
                            continuation.yield(trailing)
                        }
                        break
                    }

                    if firstTokenTime == nil {
                        firstTokenTime = Date()
                    }

                    // Convert token to text piece with UTF-8 byte stream validation
                    let pieceBytes = self.tokenToPiece(vocab: vocab, token: sampledToken)
                    temporaryInvalidChars.append(contentsOf: pieceBytes)

                    if let validString = String(validatingUTF8: temporaryInvalidChars + [0]) {
                        temporaryInvalidChars.removeAll()
                        continuation.yield(validString)
                    } else if let validSuffix = (0..<temporaryInvalidChars.count).first(where: {
                        $0 != 0 && String(validatingUTF8: Array(temporaryInvalidChars.suffix($0)) + [0]) != nil
                    }) {
                        let validString = String(cString: temporaryInvalidChars + [0])
                        temporaryInvalidChars.removeAll()
                        continuation.yield(validString)
                    }

                    generatedCount += 1
                    currentPos += 1

                    if currentPos >= Int32(self.currentContextSize) {
                        break
                    }

                    // Prepare single-token batch for next iteration
                    self.batchClear(&batch)
                    self.batchAdd(&batch, token: sampledToken, pos: currentPos - 1, seqId: 0, logits: true)

                    if llama_decode(context, batch) != 0 {
                        break
                    }
                }

                llama_synchronize(context)

                let totalDuration = Date().timeIntervalSince(startTime)
                let ttftMs = (firstTokenTime?.timeIntervalSince(startTime) ?? totalDuration) * 1000.0
                let tps = totalDuration > 0 ? Double(generatedCount) / totalDuration : 0.0
                let mem = HardwareTelemetry.shared.currentMemoryUsage()

                self.lastTelemetry = InferenceTelemetry(
                    timeToFirstTokenMs: ttftMs,
                    generationTokensPerSecond: tps,
                    promptTokenCount: Int(promptTokenCount),
                    generatedTokenCount: generatedCount,
                    durationSeconds: totalDuration,
                    physicalMemoryMB: mem.physicalFootprintMB,
                    thermalState: HardwareTelemetry.shared.thermalState,
                    isMockEngine: false
                )

                continuation.finish()
            }
        }
    }

    public func latestTelemetry() async -> InferenceTelemetry {
        lastTelemetry
    }

    // MARK: - Private Batch Helpers

    private func batchClear(_ batch: inout llama_batch) {
        batch.n_tokens = 0
    }

    private func batchAdd(
        _ batch: inout llama_batch,
        token: llama_token,
        pos: llama_pos,
        seqId: llama_seq_id,
        logits: Bool
    ) {
        let idx = Int(batch.n_tokens)
        batch.token[idx] = token
        batch.pos[idx] = pos
        batch.n_seq_id[idx] = 1
        batch.seq_id[idx]?[0] = seqId
        batch.logits[idx] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    private func tokenToPiece(vocab: OpaquePointer, token: llama_token) -> [CChar] {
        var buf = [CChar](repeating: 0, count: 16)
        let n = llama_token_to_piece(vocab, token, &buf, 16, 0, false)
        if n >= 0 {
            return Array(buf.prefix(Int(n)))
        }

        // Negative value indicates buffer too small; -n is required size
        var dynamicBuf = [CChar](repeating: 0, count: Int(-n))
        let n2 = llama_token_to_piece(vocab, token, &dynamicBuf, -n, 0, false)
        if n2 > 0 {
            return Array(dynamicBuf.prefix(Int(n2)))
        }
        return []
    }
}
