import SwiftUI

// MARK: - 첫 실행 안내
//
// 이 앱은 '타이머 여러 개'가 아니라 '냄비 두 개가 겹쳐 도는 시간표'다.
// 처음 보면 색과 막대가 무엇을 뜻하는지 모르고 지나가기 쉬워서, 세 장만 보여 준다.
// 한 번 보면 다시 뜨지 않고, 설정의 '사용 방법 다시 보기'로 언제든 다시 열 수 있다.

struct GeusaieOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        Page(id: 0, symbol: "frying.pan.fill", tint: Theme.terracotta,
             title: "냄비 두 개를 한 화면에",
             body: "면 삶는 그사이에 소스까지. 냄비마다 무엇을 하는 중인지, 얼마나 남았는지 따로 보여 드려요."),
        Page(id: 1, symbol: "exclamationmark.triangle.fill", tint: Theme.terracotta,
             title: "색이 곧 급한 정도",
             body: "테라코타는 미루면 면이 퍼지거나 타는 일이에요. 초록은 도마 일이라 손이 빌 때 천천히 하면 돼요."),
        Page(id: 2, symbol: "mic.fill", tint: Theme.green,
             title: "다 했으면 \"다음\"",
             body: "버튼을 누르거나, 손이 젖었으면 \"다음\"이라고 말하세요. 냄비가 다 되면 알림으로 알려 드려요."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if !isLast {
                        Button("건너뛰기") { finish() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 20)

                TabView(selection: $page) {
                    ForEach(pages) { p in
                        pageView(p).tag(p.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if isLast { finish() } else { withAnimation { page += 1 } }
                } label: {
                    Text(isLast ? "시작하기" : "다음")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledButton(tint: Theme.terracotta))
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: 560)
        }
    }

    private func pageView(_ p: Page) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            Image(systemName: p.symbol)
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(p.tint)
                .frame(width: 120, height: 120)
                .background(Circle().fill(Theme.card))
                .accessibilityHidden(true)
            Text(p.title)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(p.body)
                .font(.body)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
        .accessibilityElement(children: .combine)
    }

    private func finish() {
        hasSeenOnboarding = true
        dismiss()
    }
}
