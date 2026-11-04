//
//  CookSnapshot.swift
//  아이폰 · 워치 · 워치 컴플리케이션이 함께 쓰는 '지금 부엌' 한 장.
//
//  아이폰의 조리 세션이 바뀔 때마다 이 한 장을 워치로 보낸다. 글은 아이폰에서 이미 번역된 채로 온다.
//  냄비 시간은 '끝나는 시각'으로 담는다 — 폰이 멀어져도 워치가 혼자 세고, 혼자 알림을 울린다.
//

import Foundation

struct CookSnapshot: Codable, Equatable {
    struct Pot: Codable, Equatable, Identifiable {
        var lane: String            // "면냄비"
        var colorIndex: Int         // 아이폰 화면의 냄비 색 순서
        var text: String            // "면 삶는 중" · "비어 있음"
        var endsAt: Date?           // 냄비가 혼자 도는 중이면 끝나는 시각
        var remaining: Int          // 멈춰 있을 때 남은 초 (돌고 있으면 endsAt 으로 센다)
        var id: String { lane }
    }

    /// 냄비가 다 되는 순간의 알림. 아이폰과 같은 identifier 를 써서 두 기기에서 겹쳐 울리지 않게 한다.
    struct Alarm: Codable, Equatable {
        var id: String              // "cook-<단계 id>"
        var at: Date
        var title: String           // "💧 물 끓이기 다 됐어요"
        var body: String            // "⬇️ 끓으면 면 넣기 — 지금 하세요"
        var urgent: Bool            // 늦으면 상하는 일 — 집중 모드도 뚫는다
        var stepID: String?         // 알림의 [다음 단계] 가 끝낼 일
    }

    var recipe: String              // "🍝 알리오 올리오"
    var nowTitle: String            // "🍝 면 건지기" — 지금 할 일 하나
    var nowUrgent: Bool
    var nowStepID: String?          // [다음 단계] 가 끝낼 일. 없으면 넘길 게 없다(냄비만 기다리는 중)
    var running: Bool               // false 면 일시정지
    var pots: [Pot]
    var alarms: [Alarm]

    /// 가장 먼저 끝나는 냄비 — 컴플리케이션의 값
    func soonestPot(after date: Date = .now) -> Pot? {
        guard running else { return nil }
        return pots.filter { ($0.endsAt ?? .distantPast) > date }
            .min { ($0.endsAt ?? .distantFuture) < ($1.endsAt ?? .distantFuture) }
    }
}

// MARK: - 주고받는 말

enum CookLink {
    /// 아이폰 → 워치: 지금 부엌 (JSON). 요리가 끝나면 빈 Data.
    static let snapshotKey = "snapshot"
    /// 워치 → 아이폰: 이 일을 끝냈다. 값은 단계 id.
    static let nextKey = "next"
    /// 알림 묶음과 그 안의 [다음 단계] 버튼
    static let category = "COOK_STEP"
    static let nextAction = "NEXT_STEP"
    static let stepInfoKey = "stepID"

    static func encode(_ snapshot: CookSnapshot?) -> Data {
        guard let snapshot else { return Data() }
        return (try? JSONEncoder().encode(snapshot)) ?? Data()
    }

    static func decode(_ data: Data?) -> CookSnapshot? {
        guard let data, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(CookSnapshot.self, from: data)
    }
}
