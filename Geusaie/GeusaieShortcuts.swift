import AppIntents
import Combine

// MARK: - 단축어 · Siri — "그사이에에서 알리오 올리오 만들기"
//
// 요리 직전엔 손이 바쁘다. Siri 나 단축어로 바로 그 요리의 조리 화면을 연다.
// 열기만 하고 시계는 돌리지 않는다 — 물을 올릴 준비가 됐을 때 '요리 시작'을 누르는 흐름은 그대로다.
//
// Siri · 단축어는 그사이에 Pro 다(페이월 전 빌드를 받은 사람은 그대로 쓴다). Pro 가 아니어도 무료 요리는
// 그대로 열고, 연 다음에 Pro 를 안내한다 — 말한 것이 허공에 사라지지 않게 (→ RecipeListView.openFromShortcut).

/// 단축어에서 고를 수 있는 요리 — rawValue 는 RecipeDB 의 id
enum RecipeChoice: String, AppEnum {
    case aglioOlio = "aglio-olio"
    case tomatoCream = "tomato-cream"
    // 레시피 팩 (Pro). Pro 가 아니면 열지 않고 Pro 안내가 뜬다 (→ RecipeListView.openFromShortcut)
    case kimchiStew = "kimchi-stew"
    case doenjangStew = "doenjang-stew"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "요리"
    static var caseDisplayRepresentations: [RecipeChoice: DisplayRepresentation] = [
        .aglioOlio: "알리오 올리오",
        .tomatoCream: "토마토 크림 파스타",
        .kimchiStew: "김치찌개와 계란말이",
        .doenjangStew: "된장찌개와 애호박전",
    ]
}

struct OpenRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "요리 열기"
    static var description = IntentDescription("고른 요리의 조리 화면을 열어요. 시작 버튼을 누르면 타이머가 돌아요.")
    static var openAppWhenRun = true

    @Parameter(title: "요리", description: "조리 화면을 열 요리")
    var recipe: RecipeChoice

    init() {}

    init(recipe: RecipeChoice) {
        self.recipe = recipe
    }

    /// 목록에서 손으로 요리를 열었을 때 Siri 에 알린다 — 자주 여는 요리를 Siri 가 먼저 떠올린다.
    static func donate(_ recipeID: String) {
        guard let choice = RecipeChoice(rawValue: recipeID) else { return }
        IntentDonationManager.shared.donate(intent: OpenRecipeIntent(recipe: choice))
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        RecipeRouter.shared.pendingRecipeID = recipe.rawValue
        return .result()
    }
}

struct GeusaieShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenRecipeIntent(),
            phrases: [
                "\(.applicationName)에서 \(\.$recipe) 만들기",
                "\(.applicationName)로 \(\.$recipe) 요리하기",
                "\(.applicationName)로 요리하기",
            ],
            shortTitle: "요리 열기",
            systemImageName: "frying.pan"
        )
    }
}

/// 단축어 → 홈 화면으로 '이 요리를 열어 달라'는 요청을 넘기는 곳.
/// 앱이 막 켜지는 중이어도 값이 남아 있다가 홈 화면이 뜨는 순간 처리된다.
@MainActor
final class RecipeRouter: ObservableObject {
    static let shared = RecipeRouter()
    @Published var pendingRecipeID: String?
    /// Pro 가 아닌 사람이 단축어로 요리를 열었다 — 조리 화면이 뜬 뒤 그 위에 Pro 안내를 낸다 (→ CookView)
    @Published var siriPaywall = false
}
