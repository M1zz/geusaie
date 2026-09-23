import SwiftUI

// MARK: - 홈: 무엇을 만들지 고른다 → 병렬 타임라인이 펼쳐진다

struct RecipeListView: View {
    @StateObject private var session = CookSession()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        ForEach(RecipeDB.all) { recipe in
                            RecipeCard(recipe: recipe) {
                                session.prepare(recipe)   // 시작은 조리 화면의 버튼으로
                            }
                        }
                        footNote
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 뷰가 그려지는 도중에 상태를 바꾸지 않도록 한 틱 뒤에
                DispatchQueue.main.async { startDemoIfRequested() }
            }
        }
        .tint(Theme.terracotta)
        .fullScreenCover(isPresented: Binding(
            get: { session.recipe != nil },
            set: { if !$0 { session.reset() } }
        )) {
            CookView(session: session)
        }
    }

    /// 스크린샷·디버그용: -demoRecipe <id> -demoAt <초> 로 실행하면 그 시점부터 바로 조리 화면
    private func startDemoIfRequested() {
        #if DEBUG
        let args = UserDefaults.standard
        guard session.recipe == nil,
              let id = args.string(forKey: "demoRecipe"),
              let recipe = RecipeDB.all.first(where: { $0.id == id }) else { return }
        let at = args.integer(forKey: "demoAt")
        if at > 0 { session.start(recipe, at: at) } else { session.prepare(recipe) }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("그사이에")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
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
                            .stroke(Theme.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
