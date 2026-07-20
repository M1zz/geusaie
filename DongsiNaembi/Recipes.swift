import Foundation

// MARK: - 레시피 DB
//
// 원칙: 사람은 손이 하나다. hands 작업(썰기·볶기·유화)은 절대 겹치지 않게
// '내 손' 레인에 순서대로 배치한다. 불 위에서 알아서 되는 것(물 끓이기·면 삶기·
// 졸이기)만 '자동' 레인에서 배경으로 돌아간다. 자동이 도는 그 사이사이에
// 손 작업을 끼워 넣는 것 — 그게 이 앱이 짜주는 동선이다.
//
// lanes[0] = "내 손"(순서대로) · lanes[1] = "자동"(걸어두면 됨)

enum RecipeDB {

    // 알리오 올리오
    // 자동: 물 끓이기(0~5:00) → 면 삶기(5:00~13:00)
    // 내 손: 물 끓는 동안 마늘·페퍼론치노 손질 → 면 넣고 → 팬 데우고 →
    //        마늘 볶고(면 삶는 사이) → 면수 남겨 건지고 → 유화
    // 참고: Serious Eats / Gimme Some Oven 정통 레시피
    static let aglioOlio = Recipe(
        id: "aglio-olio",
        name: "알리오 올리오",
        emoji: "🍝",
        subtitle: "물 끓는 사이 마늘 손질, 면 삶는 사이 오일 — 손은 쉬지 않게",
        lanes: ["내 손", "자동"],
        steps: [
            // 자동 (걸어두면 됨)
            RecipeStep(id: "ao-boil", name: "물 끓이기", emoji: "💧",
                       lane: "자동", startAt: 0, duration: 300, attention: .passive,
                       tip: "물 넉넉히 + 소금은 바닷물처럼 짜게"),
            RecipeStep(id: "ao-pasta", name: "면 삶기", emoji: "🍝",
                       lane: "자동", startAt: 300, duration: 480, attention: .passive,
                       tip: "봉지 표기보다 1분 덜 — 마지막은 팬에서 완성"),
            // 내 손 (순서대로, 겹치지 않음)
            RecipeStep(id: "ao-slice", name: "마늘 얇게 편 썰기", emoji: "🧄",
                       lane: "내 손", startAt: 60, duration: 120, attention: .active,
                       tip: "물 끓는 동안 미리 — 최대한 얇게"),
            RecipeStep(id: "ao-pepper", name: "페퍼론치노·파슬리 다지기", emoji: "🌶️",
                       lane: "내 손", startAt: 180, duration: 100, attention: .active,
                       tip: "기호껏 — 파슬리는 마무리용도 남겨두기"),
            RecipeStep(id: "ao-drop", name: "끓으면 면 넣기", emoji: "⬇️",
                       lane: "내 손", startAt: 300, duration: 10, attention: .instant,
                       tip: "소금 넣은 끓는 물에 부채꼴로"),
            RecipeStep(id: "ao-panoil", name: "팬에 오일 두르고 데우기", emoji: "🫒",
                       lane: "내 손", startAt: 430, duration: 50, attention: .active,
                       tip: "넉넉한 올리브유, 약불"),
            RecipeStep(id: "ao-garlic", name: "마늘·페퍼론치노 볶기", emoji: "🍳",
                       lane: "내 손", startAt: 480, duration: 280, attention: .active,
                       tip: "약불! 옅은 황금색까지만 — 타면 끝"),
            RecipeStep(id: "ao-reserve", name: "면수 남기고 면 건지기", emoji: "🥣",
                       lane: "내 손", startAt: 760, duration: 20, attention: .instant,
                       tip: "면수 한 컵 먼저 떠두기! 유화의 핵심"),
            RecipeStep(id: "ao-toss", name: "면수 넣고 유화·버무리기", emoji: "🌀",
                       lane: "내 손", startAt: 780, duration: 120, attention: .active,
                       tip: "면수 반 컵, 강하게 토스해 오일과 유화"),
        ],
        source: "Serious Eats · Gimme Some Oven 정통 레시피"
    )

    // 토마토 크림 파스타
    // 자동: 물 끓이기 → 면 삶기(12분) → 크림 뭉근히 졸이기
    // 내 손: 물 끓는 동안 양파·마늘 손질 → 면 넣고 → 양파부터 페이스트까지 볶고 →
    //        크림 붓고 → 면 건지고 → 소스에 버무려 마무리
    // 참고: RecipeTin Eats / The Burnt Butter Table
    static let tomatoCream = Recipe(
        id: "tomato-cream",
        name: "토마토 크림 파스타",
        emoji: "🍅",
        subtitle: "면 삶는 사이 양파부터 크림까지, 손은 소스에만 집중",
        lanes: ["내 손", "자동"],
        steps: [
            // 자동
            RecipeStep(id: "tc-boil", name: "물 끓이기", emoji: "💧",
                       lane: "자동", startAt: 0, duration: 300, attention: .passive,
                       tip: "소금 넉넉히"),
            RecipeStep(id: "tc-pasta", name: "면 삶기", emoji: "🍝",
                       lane: "자동", startAt: 300, duration: 720, attention: .passive,
                       tip: "1분 덜 삶기 — 소스에서 마저 익힘"),
            RecipeStep(id: "tc-simmer", name: "크림 뭉근히 졸이기", emoji: "🥛",
                       lane: "자동", startAt: 990, duration: 90, attention: .passive,
                       tip: "아주 약한 simmer — 끓이지 말 것"),
            // 내 손
            RecipeStep(id: "tc-onion-prep", name: "양파 채썰기", emoji: "🧅",
                       lane: "내 손", startAt: 60, duration: 150, attention: .active,
                       tip: "물 끓는 동안 미리 — 잘게"),
            RecipeStep(id: "tc-garlic-prep", name: "마늘 다지기", emoji: "🧄",
                       lane: "내 손", startAt: 210, duration: 90, attention: .active,
                       tip: "곱게 다지기"),
            RecipeStep(id: "tc-drop", name: "끓으면 면 넣기", emoji: "⬇️",
                       lane: "내 손", startAt: 300, duration: 10, attention: .instant,
                       tip: "소금 넣은 끓는 물에"),
            RecipeStep(id: "tc-onion", name: "양파 볶기", emoji: "🍳",
                       lane: "내 손", startAt: 510, duration: 270, attention: .active,
                       tip: "중약불로 부드러워질 때까지"),
            RecipeStep(id: "tc-garlic", name: "마늘·후추 넣기", emoji: "🧄",
                       lane: "내 손", startAt: 780, duration: 90, attention: .active,
                       tip: "향이 올라오면 바로 다음"),
            RecipeStep(id: "tc-paste", name: "토마토페이스트 볶기", emoji: "🥫",
                       lane: "내 손", startAt: 870, duration: 90, attention: .active,
                       tip: "한 번 볶아 신맛 날리기"),
            RecipeStep(id: "tc-cream", name: "크림 붓고 젓기", emoji: "🥛",
                       lane: "내 손", startAt: 960, duration: 30, attention: .instant,
                       tip: "불 줄이고 부드럽게 섞기"),
            RecipeStep(id: "tc-reserve", name: "면수 남기고 면 건지기", emoji: "🥣",
                       lane: "내 손", startAt: 1020, duration: 30, attention: .instant,
                       tip: "면수 한 컵 먼저!"),
            RecipeStep(id: "tc-finish", name: "면 넣고 버무려 마무리", emoji: "🌀",
                       lane: "내 손", startAt: 1080, duration: 120, attention: .active,
                       tip: "면수로 농도 조절, 소스에서 1분 마저 익힘"),
        ],
        source: "RecipeTin Eats · The Burnt Butter Table"
    )

    static let all: [Recipe] = [aglioOlio, tomatoCream]
}
