import AppIntents
import Combine

// MARK: - 단축어 · Siri — "그사이에에서 알리오 올리오 만들기"
//
// 요리 직전엔 손이 바쁘다. Siri 나 단축어로 바로 그 요리의 조리 화면을 연다.
// 열기만 하고 시계는 돌리지 않는다 — 물을 올릴 준비가 됐을 때 '요리 시작'을 누르는 흐름은 그대로다.

/// 단축어에서 고를 수 있는 요리 — rawValue 는 RecipeDB 의 id
enum RecipeChoice: String, AppEnum {
    case aglioOlio = "aglio-olio"
    case tomatoCream = "tomato-cream"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "요리"
    static var caseDisplayRepresentations: [RecipeChoice: DisplayRepresentation] = [
        .aglioOlio: "알리오 올리오",
        .tomatoCream: "토마토 크림 파스타",
    ]
}

struct OpenRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "요리 열기"
    static var description = IntentDescription("고른 요리의 조리 화면을 열어요. 시작 버튼을 누르면 타이머가 돌아요.")
    static var openAppWhenRun = true

    @Parameter(title: "요리")
    var recipe: RecipeChoice

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
}
