import Foundation

// MARK: - 레시피 DB
//
// 두 가지 원칙:
// 1) 손은 하나 — hands 작업은 절대 겹치지 않고, 물·면이 익는 사이사이에
//    프렙(썰기·계량·치즈 갈기)까지 끼워 넣어 손이 놀지 않게 한다.
// 2) 타이머 = 냄비 수 + 1(내 손). 냄비마다 배경 타이머가 하나씩 생긴다.
//
// lanes[0] = "내 손"(손 작업 전체), 그 뒤 = 냄비/팬별 배경 타이머.
// 손 작업은 어느 냄비에 있든 '내 손' 행에도 함께 표시된다.

enum RecipeDB {

    // 알리오 올리오 — 냄비 2개(면냄비·소스팬) → 타이머 3개
    // 손 동선: 준비→마늘 편썰기→페퍼론치노 다지기→면 넣기→치즈 갈기→
    //          마늘 볶기→면수 남기고 건지기→유화 (0~15:00 내내 손이 움직임)
    // 참고: Serious Eats / Gimme Some Oven 정통 레시피
    static let aglioOlio = Recipe(
        id: "aglio-olio",
        name: "알리오 올리오",
        emoji: "🍝",
        subtitle: "물·면이 익는 사이 손은 계속 — 프렙까지 끼워 넣은 동선",
        lanes: ["내 손", "면냄비", "소스팬"],
        steps: [
            // 면냄비 (배경 타이머)
            RecipeStep(id: "ao-boil", name: "물 끓이기", emoji: "💧",
                       lane: "면냄비", startAt: 0, duration: 300, attention: .passive,
                       tip: "물 넉넉히 + 소금은 바닷물처럼 짜게"),
            RecipeStep(id: "ao-pasta", name: "면 삶기", emoji: "🍝",
                       lane: "면냄비", startAt: 300, duration: 480, attention: .passive,
                       tip: "봉지 표기보다 1분 덜 — 마지막은 팬에서 완성"),
            // 내 손 (순서대로, 빈틈 없이)
            RecipeStep(id: "ao-prep", name: "냄비·팬 올리고 재료 꺼내기", emoji: "🧑‍🍳",
                       lane: "내 손", startAt: 0, duration: 60, attention: .active,
                       tip: "물 올리는 김에 필요한 재료를 한자리에"),
            RecipeStep(id: "ao-slice", name: "마늘 얇게 편 썰기", emoji: "🧄",
                       lane: "내 손", startAt: 60, duration: 120, attention: .active,
                       tip: "최대한 얇게 — 물 끓는 동안"),
            RecipeStep(id: "ao-pepper", name: "페퍼론치노·파슬리 다지기", emoji: "🌶️",
                       lane: "내 손", startAt: 180, duration: 120, attention: .active,
                       tip: "파슬리는 마무리용도 남겨두기"),
            RecipeStep(id: "ao-drop", name: "끓으면 면 넣기", emoji: "⬇️",
                       lane: "면냄비", startAt: 300, duration: 10, attention: .instant,
                       tip: "소금 넣은 끓는 물에 부채꼴로"),
            RecipeStep(id: "ao-cheese", name: "치즈 갈고 접시 데우기", emoji: "🧀",
                       lane: "내 손", startAt: 310, duration: 130, attention: .active,
                       tip: "면 삶는 초반 빈손 방지 — 미리 준비"),
            RecipeStep(id: "ao-garlic", name: "마늘·오일 볶기", emoji: "🍳",
                       lane: "소스팬", startAt: 440, duration: 320, attention: .active,
                       tip: "약불! 옅은 황금색까지만 — 타면 끝"),
            RecipeStep(id: "ao-reserve", name: "면수 남기고 면 건지기", emoji: "🥣",
                       lane: "면냄비", startAt: 760, duration: 20, attention: .instant,
                       tip: "면수 한 컵 먼저 떠두기!"),
            RecipeStep(id: "ao-toss", name: "면수 넣고 유화·버무리기", emoji: "🌀",
                       lane: "소스팬", startAt: 780, duration: 120, attention: .active,
                       tip: "면수 반 컵, 강하게 토스해 유화"),
        ],
        source: "Serious Eats · Gimme Some Oven 정통 레시피"
    )

    // 토마토 크림 파스타 — 냄비 2개(면냄비·소스팬) → 타이머 3개
    // 참고: RecipeTin Eats / The Burnt Butter Table
    static let tomatoCream = Recipe(
        id: "tomato-cream",
        name: "토마토 크림 파스타",
        emoji: "🍅",
        subtitle: "면 삶는 사이 양파부터 크림까지 — 손은 소스에 붙어서",
        lanes: ["내 손", "면냄비", "소스팬"],
        steps: [
            // 면냄비
            RecipeStep(id: "tc-boil", name: "물 끓이기", emoji: "💧",
                       lane: "면냄비", startAt: 0, duration: 300, attention: .passive,
                       tip: "소금 넉넉히"),
            RecipeStep(id: "tc-pasta", name: "면 삶기", emoji: "🍝",
                       lane: "면냄비", startAt: 300, duration: 720, attention: .passive,
                       tip: "1분 덜 삶기 — 소스에서 마저 익힘"),
            // 소스팬 (배경 졸이기만 passive)
            RecipeStep(id: "tc-simmer", name: "크림 뭉근히 졸이기", emoji: "🥛",
                       lane: "소스팬", startAt: 990, duration: 90, attention: .passive,
                       tip: "아주 약한 simmer — 끓이지 말 것"),
            // 내 손 (빈틈 없이)
            RecipeStep(id: "tc-prep", name: "냄비·팬 올리고 재료 꺼내기", emoji: "🧑‍🍳",
                       lane: "내 손", startAt: 0, duration: 60, attention: .active,
                       tip: "물 올리는 김에 재료 세팅"),
            RecipeStep(id: "tc-onion-prep", name: "양파 채썰기", emoji: "🧅",
                       lane: "내 손", startAt: 60, duration: 150, attention: .active,
                       tip: "잘게 — 물 끓는 동안"),
            RecipeStep(id: "tc-garlic-prep", name: "마늘 다지기", emoji: "🧄",
                       lane: "내 손", startAt: 210, duration: 90, attention: .active,
                       tip: "곱게 다지기"),
            RecipeStep(id: "tc-drop", name: "끓으면 면 넣기", emoji: "⬇️",
                       lane: "면냄비", startAt: 300, duration: 10, attention: .instant,
                       tip: "소금 넣은 끓는 물에"),
            RecipeStep(id: "tc-mise", name: "치즈 갈고 소스 재료 계량", emoji: "🧀",
                       lane: "내 손", startAt: 310, duration: 200, attention: .active,
                       tip: "양파 볶기 전 빈손 방지 — 미리 계량"),
            RecipeStep(id: "tc-onion", name: "양파 볶기", emoji: "🍳",
                       lane: "소스팬", startAt: 510, duration: 270, attention: .active,
                       tip: "중약불로 부드러워질 때까지"),
            RecipeStep(id: "tc-garlic", name: "마늘·후추 넣기", emoji: "🧄",
                       lane: "소스팬", startAt: 780, duration: 90, attention: .active,
                       tip: "향이 올라오면 바로 다음"),
            RecipeStep(id: "tc-paste", name: "토마토페이스트 볶기", emoji: "🥫",
                       lane: "소스팬", startAt: 870, duration: 90, attention: .active,
                       tip: "한 번 볶아 신맛 날리기"),
            RecipeStep(id: "tc-cream", name: "크림 붓고 젓기", emoji: "🥛",
                       lane: "소스팬", startAt: 960, duration: 30, attention: .active,
                       tip: "불 줄이고 부드럽게 섞기"),
            RecipeStep(id: "tc-taste", name: "간 보고 면 상태 확인", emoji: "👅",
                       lane: "내 손", startAt: 990, duration: 30, attention: .active,
                       tip: "졸이는 사이 간 맞추기"),
            RecipeStep(id: "tc-reserve", name: "면수 남기고 면 건지기", emoji: "🥣",
                       lane: "면냄비", startAt: 1020, duration: 30, attention: .instant,
                       tip: "면수 한 컵 먼저!"),
            RecipeStep(id: "tc-plate", name: "접시 데우고 옮길 준비", emoji: "🍽️",
                       lane: "내 손", startAt: 1050, duration: 30, attention: .active,
                       tip: "마무리 직전 세팅"),
            RecipeStep(id: "tc-finish", name: "면 넣고 버무려 마무리", emoji: "🌀",
                       lane: "소스팬", startAt: 1080, duration: 120, attention: .active,
                       tip: "면수로 농도 조절, 소스에서 1분 마저"),
        ],
        source: "RecipeTin Eats · The Burnt Butter Table"
    )

    static let all: [Recipe] = [aglioOlio, tomatoCream]
}
