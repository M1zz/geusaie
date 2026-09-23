import SwiftUI
import UIKit
import Combine
import UserNotifications
import AudioToolbox

// MARK: - 조리 세션 엔진
//
// 시계 하나로 모든 걸 파생시키지 않는다. 실제 부엌이 그렇지 않기 때문이다.
//
// - **냄비**는 내가 시작 동작을 해야 돌기 시작하고, 한번 돌면 사람을 기다려 주지 않는다.
//   면이 다 삶기면 그 순간이 곧 건지는 마감이다(deadline).
// - **도마 일**은 손이 비는 동안에만 는다. 냄비가 부르면 하던 데서 멈췄다가,
//   돌아와서 이어서 한다. 시각이 아니라 '얼마나 했나'로 센다.
//
// 그래서 상태는 실제로 한 일(시작 시각·끝낸 시각·도마 일 진행량)뿐이고,
// 화면에 그리는 시간표(Plan)는 그 상태에서 매번 계산해 낸다.

@MainActor
final class CookSession: ObservableObject {
    @Published private(set) var recipe: Recipe?
    @Published private(set) var phase: Phase = .idle
    @Published var now: Date = Date()

    /// 실제로 한 일 — 이것만이 진짜 상태다
    @Published private(set) var state = CookState()
    /// 냄비 때문에 끊겼던 도마 일 (돌아오면 '이어서')
    @Published private(set) var interrupted: Set<String> = []

    enum Phase: Equatable {
        case idle
        case ready                      // 레시피를 열어두고, 시작 버튼을 기다리는 중
        case running(startedAt: Date)
        case paused(elapsed: Int)
        case done
    }

    private var ticker: AnyCancellable?
    private var lastAccrual = 0
    private var finishedAt: Int?

    init() {
        ticker = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.tick(date) }
        #if DEBUG
        // 데모(스크린샷) 실행에선 권한 팝업이 화면을 가리므로 건너뛴다
        let demo = UserDefaults.standard.string(forKey: "demoRecipe") != nil
        #else
        let demo = false
        #endif
        if !demo {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: 시간

    var isActive: Bool {
        if case .running = phase { return true }
        return false
    }

    /// 요리를 시작한 뒤 흐른 시간. 기다리는 동안에도 흐른다 — 냄비가 그러니까.
    var elapsed: Int {
        switch phase {
        case .idle, .ready: return 0
        case .running(let s): return max(0, Int(now.timeIntervalSince(s)))
        case .paused(let e): return e
        case .done: return finishedAt ?? 0
        }
    }

    var cookingElapsed: Int { elapsed }

    /// 지금 상태에서 계산해 낸 시간표 — 냄비가 늦어지면 뒤따르는 것도 같이 밀린다
    var plan: Plan {
        guard let recipe else { return Plan(RecipeDB.all[0], CookState()) }
        var s = state
        s.now = elapsed
        return Plan(recipe, s)
    }

    /// 다 됐을 때의 예상 시각 ("오후 6:45")
    var finishClock: String {
        let left = max(0, plan.total - elapsed)
        return Date().addingTimeInterval(TimeInterval(left))
            .formatted(date: .omitted, time: .shortened)
    }

    // MARK: 두 계층 — 지금 무엇을 해야 하는가

    /// 지금 차례가 된, 냄비에 매인 내 동작. 이게 있으면 도마 일은 멈춘다.
    var dueAction: RecipeStep? {
        guard let recipe else { return nil }
        let p = plan
        let e = elapsed
        let due = recipe.chains.flatMap { chain -> [RecipeStep] in
            var out: [RecipeStep] = []
            for (i, step) in chain.enumerated() where step.role == .action {
                if state.doneAt[step.id] != nil { continue }
                // 앞의 일이 끝나야 차례가 온다
                if i > 0, state.doneAt[chain[i - 1].id] == nil { continue }
                if p.start(step) <= e { out.append(step) }
            }
            return out
        }
        // 늦으면 상하는 것부터, 그다음은 먼저 차례가 온 것부터
        return due.sorted {
            $0.deadline == $1.deadline ? p.start($0) < p.start($1) : $0.deadline
        }.first
    }

    /// 지금 하고 있는(또는 돌아가서 이어 할) 도마 일
    var currentPrep: RecipeStep? {
        recipe?.preps.first { state.doneAt[$0.id] == nil }
    }

    /// 그 도마 일을 얼마나 했나 (초)
    func progress(of step: RecipeStep) -> Int { state.prepProgress[step.id] ?? 0 }

    /// 도마 일을 다 채워 놓고 "다음" 한 마디를 기다리는 중인가
    var isWaitingForNext: Bool {
        guard dueAction == nil, let prep = currentPrep else { return false }
        return progress(of: prep) >= prep.duration
    }

    /// 마감을 넘긴 냄비 일 — 면이 퍼지는 중이니 숨기지 않는다
    func isOverdue(_ step: RecipeStep) -> Bool {
        guard step.role == .action, step.deadline, state.doneAt[step.id] == nil else { return false }
        return elapsed > plan.start(step) + step.duration
    }

    /// 지금 냄비가 혼자 돌고 있는 것
    var runningCooks: [RecipeStep] {
        guard let recipe else { return [] }
        return recipe.steps.filter {
            $0.role == .cook && state.startedAt[$0.id] != nil && state.doneAt[$0.id] == nil
        }
    }

    /// 냄비마다 지금 무슨 상태인가 — 항상 전부 보여준다
    struct PotState: Identifiable {
        enum Kind { case empty, cooking, handsOn, finished }
        let lane: String
        let kind: Kind
        let step: RecipeStep?
        let remaining: Int
        let total: Int
        let text: String
        var id: String { lane }
    }

    var potStates: [PotState] {
        guard let recipe else { return [] }
        return recipe.potLanes.enumerated().map { index, lane in
            // 시작 전에는 아무 냄비도 올라가 있지 않다
            if isReady {
                return PotState(lane: lane, kind: .empty, step: nil,
                                remaining: 0, total: 0, text: "비어 있음")
            }
            let chain = index < recipe.chains.count ? recipe.chains[index] : []

            // 냄비가 혼자 도는 중 — 지켜야 하는 시계
            if let cook = chain.first(where: {
                $0.role == .cook && state.startedAt[$0.id] != nil && state.doneAt[$0.id] == nil
            }) {
                return PotState(lane: lane, kind: .cooking, step: cook,
                                remaining: countdown(for: cook), total: cook.duration,
                                text: progressivePhrase(cook.name))
            }
            // 내 손이 거기 붙어 있는 중
            if let due = dueAction, due.lane == lane {
                return PotState(lane: lane, kind: .handsOn, step: due,
                                remaining: 0, total: due.duration,
                                text: progressivePhrase(due.name))
            }
            // 다 썼다
            if !chain.isEmpty, chain.allSatisfy({ state.doneAt[$0.id] != nil }) {
                return PotState(lane: lane, kind: .finished, step: nil,
                                remaining: 0, total: 0, text: "다 썼어요")
            }
            return PotState(lane: lane, kind: .empty, step: nil,
                            remaining: 0, total: 0, text: "비어 있음")
        }
    }

    /// 다음에 닥칠 냄비 일 (손이 빈 순간의 안내용)
    var nextAction: RecipeStep? {
        guard let recipe else { return nil }
        let p = plan
        let e = elapsed
        return recipe.steps
            .filter { $0.role == .action && state.doneAt[$0.id] == nil && p.start($0) > e }
            .min { p.start($0) < p.start($1) }
    }

    /// 이 다음에 내가 할 일 — 미리 알면 준비가 된다
    var upNext: RecipeStep? {
        guard let recipe else { return nil }
        if dueAction != nil { return nil }          // 그때는 '하던 일'을 대신 보여준다
        if let next = nextAction { return next }
        guard let current = currentPrep else { return nil }
        return recipe.preps.first { $0.id != current.id && state.doneAt[$0.id] == nil }
    }

    /// 손으로 할 일이 다 끝났는가
    var allHandsDone: Bool {
        guard let recipe else { return false }
        return recipe.steps.filter(\.needsHands).allSatisfy { state.doneAt[$0.id] != nil }
    }

    // MARK: 상태 조회 (타임라인·체크리스트용)

    func status(of step: RecipeStep) -> StepStatus {
        if state.doneAt[step.id] != nil { return .done }
        switch step.role {
        case .cook:
            return state.startedAt[step.id] != nil ? .active : .upcoming
        case .action:
            return dueAction?.id == step.id ? .active : .upcoming
        case .prep:
            if dueAction == nil, currentPrep?.id == step.id { return .active }
            return progress(of: step) > 0 ? .active : .upcoming
        }
    }

    /// 지금 손이 붙잡혀 있는 일 (냄비 일이 우선, 없으면 도마 일)
    var activeHandsSteps: [RecipeStep] {
        if let due = dueAction { return [due] }
        if let prep = currentPrep { return [prep] }
        return []
    }

    /// 한 일에 남은 초. 도마 일은 '내가 더 해야 할 분량', 냄비 일은 '시계가 남긴 시간'.
    func countdown(for step: RecipeStep) -> Int {
        if state.doneAt[step.id] != nil { return 0 }
        if step.isPrep { return max(0, step.duration - progress(of: step)) }
        if step.role == .cook, let began = state.startedAt[step.id] {
            return max(0, began + step.duration - elapsed)
        }
        return max(0, plan.start(step) + step.duration - elapsed)
    }

    // MARK: 제어

    /// 레시피를 열어만 둔다 — 시계는 아직 돌지 않는다.
    /// 물을 올릴 준비가 됐을 때 begin()으로 시작한다.
    func prepare(_ recipe: Recipe) {
        self.recipe = recipe
        state = CookState()
        interrupted = []
        finishedAt = nil
        lastAccrual = 0
        phase = .ready
    }

    /// 요리 시작 — 여기서부터 냄비의 시계가 돈다
    func begin() {
        guard case .ready = phase, recipe != nil else { return }
        runFrom(0)
        haptic(.success)
    }

    /// 시작 전인가 (준비 화면)
    var isReady: Bool {
        if case .ready = phase { return true }
        return false
    }

    /// 시작하면 가장 먼저 할 일
    var firstStep: RecipeStep? {
        guard let recipe else { return nil }
        let p = recipe.previewPlan
        return recipe.steps.filter(\.needsHands).min { p.start($0) < p.start($1) }
    }

    /// at: 이미 흘러간 초부터 시작(스크린샷·디버그용, 기본 0)
    func start(_ recipe: Recipe, at elapsed: Int = 0) {
        self.recipe = recipe
        state = CookState(now: elapsed)
        interrupted = []
        finishedAt = nil
        lastAccrual = elapsed

        // 데모로 중간부터 열면, 그 시각까지 계획된 일은 해둔 것으로 본다
        if elapsed > 0 {
            let preview = Plan(recipe, CookState())
            for step in recipe.steps where preview.end(step) <= elapsed {
                state.startedAt[step.id] = preview.start(step)
                state.doneAt[step.id] = preview.end(step)
                if step.isPrep { state.prepProgress[step.id] = step.duration }
            }
            for step in recipe.steps
            where state.doneAt[step.id] == nil && preview.start(step) <= elapsed {
                state.startedAt[step.id] = preview.start(step)
                if step.isPrep {
                    state.prepProgress[step.id] = max(0, elapsed - preview.start(step))
                }
            }
        }

        runFrom(elapsed)
        haptic(.success)
    }

    private func runFrom(_ t: Int) {
        let started = Date().addingTimeInterval(-TimeInterval(t))
        phase = .running(startedAt: started)
        lastAccrual = t
        rescheduleNotifications()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// "다음" — 지금 하고 있는 일을 끝냈다고 알린다.
    /// 냄비 일이 걸려 있으면 그것부터 지우고, 아니면 도마 일을 끝낸다.
    func advance() {
        if case .paused = phase { resume(); return }
        guard case .running = phase, let recipe else { return }
        let e = elapsed

        if let due = dueAction {
            state.doneAt[due.id] = e
            if state.startedAt[due.id] == nil { state.startedAt[due.id] = plan.start(due) }
            // 그 동작이 냄비를 걸어두는 일이었다면, 지금부터 냄비가 돈다
            if let chain = recipe.chains.first(where: { c in c.contains { $0.id == due.id } }),
               let idx = chain.firstIndex(where: { $0.id == due.id }),
               idx + 1 < chain.count, chain[idx + 1].role == .cook {
                let cook = chain[idx + 1]
                state.startedAt[cook.id] = e
                scheduleCookAlarm(cook, from: e)
            }
            haptic(.success)
        } else if let prep = currentPrep {
            state.doneAt[prep.id] = e
            if state.startedAt[prep.id] == nil { state.startedAt[prep.id] = e }
            haptic(.success)
        }

        if allHandsDone && runningCooks.isEmpty { finish() }
    }

    /// 단계 종료 — "다음"과 같다
    func endCurrentStage() { advance() }

    /// 더 넘길 게 없는 마지막인가 (버튼이 '완성 처리'가 되는 시점)
    var isLastStage: Bool {
        guard recipe != nil else { return true }
        if dueAction != nil || currentPrep != nil { return false }
        return runningCooks.isEmpty
    }

    func pause() {
        guard case .running = phase else { return }
        phase = .paused(elapsed: elapsed)
        cancelNotifications()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func resume() {
        guard case .paused(let e) = phase else { return }
        runFrom(e)
    }

    func finish() {
        finishedAt = elapsed
        phase = .done
        cancelNotifications()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func reset() {
        recipe = nil
        phase = .idle
        state = CookState()
        interrupted = []
        finishedAt = nil
        cancelNotifications()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: 틱 — 냄비는 저절로, 도마 일은 손이 빌 때만

    private func tick(_ date: Date) {
        now = date
        guard case .running = phase, let recipe else { return }
        let e = elapsed
        state.now = e

        // 1) 다 된 냄비는 스스로 끝난다 (그 순간이 다음 동작의 마감)
        for cook in recipe.steps where cook.role == .cook {
            if let began = state.startedAt[cook.id], state.doneAt[cook.id] == nil,
               e >= began + cook.duration {
                state.doneAt[cook.id] = began + cook.duration
                haptic(.warning)
            }
        }

        // 2) 흐른 만큼 도마 일에 적립. 냄비 일이 걸려 있으면 손이 거기 가 있으니 안 는다.
        let delta = e - lastAccrual
        if delta > 0 {
            lastAccrual = e
            let blocked = dueAction != nil
            if let prep = currentPrep {
                if blocked {
                    if progress(of: prep) > 0 { interrupted.insert(prep.id) }
                } else {
                    let soFar = progress(of: prep)
                    if state.startedAt[prep.id] == nil { state.startedAt[prep.id] = e }
                    if soFar < prep.duration {
                        state.prepProgress[prep.id] = min(prep.duration, soFar + delta)
                    }
                }
            }
        }

        // 3) 손도 끝나고 냄비도 다 돌았으면 완성
        if allHandsDone && runningCooks.isEmpty {
            finishedAt = e
            phase = .done
            AudioServicesPlaySystemSound(1005)
            haptic(.success)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: 스크럽 — 드래그로 진행 상황 이동

    private var resumeRunningAfterScrub = false

    func beginScrub() {
        resumeRunningAfterScrub = isActive
        phase = .paused(elapsed: elapsed)
        cancelNotifications()
    }

    func updateScrub(toFraction f: Double) {
        let total = plan.total
        let clamped = min(max(f, 0), 1)
        phase = .paused(elapsed: Int((Double(total) * clamped).rounded()))
    }

    func endScrub() {
        if resumeRunningAfterScrub { runFrom(elapsed) }
        resumeRunningAfterScrub = false
    }

    // MARK: 알림 — 냄비가 다 됐을 때만 부른다
    //
    // 도마 일은 시각에 매이지 않으니 알리지 않는다. 재촉할 이유가 없다.

    private func rescheduleNotifications() {
        cancelNotifications()
        guard let recipe else { return }
        for cook in recipe.steps where cook.role == .cook {
            guard let began = state.startedAt[cook.id], state.doneAt[cook.id] == nil else { continue }
            scheduleCookAlarm(cook, from: began)
        }
    }

    private func scheduleCookAlarm(_ cook: RecipeStep, from began: Int) {
        guard let recipe else { return }
        let after = TimeInterval(began + cook.duration - elapsed)
        guard after > 1 else { return }

        // 그 냄비에서 다음에 할 동작 = 이 시간이 끝나는 순간의 마감
        let chain = recipe.chains.first { c in c.contains { $0.id == cook.id } } ?? []
        let idx = chain.firstIndex { $0.id == cook.id } ?? 0
        let next = idx + 1 < chain.count ? chain[idx + 1] : nil

        let c = UNMutableNotificationContent()
        c.title = "\(cook.emoji) \(cook.name) 다 됐어요"
        c.body = next.map { "\($0.emoji) \($0.name) — 지금 하세요" } ?? "보러 오세요"
        c.sound = .default
        c.interruptionLevel = (next?.deadline ?? false) ? .timeSensitive : .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: after, repeats: false)
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "cook-\(cook.id)", content: c, trigger: trigger))
    }

    private func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
