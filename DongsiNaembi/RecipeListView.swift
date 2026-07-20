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
                                session.start(recipe)
                            }
                        }
                        footNote
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Theme.terracotta)
        .fullScreenCover(isPresented: Binding(
            get: { session.recipe != nil },
            set: { if !$0 { session.reset() } }
        )) {
            CookView(session: session)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("그사이에")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("한 요리 안에서 동시에 돌아가는 작업들.\n면 삶는 그사이에 소스도 함께 끝내세요.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.bottom, 4)
    }

    private var footNote: some View {
        Text("각 작업의 시작·완료 순간마다 알림이 옵니다. 손이 바쁠 때 화면을 안 봐도 괜찮아요.")
            .font(.caption)
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 4)
    }
}

// MARK: - 레시피 카드: 미리 보는 병렬 타임라인

struct RecipeCard: View {
    let recipe: Recipe
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text(recipe.emoji).font(.largeTitle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipe.name)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(Theme.ink)
                        Text(recipe.subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                // 미니 타임라인 미리보기 — 겹침이 곧 병렬
                MiniTimeline(recipe: recipe)
                    .frame(height: CGFloat(recipe.lanes.count) * 16 + 8)

                HStack(spacing: 12) {
                    Label(koreanDuration(recipe.totalSeconds), systemImage: "clock")
                    Label("타이머 \(recipe.timerCount)개", systemImage: "timer")
                    Label(recipe.handsIdleSeconds == 0
                          ? "손 풀가동"
                          : "손 여유 \(koreanDuration(recipe.handsIdleSeconds))",
                          systemImage: "hand.raised.fill")
                    Spacer()
                    Image(systemName: "play.circle.fill").font(.title3)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.terracotta)
            }
            .padding(16)
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

/// 정적 미니 간트 — 카드에서 병렬 구조를 한눈에
struct MiniTimeline: View {
    let recipe: Recipe

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let total = CGFloat(max(1, recipe.totalSeconds))
            VStack(spacing: 4) {
                ForEach(recipe.lanes, id: \.self) { lane in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.ringTrack).frame(height: 12)
                        ForEach(recipe.rowSteps(lane)) { step in
                            Capsule()
                                .fill(recipe.color(for: lane))
                                .frame(width: max(5, w * CGFloat(step.duration) / total),
                                       height: 12)
                                .offset(x: w * CGFloat(step.startAt) / total)
                        }
                    }
                }
            }
        }
    }
}
