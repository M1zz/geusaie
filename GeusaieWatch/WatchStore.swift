//
//  WatchStore.swift
//  워치 앱과 컴플리케이션이 함께 보는 '마지막으로 받은 부엌'. 폰이 멀어져도 이것으로 센다.
//

import SwiftUI

enum WatchStore {
    static let group = "group.com.leeo.geusaie"
    private static let key = "snapshot"
    private static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    static func load() -> CookSnapshot? {
        // 몇 시간 지난 장은 버린다 — 아이폰이 '끝' 을 못 보낸 채 멀어진 요리다
        guard defaults.double(forKey: "savedAt") > Date.now.addingTimeInterval(-4 * 3600).timeIntervalSince1970
        else { return nil }
        return CookLink.decode(defaults.data(forKey: key))
    }

    static func save(_ snapshot: CookSnapshot?) {
        defaults.set(CookLink.encode(snapshot), forKey: key)
        defaults.set(Date.now.timeIntervalSince1970, forKey: "savedAt")
    }
}

/// 아이폰 화면의 냄비 색 — 색 순서가 같아야 손목과 화면의 냄비가 같은 냄비로 읽힌다.
/// 워치는 늘 어두운 화면이라 아이폰의 어두운 화면 색을 쓴다.
enum WatchTheme {
    static let accent = Color(hex: 0xE07D5C)
    private static let dish: [UInt32] = [0xE07D5C, 0xE3AE5A, 0x82B381, 0xE2735A, 0xA89ED0, 0x7DB0C2]
    static func dish(_ index: Int) -> Color {
        Color(hex: dish[((index % dish.count) + dish.count) % dish.count])
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
