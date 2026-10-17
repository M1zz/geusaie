//
//  GeusaieRoadmap.swift
//  Geusaie
//
//  **앞으로 만들 것**의 원본. 설정 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. 내보내면 `.shipped("1.1.0")`.
//     - id 는 한 번 정하면 바꾸지 않는다(문구는 바꿔도 된다).
//     - 문구는 사용자 말로 쓴다(내부 이름 · 기술 용어 금지). 영어는 Geusaie/Localizable.xcstrings 에 넣는다
//       (한국어 전용 앱이라 카탈로그에는 이 화면 문구만 있다 — 영어가 빠지면 영어 쓰는 사람에게 한국어가 보인다).
//     - 사용자에게 보일 만한 것만 적는다. 리팩터링 · 시험 · 빌드 설정은 `.sprintcommander/tasks.json` 의 몫이다.
//

import SwiftUI
import LeeoKit

extension GeusaieSpec {
    static var roadmap: [LeeoRoadmapItem] {[
        // MARK: 다음에 만들어요
        .init(id: "a11y.voiceover", status: .planned,
              title: NSLocalizedString("VoiceOver로 더 편하게", comment: "Roadmap item: a11y.voiceover"),
              detail: NSLocalizedString("VoiceOver가 냄비 시간과 할 일을 빠짐없이, 알맞은 순서로 읽어 줘요.", comment: "Roadmap item detail: a11y.voiceover")),
        .init(id: "a11y.largetext", status: .planned,
              title: NSLocalizedString("큰 글씨에 맞춘 화면", comment: "Roadmap item: a11y.largetext"),
              detail: NSLocalizedString("기기 글자 크기를 키워도 레시피 목록과 화면이 잘리지 않게 다시 배치돼요.", comment: "Roadmap item detail: a11y.largetext")),
        .init(id: "display.dark", status: .planned,
              title: NSLocalizedString("다크 모드", comment: "Roadmap item: display.dark"),
              detail: NSLocalizedString("어두운 부엌에서도 눈부시지 않게 어두운 화면으로 볼 수 있어요.", comment: "Roadmap item detail: display.dark")),
        .init(id: "a11y.contrast", status: .planned,
              title: NSLocalizedString("보기 편한 색과 대비", comment: "Roadmap item: a11y.contrast"),
              detail: NSLocalizedString("대비를 높이거나 색을 구별하기 어려워도 냄비마다 상태를 알아볼 수 있어요.", comment: "Roadmap item detail: a11y.contrast")),
        .init(id: "a11y.motion", status: .planned,
              title: NSLocalizedString("움직임 줄이기", comment: "Roadmap item: a11y.motion"),
              detail: NSLocalizedString("움직임 줄이기를 켜면 화면 효과가 차분해져요.", comment: "Roadmap item detail: a11y.motion")),
        .init(id: "a11y.keyboard", status: .planned,
              title: NSLocalizedString("키보드로 조작하기", comment: "Roadmap item: a11y.keyboard"),
              detail: NSLocalizedString("아이패드에 키보드를 연결하면 키만으로 다음 단계로 넘어가요.", comment: "Roadmap item detail: a11y.keyboard")),
        .init(id: "lang.english", status: .planned,
              title: NSLocalizedString("영어 지원", comment: "Roadmap item: lang.english"),
              detail: NSLocalizedString("앱을 영어로도 쓸 수 있어요.", comment: "Roadmap item detail: lang.english")),
        .init(id: "lang.more", status: .planned,
              title: NSLocalizedString("더 많은 언어", comment: "Roadmap item: lang.more"),
              detail: NSLocalizedString("영어 말고도 더 많은 나라 말로 쓸 수 있게 해요.", comment: "Roadmap item detail: lang.more")),
        .init(id: "whatsnew", status: .planned,
              title: NSLocalizedString("업데이트 소식", comment: "Roadmap item: whatsnew"),
              detail: NSLocalizedString("업데이트 뒤 처음 열 때 무엇이 새로 생겼는지 알려 줘요.", comment: "Roadmap item detail: whatsnew")),
        .init(id: "feedback.reply", status: .planned,
              title: NSLocalizedString("보낸 의견에 답장 받기", comment: "Roadmap item: feedback.reply"),
              detail: NSLocalizedString("보내 주신 의견에 단 답장을 앱 안에서 볼 수 있어요.", comment: "Roadmap item detail: feedback.reply")),
        .init(id: "widgets", status: .planned,
              title: NSLocalizedString("홈 화면 위젯", comment: "Roadmap item: widgets"),
              detail: NSLocalizedString("자주 하는 요리를 홈 화면에서 바로 시작해요.", comment: "Roadmap item detail: widgets")),
        .init(id: "fold", status: .planned,
              title: NSLocalizedString("펼치는 아이폰 화면", comment: "Roadmap item: fold"),
              detail: NSLocalizedString("펼치는 아이폰에서 넓은 화면에 냄비와 할 일을 나란히 봐요.", comment: "Roadmap item detail: fold")),
        .init(id: "autosave", status: .planned,
              title: NSLocalizedString("하던 요리 이어서", comment: "Roadmap item: autosave"),
              detail: NSLocalizedString("요리하다 앱이 꺼져도 냄비 시간과 진행 상황이 그대로 이어져요.", comment: "Roadmap item detail: autosave")),
    ]}
}

// MARK: - 화면

/// 설정 ▸ 앞으로 만들 기능. "이런 기능이 있으면 좋겠어요" 는 기능 제안으로 시작하는 피드백 창을 연다.
struct RoadmapScreen: View {
    @State private var showFeedback = false

    var body: some View {
        LeeoRoadmapView<GeusaieSpec>(onSuggest: { showFeedback = true })
            .sheet(isPresented: $showFeedback) {
                NavigationStack {
                    LeeoFeedbackView<GeusaieSpec>(initialType: .feature)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("닫기") { showFeedback = false }
                            }
                        }
                }
                .tint(Theme.terracotta)
            }
    }
}
