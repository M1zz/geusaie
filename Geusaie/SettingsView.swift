import SwiftUI
import UIKit
import StoreKit
import LeeoKit

// MARK: - 설정 — 그사이에 Pro · 지원 · 문의
//
// 이 앱의 설정은 조리 화면 안에 있다(글자 크기·마이크). 여기는 그사이에 Pro(구독 관리 · 평생으로 바꾸기 · 복원)와
// 앱 밖으로 나가는 길을 모은다: 의견 보내기 · 리뷰 · 메일 · 인스타그램 · 정책 링크, 그리고 첫 실행 안내 다시 보기.

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showOnboarding = false
    @State private var purchases = Purchases.shared
    @State private var showsPaywall = false
    @State private var showsGraduation = false
    @State private var showsManageSubscription = false

    var body: some View {
        NavigationStack {
            List {
                proSection

                Section("지원") {
                    LeeoSupportSection<GeusaieSpec>()
                    // 앞으로 만들 기능 — 원본은 GeusaieRoadmap.swift
                    NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }
                    // 친구에게 소개하기 — App Store ID 가 없으면 그리지 않는다
                    LeeoShareAppLink<GeusaieSpec>()
                    // 개발자 응원하기 — 판매 중인 팁이 있어야 선다. 아무것도 열지 않는다 (→ GeusaieTipJar.swift)
                    LeeoTipJarLink<GeusaieSpec>(tipJar: purchases.tipJar)
                }

                Section {
                    Button { openURL(Self.mailURL) } label: {
                        Label("메일로 문의하기", systemImage: "envelope")
                    }
                    Link(destination: URL(string: "https://instagram.com/lee25_ios")!) {
                        Label("인스타그램", systemImage: "camera")
                    }
                } header: {
                    Text("문의")
                } footer: {
                    Text(GeusaieSpec.developerEmail)
                }

                Section("도움말") {
                    Button { showOnboarding = true } label: {
                        Label("사용 방법 다시 보기", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // 세로로 서는 툴바(아이폰 듀오)에서는 아이콘 없는 아이템이 사라진다.
                    Button { dismiss() } label: { Label("닫기", systemImage: "xmark") }
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                GeusaieOnboardingView().foldConfined()
            }
            .manageSubscriptionsSheet(isPresented: $showsManageSubscription)
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .sheet(isPresented: $showsGraduation) {
                LeeoGraduationOfferView(graduate: purchases.product(GeusaieProducts.graduateID)) {
                    await purchases.refresh()
                }
            }
            .task { await purchases.refresh() }
        }
        .tint(Theme.terracotta)
    }

    // MARK: - 그사이에 Pro

    private var proSection: some View {
        Section {
            if purchases.isPro {
                Label {
                    Text("그사이에 Pro 사용 중")
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.green)
                }
            } else {
                Button {
                    showsPaywall = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("그사이에 Pro")
                            .font(.body.weight(.semibold))
                        Text("레시피 팩, Siri · 단축어로 바로 열기")
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            // 구독 중인 사람에게는 늘 평생으로 바꾸는 길이 있다.
            if purchases.subscription != nil {
                Button(LeeoLadderText.manageSubscription) { showsManageSubscription = true }
                if purchases.product(GeusaieProducts.graduateID) != nil, !purchases.ownsLifetime {
                    Button(LeeoLadderText.switchToLifetimeEntry) { showsGraduation = true }
                }
            }
            Button("구매 복원") {
                Task { await purchases.restore() }
            }
            .disabled(purchases.isWorking)
        } header: {
            Text("구독 관리")
        } footer: {
            if let message = purchases.failureMessage {
                Text(message)
            }
        }
    }

    /// 앱 버전과 기기를 미리 적어 둔 문의 메일 — 답을 빨리 드리려면 이 두 가지가 먼저 필요하다
    static var mailURL: URL {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let device = UIDevice.current
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = GeusaieSpec.developerEmail
        c.queryItems = [
            URLQueryItem(name: "subject", value: "[그사이에] 문의"),
            URLQueryItem(name: "body", value: "\n\n---\n그사이에 \(version) (\(build)) · \(device.model) · iOS \(device.systemVersion)"),
        ]
        return c.url ?? URL(string: "mailto:\(GeusaieSpec.developerEmail)")!
    }
}
