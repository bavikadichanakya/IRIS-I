//
//  AudioFrameProcessor.swift
//  IRIS-I
//
//  Real-time audio frame processor converting hardware audio buffers into
//  standard 16kHz mono PCM frames with RMS and zero-crossing rate calculation.
//

import Foundation
import AVFoundation
import Accelerate

public protocol AudioFrameProcessorDelegate: AnyObject, Sendable {
    func audioFrameProcessor(_ processor: AudioFrameProcessor, didProduceFrame frame: [Float], rms: Float, zcr: Float)
}

public final class AudioFrameProcessor: @unchecked Sendable {
    public static let shared = AudioFrameProcessor()

    public weak var delegate: AudioFrameProcessorDelegate?

    public static let targetSampleRate: Double = 16000.0
    public static let frameSize: Int = 512 // 32ms window at 16kHz
    public static let hopSize: Int = 256   // 50% overlap

    private let targetFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var ringBuffer: [Float] = []
    private let lock = NSLock()

    private init() {
        self.targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        )
    }

    /// Processes an incoming raw PCM buffer from AudioSessionManager
    public func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let targetFormat = self.targetFormat else { return }

        // Setup converter if needed or if format changed
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }

        guard let converter = self.converter else { return }

        let sampleRatio = Self.targetSampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * sampleRatio + 1024)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            return
        }

        var error: NSError?
        var consumed = false

        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if !consumed {
                consumed = true
                outStatus.pointee = .haveData
                return buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let err = error {
            print("[AUDIO_FRAME] Resampling error: \(err.localizedDescription)")
            return
        }

        guard let channelData = outputBuffer.floatChannelData?[0], outputBuffer.frameLength > 0 else {
            return
        }

        let floatCount = Int(outputBuffer.frameLength)
        let newSamples = Array(UnsafeBufferPointer(start: channelData, count: floatCount))

        lock.lock()
        ringBuffer.append(contentsOf: newSamples)

        // Process frames with hopSize
        while ringBuffer.count >= Self.frameSize {
            let frame = Array(ringBuffer.prefix(Self.frameSize))
            ringBuffer.removeFirst(Self.hopSize)
            lock.unlock()

            // Compute features
            let (rms, zcr) = computeAcousticFeatures(frame)
            delegate?.audioFrameProcessor(self, didProduceFrame: frame, rms: rms, zcr: zcr)

            lock.lock()
        }
        lock.unlock()
    }

    /// Calculates root-mean-square amplitude and zero-crossing rate for spectral voicing/fricative analysis
    private func computeAcousticFeatures(_ samples: [Float]) -> (rms: Float, zcr: Float) {
        guard !samples.isEmpty else { return (0.0, 0.0) }

        var sumSquare: Float = 0.0
        vDSP_svesq(samples, 1, &sumSquare, vDSP_Length(samples.count))
        let rms = sqrt(sumSquare / Float(samples.count))

        var zeroCrossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i - 1] < 0) || (samples[i] < 0 && samples[i - 1] >= 0) {
                zeroCrossings += 1
            }
        }
        let zcr = Float(zeroCrossings) / Float(samples.count)

        return (rms, zcr)
    }

    public func reset() {
        lock.lock()
        ringBuffer.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}
