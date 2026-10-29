//
//  MemoryPressureMonitor.swift
//  IRIS-I
//
//  Subscribes to Darwin memory pressure events to prevent OS Jetsam termination.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class MemoryPressureMonitor: @unchecked Sendable {
    private var source: DispatchSourceMemoryPressure?
    private let onWarning: @Sendable () -> Void
    private let onCritical: @Sendable () -> Void

    public init(
        onWarning: @escaping @Sendable () -> Void,
        onCritical: @escaping @Sendable () -> Void
    ) {
        self.onWarning = onWarning
        self.onCritical = onCritical
        startMonitoring()
    }

    private func startMonitoring() {
        let src = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .userInitiated)
        )

        src.setEventHandler { [weak self] in
            guard let self = self, let activeSource = self.source else { return }
            let data = activeSource.data
            if data.contains(.critical) {
                self.onCritical()
            } else if data.contains(.warning) {
                self.onWarning()
            }
        }

        src.resume()
        self.source = src

        #if canImport(UIKit)
        // Also observe UIKit memory warning notification
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onWarning()
        }
        #endif
    }

    deinit {
        source?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
}
