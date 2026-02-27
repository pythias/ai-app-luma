import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

struct VolumeButtonCaptureView: UIViewRepresentable {
    let onCapture: () -> Void

    func makeUIView(context: Context) -> UIView {
        context.coordinator.start(onCapture: onCapture)
        return context.coordinator.container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onCapture = onCapture
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        let container = UIView(frame: .zero)
        private let volumeView = MPVolumeView(frame: .zero)
        private var observation: NSKeyValueObservation?
        private var volumeChangeObserver: NSObjectProtocol?
        private var appDidBecomeActiveObserver: NSObjectProtocol?
        private var appWillResignActiveObserver: NSObjectProtocol?
        fileprivate var onCapture: (() -> Void)?
        private var isProgrammaticVolumeChange = false
        private var lastCaptureAt: Date = .distantPast
        private let baselineVolume: Float = 0.5

        func start(onCapture: @escaping () -> Void) {
            self.onCapture = onCapture

            volumeView.alpha = 0.01
            volumeView.isUserInteractionEnabled = false
            volumeView.frame = CGRect(x: -1000, y: -1000, width: 1, height: 1)
            container.addSubview(volumeView)

            registerAppLifecycleObservers()
            restartVolumeMonitoring()
        }

        func stop() {
            teardownVolumeMonitoring()
            if let appDidBecomeActiveObserver {
                NotificationCenter.default.removeObserver(appDidBecomeActiveObserver)
            }
            if let appWillResignActiveObserver {
                NotificationCenter.default.removeObserver(appWillResignActiveObserver)
            }
            appDidBecomeActiveObserver = nil
            appWillResignActiveObserver = nil
            onCapture = nil
        }

        private func setSystemVolume(to value: Float) {
            guard let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first else {
                return
            }
            isProgrammaticVolumeChange = true
            slider.value = value
            slider.sendActions(for: .valueChanged)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isProgrammaticVolumeChange = false
            }
        }

        private func handleVolumeButtonPress() {
            if isProgrammaticVolumeChange { return }
            let now = Date()
            if now.timeIntervalSince(lastCaptureAt) < 0.14 { return }
            lastCaptureAt = now
            onCapture?()
            setSystemVolume(to: baselineVolume)
        }

        private func registerAppLifecycleObservers() {
            appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.restartVolumeMonitoring()
            }
            appWillResignActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.teardownVolumeMonitoring()
            }
        }

        private func restartVolumeMonitoring() {
            teardownVolumeMonitoring()

            let audio = AVAudioSession.sharedInstance()
            try? audio.setCategory(.ambient, options: [.mixWithOthers])
            try? audio.setActive(true)
            setSystemVolume(to: baselineVolume)

            volumeChangeObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                let reasonKey = "AVSystemController_AudioVolumeChangeReasonNotificationParameter"
                let reason = notification.userInfo?[reasonKey] as? String
                guard reason == "ExplicitVolumeChange" else { return }
                self.handleVolumeButtonPress()
            }

            observation = audio.observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
                guard let self else { return }
                if self.isProgrammaticVolumeChange {
                    return
                }
                DispatchQueue.main.async {
                    self.handleVolumeButtonPress()
                }
            }
        }

        private func teardownVolumeMonitoring() {
            observation?.invalidate()
            observation = nil
            if let volumeChangeObserver {
                NotificationCenter.default.removeObserver(volumeChangeObserver)
            }
            volumeChangeObserver = nil
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }
}
