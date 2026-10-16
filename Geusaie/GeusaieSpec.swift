//
//  GeusaieSpec.swift
//  Geusaie
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//  피드백·리뷰·진단 구현은 전부 LeeoKit 에 있고, 앱은 이 설정만 제공한다.
//
//  ⚠️ recordType/구독 ID는 CloudKit Dashboard·기존 사용자 기기와의 계약이다 — 변경 금지.
//

import Foundation
import LeeoKit

enum GeusaieSpec: LeeoAppSpec {
    static let appName = "그사이에"
    static let developerEmail = "leeo@kakao.com"

    /// 공용 피드백 허브(FeedbackHub)로 수집 — appIdentifier(번들 ID)로 앱을 구분한다.
    /// 컨테이너 권한은 Geusaie.entitlements 에 있다 — 빼면 CKContainer 를 만드는 순간 앱이 죽는다.
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.leeo.geusaie"
    )

    /// 개인정보·지원 페이지 (LeeoKit 3.x 부터 필수). README.md 에 적힌 주소를 그대로 쓴다.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/geusaie/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/geusaie/support.html")!,
        marketingURL: URL(string: "https://m1zz.github.io/geusaie/")!
    )

    /// 수익모델 (LeeoKit 3.x 부터 필수) — 인앱 결제가 없는 무료 앱.
    static let monetization = LeeoMonetization.free

    /// 익명 사용 통계 → FeedbackHub(CloudKit). 기본값(Noop)이면 부트스트랩이 아무것도 보내지 않는다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: GeusaieSpec.self)
}
