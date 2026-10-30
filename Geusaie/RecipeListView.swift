import SwiftUI
import UIKit
import LeeoKit

// MARK: - 홈: 무엇을 만들지 고른다 → 병렬 타임라인이 펼쳐진다

struct RecipeListView: View {
    @StateObject private var session = CookSession()
    @ObservedObject private var router = RecipeRouter.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var showSettings = false
    @Environment(\.foldLayout) private var fold
    /// 펼친 아이폰 듀오에서 결과 쪽에 시작 전 화면을 보여 주는 요리. 처음엔 맨 위 요리.
    @State private var previewed = RecipeDB.all.first

    var body: some View {
        NavigationStack {
            // 아이폰 듀오를 펴면 고르는 쪽은 요리 목록, 결과 쪽은 고른 요리의 시작 전 화면(타임라인 · 순서).
            // 접혀 있거나 보통 아이폰 · 아이패드면 목록만, 곧 지금 화면 그대로다.
            FoldSplitView {
                ZStack {
                    Theme.cream.ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header
                            ForEach(RecipeDB.all) { recipe in
                                RecipeCard(recipe: recipe,
                                           isSelected: fold.isUnfolded && recipe == previewed) {
                                    // 펼쳐 있으면 결과 쪽에 시작 전 화면을 띄운다. 시작은 거기 버튼으로.
                                    if fold.isUnfolded {
                                        previewed = recipe
                                    } else {
                                        session.prepare(recipe)   // 시작은 조리 화면의 버튼으로
                                    }
                                }
                            }
                            footNote
                        }
                        .padding(16)
                        // 아이패드에서 카드가 화면 끝까지 늘어나지 않게
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                    }
                }
            } result: {
                if let previewed {
                    RecipePreviewPane(recipe: previewed) {
                        session.prepare(previewed)
                        session.begin()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .accessibilityLabel("설정")
                }
            }
            .onAppear {
                // 뷰가 그려지는 도중에 상태를 바꾸지 않도록 한 틱 뒤에
                DispatchQueue.main.async {
                    startDemoIfRequested()
                    if !hasSeenOnboarding && !Self.isDemoRun && session.recipe == nil {
                        showOnboarding = true
                    }
                }
            }
            // 단축어·Siri 로 고른 요리 — 앱이 막 켜지는 중이었어도 여기서 받는다
            .onReceive(router.$pendingRecipeID) { id in
                guard let id else { return }
                DispatchQueue.main.async { openFromShortcut(id) }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fullScreenCover(isPresented: $showOnboarding) { GeusaieOnboardingView().foldConfined() }
        }
        .tint(Theme.terracotta)
        .fullScreenCover(isPresented: Binding(
            get: { session.recipe != nil },
            set: { if !$0 { session.reset() } }
        )) {
            CookView(session: session)
        }
    }

    /// 단축어로 요리를 연다. 이미 요리 중이면 그 진행을 지우지 않는다 — 냄비가 돌고 있을 수 있다.
    private func openFromShortcut(_ id: String) {
        router.pendingRecipeID = nil
        guard session.recipe == nil,
              let recipe = RecipeDB.all.first(where: { $0.id == id }) else { return }
        // 첫 실행 안내·설정이 떠 있으면 먼저 내린다 (안내는 다음 실행에 다시 보인다).
        // 내려가는 중에 조리 화면을 올리면 무시되므로 내려간 뒤에 연다.
        let covering = showOnboarding || showSettings
        showOnboarding = false
        showSettings = false
        if covering {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { session.prepare(recipe) }
        } else {
            session.prepare(recipe)
        }
    }

    /// 스크린샷용 데모 실행인가 — 이때는 첫 실행 안내로 화면을 가리지 않는다
    private static var isDemoRun: Bool {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "demoRecipe") != nil
        #else
        return false
        #endif
    }

    /// 스크린샷·디버그용: -demoRecipe <id> [-demoAt <초>] [-demoTextScale 0~3]
    /// (글자 크기 인자 이름을 앱 설정 키와 다르게 둔다 — 같으면 실행 인자 전체가 무시된다)
    private func startDemoIfRequested() {
        #if DEBUG
        let args = UserDefaults.standard
        if args.object(forKey: "demoTextScale") != nil {
            args.set(args.integer(forKey: "demoTextScale"), forKey: "textScale")
        }
        if args.bool(forKey: "demoLandscape") { Self.rotateToLandscape() }
        guard session.recipe == nil,
              let id = args.string(forKey: "demoRecipe"),
              let recipe = RecipeDB.all.first(where: { $0.id == id }) else { return }
        let at = args.integer(forKey: "demoAt")
        if at > 0 { session.start(recipe, at: at) } else { session.prepare(recipe) }
        #endif
    }

    #if DEBUG
    /// 스크린샷용 가로 전환 — 시뮬레이터를 손으로 돌릴 수 없을 때.
    /// 화면(scene)이 붙기 전에는 요청이 무시되므로 될 때까지 몇 번 다시 시도한다.
    private static func rotateToLandscape(_ tries: Int = 0) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ??
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        guard tries < 8 else { return }
        if scene?.interfaceOrientation.isLandscape != true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { rotateToLandscape(tries + 1) }
        }
    }
    #endif

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("그사이에")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("면 삶는 그사이에 소스까지.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.bottom, 4)
    }

    private var footNote: some View {
        Text("냄비가 다 되면 알려 드려요.")
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 4)
    }
}

// MARK: - 레시피 카드 — 고를 때 필요한 것만
//
// 고르는 순간에 알아야 하는 건 두 가지다. 얼마나 걸리나, 냄비가 몇 개 필요한가.
// 어떤 작업이 언제 오는지는 들어가면 다 나온다.

struct RecipeCard: View {
    let recipe: Recipe
    /// 펼친 아이폰 듀오에서 결과 쪽에 보이는 요리인가.
    var isSelected = false
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 14) {
                Text(recipe.emoji).font(.system(size: 40))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                    // 고를 때는 분 단위면 충분하다
                    Text("약 \(Int((Double(recipe.estimatedSeconds) / 60).rounded()))분 · 냄비 \(recipe.potCount)개")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                }

                Spacer(minLength: 8)
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(Theme.terracotta)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isSelected ? Theme.terracotta : Theme.cardBorder,
                                    lineWidth: isSelected ? 2.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // 이모지·재생 아이콘을 따로 읽지 않고 한 문장으로
        .accessibilityLabel(String(localized: "\(recipe.name), 약 \(Int((Double(recipe.estimatedSeconds) / 60).rounded()))분, 냄비 \(recipe.potCount)개"))
        .accessibilityHint("조리 화면을 엽니다")
        // 음성 명령은 요리 이름만 말해도 열리게
        .accessibilityInputLabels([Text(recipe.name)])
    }
}

// MARK: - 아이폰 듀오 결과 쪽 — 고른 요리의 시작 전 화면
//
// 조리 화면의 '시작 전'과 같은 것(타임라인 · 순서)을 목록 옆에 둔다. 고르는 동안 무엇이 언제 오는지 보고,
// 요리 시작을 누르면 조리 화면이 바로 돌기 시작한다. 시계는 시작 전이라 돌지 않는다.

struct RecipePreviewPane: View {
    let recipe: Recipe
    let onStart: () -> Void
    /// 시작 전 계획만 그리는 세션. 시작하지 않으므로 시계도 알림도 돌지 않는다.
    @StateObject private var preview = CookSession()

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(recipe.emoji) \(recipe.name)")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    if preview.recipe == recipe {
                        GanttTimeline(recipe: recipe, session: preview)
                        StepChecklist(recipe: recipe, session: preview)
                    }
                }
                .padding(16)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onStart) {
                Label("요리 시작", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButton(tint: Theme.terracotta))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.cream)
        }
        .onChange(of: recipe, initial: true) { _, recipe in preview.prepare(recipe) }
    }
}
