import SwiftUI

// MARK: - 동시냄비 팔레트 (기획서 무드: 크림 · 테라코타 · 머스터드 · 그린)

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

enum Theme {
    static let cream      = Color(hex: 0xFAF6ED)   // 배경
    static let card       = Color(hex: 0xF1EAD6)   // 카드 배경
    static let cardBorder = Color(hex: 0xE3D9BE)
    static let ink        = Color(hex: 0x2D2A24)   // 본문
    static let inkSoft    = Color(hex: 0x8A8271)   // 보조 텍스트
    static let terracotta = Color(hex: 0xC75B39)   // 포인트
    static let mustard    = Color(hex: 0xD99A3C)
    static let green      = Color(hex: 0x5B8C5A)
    static let brick      = Color(hex: 0xA9432C)
    static let ringTrack  = Color(hex: 0xE8E0CC)

    /// 타이머 카드에 쓰는 색상 팔레트 (색인으로 선택)
    static let dishColors: [Color] = [terracotta, mustard, green, brick,
                                      Color(hex: 0x7A6FA0), Color(hex: 0x4A7A8C)]

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

/// "12분", "6분 30초" 같은 한국어 길이 표기
func koreanDuration(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    if m > 0 && s > 0 { return "\(m)분 \(s)초" }
    if m > 0 { return "\(m)분" }
    return "\(s)초"
}
