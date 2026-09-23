import SwiftUI

// MARK: - 밀려도 되는 일과, 밀리면 안 되는 일
//
// 요리에서 시간이 걸린 일은 두 종류다.
//
// - **도마 일(prep)** — 썰기·갈기·계량. 언제 해도 되고, 냄비 때문에 끊겼다가
//   이어서 해도 아무 일 없다. 재촉할 이유가 없다.
// - **냄비 일(action·cook)** — 냄비의 시계가 정한다. 면은 사람을 기다려 주지 않는다.
//   내가 불을 켜야 물이 끓기 시작하고, 물이 끓어야 면을 넣고,
//   면이 다 삶기면 그 순간이 곧 건지는 마감이다.
//
// 그래서 타임라인은 '몇 분에 무엇'이 아니라 '무엇 다음에 무엇'이다.
// 절대 시각(startAt)은 데이터에 없다 — 실제로 한 일에서 계산해 낸다(Plan).

enum StepRole {
    case prep     // 도마 일 — 미뤄도 되고 이어서 해도 된다
    case action   // 내가 냄비에 하는 동작 — 하는 동안 손이 붙잡힌다
    case cook     // 냄비가 혼자 하는 시간 — 시작 동작을 해야 비로소 돈다
}

/// 이 일이 언제 시작되는가
enum Trigger: Hashable {
    case atStart                // 요리를 시작하면 바로
    case after(String)          // 그 일이 끝나면 이어서
    case endingWith(String)     // 그 일이 시작될 때 이쪽도 준비돼 있도록, 거꾸로 잡는다
}

struct RecipeStep: Identifiable, Hashable {
    let id: String
    var name: String
    var emoji: String
    var lane: String            // "내 손" · "면냄비" · "소스팬"
    var role: StepRole
    var duration: Int           // 이 일에 걸리는 초
    var trigger: Trigger = .atStart
    /// 늦으면 음식이 상한다 (면이 퍼지거나 타거나) — 하던 일을 멈추고 이것부터
    var deadline: Bool = false
    /// 어떻게 하는가 — 분량·두께·불 세기처럼 손을 움직이는 데 필요한 것
    var detail: [String] = []
    /// 무엇을 보면 다 된 것인가 (색·소리·농도)
    var doneWhen: String?
    var tip: String?

    /// 도마 일인가 — 밀려도 괜찮은 쪽
    var isPrep: Bool { role == .prep }
    /// 사람 손이 있어야 하는가 (냄비가 혼자 도는 시간이 아닌가)
    var needsHands: Bool { role != .cook }

    var icon: String {
        if deadline { return "exclamationmark.triangle.fill" }
        switch role {
        case .prep:   return "hand.raised.fill"
        case .action: return "flame.fill"
        case .cook:   return "hourglass"
        }
    }
}

// MARK: - 레시피 = 냄비별 사슬 + 사이사이 끼워 넣는 도마 일

struct Recipe: Identifiable, Hashable {
    static let handsLane = "내 손"

    let id: String
    var name: String
    var emoji: String
    var subtitle: String
    var potLanes: [String]          // ["면냄비", "소스팬"]
    var chains: [[RecipeStep]]      // 냄비별 순서 (potLanes와 같은 순서)
    var preps: [RecipeStep]         // 도마 일 순서
    var source: String?

    var lanes: [String] { [Recipe.handsLane] + potLanes }
    var steps: [RecipeStep] { preps + chains.flatMap { $0 } }

    /// 화면에 보이는 타이머 개수 = 냄비 수 + 1(내 손)
    var timerCount: Int { lanes.count }
    var potCount: Int { potLanes.count }

    func step(_ id: String) -> RecipeStep? { steps.first { $0.id == id } }

    /// 한 레인에 그릴 일들. '내 손' 행은 손이 붙잡히는 일 전체.
    func rowSteps(_ lane: String) -> [RecipeStep] {
        lane == Recipe.handsLane
            ? steps.filter { $0.needsHands }
            : steps.filter { $0.lane == lane }
    }

    func laneIndex(_ lane: String) -> Int { lanes.firstIndex(of: lane) ?? 0 }
    func color(for lane: String) -> Color { Theme.dishColor(laneIndex(lane)) }

    /// 아직 아무것도 안 한 상태의 계획 — 카드 미리보기·예상 시간에 쓴다
    var previewPlan: Plan { Plan(self, CookState()) }
    var estimatedSeconds: Int { previewPlan.total }

    /// 계획대로 갔을 때 손이 노는 시간
    var handsIdleSeconds: Int {
        let plan = previewPlan
        let busy = steps.filter(\.needsHands)
            .map { (plan.start($0), plan.end($0)) }
            .sorted { $0.0 < $1.0 }
        var covered = 0, cursor = 0
        for (s, e) in busy {
            let from = max(s, cursor)
            if e > from { covered += e - from }
            cursor = max(cursor, e)
        }
        return max(0, plan.total - covered)
    }

    /// 데이터 검증 — 냄비가 혼자 도는 시간(cook) 앞에는 반드시 사람이 하는 시작 동작이 있어야 한다
    var unstartedCooks: [RecipeStep] {
        chains.flatMap { chain -> [RecipeStep] in
            var out: [RecipeStep] = []
            for (i, step) in chain.enumerated() where step.role == .cook {
                let hasStarter = i > 0 && chain[i - 1].role == .action
                if !hasStarter { out.append(step) }
            }
            return out
        }
    }
}

// MARK: - 지금까지 실제로 한 일

struct CookState {
    var now: Int = 0                        // 요리 시작 후 경과 초
    var startedAt: [String: Int] = [:]      // 그 일을 시작한 시각
    var doneAt: [String: Int] = [:]         // 끝낸 시각
    var prepProgress: [String: Int] = [:]   // 도마 일을 얼마나 했나 (초)
}

// MARK: - 계획 = 실제로 한 일에서 계산해 낸 시간표
//
// 밀리면 안 되는 것(냄비 사슬)은 냄비의 시계대로 이어 붙이고,
// 밀려도 되는 것(도마 일)은 손이 비는 틈에 끼워 넣는다.
// 냄비가 늦어지면 뒤따르는 것도 같이 늦어진다 — 그게 실제 부엌이다.

struct Plan {
    struct Span: Hashable {
        var start: Int
        var end: Int
    }

    private(set) var spans: [String: Span] = [:]
    private(set) var total: Int = 60

    func span(_ id: String) -> Span { spans[id] ?? Span(start: 0, end: 0) }
    func start(_ step: RecipeStep) -> Int { span(step.id).start }
    func end(_ step: RecipeStep) -> Int { span(step.id).end }

    init(_ recipe: Recipe, _ state: CookState) {
        let now = state.now

        // 1) 냄비 사슬 — 의존이 풀리는 것부터 (다른 냄비를 참조할 수 있으므로 몇 번 돈다)
        var pending = recipe.chains
        var pass = 0
        while !pending.isEmpty && pass <= recipe.chains.count + 1 {
            pass += 1
            var stuck: [[RecipeStep]] = []
            for chain in pending {
                if let planned = Self.planChain(chain, state: state, known: spans, now: now) {
                    spans.merge(planned) { old, _ in old }
                } else {
                    stuck.append(chain)
                }
            }
            if stuck.count == pending.count { break }   // 더는 못 푼다
            pending = stuck
        }

        // 2) 도마 일 — 손이 비는 틈에 순서대로 끼워 넣는다
        let busy = recipe.steps
            .filter { $0.role == .action }
            .compactMap { spans[$0.id] }
            .map { ($0.start, $0.end) }
            .sorted { $0.0 < $1.0 }

        var cursor = now
        for prep in recipe.preps {
            if let finished = state.doneAt[prep.id] {
                let began = state.startedAt[prep.id] ?? max(0, finished - prep.duration)
                spans[prep.id] = Span(start: began, end: finished)
                continue
            }
            var left = max(0, prep.duration - (state.prepProgress[prep.id] ?? 0))
            var t = max(cursor, now)
            // 손이 냄비에 가 있는 동안은 시작도 못 한다 — 첫 빈 틈부터가 시작
            while let block = busy.first(where: { $0.0 <= t && t < $0.1 }) { t = block.1 }
            let began = state.startedAt[prep.id] ?? t
            while left > 0 {
                if let block = busy.first(where: { $0.0 <= t && t < $0.1 }) {
                    t = block.1               // 냄비 일에 붙잡힌 동안은 도마 일이 안 는다
                    continue
                }
                let nextBlock = busy.first(where: { $0.0 > t })?.0 ?? Int.max
                let free = min(nextBlock - t, left)
                t += free
                left -= free
            }
            spans[prep.id] = Span(start: began, end: t)
            cursor = t
        }

        total = max(60, spans.values.map(\.end).max() ?? 60)
    }

    /// 사슬 하나를 앞에서부터 이어 붙인다. 참조하는 일이 아직 안 잡혔으면 nil.
    private static func planChain(_ chain: [RecipeStep], state: CookState,
                                  known: [String: Span], now: Int) -> [String: Span]? {
        var out: [String: Span] = [:]
        var cursor: Int? = nil

        for step in chain {
            var earliest: Int
            switch step.trigger {
            case .atStart:
                earliest = 0
            case .after(let ref):
                guard let s = known[ref] ?? out[ref] else { return nil }
                earliest = s.end
            case .endingWith(let ref):
                guard let s = known[ref] ?? out[ref] else { return nil }
                // 이 사슬이 ref 시작 때까지 준비돼 있어야 한다 — 그만큼 거꾸로 당긴다
                earliest = max(0, s.start - leadUp(to: step, in: chain))
            }

            var start = max(earliest, cursor ?? earliest)
            var end: Int

            if let finished = state.doneAt[step.id] {
                start = state.startedAt[step.id] ?? max(0, finished - step.duration)
                end = finished
            } else if let began = state.startedAt[step.id] {
                start = began
                // 냄비는 제 시간에 끝나고, 사람이 하는 동작은 내가 끝냈다고 할 때까지 이어진다
                end = step.role == .cook ? began + step.duration
                                         : max(began + step.duration, now)
            } else {
                start = max(start, now)
                end = start + step.duration
            }

            out[step.id] = Span(start: start, end: end)
            cursor = end
        }
        return out
    }

    /// step부터 시작해, 자기 트리거를 따로 가진 일이 나오기 전까지의 길이
    /// (소스가 면 건지기 전에 다 돼 있어야 하듯, 사슬 앞머리를 통째로 당길 때 쓴다)
    private static func leadUp(to step: RecipeStep, in chain: [RecipeStep]) -> Int {
        guard let from = chain.firstIndex(where: { $0.id == step.id }) else { return step.duration }
        var total = step.duration
        // 뒤따르는 일들은 기본(.atStart = 앞의 것에 이어서)인 동안만 함께 당긴다.
        // 제 트리거를 따로 가진 일(예: 면 건진 뒤 유화)부터는 그쪽 기준으로 잡힌다.
        for item in chain[(from + 1)...] {
            guard case .atStart = item.trigger else { break }
            total += item.duration
        }
        return total
    }
}

// MARK: - 진행 중인 작업의 상태

enum StepStatus {
    case upcoming   // 아직
    case active     // 지금
    case done       // 끝
}
