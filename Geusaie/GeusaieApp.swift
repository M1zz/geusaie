import SwiftUI
import TipKit
import LeeoKit

// 그사이에 — 한 요리 안에서 동시에 돌아가는 작업들.
// 면 삶는 그사이에 소스도 함께 끝낸다. 핵심은 '병렬'을 시간축에 보여주는 것.

@main
struct GeusaieApp: App {
    init() {
        // LeeoKit 계약을 켜는 한 줄 (→ GeusaieSpec.swift). 실행 횟수 기록 · 익명 사용 통계 ·
        // 크래시 진단 · 원격 킬스위치(→ GeusaieFlags.swift) · DEBUG 프리플라이트.
        // 통계·진단·플래그는 FeedbackHub(CloudKit)를 쓴다 — 그 iCloud 컨테이너 권한은 Geusaie.entitlements 에 있다.
        LeeoKit.bootstrap(GeusaieSpec.self, flags: GeusaieFlag.self)

        // 사용 팁 (→ GeusaieTips.swift). 스크린샷용 데모 실행에서는 팁이 화면을 가리지 않게 숨긴다.
        #if DEBUG
        if UserDefaults.standard.string(forKey: "demoRecipe") != nil {
            Tips.hideAllTipsForTesting()
        }
        #endif
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        WindowGroup {
            RecipeListView()
                .preferredColorScheme(.light)
                // 요리를 몇 번 끝낸 뒤에만, 버전당 한 번 "즐겁게 쓰고 계신가요?"를 묻는다.
                // 만족 → 시스템 리뷰 요청 / 아쉬움 → 피드백 화면
                .leeoSatisfactionCheck(GeusaieSpec.self)
        }
    }
}
