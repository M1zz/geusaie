import SwiftUI
import UIKit

// MARK: - 그사이에 팔레트 — 앱 아이콘에서 가져왔다
//
// 아이콘: 흰 바탕 위에 토마토빛 큰 링(소스)과 노란 작은 링(면). 화면도 같은 세 가지로 읽힌다 —
// 중립 바탕, 토마토(지금 · 누르는 곳), 노랑(냄비). 초록은 '천천히 해도 되는 일'에만 쓴다.
//
// 색마다 네 벌: 밝은 화면 · 어두운 화면, 그리고 각각 '대비 증가'를 켰을 때.
// 대비 증가 쪽은 글자로 쓰여도 배경과 4.5:1 이상 벌어지게 골랐다.

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// 화면 모드·대비 설정을 따라가는 색
    static func adaptive(_ light: UInt32, dark: UInt32,
                         lightHC: UInt32? = nil, darkHC: UInt32? = nil) -> Color {
        Color(uiColor: UIColor { t in
            let high = t.accessibilityContrast == .high
            let hex = t.userInterfaceStyle == .dark
                ? (high ? darkHC ?? dark : dark)
                : (high ? lightHC ?? light : light)
            return UIColor(hex: hex)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

enum Theme {
    // 이름은 옛 팔레트(크림 · 테라코타 · 머스터드) 그대로 둔다 — 쓰는 곳이 많고, 맡은 역할은 같다.
    static let cream      = Color.adaptive(0xF5F5F7, dark: 0x111113)   // 배경 (아이콘 바탕)
    static let card       = Color.adaptive(0xFFFFFF, dark: 0x1C1C1E)   // 카드 배경
    static let cardBorder = Color.adaptive(0xE3E3E8, dark: 0x38383A, lightHC: 0x8E8E93, darkHC: 0x8E8E93)
    static let ink        = Color.adaptive(0x1C1C1E, dark: 0xF2F2F7)   // 본문
    static let inkSoft    = Color.adaptive(0x6C6C70, dark: 0xA1A1A6, lightHC: 0x48484A, darkHC: 0xC7C7CC)   // 보조 텍스트
    /// 아이콘의 큰 링. 밝은 화면에서는 흰 글자가 얹히고 글자로도 쓰여서 한 단계 눌렀다.
    static let terracotta = Color.adaptive(0xEB4A2D, dark: 0xFF5A3C, lightHC: 0xB8321A, darkHC: 0xFF8F78)   // 포인트
    /// 아이콘의 작은 링. 채우는 데만 쓴다 — 흰 바탕에서 글자로는 안 읽힌다(→ mustardInk).
    static let mustard    = Color.adaptive(0xF5B01A, dark: 0xFFC43A, lightHC: 0x8A5E00, darkHC: 0xFFD873)
    /// 노랑을 글자로 쓸 때
    static let mustardInk = Color.adaptive(0x8A5E00, dark: 0xFFC43A, lightHC: 0x6B4800, darkHC: 0xFFD873)
    static let green      = Color.adaptive(0x2A8F4F, dark: 0x4CD07D, lightHC: 0x1B6B38, darkHC: 0x8AE6A8)
    static let brick      = Color.adaptive(0xB8281C, dark: 0xFF7566, lightHC: 0x8E1A10, darkHC: 0xFF9D92)
    static let ringTrack  = Color.adaptive(0xE5E5EA, dark: 0x2C2C2E)
    static let recording  = Color.adaptive(0xD9262E, dark: 0xFF5A5F, lightHC: 0xB01A22, darkHC: 0xFF8A8E)   // 마이크 사용 표시
    /// 색 채운 버튼·막대 위 글자 — 어두운 화면에서는 채움이 밝아지니 글자를 어둡게
    static let onAccent   = Color.adaptive(0xFFFFFF, dark: 0x111113)
    /// 노랑 위 글자 — 노랑은 늘 밝아서 화면 모드와 상관없이 어두운 글자
    static let onMustard  = Color(hex: 0x1C1C1E)

    /// 타이머 카드에 쓰는 색상 팔레트 (색인으로 선택)
    static let dishColors: [Color] = [terracotta, mustard, green, brick,
                                      Color.adaptive(0x7A6FA0, dark: 0xA89ED0, lightHC: 0x5B5085, darkHC: 0xC3BBE6),
                                      Color.adaptive(0x4A7A8C, dark: 0x7DB0C2, lightHC: 0x2F5D6E, darkHC: 0x9CCADA)]

    private static func wrap(_ index: Int) -> Int {
        ((index % dishColors.count) + dishColors.count) % dishColors.count
    }

    static func dishColor(_ index: Int) -> Color { dishColors[wrap(index)] }
    /// 그 색을 글자로 쓸 때
    static func dishInk(_ index: Int) -> Color { wrap(index) == 1 ? mustardInk : dishColors[wrap(index)] }
    /// 그 색으로 채운 자리 위에 얹는 글자
    static func onDish(_ index: Int) -> Color { wrap(index) == 1 ? onMustard : onAccent }
}

// MARK: - 아이콘의 두 링
//
// 큰 링(소스) 사이를 작은 링(면)이 지나간다 — 앱 아이콘과 같은 그림(AppIcon.icon 의 치수 그대로).
// 위쪽에서는 큰 링이, 아래쪽에서는 작은 링이 앞이다. 겹치는 자리는 바탕색 틈으로 끊는다.

struct BrandMark: View {
    /// 링 뒤에 깔린 색 — 틈이 이 색으로 보인다
    var gap: Color = Theme.cream

    var body: some View {
        Canvas { ctx, size in
            // 아이콘은 1024 판이고 두 링은 x 96~948, y 168~856 에 있다
            let k = min(size.width / 852, size.height / 688)
            ctx.translateBy(x: (size.width - 852 * k) / 2 - 96 * k, y: (size.height - 688 * k) / 2 - 168 * k)
            ctx.scaleBy(x: k, y: k)

            let big = CGPoint(x: 440, y: 512), small = CGPoint(x: 712, y: 512)
            let width: CGFloat = 118, cut: CGFloat = 40
            func ring(_ c: CGPoint, _ r: CGFloat, from: Double = 0, to: Double = 360) -> Path {
                Path { $0.addArc(center: c, radius: r, startAngle: .degrees(from), endAngle: .degrees(to), clockwise: false) }
            }
            let tomato = GraphicsContext.Shading.color(Theme.terracotta)
            let yellow = GraphicsContext.Shading.color(Theme.mustard)
            let space = GraphicsContext.Shading.color(gap)

            ctx.stroke(ring(big, 285), with: tomato, lineWidth: width)
            // 작은 링이 큰 링 앞을 지난다
            ctx.stroke(ring(small, 177), with: space, lineWidth: width + cut)
            ctx.stroke(ring(small, 177), with: yellow, lineWidth: width)
            // 위쪽 한 곳만 큰 링이 다시 앞으로 나온다
            ctx.stroke(ring(big, 285, from: -68, to: -8), with: space, lineWidth: width + cut)
            ctx.stroke(ring(big, 285, from: -70, to: -6), with: tomato, lineWidth: width)
        }
        .aspectRatio(852.0 / 688.0, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// mm:ss / h:mm:ss 포맷
func formatSeconds(_ seconds: Int) -> String {
    let s = max(0, seconds)
    if s >= 3600 {
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    return String(format: "%d:%02d", s / 60, s % 60)
}

// MARK: - 글자 크기
//
// 이 앱은 손에 들고 보는 앱이 아니다. 조리대 위에 세워 두고 한두 걸음 떨어져서 본다.
// 그래서 기본이 이미 크고, 거기서 더 키울 수 있어야 한다.

enum TextScale: Int, CaseIterable, Identifiable {
    case normal = 0, big, bigger, huge

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .normal: return String(localized: "보통")
        case .big:    return String(localized: "크게")
        case .bigger: return String(localized: "더 크게")
        case .huge:   return String(localized: "아주 크게")
        }
    }

    var dynamic: DynamicTypeSize {
        switch self {
        case .normal: return .large
        case .big:    return .xLarge
        case .bigger: return .xxLarge
        // 접근성 크기(.accessibility*)는 기기 설정에서 고르면 그대로 따른다 (→ CookView)
        case .huge:   return .xxxLarge
        }
    }
}

/// "면 삶기" → "면 삶는 중" 처럼 지금 상태로 읽히게
/// 한국어 말고는 단계 id 로 번역을 찾는다("progress.<id>"). 카탈로그에 없으면 한국어 규칙으로 돌아간다.
func progressivePhrase(_ step: RecipeStep) -> String {
    let key = "progress.\(step.id)"
    let found = String(localized: String.LocalizationValue(key))
    if found != key { return found }
    let name = step.name
    return name.hasSuffix("기") ? String(name.dropLast()) + "는 중" : name + " 중"
}

/// "12분", "6분 30초" 같은 길이 표기 (이름은 옛 이름 그대로, 표기는 기기 언어를 따른다)
func koreanDuration(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    if m > 0 && s > 0 { return String(localized: "\(m)분 \(s)초") }
    if m > 0 { return String(localized: "\(m)분") }
    return String(localized: "\(s)초")
}
