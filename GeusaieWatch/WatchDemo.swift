//
//  WatchDemo.swift
//  스크린샷용 데모 (DEBUG 전용): `-watchDemo cooking` · `-watchDemo boil`
//  알리오 올리오의 '마늘·오일 볶는 중, 면냄비는 삶는 중' 장면. 글은 아이폰 카탈로그와 같은 낱말이다.
//

#if DEBUG
import Foundation

enum WatchDemo {
    static var snapshot: CookSnapshot? {
        switch UserDefaults.standard.string(forKey: "watchDemo") {
        case "cooking":
            let now = Date.now
            return CookSnapshot(
                recipe: "🍝 " + String(localized: "알리오 올리오"),
                nowTitle: "🍳 " + String(localized: "마늘·오일 볶기"),
                nowUrgent: true,
                nowStepID: "ao-garlic",
                running: true,
                pots: [
                    .init(lane: String(localized: "면냄비"), colorIndex: 1, text: String(localized: "progress.ao-pasta"),
                          endsAt: now.addingTimeInterval(299), remaining: 0),
                    .init(lane: String(localized: "소스팬"), colorIndex: 2, text: String(localized: "내가 하는 중"),
                          endsAt: nil, remaining: 0),
                ],
                alarms: [])
        case "boil":
            return CookSnapshot(
                recipe: "🍝 " + String(localized: "알리오 올리오"),
                nowTitle: "🧄 " + String(localized: "마늘 얇게 편 썰기"),
                nowUrgent: false,
                nowStepID: "ao-slice",
                running: true,
                pots: [
                    .init(lane: String(localized: "면냄비"), colorIndex: 1, text: String(localized: "progress.ao-boil"),
                          endsAt: Date.now.addingTimeInterval(192), remaining: 0),
                    .init(lane: String(localized: "소스팬"), colorIndex: 2, text: String(localized: "비어 있음"),
                          endsAt: nil, remaining: 0),
                ],
                alarms: [])
        default:
            return nil
        }
    }
}
#endif
