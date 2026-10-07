import SwiftUI
import LeeoKit

// 그사이에 — 한 요리 안에서 동시에 돌아가는 작업들.
// 면 삶는 그사이에 소스도 함께 끝낸다. 핵심은 '병렬'을 시간축에 보여주는 것.

@main
struct GeusaieApp: App {
    init() {
        // LeeoKit 계약을 켜는 한 줄 (→ GeusaieSpec.swift). 실행 횟수 기록 · DEBUG 프리플라이트.
        // ⚠️ 크래시 진단은 끈다(`diagnostics: false`). 진단은 FeedbackHub(CloudKit)로 올리는데
        //    이 앱엔 아직 그 iCloud 컨테이너 권한이 없다 — 권한 없이 CKContainer 를 만들면 앱이 죽는다.
        LeeoKit.bootstrap(GeusaieSpec.self, diagnostics: false)
    }

    var body: some Scene {
        WindowGroup {
            RecipeListView()
                .preferredColorScheme(.light)
        }
    }
}
