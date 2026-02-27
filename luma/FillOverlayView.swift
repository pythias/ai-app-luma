import SwiftUI

struct FillOverlayView: View {
    let style: LightStyle
    let opacity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            overlayContent(at: timeline.date)
                .opacity(opacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.18), value: opacity)
        }
    }

    @ViewBuilder
    private func overlayContent(at date: Date) -> some View {
        switch style.animation {
        case .staticColor:
            style.previewColors[0]

        case .split:
            LinearGradient(
                colors: style.previewColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .cycle:
            LinearGradient(
                colors: style.previewColors + [style.previewColors[0]],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .hueRotation(.degrees(cycleDegrees(at: date)))

        case .strobe:
            let index = strobeIndex(at: date, count: style.previewColors.count)
            style.previewColors[index]
        }
    }

    private func cycleDegrees(at date: Date) -> Double {
        (date.timeIntervalSinceReferenceDate * style.animationSpeed * 55.0)
            .truncatingRemainder(dividingBy: 360.0)
    }

    private func strobeIndex(at date: Date, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let frame = Int(date.timeIntervalSinceReferenceDate * style.animationSpeed * 4.0)
        return abs(frame) % count
    }
}
