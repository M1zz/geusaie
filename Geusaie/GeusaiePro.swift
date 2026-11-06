//
//  GeusaiePro.swift
//  Geusaie
//
//  그사이에 Pro 를 파는 자리. 칸은 둘이다 — 무료 · Pro.
//
//   · 무료: 지금 담긴 레시피 전부(알리오 올리오 · 토마토 크림 파스타), 조리 화면 · 냄비 시간 · 알림,
//           말로 넘기기, 글자 크기 네 단계. **앞으로도 무료다.**
//   · Pro:  레시피 팩(→ RecipeDB.packs), Siri · 단축어로 레시피 바로 열기.
//
//  ⚠️ 절대 잠그지 않는 것: 접근성(VoiceOver · 글자 크기 · 대비), 안전 경고(마감 · 알림), 이미 연 요리의 조리 화면.
//
//  상품 로드 · 구매 · 복원 · 거래 리스너(다른 기기, 가족 공유, 환불, 구독 만료) · 팁은 전부 `LeeoStore` 안에 있다.
//  이 클래스는 그 값을 SwiftUI `@Observable` 로 옮겨 적고, "Pro 인가" 하나로 줄여 줄 뿐이다.
//

import Foundation
import Combine
import StoreKit
import SwiftUI
import LeeoKit

/// 값을 받고 여는 것. 페이월 · 설정 · 잠금 자리가 모두 이 목록만 읽는다.
enum GeusaieFeature: String, Identifiable, CaseIterable {
    /// 레시피 팩 (→ RecipeDB.packs)
    case packs
    /// Siri · 단축어로 레시피 바로 열기 (→ OpenRecipeIntent)
    case siri

    var id: String { rawValue }
}

enum GeusaieProducts {

    // MARK: - 상품 ID
    //
    // ⚠️ App Store Connect · Products.storekit 과 글자 하나까지 같아야 한다.
    //    주 · 월 · 연 구독 셋은 한 구독 그룹("그사이에")에 넣는다.

    private static let base = "com.leeo.geusaie"

    static let weeklyID   = base + ".pro.weekly"
    static let monthlyID  = base + ".pro.monthly"
    static let yearlyID   = base + ".pro.yearly"
    static let lifetimeID = base + ".pro.lifetime"
    /// 구독 중인 사람의 졸업가 Pro 평생 (→ LeeoGraduation).
    static let graduateID = base + ".pro.graduate"

    /// 개발자 응원 팁. 아무것도 열지 않는다 — `productIDs` 에 넣지 않는다.
    static let tipProductIDs = [base + ".tip.small", base + ".tip.medium", base + ".tip.large"]

    /// 페이월이 불러올 상품이자 Pro 를 여는 상품. 스토어에 아직 없는 상품은 불러와지지 않고, 그 단추는 서지 않는다.
    static let productIDs = [weeklyID, monthlyID, yearlyID, lifetimeID, graduateID]

    /// 자동 갱신 구독 (구독 졸업을 제안할 대상).
    static let subscriptionIDs: Set<String> = [weeklyID, monthlyID, yearlyID]

    /// 끝나지 않는 Pro.
    static let lifetimeIDs: Set<String> = [lifetimeID, graduateID]

    // MARK: - 먼저 쓰던 사람

    /// 페이월이 생기기 전 마지막 빌드(1.1.0 빌드 9). 그때까지 받은 사람은 Pro 평생처럼 쓴다 —
    /// 첫 레시피 팩을 선물처럼 받고, 쓰던 Siri · 단축어도 그대로다.
    /// ⚠️ 페이월이 든 빌드의 번호는 이보다 커야 한다.
    static let lastBuildBeforePaywall = 9

    /// App Store 에서 처음 받은 빌드가 페이월 전인가.
    /// `originalAppVersion` 은 iOS 에서 빌드 번호다. 샌드박스 · Xcode 는 늘 "1.0" 을 돌려주므로 실제 App Store 만 본다.
    static func isEarlyCook() async -> Bool {
        guard case .verified(let app)? = try? await AppTransaction.shared,
              app.environment == .production,
              let build = Int(app.originalAppVersion.split(separator: ".").first ?? "") else { return false }
        return build <= lastBuildBeforePaywall
    }
}

@MainActor
@Observable
final class Purchases {

    static let shared = Purchases()

    @ObservationIgnored let store: LeeoStore

    /// Pro 인가. 화면은 이 값(과 `allows`)만 본다. 마지막으로 알던 답으로 시작한다(LeeoStore 캐시).
    private(set) var isPro: Bool

    private(set) var products: [Product] = []
    private(set) var ownedProductIDs: Set<String> = []

    /// 지금 살아 있는 구독. 있으면 설정에 '평생으로 바꾸기' 가 선다.
    private(set) var subscription: LeeoGraduation.Subscription?

    private(set) var isWorking = false

    /// 사다가 막혔을 때 그대로 보여 줄 말.
    private(set) var failureMessage: String?

    /// **팔기 시작했는가.** Pro 상품을 하나도 못 불러온 기기는 아무것도 잠그지 않는다.
    ///
    /// ⚠️ App Store Connect 에 상품이 서기 전에 빌드가 나가면, 살 수 없는데 막히는 사람이 생긴다.
    ///    한 번이라도 불러온 기기는 기억해 둔다 — 그 뒤로 잠깐 오프라인이어도 다시 잠근다.
    private(set) var isSelling = UserDefaults.standard.bool(forKey: Purchases.onSaleKey)

    private static let onSaleKey = "plans.onSale"

    @ObservationIgnored private var observation: AnyCancellable?

    private init() {
        guard let config = GeusaieSpec.paywall else {
            preconditionFailure("계약에 페이월이 없다. GeusaieSpec.monetization 을 확인할 것")
        }
        store = LeeoStore(config: config, grandfather: { await GeusaieProducts.isEarlyCook() })
        isPro = store.hasPro
        // objectWillChange 는 바뀌기 **직전**에 온다. 다음 차례로 미뤄 읽는다.
        observation = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.pull() }
        }
    }

    /// 팁(응원). 기능을 열지 않는다.
    var tipJar: LeeoTipJar {
        guard let tipJar = store.tipJar else { preconditionFailure("계약에 팁이 없다") }
        return tipJar
    }

    func allows(_ feature: GeusaieFeature) -> Bool { isPro || !isSelling }

    /// 이 요리를 열 수 있는가. 지금 담긴 두 레시피는 늘 열린다.
    func allows(_ recipe: Recipe) -> Bool { isPro || !isSelling || !RecipeDB.isInPack(recipe) }

    var ownsLifetime: Bool { !ownedProductIDs.isDisjoint(with: GeusaieProducts.lifetimeIDs) || store.isGrandfathered }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    // MARK: - 상태 맞추기

    /// 영수증을 다시 읽는다. 앱이 켜질 때와 앞으로 나올 때마다 부른다.
    func refresh() async {
        await store.refreshEntitlements()
        await store.loadProducts()
        subscription = await LeeoGraduation.currentSubscription(among: GeusaieProducts.subscriptionIDs)
        pull()
    }

    /// 영수증만 다시 읽는다 (상품은 부르지 않는다). 단축어로 켜진 순간처럼 빨리 답해야 할 때.
    func refreshEntitlements() async {
        await store.refreshEntitlements()
        pull()
    }

    func loadProducts() async {
        await store.loadProducts()
        pull()
    }

    /// 구독 졸업을 제안할 때인가. 6개월째와 갱신 7일 전에 한 번씩.
    var graduationIsDue: Bool {
        guard let subscription, product(GeusaieProducts.graduateID) != nil, !ownsLifetime else { return false }
        return LeeoGraduation.isDue(subscription, lastOffered: LeeoGraduation.lastOffered())
    }

    func markGraduationOffered() { LeeoGraduation.markOffered() }

    // MARK: - 사기 / 되찾기

    /// ⚠️ `action` 은 화면의 `@Environment(\.purchase)` 다. 아이패드에서 결제 시트가 엉뚱한 창에 뜨지 않게.
    func purchase(_ product: Product, using action: PurchaseAction) async {
        _ = await store.purchase(product) { try await action($0) }
        subscription = await LeeoGraduation.currentSubscription(among: GeusaieProducts.subscriptionIDs)
        pull()
    }

    func restore() async {
        await store.restore()
        pull()
        if !isPro, failureMessage == nil {
            failureMessage = String(localized: "이 Apple 계정에서 산 기록을 찾지 못했어요.")
        }
    }

    // MARK: -

    private func pull() {
        isPro = store.hasPro
        products = store.products
        ownedProductIDs = store.purchasedProductIDs
        isWorking = store.purchasingProductID != nil || store.isRestoring
        failureMessage = store.lastError
        if !isSelling, products.contains(where: { GeusaieProducts.productIDs.contains($0.id) }) {
            UserDefaults.standard.set(true, forKey: Self.onSaleKey)
            isSelling = true
        }
    }
}
