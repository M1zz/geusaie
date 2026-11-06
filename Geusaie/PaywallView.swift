//
//  PaywallView.swift
//  Geusaie
//
//  그사이에의 두 칸(무료 · Pro)을 파는 한 장.
//  머리말 → (막힌 까닭과 그 요리의 순서표) → Pro 칸 → 무료 칸 → 비교표 → 약관.
//
//  **무료인 것을 먼저 말한다.** 파스타 두 접시와 조리 화면은 언제나 무료이고, 값을 받는 것은 새 요리뿐이다.
//  Pro 는 연 구독과 평생을 먼저 보이고, 주 · 월 구독은 펼쳐서 고른다.
//  첫 해 할인(App Store 첫 구독 할인)은 연 구독을 고르면 처음 보는 사람에게만 한 줄로 보인다.
//  스토어에서 불러오지 못한 상품의 단추는 서지 않는다.
//

import SwiftUI
import StoreKit
import LeeoKit

struct PaywallView: View {
    /// 어디서 들어왔는가. 막힌 까닭을 먼저 말한다.
    var highlight: GeusaieFeature?
    /// 잠긴 팩 요리를 눌러 들어왔으면 그 요리. 순서표를 미리 보여 준다.
    var preview: Recipe?

    @State private var purchases = Purchases.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// 결제 시트를 이 페이월이 떠 있는 창에 띄운다 (→ Purchases.purchase).
    @Environment(\.purchase) private var purchaseAction

    @State private var term: PlanTerm = .yearly
    @State private var loadingProducts = true
    @State private var redeemingCode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let highlight { reason(highlight) }
                    plansStatus
                    proCard
                    freeCard
                    PlanComparisonTable()
                    if let message = purchases.failureMessage, !purchases.products.isEmpty {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.brick)
                    }
                    legal
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // 세로로 서는 툴바(아이폰 듀오)에서는 아이콘 없는 아이템이 사라진다.
                    Button { dismiss() } label: { Label("나중에", systemImage: "xmark") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await purchases.restore()
                            if purchases.isPro { dismiss() }
                        }
                    } label: {
                        Label("구매 복원", systemImage: "arrow.clockwise")
                    }
                    .disabled(purchases.isWorking)
                }
            }
            .offerCodeRedemption(isPresented: $redeemingCode) { _ in
                Task {
                    await purchases.refresh()
                    if purchases.isPro { dismiss() }
                }
            }
            .task {
                LeeoAnalyticsCenter.track(.paywallShown(reason: highlight?.rawValue ?? "settings"))
                await loadPlans()
            }
        }
        .tint(Theme.terracotta)
    }

    // MARK: 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("그사이에 Pro")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("파스타 두 접시는 언제나 무료예요. 더 많은 요리를 연 구독이나 평생으로 여세요.")
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 막힌 자리에서 들어왔을 때 첫 줄. 무엇이 막혔고, 하던 것은 어떻게 되는지.
    private func reason(_ feature: GeusaieFeature) -> some View {
        let (title, note): (String, String) = switch feature {
        case .packs:
            (String(localized: "레시피 팩은 Pro에서 열려요"),
             String(localized: "찌개와 반찬도 냄비마다 시간과 순서를 잡아, 늘 한쪽이 식던 두 가지를 함께 끝내요."))
        case .siri:
            (String(localized: "Siri · 단축어는 Pro에서 열려요"),
             String(localized: "요리는 그대로 열어 두었어요. Pro면 손에 밀가루가 묻어 있어도 말로 레시피를 바로 열어요."))
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(Theme.ink)
            Text(note)
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let preview { RecipeSneakPeek(recipe: preview) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.terracotta.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: 칸 카드

    private var proCard: some View {
        card(highlighted: highlight != nil && !purchases.isPro) {
            cardTitle(String(localized: "그사이에 Pro"), current: purchases.isPro)
            tagline(String(localized: "파스타 다음 요리도 같은 방식으로."))
            row("checkmark.circle", "무료의 모든 것")
            ForEach(RecipeDB.packs) { pack in
                row("square.stack.3d.up",
                    LocalizedStringKey("레시피 팩 · \(pack.name): \(pack.recipes.map(\.name).joined(separator: " · "))"))
            }
            row("sparkles", "앞으로 나올 레시피 팩도 함께")
            row("mic.badge.plus", "Siri · 단축어로 레시피 바로 열기")
            // 이미 Pro 면 살 것이 없다. 구독을 평생으로 바꾸는 길은 설정에 있다.
            if !purchases.isPro, hasAnyProduct {
                PlanTermPicker(term: $term, products: products)
                    .padding(.top, 4)
                buyButton
            }
        }
    }

    private var freeCard: some View {
        card(highlighted: false) {
            cardTitle(String(localized: "무료"), current: !purchases.isPro)
            tagline(String(localized: "면이 익는 그사이에 소스까지, 지금 담긴 레시피 전부 무료."))
        }
    }

    private var products: PlanTermPicker.Products {
        typealias P = GeusaieProducts
        return .init(weekly: purchases.product(P.weeklyID), monthly: purchases.product(P.monthlyID),
                     yearly: purchases.product(P.yearlyID), lifetime: purchases.product(P.lifetimeID))
    }

    private var hasAnyProduct: Bool { PlanTerm.allCases.contains { products[$0] != nil } }

    private var buyButton: some View {
        let product = products[term]
        let title: String = switch term {
        case .weekly:   String(localized: "주 구독 시작")
        case .monthly:  String(localized: "월 구독 시작")
        case .yearly:   String(localized: "연 구독 시작")
        case .lifetime: String(localized: "평생으로 사기")
        }
        return Button {
            guard let product else { return }
            Task {
                await purchases.purchase(product, using: purchaseAction)
                if purchases.isPro { dismiss() }
            }
        } label: {
            Group {
                if purchases.isWorking {
                    ProgressView().tint(Theme.onAccent)
                } else {
                    Text(title).font(.body.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(FilledButton(tint: Theme.terracotta))
        .disabled(purchases.isWorking || product == nil)
        .accessibilityLabel(title)
    }

    // MARK: 요금제를 못 불러왔을 때

    @ViewBuilder
    private var plansStatus: some View {
        if purchases.products.isEmpty && loadingProducts {
            HStack(spacing: 10) {
                ProgressView()
                Text("값을 불러오는 중…").foregroundStyle(Theme.inkSoft)
            }
        } else if purchases.products.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("요금제를 불러오지 못했어요. 인터넷 연결을 확인하고 다시 불러와 주세요.")
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await loadPlans() }
                } label: {
                    Label("다시 불러오기", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// 첫 조회가 빈손이면 한 번 더 청한다. 샌드박스(심사 환경)는 첫 조회가 비어 오는 일이 잦다.
    private func loadPlans() async {
        loadingProducts = true
        await purchases.loadProducts()
        if purchases.products.isEmpty {
            try? await Task.sleep(for: .seconds(1.5))
            await purchases.loadProducts()
        }
        loadingProducts = false
    }

    // MARK: 약관 (구독을 파는 앱의 심사 필수 항목)

    private var legal: some View {
        VStack(alignment: .leading, spacing: 10) {
            if purchases.products.contains(where: { $0.subscription != nil }) {
                Text("구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 요금으로 자동 갱신되며, Apple 계정으로 결제돼요. 연 구독을 처음 시작하면 첫 해는 할인된 값일 수 있고, 그 뒤에는 정가로 갱신돼요. 해지와 관리는 App Store 계정 설정에서 해요. 평생은 구독이 아니라 한 번 결제예요. 가족 공유로 가족도 함께 써요.")
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits {
                HStack(spacing: 18) { legalLinks }
                VStack(alignment: .leading, spacing: 10) { legalLinks }
            }
        }
    }

    @ViewBuilder
    private var legalLinks: some View {
        if let terms = GeusaieSpec.monetization.subscriptionTermsURL {
            Button("이용약관") { openURL(terms) }
        }
        Button("개인정보 처리방침") { openURL(GeusaieSpec.legal.privacyURL) }
        Button {
            redeemingCode = true
        } label: {
            Label("코드 사용", systemImage: "ticket")
        }
        .disabled(purchases.isWorking)
    }

    // MARK: 부속

    private func card<Content: View>(highlighted: Bool, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(Theme.card)
                shape.strokeBorder(highlighted ? Theme.terracotta : Theme.cardBorder, lineWidth: highlighted ? 2 : 1)
            }
    }

    private func cardTitle(_ title: String, current: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            if current {
                Text("지금 쓰는 칸")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.terracotta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.terracotta.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private func tagline(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ icon: String, _ title: LocalizedStringKey) -> some View {
        Label {
            Text(title).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.terracotta)
        }
        .font(.body)
    }
}

// MARK: - 잠긴 요리의 순서표 미리보기
//
// 늘 한쪽이 식거나 넘치던 두 가지가 어떻게 함께 끝나는지. 냄비마다 한 줄, 요리 전체를 한 폭에 그린다.
// 시작 전 계획만 계산한다 — 시계도 알림도 돌지 않는다.

private struct RecipeSneakPeek: View {
    let recipe: Recipe

    var body: some View {
        let plan = recipe.previewPlan
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "\(recipe.emoji) \(recipe.name)")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("약 \(Int((Double(recipe.estimatedSeconds) / 60).rounded()))분 · 냄비 \(recipe.potCount)개")
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
            ForEach(recipe.potLanes, id: \.self) { lane in
                VStack(alignment: .leading, spacing: 4) {
                    Text(lane).font(.body.weight(.semibold)).foregroundStyle(recipe.color(for: lane))
                    GeometryReader { geo in
                        let scale = geo.size.width / CGFloat(max(plan.total, 1))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.ringTrack)
                            ForEach(recipe.rowSteps(lane)) { step in
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(recipe.color(for: lane).opacity(step.role == .cook ? 0.45 : 1))
                                    .frame(width: max(3, CGFloat(plan.end(step) - plan.start(step)) * scale - 1))
                                    .offset(x: CGFloat(plan.start(step)) * scale)
                            }
                        }
                    }
                    .frame(height: 14)
                }
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 주 · 월 · 연 · 평생

enum PlanTerm: CaseIterable {
    case weekly, monthly, yearly, lifetime
}

/// Pro 를 사는 길 고르기. 연 구독 · 평생을 먼저 보이고, 주 · 월은 펼쳐서 고른다.
struct PlanTermPicker: View {
    struct Products {
        var weekly, monthly, yearly, lifetime: Product?

        subscript(term: PlanTerm) -> Product? {
            switch term {
            case .weekly: weekly
            case .monthly: monthly
            case .yearly: yearly
            case .lifetime: lifetime
            }
        }
    }

    @Binding var term: PlanTerm
    let products: Products
    @State private var showsShortTerms = false
    @State private var introEligible = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            options(.yearly, .lifetime)
            if hasShortTerms {
                if showsShortTerms || term == .weekly || term == .monthly {
                    options(.weekly, .monthly)
                } else {
                    Button("주 · 월 구독도 보기") { showsShortTerms = true }
                        .font(.body)
                }
            }
            if let note {
                Text(note)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            // 연 구독을 못 불러왔으면 고를 수 있는 첫 길로 옮긴다.
            if products[term] == nil,
               let first = [PlanTerm.yearly, .lifetime, .monthly, .weekly].first(where: { products[$0] != nil }) {
                term = first
            }
        }
        .task(id: products.yearly?.id) {
            introEligible = await products.yearly?.subscription?.isEligibleForIntroOffer ?? false
        }
    }

    private var hasShortTerms: Bool { products.weekly != nil || products.monthly != nil }

    /// 아주 큰 글자에서는 위아래로 세운다. 나란히 두면 가격이 몇 줄로 꺾인다.
    private func options(_ a: PlanTerm, _ b: PlanTerm) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            option(a)
            option(b)
        }
    }

    private var note: String? {
        switch term {
        case .yearly:
            guard introEligible, let offer = products.yearly?.subscription?.introductoryOffer,
                  offer.paymentMode == .payUpFront || offer.paymentMode == .payAsYouGo else { return nil }
            return String(format: LeeoLadderText.introFormat, offer.displayPrice)
        case .lifetime:
            guard let yearly = products.yearly?.price, let lifetime = products.lifetime?.price, yearly > 0 else { return nil }
            let years = Int(NSDecimalNumber(decimal: lifetime / yearly).doubleValue.rounded(.down))
            return years >= 2 ? String(format: LeeoLadderText.lifetimeWorthFormat, years) : nil
        case .weekly, .monthly:
            return nil
        }
    }

    private func title(_ term: PlanTerm) -> String {
        switch term {
        case .weekly: String(localized: "주 구독")
        case .monthly: String(localized: "월 구독")
        case .yearly: LeeoLadderText.yearly
        case .lifetime: LeeoLadderText.lifetime
        }
    }

    private func price(_ term: PlanTerm) -> String? {
        guard let price = products[term]?.displayPrice else { return nil }
        switch term {
        case .weekly: return String(localized: "\(price) / 주")
        case .monthly: return String(localized: "\(price) / 월")
        case .yearly: return String(format: LeeoLadderText.perYearFormat, price)
        case .lifetime: return price
        }
    }

    @ViewBuilder
    private func option(_ value: PlanTerm) -> some View {
        if let price = price(value) {
            let selected = term == value
            Button {
                term = value
            } label: {
                VStack(spacing: 2) {
                    Text(title(value)).font(.body.weight(.semibold))
                    Text(price).font(.body).monospacedDigit()
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(selected ? Theme.terracotta : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? Theme.terracotta.opacity(0.12) : Theme.cream)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(selected ? Theme.terracotta : Theme.cardBorder, lineWidth: selected ? 1.5 : 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

// MARK: - 비교표

/// 두 칸이 무엇을 주는지 한눈에. 아주 큰 글자에서는 기능마다 두 칸을 아래로 적는다.
struct PlanComparisonTable: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Line: Identifiable {
        let title: String
        let free: Bool
        var id: String { title }
    }

    private var lines: [Line] {[
        Line(title: String(localized: "기본 레시피 2개"), free: true),
        Line(title: String(localized: "조리 계획 · 타임라인 · 알림"), free: true),
        Line(title: String(localized: "말로 넘기기"), free: true),
        Line(title: String(localized: "글자 크기 네 단계"), free: true),
        Line(title: String(localized: "레시피 팩"), free: false),
        Line(title: String(localized: "Siri · 단축어"), free: false),
    ]}

    private var freeTitle: String { String(localized: "무료") }
    private let proTitle = "Pro"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("한눈에 비교")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize {
                ForEach(lines) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.title).font(.body.weight(.semibold))
                        HStack { Text(freeTitle); Spacer(); mark(line.free, in: freeTitle) }
                        HStack { Text(proTitle); Spacer(); mark(true, in: proTitle) }
                    }
                    Divider()
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Color.clear.frame(height: 1).gridCellUnsizedAxes([.horizontal, .vertical])
                        Text(freeTitle).font(.body.weight(.semibold)).gridColumnAlignment(.center)
                        Text(proTitle).font(.body.weight(.semibold)).gridColumnAlignment(.center)
                    }
                    ForEach(lines) { line in
                        Divider()
                        GridRow {
                            Text(line.title).font(.body).fixedSize(horizontal: false, vertical: true)
                            mark(line.free, in: freeTitle)
                            mark(true, in: proTitle)
                        }
                    }
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// 칸 하나. VoiceOver 는 어느 칸인지 함께 읽는다 ("Pro: 포함").
    @ViewBuilder
    private func mark(_ included: Bool, in tier: String) -> some View {
        if included {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.green)
                .accessibilityLabel(Text(verbatim: "\(tier): \(String(localized: "포함"))"))
        } else {
            Image(systemName: "minus")
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
                .accessibilityLabel(Text(verbatim: "\(tier): \(String(localized: "포함 안 됨"))"))
        }
    }
}
