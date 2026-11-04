//
//  NextStepIntent.swift
//  동작 버튼 · Siri · 단축어로 "다음 단계" — 화면을 보지 않고 지금 할 일을 끝냈다고 알린다.
//  (Apple Watch Ultra: 설정 ▸ 동작 버튼 ▸ 단축어 ▸ 그사이에 다음 단계)
//

import AppIntents

struct NextStepIntent: AppIntent {
    static var title: LocalizedStringResource = "다음 단계"
    static var description = IntentDescription("아이폰에서 진행 중인 요리의 지금 할 일을 끝내고 다음으로 넘어가요.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        WatchLink.shared.activate()
        guard let snapshot = WatchStore.load(), snapshot.running, let step = snapshot.nowStepID else {
            return .result(dialog: "지금 넘길 단계가 없어요")
        }
        await WatchLink.shared.sendNext(step)
        return .result(dialog: "다음 단계로 넘겼어요")
    }
}

struct GeusaieWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextStepIntent(),
            phrases: ["\(.applicationName) 다음 단계"],
            shortTitle: "다음 단계",
            systemImageName: "arrow.right.circle"
        )
    }
}
