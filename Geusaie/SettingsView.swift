import SwiftUI
import UIKit
import LeeoKit

// MARK: - 설정 — 지원 · 문의
//
// 이 앱의 설정은 조리 화면 안에 있다(글자 크기·마이크). 여기는 앱 밖으로 나가는 길만 모은다:
// 의견 보내기 · 리뷰 · 메일 · 인스타그램 · 정책 링크, 그리고 첫 실행 안내 다시 보기.

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                Section("지원") {
                    LeeoSupportSection<GeusaieSpec>()
                    // 앞으로 만들 기능 — 원본은 GeusaieRoadmap.swift
                    NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }
                    // 친구에게 소개하기 — App Store ID 가 없으면 그리지 않는다
                    LeeoShareAppLink<GeusaieSpec>()
                    // 개발자 응원하기 — 판매 중인 팁이 있어야 선다 (→ GeusaieTipJar.swift)
                    LeeoTipJarLink<GeusaieSpec>(tipJar: GeusaieSpec.tipJar)
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
                    Button("닫기") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                GeusaieOnboardingView()
            }
        }
        .tint(Theme.terracotta)
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
