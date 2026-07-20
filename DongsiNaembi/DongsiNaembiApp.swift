import SwiftUI

// 그사이에 — 한 요리 안에서 동시에 돌아가는 작업들.
// 면 삶는 그사이에 소스도 함께 끝낸다. 핵심은 '병렬'을 시간축에 보여주는 것.

@main
struct DongsiNaembiApp: App {
    var body: some Scene {
        WindowGroup {
            RecipeListView()
                .preferredColorScheme(.light)
        }
    }
}
