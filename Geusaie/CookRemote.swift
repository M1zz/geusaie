//
//  CookRemote.swift
//  Geusaie
//
//  손을 쓰지 않고 넘기는 길 — Apple Watch 와 알림의 [다음 단계].
//
//  - 워치로: 조리 세션이 바뀔 때마다 '지금 부엌' 한 장(CookSnapshot)을 보낸다.
//    가장 먼저 끝나는 냄비가 바뀌면 컴플리케이션도 깨운다(하루 횟수가 정해져 있어 그때만).
//  - 워치에서: [다음 단계] · 동작 버튼 · 워치 알림의 버튼이 '이 일을 끝냈다'를 보낸다.
//  - 알림에서: 냄비가 다 됐다는 알림에 [다음 단계] 버튼이 붙는다. 잠긴 아이폰 · 손목 어디서 눌러도 여기로 온다.
//

import Foundation
import UserNotifications
import WatchConnectivity

@MainActor
final class CookRemote: NSObject {
    static let shared = CookRemote()

    /// 지금 요리 중인 세션 (홈 화면이 단다)
    weak var session: CookSession?

    /// 마지막으로 보낸 장. 바깥 nil = 아직 안 보냄, 안쪽 nil = '요리 안 하는 중'을 보냄
    private var lastSent: CookSnapshot??
    private var lastComplicationEnd: Date?

    /// 앱이 켜질 때 한 번. 알림 버튼은 앱이 꺼져 있다가 깨어날 때도 받아야 하므로 시작하자마자 단다.
    func activate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let next = UNNotificationAction(identifier: CookLink.nextAction,
                                        title: String(localized: "다음 단계"), options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: CookLink.category, actions: [next], intentIdentifiers: [])
        ])

        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 냄비 알림 한 통의 내용. 끝낼 일이 있으면 [다음 단계] 버튼을 붙인다.
    static func content(for alarm: CookSnapshot.Alarm) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = alarm.title
        c.body = alarm.body
        c.sound = .default
        c.interruptionLevel = alarm.urgent ? .timeSensitive : .active
        if let step = alarm.stepID {
            c.categoryIdentifier = CookLink.category
            c.userInfo = [CookLink.stepInfoKey: step]
        }
        return c
    }

    /// 지금 부엌을 워치로. 같은 장이면 보내지 않는다.
    func publish(_ snapshot: CookSnapshot?) {
        if let last = lastSent, last == snapshot { return }
        guard WCSession.isSupported() else { return }
        let wc = WCSession.default
        guard wc.activationState == .activated, wc.isPaired, wc.isWatchAppInstalled else { return }
        lastSent = .some(snapshot)

        let payload: [String: Any] = [CookLink.snapshotKey: CookLink.encode(snapshot)]
        try? wc.updateApplicationContext(payload)

        // 컴플리케이션은 '가장 먼저 끝나는 냄비'가 바뀔 때만 깨운다
        let soonest = snapshot?.soonestPot()?.endsAt
        if soonest != lastComplicationEnd, wc.isComplicationEnabled,
           wc.remainingComplicationUserInfoTransfers > 0 {
            lastComplicationEnd = soonest
            wc.transferCurrentComplicationUserInfo(payload)
        }
    }

    fileprivate func received(_ info: [String: Any]) {
        guard let step = info[CookLink.nextKey] as? String else { return }
        session?.complete(stepID: step)
    }
}

extension CookRemote: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in self.lastSent = nil; self.lastComplicationEnd = nil }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.lastSent = nil; self.lastComplicationEnd = nil }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.received(message) }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.received(userInfo) }
    }
}

extension CookRemote: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == CookLink.nextAction,
              let step = response.notification.request.content.userInfo[CookLink.stepInfoKey] as? String
        else { return }
        await MainActor.run { self.session?.complete(stepID: step) }
    }
}
