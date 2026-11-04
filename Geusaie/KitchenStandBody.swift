import SwiftUI

// MARK: - 아이패드 주방 스탠드 — 1미터 밖에서 읽는 조리 화면
//
// 조리대 위 스탠드에 세워 두고, 손은 도마와 냄비에 있다. 화면에 다가오지 않아도 알 수 있어야 하는 것은 둘뿐이다.
//   1) 지금 할 일 하나 — 아주 크게, 급한 정도는 카드 색으로
//   2) 냄비마다 남은 시간 — 전부 나란히, 숨기지 않는다
// 전체 순서(타임라인 · 체크리스트)는 그 아래에서 따로 스크롤된다. 다른 화면으로 넘어가지 않는다.
//
// 세로: [지금 할 일] / [냄비 나란히] / [전체 순서]
// 가로: [지금 할 일 · 전체 순서] | [냄비 위아래로]
// Split View 로 좁아지면 CookView 가 아이폰 배치로 돌아간다(가로 compact).

struct KitchenStandBody<Overview: View>: View {
    let recipe: Recipe
    @ObservedObject var session: CookSession
    @ObservedObject var voice: VoiceCue
    @ViewBuilder let overview: () -> Overview

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 20) {
                        NowStrip(session: session, voice: voice, hero: true)
                        overviewScroll
                    }
                    .frame(maxWidth: .infinity)

                    ScrollView {
                        PotBoard(recipe: recipe, session: session, hero: true, vertical: true)
                            .padding(.bottom, 12)
                    }
                    .frame(width: max(300, geo.size.width * 0.34))
                }
            } else {
                VStack(spacing: 20) {
                    NowStrip(session: session, voice: voice, hero: true)
                    PotBoard(recipe: recipe, session: session, hero: true)
                    overviewScroll
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    private var overviewScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) { overview() }
                .padding(.bottom, 12)
        }
        .frame(maxHeight: .infinity)
    }
}
