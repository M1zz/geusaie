//
//  GeusaieWatchApp.swift
//  GeusaieWatch
//
//  손목 위 한 화면: 지금 할 일 하나 · 냄비마다 남은 시간 · [다음 단계] 한 동작.
//  요리는 아이폰에서 시작하고, 손이 젖어 폰을 못 만질 때 손목으로 넘긴다.
//  [다음 단계] 는 화면 버튼 · 두 번 두드리기 · 동작 버튼(→ NextStepIntent) · 냄비 알림의 버튼 어디서나 같다.
//

import SwiftUI
import WatchKit
import UserNotifications

@main
struct GeusaieWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate

    var body: some Scene {
        WindowGroup {
            WatchCookView(link: .shared)
        }
        // 아이폰이 컴플리케이션을 깨우면 앱이 잠깐 깨어 새 장을 받고 컴플리케이션 · 알림을 맞춘다
        .backgroundTask(.watchConnectivity) { await WatchLink.shared.drain() }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let next = UNNotificationAction(identifier: CookLink.nextAction,
                                        title: String(localized: "다음 단계"), options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: CookLink.category, actions: [next], intentIdentifiers: [])
        ])
        // 스크린샷용 데모에서는 권한 창이 화면을 가리지 않게 묻지 않는다
        #if DEBUG
        let demo = WatchDemo.snapshot != nil
        #else
        let demo = false
        #endif
        if !demo { center.requestAuthorization(options: [.alert, .sound]) { _, _ in } }
        Task { @MainActor in WatchLink.shared.activate() }
    }

    /// 앱을 보고 있을 때 냄비가 끝나도 알림 · 진동은 그대로 온다
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }

    /// 알림의 [다음 단계] — 앱을 열지 않고 넘긴다
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == CookLink.nextAction,
              let step = response.notification.request.content.userInfo[CookLink.stepInfoKey] as? String
        else { return }
        await WatchLink.shared.sendNext(step)
    }
}

// MARK: - 한 화면

struct WatchCookView: View {
    @ObservedObject var link: WatchLink

    var body: some View {
        NavigationStack {
            if let snapshot = link.snapshot {
                cooking(snapshot)
            } else {
                waiting
            }
        }
    }

    private func cooking(_ s: CookSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // 지금 할 일 하나
                Text(s.nowTitle)
                    .font(.headline)
                    .foregroundStyle(s.nowUrgent ? WatchTheme.accent : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if !s.running {
                    Label("일시정지됨", systemImage: "pause.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(s.pots) { pot in
                    PotRow(pot: pot, running: s.running)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(s.recipe)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let step = s.nowStepID, s.running {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    NextButton(disabled: link.sending == step) {
                        Task { await link.sendNext(step) }
                    }
                    Spacer()
                }
            }
        }
    }

    private var waiting: some View {
        VStack(spacing: 8) {
            Image(systemName: "frying.pan")
                .font(.title)
                .foregroundStyle(WatchTheme.accent)
            Text("아이폰에서 요리를 시작하면 냄비마다 남은 시간이 여기 보여요")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .navigationTitle("그사이에")
    }
}

/// 냄비 한 줄 — 이름 · 상태, 그리고 남은 시간을 크게
struct PotRow: View {
    let pot: CookSnapshot.Pot
    let running: Bool

    var body: some View {
        let color = WatchTheme.dish(pot.colorIndex)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(pot.lane).font(.caption2.weight(.bold)).foregroundStyle(color)
            }
            Text(pot.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let end = pot.endsAt, running, end > .now {
                Text(timerInterval: Date.now...end, countsDown: true)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
            } else if !running, pot.remaining > 0 {
                Text(Duration.seconds(pot.remaining), format: .time(pattern: .minuteSecond))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// [다음 단계] — 젖은 손이면 손가락 두 번 두드리기로도 누른다
struct NextButton: View {
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        let button = Button(action: action) {
            Label("다음 단계", systemImage: "arrow.right")
        }
        .tint(WatchTheme.accent)
        .disabled(disabled)
        if #available(watchOS 11.0, *) {
            button.handGestureShortcut(.primaryAction)
        } else {
            button
        }
    }
}
