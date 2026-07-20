import SwiftUI
import UIKit
import Combine
import UserNotifications
import AudioToolbox

// MARK: - 조리 세션 엔진
//
// 레시피 하나를 시작하면, 시작 시각(startedAt) 하나만 붙잡으면 된다.
// 나머지(어떤 작업이 지금 진행 중인지, 다음은 무엇인지)는 모두 elapsed에서 파생.
// 병렬 작업의 시작·종료 순간마다 알림을 걸어, 손이 바쁠 때도 놓치지 않게 한다.

@MainActor
final class CookSession: ObservableObject {
    @Published private(set) var recipe: Recipe?
    @Published private(set) var phase: Phase = .idle
    @Published var now: Date = Date()

    enum Phase: Equatable {
        case idle
        case running(startedAt: Date)
        case paused(elapsed: Int)
        case done
    }

    private var ticker: AnyCancellable?

    init() {
        ticker = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.tick(date) }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: 파생 상태

    var isActive: Bool {
        if case .running = phase { return true }
        return false
    }

    /// 요리 시작 기준 경과 초
    var elapsed: Int {
        switch phase {
        case .idle: return 0
        case .running(let s): return max(0, Int(now.timeIntervalSince(s)))
        case .paused(let e): return e
        case .done: return recipe?.totalSeconds ?? 0
        }
    }

    var remaining: Int {
        guard let recipe else { return 0 }
        return max(0, recipe.totalSeconds - elapsed)
    }

    func status(of step: RecipeStep) -> StepStatus {
        let e = elapsed
        if e < step.startAt { return .upcoming }
        if e < step.end { return .active }
        return .done
    }

    /// 지금 이 순간 진행 중인 작업들 (병렬이면 여럿)
    var activeSteps: [RecipeStep] {
        guard let recipe else { return [] }
        return recipe.steps.filter { status(of: $0) == .active }
            .sorted { $0.end < $1.end }
    }

    /// 다음에 시작될 작업 (가장 가까운 것)
    var nextStep: RecipeStep? {
        guard let recipe else { return nil }
        return recipe.steps.filter { $0.startAt > elapsed }
            .min { $0.startAt < $1.startAt }
    }

    /// 한 작업의 남은 초 (진행 중이면 종료까지, 대기면 시작까지)
    func countdown(for step: RecipeStep) -> Int {
        switch status(of: step) {
        case .upcoming: return step.startAt - elapsed
        case .active:   return step.end - elapsed
        case .done:     return 0
        }
    }

    // MARK: 제어

    func start(_ recipe: Recipe) {
        self.recipe = recipe
        phase = .running(startedAt: Date())
        scheduleNotifications(for: recipe, startedAt: Date())
        UIApplication.shared.isIdleTimerDisabled = true
        haptic(.success)
    }

    func pause() {
        guard case .running = phase else { return }
        phase = .paused(elapsed: elapsed)
        cancelNotifications()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func resume() {
        guard case .paused(let e) = phase, let recipe else { return }
        let started = Date().addingTimeInterval(-TimeInterval(e))
        phase = .running(startedAt: started)
        scheduleNotifications(for: recipe, startedAt: started)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func finish() {
        phase = .done
        cancelNotifications()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func reset() {
        recipe = nil
        phase = .idle
        cancelNotifications()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: 틱

    private func tick(_ date: Date) {
        now = date
        guard case .running = phase, let recipe else { return }
        if elapsed >= recipe.totalSeconds {
            phase = .done
            AudioServicesPlaySystemSound(1005)
            haptic(.success)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: 알림 — 각 작업의 '시작'과 '완료' 순간마다

    private func scheduleNotifications(for recipe: Recipe, startedAt: Date) {
        cancelNotifications()
        let center = UNUserNotificationCenter.current()
        let elapsedNow = Int(Date().timeIntervalSince(startedAt))

        for step in recipe.steps {
            // 시작 알림 — instant(한 번 동작) 작업은 시작 알림이 곧 액션 알림
            if step.startAt > elapsedNow + 1, step.duration >= 20 || step.attention == .instant {
                let c = UNMutableNotificationContent()
                c.title = "\(step.emoji) 이제 \(step.name)"
                c.body = step.attention == .active
                    ? "불 앞에서 지켜봐 주세요 · \(koreanDuration(step.duration))"
                    : (step.tip ?? "지금 시작하세요")
                c.sound = .default
                add(center, id: "start-\(step.id)",
                    after: TimeInterval(step.startAt - elapsedNow), content: c)
            }
            // 완료 알림
            if step.end > elapsedNow + 1, step.duration >= 20 {
                let c = UNMutableNotificationContent()
                c.title = "\(step.emoji) \(step.name) 완료"
                c.body = "다음 작업으로 넘어갈 시간이에요"
                c.sound = .default
                add(center, id: "end-\(step.id)",
                    after: TimeInterval(step.end - elapsedNow), content: c)
            }
        }

        // 전체 완성
        let c = UNMutableNotificationContent()
        c.title = "\(recipe.emoji) \(recipe.name) 완성!"
        c.body = "접시에 담으세요. 맛있게 드세요 🍴"
        c.sound = .default
        add(center, id: "done-\(recipe.id)",
            after: TimeInterval(max(1, recipe.totalSeconds - elapsedNow)), content: c)
    }

    private func add(_ center: UNUserNotificationCenter, id: String,
                     after seconds: TimeInterval, content: UNMutableNotificationContent) {
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
