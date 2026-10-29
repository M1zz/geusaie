import SwiftUI
import UIKit

// MARK: - 동시냄비 팔레트 (기획서 무드: 크림 · 테라코타 · 머스터드 · 그린)
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
    static let cream      = Color.adaptive(0xFAF6ED, dark: 0x1E1B16)   // 배경
    static let card       = Color.adaptive(0xF1EAD6, dark: 0x2A261F)   // 카드 배경
    static let cardBorder = Color.adaptive(0xE3D9BE, dark: 0x3D372C, lightHC: 0xB8AA85, darkHC: 0x6A604C)
    static let ink        = Color.adaptive(0x2D2A24, dark: 0xF3EEE2)   // 본문
    static let inkSoft    = Color.adaptive(0x8A8271, dark: 0xADA592, lightHC: 0x5E5747, darkHC: 0xCFC7B4)   // 보조 텍스트
    static let terracotta = Color.adaptive(0xC75B39, dark: 0xE07D5C, lightHC: 0xA8452A, darkHC: 0xF09A7C)   // 포인트
    static let mustard    = Color.adaptive(0xD99A3C, dark: 0xE3AE5A, lightHC: 0x8A5E14, darkHC: 0xF0C47E)
    static let green      = Color.adaptive(0x5B8C5A, dark: 0x82B381, lightHC: 0x3F6B3E, darkHC: 0xA3CDA2)
    static let brick      = Color.adaptive(0xA9432C, dark: 0xE2735A, lightHC: 0x8C3220, darkHC: 0xF0937D)
    static let ringTrack  = Color.adaptive(0xE8E0CC, dark: 0x3A342A)
    static let recording  = Color.adaptive(0xD93A2B, dark: 0xF06A5C, lightHC: 0xB32A1D, darkHC: 0xFF8A7E)   // 마이크 사용 표시
    /// 색 채운 버튼·막대 위 글자 — 어두운 화면에서는 채움이 밝아지니 글자를 어둡게
    static let onAccent   = Color.adaptive(0xFFFFFF, dark: 0x1E1B16)

    /// 타이머 카드에 쓰는 색상 팔레트 (색인으로 선택)
    static let dishColors: [Color] = [terracotta, mustard, green, brick,
                                      Color.adaptive(0x7A6FA0, dark: 0xA89ED0, lightHC: 0x5B5085, darkHC: 0xC3BBE6),
                                      Color.adaptive(0x4A7A8C, dark: 0x7DB0C2, lightHC: 0x2F5D6E, darkHC: 0x9CCADA)]

    static func dishColor(_ index: Int) -> Color {
        dishColors[((index % dishColors.count) + dishColors.count) % dishColors.count]
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
