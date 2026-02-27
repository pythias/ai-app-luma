import SwiftUI

enum LightAnimation: String, Hashable {
    case staticColor
    case split
    case cycle
    case strobe
}

struct LightStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let defaultIntensity: Double
    let description: String
    let colors: [Color]
    let animation: LightAnimation
    let animationSpeed: Double

    var previewColors: [Color] {
        colors.isEmpty ? [.white] : colors
    }

    var previewStyle: AnyShapeStyle {
        if previewColors.count > 1 {
            return AnyShapeStyle(
                LinearGradient(
                    colors: previewColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(previewColors[0])
    }
}

extension LightStyle {
    static let presets: [LightStyle] = [
        LightStyle(
            id: "natural-soft",
            name: "自然柔光",
            defaultIntensity: 0.45,
            description: "接近日光的柔和提亮，适合日常自拍。",
            colors: [Color(red: 1.0, green: 0.97, blue: 0.92)],
            animation: .staticColor,
            animationSpeed: 1.0
        ),
        LightStyle(
            id: "warm-portrait",
            name: "暖肤人像",
            defaultIntensity: 0.50,
            description: "偏暖色补光，增强肤色红润感。",
            colors: [Color(red: 1.0, green: 0.90, blue: 0.78)],
            animation: .staticColor,
            animationSpeed: 1.0
        ),
        LightStyle(
            id: "cool-cinematic",
            name: "冷调电影",
            defaultIntensity: 0.42,
            description: "冷色层次更明显，适合情绪化风格。",
            colors: [Color(red: 0.80, green: 0.88, blue: 1.0)],
            animation: .staticColor,
            animationSpeed: 1.0
        ),
        LightStyle(
            id: "high-key",
            name: "高调时尚",
            defaultIntensity: 0.60,
            description: "高亮白光，强化清透和干净质感。",
            colors: [Color(red: 1.0, green: 1.0, blue: 1.0)],
            animation: .staticColor,
            animationSpeed: 1.0
        ),
        LightStyle(
            id: "sunset-gold",
            name: "日落金调",
            defaultIntensity: 0.52,
            description: "金色偏暖氛围，突出环境温度感。",
            colors: [Color(red: 1.0, green: 0.82, blue: 0.60)],
            animation: .staticColor,
            animationSpeed: 1.0
        ),
        LightStyle(
            id: "neon-magenta",
            name: "霓虹洋红",
            defaultIntensity: 0.35,
            description: "强调个性和夜景视觉张力。",
            colors: [Color(red: 1.0, green: 0.55, blue: 0.86)],
            animation: .staticColor,
            animationSpeed: 1.0
        ),
        LightStyle(
            id: "rembrandt-amber",
            name: "伦勃朗琥珀",
            defaultIntensity: 0.48,
            description: "经典人像暖向补光，突出面部体积感。",
            colors: [Color(red: 0.98, green: 0.80, blue: 0.58)],
            animation: .staticColor,
            animationSpeed: 1.0
        ),
        LightStyle(
            id: "deakins-teal-amber",
            name: "德金斯青橙",
            defaultIntensity: 0.43,
            description: "青橙对比风格，常见于商业与电影质感。",
            colors: [Color(red: 0.39, green: 0.82, blue: 0.86), Color(red: 0.98, green: 0.62, blue: 0.30)],
            animation: .split,
            animationSpeed: 1.0
        ),
        LightStyle(
            id: "wong-neon",
            name: "王家卫霓虹",
            defaultIntensity: 0.36,
            description: "紫青霓虹氛围，适合夜景情绪表达。",
            colors: [Color(red: 0.96, green: 0.37, blue: 0.86), Color(red: 0.33, green: 0.86, blue: 0.92)],
            animation: .cycle,
            animationSpeed: 0.9
        ),
        LightStyle(
            id: "blade-runner-rain",
            name: "银翼夜雨",
            defaultIntensity: 0.40,
            description: "蓝紫冷暖交错，科幻都市氛围。",
            colors: [Color(red: 0.26, green: 0.55, blue: 0.96), Color(red: 0.86, green: 0.25, blue: 0.70)],
            animation: .cycle,
            animationSpeed: 1.2
        ),
        LightStyle(
            id: "la-la-neon-floor",
            name: "歌舞厅地灯",
            defaultIntensity: 0.34,
            description: "多色渐变慢扫，KTV/舞厅感更强。",
            colors: [
                Color(red: 1.0, green: 0.46, blue: 0.60),
                Color(red: 0.37, green: 0.67, blue: 1.0),
                Color(red: 0.47, green: 1.0, blue: 0.73)
            ],
            animation: .cycle,
            animationSpeed: 1.4
        )
    ]
}
