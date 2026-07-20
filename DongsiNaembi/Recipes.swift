import Foundation

// MARK: - 레시피 DB
//
// 시간은 리서치한 실제 레시피의 조리 순서를 초 단위 타임라인으로 옮긴 것.
// 각 작업의 startAt(시작 시점)이 겹치는 구간이 곧 "병렬로 해야 하는 것".

enum RecipeDB {

    // 알리오 올리오 — 병렬성이 가장 또렷한 교과서
    //
    // 면: 물 끓이기(0~5:00) → 스파게티 삶기(5:00~13:00)
    // 소스: 면 넣고 3분 뒤(8:00) 마늘·페퍼론치노 약불에 볶기 시작 → 면과 함께 13:00에 완성
    // 마무리: 면수와 유화(13:00~15:00)
    // 참고: Serious Eats / Gimme Some Oven 계열 정통 레시피
    static let aglioOlio = Recipe(
        id: "aglio-olio",
        name: "알리오 올리오",
        emoji: "🍝",
        subtitle: "면 삶는 그사이에 마늘 오일 — 정통 4재료",
        lanes: ["면", "소스", "마무리"],
        steps: [
            RecipeStep(id: "ao-boil", name: "물 끓이기", emoji: "💧",
                       lane: "면", startAt: 0, duration: 300, attention: .passive,
                       tip: "물 넉넉히 + 소금은 바닷물처럼 짜게"),
            RecipeStep(id: "ao-pasta", name: "스파게티 삶기", emoji: "🍝",
                       lane: "면", startAt: 300, duration: 480, attention: .passive,
                       tip: "봉지 표기보다 1분 덜 — 마지막은 팬에서 완성"),
            RecipeStep(id: "ao-garlic", name: "마늘·페퍼론치노 볶기", emoji: "🧄",
                       lane: "소스", startAt: 480, duration: 300, attention: .active,
                       tip: "약불! 마늘이 타면 끝 — 옅은 황금색까지만"),
            RecipeStep(id: "ao-reserve", name: "면수 한 컵 남기기", emoji: "🥣",
                       lane: "마무리", startAt: 765, duration: 15, attention: .instant,
                       tip: "건지기 전에! 유화의 핵심"),
            RecipeStep(id: "ao-toss", name: "면수 넣고 유화·버무리기", emoji: "🌀",
                       lane: "마무리", startAt: 780, duration: 120, attention: .active,
                       tip: "면수 반 컵, 강하게 토스해 오일과 유화"),
        ],
        source: "Serious Eats · Gimme Some Oven 정통 레시피"
    )

    // 토마토 크림 파스타
    //
    // 면: 물 끓이기(0~5:00) → 파스타 삶기(5:00~17:00)
    // 소스: 면 넣고 3~4분 뒤(8:30) 양파 → 마늘·후추 → 토마토페이스트 → 크림 졸이기
    // 마무리: 면을 소스에 넣고 버무려 완성
    // 참고: RecipeTin Eats / The Burnt Butter Table
    static let tomatoCream = Recipe(
        id: "tomato-cream",
        name: "토마토 크림 파스타",
        emoji: "🍅",
        subtitle: "면 삶는 그사이에 양파부터 크림까지 소스 완성",
        lanes: ["면", "소스", "마무리"],
        steps: [
            RecipeStep(id: "tc-boil", name: "물 끓이기", emoji: "💧",
                       lane: "면", startAt: 0, duration: 300, attention: .passive,
                       tip: "소금 넉넉히"),
            RecipeStep(id: "tc-pasta", name: "파스타 삶기", emoji: "🍝",
                       lane: "면", startAt: 300, duration: 720, attention: .passive,
                       tip: "1분 덜 삶고 면수 한 컵 남기기 — 소스에서 마저 익힘"),
            RecipeStep(id: "tc-onion", name: "양파 볶기", emoji: "🧅",
                       lane: "소스", startAt: 510, duration: 270, attention: .active,
                       tip: "중약불로 부드러워질 때까지"),
            RecipeStep(id: "tc-garlic", name: "마늘·후추 넣기", emoji: "🧄",
                       lane: "소스", startAt: 780, duration: 90, attention: .active,
                       tip: "향이 올라오면 바로 다음 단계"),
            RecipeStep(id: "tc-paste", name: "토마토페이스트 볶기", emoji: "🥫",
                       lane: "소스", startAt: 870, duration: 90, attention: .active,
                       tip: "페이스트를 한 번 볶아 신맛 날리기"),
            RecipeStep(id: "tc-cream", name: "크림 넣고 졸이기", emoji: "🥛",
                       lane: "소스", startAt: 960, duration: 120, attention: .passive,
                       tip: "아주 약한 뭉근한 simmer — 끓이지 말 것"),
            RecipeStep(id: "tc-finish", name: "면 넣고 버무려 마무리", emoji: "🌀",
                       lane: "마무리", startAt: 1080, duration: 120, attention: .active,
                       tip: "면수로 농도 조절, 소스에서 1분 마저 익힘"),
        ],
        source: "RecipeTin Eats · The Burnt Butter Table"
    )

    static let all: [Recipe] = [aglioOlio, tomatoCream]
}
