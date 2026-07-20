import SwiftUI

// MARK: - 레시피 = 병렬로 겹쳐 돌아가는 작업들의 타임라인
//
// 핵심 아이디어: "면 삶기"와 "소스 만들기"는 순서(먼저/나중)가 아니라
// 특정 구간에서 '동시에' 진행된다. 각 작업이 시작(startAt)·길이(duration)를
// 가지므로, 한 요리를 하나의 시간축 위에 여러 레인으로 펼칠 수 있다.

/// 그 작업이 사람 손을 얼마나 붙잡는가
enum Attention: String {
    case active   // 불 앞에서 계속 지켜봐야 함 (볶기 등)
    case passive  // 걸어두고 그사이에 다른 걸 해도 됨 (끓이기·졸이기)
    case instant  // 한 번의 동작 (면수 남기기·투입)

    var icon: String {
        switch self {
        case .active:  return "flame.fill"
        case .passive: return "hourglass"
        case .instant: return "hand.tap.fill"
        }
    }

    var label: String {
        switch self {
        case .active:  return "지켜보기"
        case .passive: return "그사이에 방치 OK"
        case .instant: return "한 번 동작"
        }
    }

    /// 사람 손을 붙잡는가 (손은 하나뿐 — hands 작업끼리는 겹칠 수 없다)
    var isHands: Bool { self != .passive }
}

struct RecipeStep: Identifiable, Hashable {
    let id: String
    var name: String
    var emoji: String
    var lane: String       // "면" · "소스" · "마무리"
    var startAt: Int       // 요리 시작 기준 초
    var duration: Int      // 작업 길이(초)
    var attention: Attention
    var tip: String?

    var end: Int { startAt + duration }
}

struct Recipe: Identifiable, Hashable {
    let id: String
    var name: String
    var emoji: String
    var subtitle: String
    var lanes: [String]        // 레인 표시 순서
    var steps: [RecipeStep]
    var source: String?        // 참고 레시피 출처

    var totalSeconds: Int { steps.map(\.end).max() ?? 0 }

    /// 두 개 이상의 작업이 실제로 겹치는 총 구간(초) — "병렬성"의 척도
    var overlapSeconds: Int {
        guard totalSeconds > 0 else { return 0 }
        var overlap = 0
        for t in stride(from: 0, to: totalSeconds, by: 5) {
            let active = steps.filter { $0.startAt <= t && t < $0.end }.count
            if active >= 2 { overlap += 5 }
        }
        return overlap
    }

    func laneIndex(_ lane: String) -> Int {
        lanes.firstIndex(of: lane) ?? 0
    }

    func color(for lane: String) -> Color {
        Theme.dishColor(laneIndex(lane))
    }

    /// 손 작업(hands)끼리 시간이 겹치는 쌍 — 있으면 안 됨(손은 하나).
    /// 레시피 데이터 검증용.
    var handsConflicts: [(RecipeStep, RecipeStep)] {
        let hands = steps.filter { $0.attention.isHands }.sorted { $0.startAt < $1.startAt }
        var out: [(RecipeStep, RecipeStep)] = []
        for i in hands.indices {
            for j in hands.index(after: i)..<hands.endIndex {
                if hands[i].end > hands[j].startAt { out.append((hands[i], hands[j])) }
            }
        }
        return out
    }
}

// MARK: - 진행 중인 작업의 상태

enum StepStatus {
    case upcoming   // 아직 시작 전
    case active     // 지금 진행 중
    case done       // 끝남
}
