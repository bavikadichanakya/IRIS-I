//
//  AudioSessionManager.swift
//  IRIS-I
//
//  Dedicated AVFoundation audio session and audio engine input manager.
//  Configures .playAndRecord with Bluetooth and speaker routing,
//  computes true RMS audio amplitude, and handles hardware interruptions.
//

import Foundation
import AVFoundation

public protocol AudioSessionManagerDelegate: AnyObject, Sendable {
    func audioSessionManager(_ manager: AudioSessionManager, didUpdateAudioLevel level: Float)
    func audioSessionManagerDidReceiveInterruption(_ manager: AudioSessionManager)
    func audioSessionManagerDidChangeRoute(_ manager: AudioSessionManager, toBluetooth: Bool)
}

@MainActor
public final class AudioSessionManager: NSObject {
    public static let shared = AudioSessionManager()

    public weak var delegate: AudioSessionManagerDelegate?

    private var audioEngine = AVAudioEngine()
    private var isRunning: Bool = false
    private var currentRMS: Float = 0.0

    private override init() {
        super.init()
        setupNotificationObservers()
    }

    // MARK: - Lifecycle Notifications

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            if type == .began {
                self.delegate?.audioSessionManagerDidReceiveInterruption(self)
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let _ = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

            let session = AVAudioSession.sharedInstance()
            let isBluetooth = session.currentRoute.inputs.contains {
                $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP || $0.portType == .bluetoothLE
            }
            self.delegate?.audioSessionManagerDidChangeRoute(self, toBluetooth: isBluetooth)
        }
    }

    // MARK: - Permissions

    public func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public var isMicrophoneAuthorized: Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }

    // MARK: - Configuration & Start

    public func startCapture(bufferHandler: (@Sendable (AVAudioPCMBuffer) -> Void)? = nil) throws {
        guard !isRunning else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            bufferHandler?(buffer)

            // Calculate true RMS amplitude
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = UInt(buffer.frameLength)
            guard frameLength > 0 else { return }

            var sum: Float = 0.0
            for i in 0..<Int(frameLength) {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rawRMS = sqrt(sum / Float(frameLength))

            // Normalize RMS: map ~0.001..0.15 range to 0.0..1.0
            let normalized = min(1.0, max(0.0, rawRMS * 12.0))

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentRMS = normalized
                self.delegate?.audioSessionManager(self, didUpdateAudioLevel: normalized)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRunning = true
    }

    public func stopCapture() {
        guard isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRunning = false
        currentRMS = 0.0
    }

    public func deactivateAudioSession() {
        stopCapture()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    public var isAudioCapturing: Bool {
        isRunning
    }

    public var latestLevel: Float {
        currentRMS
    }
}
