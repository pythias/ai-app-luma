import AVFoundation
import Combine
import SwiftUI

@MainActor
final class FillLightViewModel: ObservableObject {
    @Published var isFillLightEnabled = true
    @Published var intensity: Double
    @Published var selectedStyle: LightStyle
    @Published var cameraAuthorized = false
    @Published var cameraDenied = false

    let styles: [LightStyle]

    init(styles: [LightStyle]? = nil) {
        let resolvedStyles = styles ?? LightStyle.presets
        self.styles = resolvedStyles
        self.selectedStyle = resolvedStyles[0]
        self.intensity = resolvedStyles[0].defaultIntensity
    }

    func requestCameraAccessIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
            cameraDenied = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.cameraAuthorized = granted
                    self?.cameraDenied = !granted
                }
            }
        case .denied, .restricted:
            cameraAuthorized = false
            cameraDenied = true
        @unknown default:
            cameraAuthorized = false
            cameraDenied = true
        }
    }

    func applyStyle(_ style: LightStyle) {
        selectedStyle = style
        intensity = style.defaultIntensity
    }

    func selectNextStyle() {
        selectStyle(withStep: 1)
    }

    func selectPreviousStyle() {
        selectStyle(withStep: -1)
    }

    var overlayOpacity: Double {
        guard isFillLightEnabled else { return 0.0 }
        let clamped = min(max(intensity, 0.0), 1.0)
        return 0.45 + (0.55 * clamped)
    }

    private func selectStyle(withStep step: Int) {
        guard
            let currentIndex = styles.firstIndex(where: { $0.id == selectedStyle.id }),
            !styles.isEmpty
        else { return }

        let nextIndex = (currentIndex + step + styles.count) % styles.count
        applyStyle(styles[nextIndex])
    }
}
