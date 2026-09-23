import Foundation

// MARK: - 레시피 DB
//
// 각 일을 셋 중 하나로 분류한다. 이 분류가 앱의 전부다.
//
// - `.prep`   도마 일. **밀려도 된다.** 물이 끓든 말든 상관없고, 끊겼다 이어서 해도 된다.
// - `.action` 내가 냄비에 하는 동작. 손이 붙잡힌다. `deadline: true` 면 **밀리면 안 된다**
//             — 면이 퍼지거나 마늘이 타는 일들.
// - `.cook`   냄비가 혼자 도는 시간. 내가 시작 동작을 해야 비로소 돈다.
//
// 절대 시각은 적지 않는다. '무엇 다음에 무엇'만 적으면
// 실제로 내가 언제 했는지에 따라 시간표가 저절로 따라온다.

enum RecipeDB {

    // 알리오 올리오 — 냄비 2개(면냄비·소스팬) → 타이머 3개
    // 못 미루는 것: 면 건지기(퍼짐), 마늘 볶기 끝(탐), 건진 직후 유화(굳음)
    // 밀려도 되는 것: 마늘 썰기, 페퍼론치노 다지기, 치즈 갈기, 접시 데우기
    // 참고: Serious Eats / Gimme Some Oven
    static let aglioOlio = Recipe(
        id: "aglio-olio",
        name: "알리오 올리오",
        emoji: "🍝",
        subtitle: "면은 기다려 주지 않고, 도마 일은 기다려 준다",
        potLanes: ["면냄비", "소스팬"],
        chains: [
            // 면냄비 — 물 올리기부터 건지기까지 한 줄로 이어진다
            [
                RecipeStep(id: "ao-water-on", name: "물 올리고 센 불 켜기", emoji: "🔥",
                           lane: "면냄비", role: .action, duration: 15,
                           trigger: .atStart,
                           detail: ["물 2L, 소금 2큰술", "뚜껑을 덮으면 더 빨리 끓어요"],
                           doneWhen: "바닥에서 큰 기포가 계속 올라오면",
                           tip: "물 넉넉히, 소금은 바닷물처럼 짜게 — 5분쯤 끓습니다"),
                RecipeStep(id: "ao-boil", name: "물 끓이기", emoji: "💧",
                           lane: "면냄비", role: .cook, duration: 285,
                           tip: "끓는 동안 도마 일을 해두면 됩니다"),
                RecipeStep(id: "ao-drop", name: "끓으면 면 넣기", emoji: "⬇️",
                           lane: "면냄비", role: .action, duration: 10,
                           detail: ["스파게티 180g을 부채꼴로 펼쳐 넣기", "넣자마자 한 번 저어 붙지 않게"],
                           tip: "부채꼴로 펼쳐 넣기 — 넣는 순간부터 8분"),
                RecipeStep(id: "ao-pasta", name: "면 삶기", emoji: "🍝",
                           lane: "면냄비", role: .cook, duration: 470,
                           tip: "봉지 표기보다 1분 덜 — 마지막은 팬에서"),
                RecipeStep(id: "ao-reserve", name: "면수 남기고 면 건지기", emoji: "🥣",
                           lane: "면냄비", role: .action, duration: 20,
                           deadline: true,                       // 늦으면 면이 퍼진다
                           detail: ["면수 한 컵(200ml)을 먼저 떠두기", "면은 털지 말고 물기를 묻힌 채 바로 팬으로"],
                           tip: "면수 한 컵 먼저 떠두기!"),
            ],
            // 소스팬 — 면이 건져지는 순간에 맞춰 거꾸로 잡힌다
            [
                RecipeStep(id: "ao-garlic", name: "마늘·오일 볶기", emoji: "🍳",
                           lane: "소스팬", role: .action, duration: 320,
                           trigger: .endingWith("ao-reserve"),   // 면 건질 때 딱 맞춰 끝나게
                           deadline: true,                       // 넘기면 마늘이 탄다
                           detail: ["올리브유 6큰술에 마늘 편과 페퍼론치노", "약불에서 계속 저어 주기", "갈색이 되면 쓴맛 — 색이 오르면 불을 빼세요"],
                           doneWhen: "마늘 가장자리가 옅은 금색이 되면",
                           tip: "약불! 옅은 황금색까지만"),
                RecipeStep(id: "ao-toss", name: "면수 넣고 유화·버무리기", emoji: "🌀",
                           lane: "소스팬", role: .action, duration: 120,
                           trigger: .after("ao-reserve"),
                           deadline: true,                       // 면이 식기 전에
                           detail: ["면수 반 컵을 붓고 센 불", "팬을 흔들며 30초 — 기름과 면수가 섞이게", "불을 끄고 파슬리와 치즈"],
                           doneWhen: "소스가 뿌옇게 엉겨 면에 붙으면",
                           tip: "면수 반 컵, 강하게 토스해 유화"),
            ],
        ],
        preps: [
            RecipeStep(id: "ao-prep", name: "재료 꺼내고 팬 올리기", emoji: "🧑‍🍳",
                       lane: Recipe.handsLane, role: .prep, duration: 60,
                       detail: ["스파게티 180g(2인분), 마늘 6쪽, 올리브유 6큰술", "페퍼론치노 2~3개, 파슬리 조금, 파르미지아노 30g", "팬은 면이 다 들어갈 만큼 넓은 것으로"],
                       tip: "필요한 재료를 한자리에"),
            RecipeStep(id: "ao-slice", name: "마늘 얇게 편 썰기", emoji: "🧄",
                       lane: Recipe.handsLane, role: .prep, duration: 120,
                       detail: ["마늘 6쪽을 1~2mm 두께로", "칼을 눕혀 얇게 — 두꺼우면 속이 안 익고 겉만 타요"],
                       doneWhen: "편이 반투명하게 비치면 충분히 얇은 것",
                       tip: "최대한 얇게 — 급할 것 없습니다"),
            RecipeStep(id: "ao-pepper", name: "페퍼론치노·파슬리 다지기", emoji: "🌶️",
                       lane: Recipe.handsLane, role: .prep, duration: 105,
                       detail: ["페퍼론치노 2~3개를 반 갈라 씨 털기", "파슬리는 잎만 굵게 다지기", "절반은 마무리용으로 남겨두기"],
                       tip: "파슬리는 마무리용도 남겨두기"),
            RecipeStep(id: "ao-cheese", name: "치즈 갈고 접시 데우기", emoji: "🧀",
                       lane: Recipe.handsLane, role: .prep, duration: 130,
                       detail: ["파르미지아노 30g을 곱게 갈아두기", "접시는 뜨거운 물을 부어 데우고 물기 닦기"],
                       tip: "마무리 전에 해두면 편합니다"),
        ],
        source: "Serious Eats · Gimme Some Oven"
    )

    // 토마토 크림 파스타 — 냄비 2개 → 타이머 3개
    // 못 미루는 것: 면 건지기, 크림 졸인 뒤 마무리
    // 밀려도 되는 것: 양파 채썰기, 마늘 다지기, 치즈 갈기·계량
    // 참고: RecipeTin Eats / The Burnt Butter Table
    static let tomatoCream = Recipe(
        id: "tomato-cream",
        name: "토마토 크림 파스타",
        emoji: "🍅",
        subtitle: "소스는 면이 나오는 순간에 맞춰 거꾸로 잡힌다",
        potLanes: ["면냄비", "소스팬"],
        chains: [
            [
                RecipeStep(id: "tc-water-on", name: "물 올리고 센 불 켜기", emoji: "🔥",
                           lane: "면냄비", role: .action, duration: 15,
                           trigger: .atStart,
                           detail: ["물 2L, 소금 2큰술"],
                           doneWhen: "큰 기포가 계속 올라오면",
                           tip: "소금 넉넉히 — 5분쯤 끓습니다"),
                RecipeStep(id: "tc-boil", name: "물 끓이기", emoji: "💧",
                           lane: "면냄비", role: .cook, duration: 285,
                           tip: "끓는 동안 양파·마늘을 손질해두면 됩니다"),
                RecipeStep(id: "tc-drop", name: "끓으면 면 넣기", emoji: "⬇️",
                           lane: "면냄비", role: .action, duration: 10,
                           detail: ["파스타 180g — 봉지 표기보다 1분 덜 삶습니다"],
                           tip: "넣는 순간부터 12분"),
                RecipeStep(id: "tc-pasta", name: "면 삶기", emoji: "🍝",
                           lane: "면냄비", role: .cook, duration: 710,
                           tip: "1분 덜 삶기 — 소스에서 마저 익힘"),
                RecipeStep(id: "tc-reserve", name: "면수 남기고 면 건지기", emoji: "🥣",
                           lane: "면냄비", role: .action, duration: 30,
                           deadline: true,
                           detail: ["면수 한 컵(200ml) 먼저 떠두기"],
                           tip: "면수 한 컵 먼저!"),
            ],
            [
                RecipeStep(id: "tc-onion", name: "양파 볶기", emoji: "🍳",
                           lane: "소스팬", role: .action, duration: 270,
                           trigger: .endingWith("tc-reserve"),   // 소스 전체가 면 나올 때 준비되게
                           detail: ["올리브유 2큰술에 양파, 중약불", "눌어붙으면 물 한 숟갈"],
                           doneWhen: "투명해지고 가장자리가 노릇해지면",
                           tip: "중약불로 부드러워질 때까지"),
                RecipeStep(id: "tc-garlic", name: "마늘·후추 넣기", emoji: "🧄",
                           lane: "소스팬", role: .action, duration: 90,
                           deadline: true,                       // 향 올라오면 바로 다음
                           detail: ["다진 마늘과 후추를 넣고 30초", "마늘은 금방 타니 계속 저어 주세요"],
                           doneWhen: "마늘 향이 올라오면",
                           tip: "타기 쉬우니 바로 다음으로"),
                RecipeStep(id: "tc-paste", name: "토마토페이스트 볶기", emoji: "🥫",
                           lane: "소스팬", role: .action, duration: 90,
                           detail: ["토마토페이스트 2큰술을 팬 바닥에 펴 바르듯", "한 번 볶아야 신맛이 날아갑니다"],
                           doneWhen: "색이 짙어지고 고소한 냄새가 나면",
                           tip: "한 번 볶아 신맛 날리기"),
                RecipeStep(id: "tc-cream", name: "크림 붓고 약불로 줄이기", emoji: "🥛",
                           lane: "소스팬", role: .action, duration: 30,
                           detail: ["생크림 200ml를 붓고 고루 섞기", "불을 약하게 — 끓이면 분리됩니다"],
                           tip: "섞고 불을 낮추면 1분 30초 졸입니다"),
                RecipeStep(id: "tc-simmer", name: "크림 뭉근히 졸이기", emoji: "🫕",
                           lane: "소스팬", role: .cook, duration: 90,
                           detail: ["아주 약한 불에서 뭉근하게", "끓이지 말 것"],
                           doneWhen: "주걱으로 그었을 때 자국이 잠깐 남으면",
                           tip: "아주 약한 simmer — 끓이지 말 것"),
                RecipeStep(id: "tc-finish", name: "면 넣고 버무려 마무리", emoji: "🌀",
                           lane: "소스팬", role: .action, duration: 120,
                           trigger: .after("tc-reserve"),
                           deadline: true,
                           detail: ["건진 면을 소스에 넣고 1분", "면수로 농도 조절 — 주르륵 흐를 정도"],
                           doneWhen: "소스가 면에 고루 입혀지면",
                           tip: "면수로 농도 조절, 소스에서 1분 마저"),
            ],
        ],
        preps: [
            RecipeStep(id: "tc-prep", name: "재료 꺼내고 팬 올리기", emoji: "🧑‍🍳",
                       lane: Recipe.handsLane, role: .prep, duration: 60,
                       detail: ["파스타 180g(2인분), 양파 1/2개, 마늘 3쪽", "토마토페이스트 2큰술, 생크림 200ml", "파르미지아노 30g, 올리브유 2큰술"],
                       tip: "재료를 한자리에"),
            RecipeStep(id: "tc-onion-prep", name: "양파 채썰기", emoji: "🧅",
                       lane: Recipe.handsLane, role: .prep, duration: 135,
                       detail: ["양파 1/2개를 잘게 채썰기", "결 반대로 썰면 더 빨리 물러요"],
                       tip: "잘게 — 급할 것 없습니다"),
            RecipeStep(id: "tc-garlic-prep", name: "마늘 다지기", emoji: "🧄",
                       lane: Recipe.handsLane, role: .prep, duration: 90,
                       detail: ["마늘 3쪽을 곱게 다지기"],
                       tip: "곱게 다지기"),
            RecipeStep(id: "tc-mise", name: "치즈 갈고 소스 재료 계량", emoji: "🧀",
                       lane: Recipe.handsLane, role: .prep, duration: 200,
                       detail: ["파르미지아노 30g 갈아두기", "생크림 200ml, 토마토페이스트 2큰술 미리 계량", "소금·후추도 손 닿는 곳에"],
                       tip: "소스 시작 전에 해두면 편합니다"),
            RecipeStep(id: "tc-plate", name: "접시 데우고 옮길 준비", emoji: "🍽️",
                       lane: Recipe.handsLane, role: .prep, duration: 30,
                       detail: ["접시를 뜨거운 물로 데우기", "남은 치즈와 후추를 옆에 준비"],
                       tip: "언제 해도 되는 일"),
        ],
        source: "RecipeTin Eats · The Burnt Butter Table"
    )

    static let all: [Recipe] = [aglioOlio, tomatoCream]
}
