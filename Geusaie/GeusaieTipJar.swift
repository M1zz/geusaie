import SwiftUI
import LeeoKit

// MARK: - 개발자 응원하기 (소모성 팁 세 가지)
//
// 팁 상품은 계약(GeusaieSpec.monetization)의 tipJar 에 있고, LeeoStore 가 불러오고 결제 업데이트를 듣는다
// (→ Purchases.tipJar). 리스너가 둘이면 같은 거래를 다투므로 따로 돌리지 않는다.
// 판매 중인 팁이 없으면(App Store Connect 에 아직 안 만들었으면) 설정 줄도 부탁 카드도 서지 않는다.
// 팁은 아무것도 열지 않는다. 응원 부탁은 이미 Pro 인 사람에게만 한다(→ CookView).

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
