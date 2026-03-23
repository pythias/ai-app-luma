import SwiftUI
import UIKit

enum LiveMode: String, CaseIterable {
    case off
    case auto
    case on

    var title: String {
        switch self {
        case .off: return "关"
        case .auto: return "自动"
        case .on: return "开"
        }
    }

    var icon: String {
        switch self {
        case .off: return "livephoto.slash"
        case .auto: return "a.circle"
        case .on: return "livephoto"
        }
    }
}

struct MainCaptureView: View {
    @StateObject private var viewModel = FillLightViewModel()
    @StateObject private var cameraController = CameraSessionController()
    @Environment(\.scenePhase) private var scenePhase
    private let previewMaxHeightRatio: CGFloat = 0.40
    @State private var isControlsExpanded = false
    @State private var isPreviewMirrored = true
    @State private var selectedLiveMode: LiveMode = .auto
    @State private var selectedAspectRatio: CGFloat = 3.0 / 4.0
    @State private var originalScreenBrightness: CGFloat?
    @State private var captureFlashOpacity = 0.0
    @State private var isPrivacyPresented = false
    @State private var activeScreen: UIScreen?
    @State private var brightnessIndicatorOpacity: Double = 0
    @State private var displayedBrightness: Double = 50
    @State private var isAdjustingBrightness = false
    @State private var gestureStartIntensity: Double = 0.5
    @State private var gestureStartLocation: CGPoint = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FillOverlayView(
                style: viewModel.selectedStyle,
                opacity: viewModel.overlayOpacity
            )

            topSafeAreaMask
            previewWindowLayer
            
            // 亮度滑块指示器
            if isAdjustingBrightness {
                brightnessSliderOverlay
            }
            
            Color.white
                .opacity(captureFlashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VolumeButtonCaptureView {
                triggerCapture()
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)

            brightnessIndicator
            controlsPanel
        }
        .background(Color.black)
        .simultaneousGesture(globalInteractionGesture)
        .onAppear {
            updateActiveScreen()
            viewModel.requestCameraAccessIfNeeded()
            if viewModel.cameraAuthorized {
                cameraController.configureIfNeeded()
            }
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onChange(of: viewModel.cameraAuthorized) { _, isAuthorized in
            guard isAuthorized else { return }
            cameraController.configureIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                updateActiveScreen()
            }
            guard viewModel.cameraAuthorized else { return }
            if phase == .active {
                cameraController.startRunning()
            } else if phase == .background {
                cameraController.stopRunning()
            }
        }
        .onDisappear {
            restoreScreenBrightnessIfNeeded()
        }
        .sheet(isPresented: $isPrivacyPresented) {
            PrivacyPolicyView()
        }
    }

    private var brightnessIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                    Text("\(Int(displayedBrightness))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .opacity(brightnessIndicatorOpacity)
                .padding(.trailing, 20)
                .padding(.bottom, 200)
            }
        }
    }

    private var brightnessSliderOverlay: some View {
        GeometryReader { geometry in
            let _: CGFloat = geometry.size.height * 0.55
            
            ZStack {
                // 半透明遮罩
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                
                // 右侧简洁亮度显示（小尺寸）
                HStack {
                    Spacer()
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // 小尺寸亮度百分比
                        VStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(viewModel.selectedStyle.colors.first ?? .white)
                            
                            Text("\(Int(displayedBrightness))")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        
                        Spacer()
                    }
                    .padding(.trailing, 20)
                }
            }
        }
        .background(Color.clear)
        .opacity(isAdjustingBrightness && !isControlsExpanded ? 1 : 0)
        .transition(.opacity)
    }

    private var previewWindowLayer: some View {
        GeometryReader { proxy in
            let maxWidth = min(proxy.size.width - 28, 360)
            let maxHeight = proxy.size.height * previewMaxHeightRatio
            let width = min(maxWidth, maxHeight * selectedAspectRatio)
            let height = width / selectedAspectRatio

            VStack {
                previewWindowContent
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 0.8)
                    )
                    .padding(.top, proxy.safeAreaInsets.top + 14)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var previewWindowContent: some View {
        if viewModel.cameraAuthorized {
            CameraPreviewView(session: cameraController.session, mirrored: isPreviewMirrored)
        } else if viewModel.cameraDenied {
            previewDeniedView
        } else {
            previewLoadingView
        }
    }

    private var previewLoadingView: some View {
        ZStack {
            Color.black.opacity(0.68)
            VStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                Text("请求相机权限中...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var previewDeniedView: some View {
        ZStack {
            Color.black.opacity(0.72)
            VStack(spacing: 8) {
                Image(systemName: "camera.slash.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.9))
                Text("未获得相机权限")
                    .font(.caption)
                    .foregroundStyle(.white)
                Text("请到设置开启相机")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 14)
        }
    }

    private var topSafeAreaMask: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Color.black.opacity(0.9)
                    .frame(height: proxy.safeAreaInsets.top)
                Spacer()
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    private var controlsPanel: some View {
        VStack {
            Spacer()

            Group {
                if isControlsExpanded {
                    VStack(spacing: 12) {
                        expandedControlsHeader
                        stylePicker
                        intensitySlider
                        styleDescriptionRow
                        cameraBasicConfigSection
                        extraSettingsSection
                        privacyEntryButton
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(panelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    collapsedControlsHint
                        .padding(.horizontal, 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 22)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isControlsExpanded)
    }

    private var collapsedControlsHint: some View {
        HStack(spacing: 10) {
            Text(viewModel.selectedStyle.name)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
            Image(systemName: "chevron.up")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
            Text("点击展开")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .onTapGesture {
            isControlsExpanded = true
        }
    }

    private var stylePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.styles) { style in
                    Button {
                        viewModel.applyStyle(style)
                    } label: {
                        VStack(spacing: 7) {
                            Circle()
                                .fill(style.previewStyle)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.72), lineWidth: 1)
                                )

                            Text(style.name)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(viewModel.selectedStyle.id == style.id ? Color.white.opacity(0.17) : Color.white.opacity(0.04))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var expandedControlsHeader: some View {
        HStack {
            Text(viewModel.selectedStyle.name)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
            Spacer()
            Toggle("补光", isOn: $viewModel.isFillLightEnabled)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.92))
                .toggleStyle(.switch)
                .tint(.green)
            Button {
                isControlsExpanded = false
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                    Text("收起")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.14))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var intensitySlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("补光强度")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.86))
                Spacer()
                Text("\(Int(displayedBrightness))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Slider(value: $viewModel.intensity, in: 0.0...1.0, step: 0.01)
                .tint(.white)
                .disabled(!viewModel.isFillLightEnabled)
                .onChange(of: viewModel.intensity) { _, newValue in
                    displayedBrightness = newValue * 100
                    applyScreenBrightness()
                }
        }
    }

    private var styleDescriptionRow: some View {
        Text(viewModel.selectedStyle.description)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.72))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cameraBasicConfigSection: some View {
        HStack(spacing: 10) {
            liveModeCycleButton
            aspectRatioCycleButton
        }
        .padding(.top, 2)
    }

    private var extraSettingsSection: some View {
        HStack(spacing: 10) {
            mirrorFlipButton
            Spacer()
        }
        .padding(.top, 2)
    }

    private var mirrorFlipButton: some View {
        Button {
            isPreviewMirrored.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isPreviewMirrored ? "arrow.left.and.right.righttriangle.left.righttriangle.right.fill" : "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    .font(.caption)
                Text("镜像")
                    .font(.caption)
                Spacer(minLength: 0)
                Image(systemName: isPreviewMirrored ? "checkmark" : "")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.74))
            }
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }

    private var liveModeCycleButton: some View {
        Button {
            selectedLiveMode = nextLiveMode(after: selectedLiveMode)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedLiveMode.icon)
                    .font(.caption)
                Text("实况")
                    .font(.caption)
                Spacer(minLength: 0)
                Text(selectedLiveMode.title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }

    private var aspectRatioCycleButton: some View {
        Button {
            selectedAspectRatio = nextAspectRatio(after: selectedAspectRatio)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: aspectRatioIcon(selectedAspectRatio))
                    .font(.caption)
                Text("宽高比")
                    .font(.caption)
                Spacer(minLength: 0)
                Text(aspectRatioLabel(selectedAspectRatio))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.74))
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }

    private var panelBackground: some View {
        Color.black.opacity(0.42)
    }

    private var privacyEntryButton: some View {
        Button {
            isPrivacyPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised")
                    .font(.caption)
                Text("隐私政策")
                    .font(.caption)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }

    private func nextLiveMode(after mode: LiveMode) -> LiveMode {
        let modes = LiveMode.allCases
        guard let currentIndex = modes.firstIndex(of: mode) else { return .auto }
        return modes[(currentIndex + 1) % modes.count]
    }

    private func nextAspectRatio(after ratio: CGFloat) -> CGFloat {
        let ratios: [CGFloat] = [3.0 / 4.0, 1.0, 9.0 / 16.0]
        guard let currentIndex = ratios.firstIndex(where: { abs($0 - ratio) < 0.001 }) else {
            return ratios[0]
        }
        return ratios[(currentIndex + 1) % ratios.count]
    }

    private func aspectRatioLabel(_ ratio: CGFloat) -> String {
        if abs(ratio - (3.0 / 4.0)) < 0.001 { return "3:4" }
        if abs(ratio - 1.0) < 0.001 { return "1:1" }
        return "9:16"
    }

    private func aspectRatioIcon(_ ratio: CGFloat) -> String {
        if abs(ratio - 1.0) < 0.001 { return "square" }
        return "rectangle.portrait"
    }

    private var globalInteractionGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let screenHeight = activeScreen?.bounds.height ?? 0
                let panelThreshold: CGFloat = isControlsExpanded ? 0.55 : 0.8
                let inControlsZone = screenHeight > 0 && value.startLocation.y >= screenHeight * panelThreshold

                // 初始化手势起点
                if gestureStartLocation == .zero {
                    gestureStartLocation = value.startLocation
                    gestureStartIntensity = viewModel.intensity
                }
                
                if inControlsZone {
                    guard abs(dy) > abs(dx), abs(dy) > 30 else { return }
                    if dy < -30 && !isControlsExpanded {
                        isControlsExpanded = true
                    } else if dy > 30 && isControlsExpanded {
                        isControlsExpanded = false
                    }
                    return
                }

                // 上下滑调整亮度 - 基于起点的增量，丝滑跟手
                if abs(dy) > abs(dx) && abs(dy) > 8 {
                    // 显示亮度指示器（面板展开时不显示）
                    if !isAdjustingBrightness && !isControlsExpanded {
                        isAdjustingBrightness = true
                    }
                    
                    // 使用相对于起点的增量
                    let screenHeight = UIScreen.main.bounds.height
                    let fullSwipeDistance = screenHeight * 0.66
                    let delta = -dy / fullSwipeDistance
                    let newIntensity = max(0, min(1, gestureStartIntensity + delta))
                    
                    viewModel.intensity = newIntensity
                    displayedBrightness = newIntensity * 100
                    return
                }

                // 左右滑切换风格 - 需要更大距离避免误触
                if abs(dx) > abs(dy) && abs(dx) > 50 && abs(dy) < 20 {
                    if dx < -50 {
                        viewModel.selectNextStyle()
                        // 重置手势起点
                        gestureStartLocation = .zero
                        gestureStartIntensity = viewModel.intensity
                    } else if dx > 50 {
                        viewModel.selectPreviousStyle()
                        // 重置手势起点
                        gestureStartLocation = .zero
                        gestureStartIntensity = viewModel.intensity
                    }
                }
            }
            .onEnded { _ in
                // 隐藏亮度滑块
                withAnimation(.easeOut(duration: 0.3)) {
                    isAdjustingBrightness = false
                }
                // 重置手势起点
                gestureStartLocation = .zero
            }
    }

    private func applyScreenBrightness() {
        // 只记录原始亮度，不改变它（亮度只影响补光overlay）
        updateActiveScreen()
        guard let screen = activeScreen else { return }
        if originalScreenBrightness == nil {
            originalScreenBrightness = screen.brightness
        }
        // 不再改变实际屏幕亮度，只通过overlayOpacity来调整补光效果
    }

    private func restoreScreenBrightnessIfNeeded() {
        guard let original = originalScreenBrightness, let screen = activeScreen else { return }
        screen.brightness = original
    }

    private func updateActiveScreen() {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        if let screen = windowScene?.screen {
            activeScreen = screen
        }
    }

    private func triggerCapture() {
        guard viewModel.cameraAuthorized else { return }
        cameraController.capturePhoto()
        captureFlashOpacity = 0.24
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            captureFlashOpacity = 0.0
        }
    }
}

#Preview {
    MainCaptureView()
}
