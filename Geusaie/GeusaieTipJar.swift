import SwiftUI
import LeeoKit

// MARK: - 개발자 응원하기 (소모성 팁 세 가지)
//
// 인앱 결제가 없는 무료 앱이라 LeeoStore 없이 혼자 돈다 — 앱이 켜질 때 `startStandalone()` 한 번.
// 판매 중인 팁이 없으면(App Store Connect 에 아직 안 만들었으면) 설정 줄도 부탁 카드도 서지 않는다.

extension GeusaieSpec {
    @MainActor static let tipJar = LeeoTipJar(config: LeeoTipJarConfig(productIDs: [
        "com.leeo.geusaie.tip.small",
        "com.leeo.geusaie.tip.medium",
        "com.leeo.geusaie.tip.large",
    ]))
}

// MARK: - 고마운 순간
//
// 요리를 끝까지 마친 횟수 — 완성될 때마다 LeeoEngagement 에 쌓이는 그 숫자다(→ CookView).
// 막 하나를 끝낸 화면에서만 묻는다. 얼마나 드물게 물을지는 LeeoKit 규칙(`LeeoTipAskPolicy`)이 정한다.

enum GeusaieTipMoments {
    /// 끝까지 마친 요리 수. 큰 것부터.
    static let cooks = [50, 20, 10]

    static func reached(cooks done: Int) -> [LeeoTipMoment] {
        cooks.filter { done >= $0 }.map { threshold in
            LeeoTipMoment(id: "cooks.\(threshold)",
                          message: String(localized: "지금까지 요리 \(done)번을 끝까지 마쳤어요",
                                          comment: "Tip ask card: how many dishes the person has cooked to the end with the app"))
        }
    }
}
