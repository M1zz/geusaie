import XCTest
@testable import Geusaie

// 시간표(Plan)는 이 앱의 심장이다. 화면은 이 계산을 그대로 그리기만 하므로,
// 여기서 틀리면 사용자는 면이 퍼진 뒤에야 안다.

final class RecipeDataTests: XCTestCase {

    /// 냄비가 혼자 도는 시간 앞에는 반드시 '불 켜기' 같은 사람의 시작 동작이 있어야 한다
    func testEveryCookHasAStarterAction() {
        for recipe in RecipeDB.all {
            XCTAssertTrue(recipe.unstartedCooks.isEmpty,
                          "\(recipe.id): 시작 동작 없는 냄비 일 \(recipe.unstartedCooks.map(\.id))")
        }
    }

    /// 트리거가 가리키는 일이 실제로 레시피 안에 있어야 한다 (없으면 그 사슬이 영영 안 잡힌다)
    func testTriggersReferToExistingSteps() {
        for recipe in RecipeDB.all {
            let ids = Set(recipe.steps.map(\.id))
            XCTAssertEqual(ids.count, recipe.steps.count, "\(recipe.id): 같은 id 가 둘 이상")
            for step in recipe.steps {
                switch step.trigger {
                case .atStart: break
                case .after(let ref), .endingWith(let ref):
                    XCTAssertTrue(ids.contains(ref), "\(recipe.id)/\(step.id) → 없는 일 \(ref)")
                }
            }
        }
    }

    func testChainsMatchPotLanes() {
        for recipe in RecipeDB.all {
            XCTAssertEqual(recipe.chains.count, recipe.potLanes.count, recipe.id)
            for (lane, chain) in zip(recipe.potLanes, recipe.chains) {
                XCTAssertTrue(chain.allSatisfy { $0.lane == lane }, "\(recipe.id): \(lane) 사슬에 다른 냄비 일")
            }
            XCTAssertTrue(recipe.preps.allSatisfy(\.isPrep), "\(recipe.id): 도마 일 목록에 냄비 일")
        }
    }

    /// 단축어가 고르는 요리는 레시피 DB 에 실제로 있어야 한다
    func testShortcutChoicesExistInRecipeDB() {
        let ids = Set(RecipeDB.all.map(\.id))
        for choice in RecipeChoice.allCases {
            XCTAssertTrue(ids.contains(choice.rawValue), "단축어 요리 \(choice.rawValue) 가 DB 에 없다")
        }
    }
}

final class PlanTests: XCTestCase {

    /// 아무것도 안 한 상태의 계획 — 모든 일이 잡히고, 사슬은 순서대로 이어진다
    func testPreviewPlanSchedulesEveryStepInOrder() {
        for recipe in RecipeDB.all {
            let plan = recipe.previewPlan
            for step in recipe.steps {
                XCTAssertGreaterThanOrEqual(plan.end(step) - plan.start(step), step.duration,
                                            "\(recipe.id)/\(step.id) 길이가 줄었다")
                XCTAssertLessThanOrEqual(plan.end(step), plan.total, "\(recipe.id)/\(step.id) 가 끝 시각을 넘는다")
            }
            for chain in recipe.chains {
                for (a, b) in zip(chain, chain.dropFirst()) {
                    XCTAssertGreaterThanOrEqual(plan.start(b), plan.end(a),
                                                "\(recipe.id): \(b.id) 가 \(a.id) 끝나기 전에 시작")
                }
            }
        }
    }

    /// 도마 일은 손이 냄비에 가 있는 동안(action)에는 진행되지 않는다
    func testPrepNeverStartsInsideAnAction() {
        for recipe in RecipeDB.all {
            let plan = recipe.previewPlan
            let actions = recipe.steps.filter { $0.role == .action }.map { (plan.start($0), plan.end($0)) }
            for prep in recipe.preps {
                let s = plan.start(prep)
                for (a, b) in actions where a < b {
                    XCTAssertFalse(a <= s && s < b, "\(recipe.id)/\(prep.id) 가 냄비 일 도중에 시작")
                }
            }
        }
    }

    /// '그 일이 끝나면 이어서' — after 트리거는 참조한 일이 끝난 뒤에 시작한다
    func testAfterTriggerWaitsForReference() {
        for recipe in RecipeDB.all {
            let plan = recipe.previewPlan
            for step in recipe.steps {
                if case .after(let ref) = step.trigger, let r = recipe.step(ref) {
                    XCTAssertGreaterThanOrEqual(plan.start(step), plan.end(r), "\(recipe.id)/\(step.id)")
                }
            }
        }
    }

    /// 첫 냄비 동작을 늦게 하면 그 냄비의 뒤따르는 일도 같이 밀린다 — 실제 부엌처럼
    func testLateStartPushesTheChain() {
        let recipe = RecipeDB.aglioOlio
        guard let chain = recipe.chains.first, let first = chain.first, chain.count > 1 else {
            return XCTFail("면냄비 사슬이 없다")
        }
        let base = recipe.previewPlan
        let delay = 180

        var state = CookState()
        state.now = base.start(first) + delay
        state.startedAt[first.id] = base.start(first) + delay
        state.doneAt[first.id] = base.start(first) + delay + first.duration
        let late = Plan(recipe, state)

        let next = chain[1]
        XCTAssertEqual(late.start(next) - base.start(next), delay, "다음 일이 늦은 만큼 밀리지 않았다")
        XCTAssertGreaterThanOrEqual(late.total, base.total + delay)
    }

    /// 손이 노는 시간은 0 이상, 전체 시간 이하
    func testHandsIdleIsWithinTotal() {
        for recipe in RecipeDB.all {
            XCTAssertGreaterThanOrEqual(recipe.handsIdleSeconds, 0)
            XCTAssertLessThanOrEqual(recipe.handsIdleSeconds, recipe.estimatedSeconds)
        }
    }
}

final class HelperTests: XCTestCase {

    func testFormatSeconds() {
        XCTAssertEqual(formatSeconds(0), "0:00")
        XCTAssertEqual(formatSeconds(65), "1:05")
        XCTAssertEqual(formatSeconds(3600), "1:00:00")
        XCTAssertEqual(formatSeconds(3725), "1:02:05")
        XCTAssertEqual(formatSeconds(-5), "0:00")
    }

    func testPaceEasedIsMonotonicAndClamped() {
        XCTAssertEqual(Pace.eased(-1), 0)
        XCTAssertEqual(Pace.eased(0), 0)
        XCTAssertEqual(Pace.eased(1), 1)
        XCTAssertEqual(Pace.eased(2), 1)
        var last = -1.0
        for i in 0...20 {
            let v = Pace.eased(Double(i) / 20)
            XCTAssertGreaterThanOrEqual(v, last)
            last = v
        }
        // 처음엔 쭉 차오른다 — 절반 시점에 절반보다 많이
        XCTAssertGreaterThan(Pace.eased(0.5), 0.5)
    }

    @MainActor
    func testHearsNextOnlyAtTheEnd() {
        XCTAssertTrue(VoiceCue.hearsNext("다음"))
        XCTAssertTrue(VoiceCue.hearsNext("자 이제 다음"))
        XCTAssertTrue(VoiceCue.hearsNext("다음 단계"))
        // 앞에서 한 번 나온 '다음'이 계속 걸리면 안 된다
        XCTAssertFalse(VoiceCue.hearsNext("다음 거 하기 전에 물 좀 더 넣고"))
        XCTAssertFalse(VoiceCue.hearsNext(""))
    }

    @MainActor
    func testHearsNextInTheAppLanguage() {
        XCTAssertTrue(VoiceCue.hearsNext("OK next", language: "en"))
        XCTAssertTrue(VoiceCue.hearsNext("Next", language: "en-GB"))
        XCTAssertTrue(VoiceCue.hearsNext("und weiter", language: "de"))
        XCTAssertTrue(VoiceCue.hearsNext("Proximo", language: "pt-BR"))
        XCTAssertTrue(VoiceCue.hearsNext("次へ", language: "ja"))
        XCTAssertTrue(VoiceCue.hearsNext("下一步", language: "zh-Hans"))
        XCTAssertTrue(VoiceCue.hearsNext("ต่อไป", language: "th"))
        XCTAssertTrue(VoiceCue.hearsNext("tiếp theo", language: "vi"))
        XCTAssertFalse(VoiceCue.hearsNext("next I add the water and then wait", language: "en"))
        XCTAssertFalse(VoiceCue.hearsNext("다음", language: "en"))
        XCTAssertEqual(VoiceCue.speechLocale(for: "zh-Hant"), "zh-TW")
        XCTAssertEqual(VoiceCue.speechLocale(for: "en-GB"), "en-GB")
    }
}
