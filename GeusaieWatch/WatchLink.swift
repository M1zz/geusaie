//
//  WatchLink.swift
//  아이폰과 잇는다. '지금 부엌' 을 받아 두고, [다음 단계] 를 보낸다.
//
//  받은 장마다 냄비가 끝나는 시각에 손목 알림을 건다 — 아이폰과 같은 identifier 라 두 기기에서 겹쳐 울리지 않고,
//  조리 중 아이폰 화면이 켜져 있어(앱이 앞에 있어 아이폰 알림이 손목으로 안 넘어올 때도) 손목이 울린다.
//

import Foundation
import WatchConnectivity
import UserNotifications
import WidgetKit
import WatchKit

@MainActor
final class WatchLink: NSObject, ObservableObject {
    static let shared = WatchLink()

    @Published private(set) var snapshot: CookSnapshot? = WatchStore.load()
    /// 방금 [다음 단계] 를 보낸 일 — 아이폰이 새 장을 보낼 때까지 버튼을 잠근다(두 번 눌림 방지)
    @Published private(set) var sending: String?

    func activate() {
        #if DEBUG
        if let demo = WatchDemo.snapshot { snapshot = demo; return }
        #endif
        guard WCSession.isSupported(), WCSession.default.activationState != .activated else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 백그라운드로 깨어났을 때 받을 것이 다 들어올 때까지 기다린다 (최대 몇 초)
    func drain() async {
        activate()
        for _ in 0..<25 where WCSession.default.hasContentPending {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    // MARK: 다음 단계

    /// '이 일을 끝냈다' 를 아이폰으로. 가까우면 바로, 멀면 가까워질 때 전해진다.
    func sendNext(_ stepID: String) async {
        guard sending != stepID else { return }
        sending = stepID
        WKInterfaceDevice.current().play(.click)
        activate()
        for _ in 0..<15 where WCSession.default.activationState != .activated {
            try? await Task.sleep(for: .milliseconds(200))
        }
        let message = [CookLink.nextKey: stepID]
        let wc = WCSession.default
        if wc.isReachable {
            wc.sendMessage(message, replyHandler: nil) { _ in wc.transferUserInfo(message) }
        } else {
            wc.transferUserInfo(message)
        }
        // 답이 안 오면 잠깐 뒤 버튼을 다시 연다
        try? await Task.sleep(for: .seconds(4))
        if sending == stepID { sending = nil }
    }

    // MARK: 받기

    fileprivate func receive(_ info: [String: Any]) {
        guard let data = info[CookLink.snapshotKey] as? Data else { return }
        let new = CookLink.decode(data)
        WatchStore.save(new)
        guard new != snapshot else { return }
        if new?.nowStepID != snapshot?.nowStepID { sending = nil }
        snapshot = new
        WidgetCenter.shared.reloadAllTimelines()
        scheduleAlarms(new?.alarms ?? [])
    }

    private func scheduleAlarms(_ alarms: [CookSnapshot.Alarm]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for alarm in alarms where alarm.at > .now.addingTimeInterval(1) {
            let c = UNMutableNotificationContent()
            c.title = alarm.title
            c.body = alarm.body
            c.sound = .default
            c.interruptionLevel = alarm.urgent ? .timeSensitive : .active
            if let step = alarm.stepID {
                c.categoryIdentifier = CookLink.category
                c.userInfo = [CookLink.stepInfoKey: step]
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: alarm.at.timeIntervalSinceNow, repeats: false)
            center.add(UNNotificationRequest(identifier: alarm.id, content: c, trigger: trigger))
        }
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in self.receive(context) }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        Task { @MainActor in self.receive(context) }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.receive(userInfo) }
    }
}
