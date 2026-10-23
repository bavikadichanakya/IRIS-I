//
//  ThermalStateMonitor.swift
//  IRIS-I
//
//  Observes device thermal state transitions on Apple A19.
//

import Foundation

public final class ThermalStateMonitor: @unchecked Sendable {
    private let onStateChanged: @Sendable (ProcessInfo.ThermalState) -> Void
    private var observer: NSObjectProtocol?

    public init(onStateChanged: @escaping @Sendable (ProcessInfo.ThermalState) -> Void) {
        self.onStateChanged = onStateChanged
        self.observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            onStateChanged(ProcessInfo.processInfo.thermalState)
        }
    }

    deinit {
        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
