import SwiftUI

// MARK: - 조리 중: 병렬 작업 타임라인 (이 앱의 심장)
//
// 배치: [상단바] · [지금 할 일 슬림 스트립] · [가로 간트 — 히어로] · [체크리스트] · [컨트롤]
// 가로 간트 위를 '지금' 선이 왼→오로 지나간다. 지금 선에 걸친 막대 = 동시에 해야 할 일.

struct CookView: View {
    @ObservedObject var session: CookSession
    @StateObject private var voice = VoiceCue()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    /// 세워 두고 보는 화면이라 기본이 이미 크다 — 여기서 더 키울 수 있다
    @AppStorage("textScale") private var textScaleRaw = TextScale.big.rawValue

    private var textScale: TextScale { TextScale(rawValue: textScaleRaw) ?? .big }
    /// 글자를 키우면 고정 배치로는 다 안 들어간다 — 그때는 전부 스크롤로 내려 보낸다.
    /// (내가 지정한 크기와 기기 설정, 둘 중 하나라도 크면)
    private var stacked: Bool {
        textScale.rawValue >= TextScale.bigger.rawValue || typeSize.isAccessibilitySize
    }

    @State private var showQuitConfirm = false
    @State private var showFinishConfirm = false

    /// 진행 중(러닝/일시정지) — 이때 나가거나 완성 처리하면 타이머가 초기화/종료됨
    private var inProgress: Bool {
        switch session.phase {
        case .running, .paused: return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            if let recipe = session.recipe {
                GeometryReader { geo in
                    // 가로로 길면(아이패드·가로모드) 지금 할 일과 타임라인을 나란히 둔다.
                    // 조리대 위에 눕혀 두면 세로보다 가로가 자연스럽다.
                    let wide = geo.size.width > geo.size.height * 1.1
                    VStack(spacing: 0) {
                        topBar(recipe)
                        if wide {
                            wideBody(recipe)
                        } else {
                            tallBody(recipe)
                        }
                        controls
                    }
                }
            }
        }
        .dynamicTypeSize(textScale.dynamic)
        .onAppear { voice.onNext = { session.advance() } }
        // 요리를 시작해야 듣기 시작한다 (준비 화면에서 마이크를 켤 이유가 없다)
        .onChange(of: session.isActive) { _, active in
            guard active else { return }
            #if DEBUG
            if UserDefaults.standard.string(forKey: "demoRecipe") == nil { voice.start() }
            #else
            voice.start()
            #endif
        }
        .onDisappear { voice.stop() }
        // 실수로 나가서 타이머가 초기화되는 것 방지
        .confirmationDialog("조리를 중단하고 나갈까요?",
                            isPresented: $showQuitConfirm, titleVisibility: .visible) {
            Button("중단하고 나가기", role: .destructive) { dismiss() }
            Button("계속 조리하기", role: .cancel) { }
        } message: {
            Text("타이머가 초기화되고 진행 상황이 사라집니다.")
        }
        // 남은 시간을 버리고 완성 처리하는 것 방지
        .confirmationDialog("완성 처리할까요?",
                            isPresented: $showFinishConfirm, titleVisibility: .visible) {
            Button("완성 처리", role: .destructive) { session.finish() }
            Button("계속 조리하기", role: .cancel) { }
        } message: {
            Text("아직 남은 단계가 있어요. 지금 멈추면 진행 상황이 사라집니다.")
        }
    }

    /// 나가기 요청 — 진행 중이면 확인, 아니면 바로 닫기
    private func requestClose() {
        if inProgress { showQuitConfirm = true } else { dismiss() }
    }

    /// 세로 화면 — 한 스크롤에 담는다. 넘치면 겹치는 대신 스크롤되는 쪽이 옳다.
    private func tallBody(_ recipe: Recipe) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NowStrip(session: session, voice: voice)
                PotBoard(recipe: recipe, session: session)
                timelineAndList(recipe)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 10)
        }
    }

    /// 가로 화면 — 왼쪽은 지금 내 손과 냄비, 오른쪽은 전체 그림.
    /// 둘은 따로 스크롤되어, 타임라인을 훑어도 할 일이 사라지지 않는다.
    private func wideBody(_ recipe: Recipe) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    NowStrip(session: session, voice: voice)
                    PotBoard(recipe: recipe, session: session)
                }
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    timelineAndList(recipe)
                }
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    @ViewBuilder private func timelineAndList(_ recipe: Recipe) -> some View {
        GanttTimeline(recipe: recipe, session: session)
        StepChecklist(recipe: recipe, session: session)
        if let src = recipe.source {
            Text("참고 · \(src)")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
    }

    // MARK: 상단 바 — 이름 · 진행 시간 · 완성 예정 시각

    private func topBar(_ recipe: Recipe) -> some View {
        // 한 줄에 모은다 — 화면은 요리에 쓰고, 머리말에는 최소한만
        Group {
            if stacked {
                VStack(spacing: 6) {
                    HStack {
                        closeButton
                        Spacer()
                        Text(recipe.emoji).font(.title3)
                        Spacer()
                        textSizeMenu
                    }
                    HStack(spacing: 10) { timeChips }
                }
            } else {
                HStack(spacing: 10) {
                    closeButton
                    timeChips
                    textSizeMenu
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var closeButton: some View {
        Button { requestClose() } label: {
            Image(systemName: "chevron.down")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 36, height: 36)
        }
    }

    /// 진행과 완성 예정은 같은 무게의 정보다 — 칸도 글자도 같은 크기로
    @ViewBuilder private var timeChips: some View {
        // 글자 대신 기호로 — 무엇을 세는 시간인지 한눈에
        timeChip(symbol: "stopwatch", label: "진행 시간",
                 value: formatSeconds(session.cookingElapsed),
                 tint: Theme.ink)
        timeChip(symbol: "fork.knife", label: "완성 예정 시각",
                 value: session.phase == .done ? "✓" : session.finishClock,
                 tint: session.phase == .done ? Theme.green : Theme.terracotta)
    }

    /// 글자 크기 — 세워 둔 거리에 맞춰 사용자가 직접 키운다
    private var textSizeMenu: some View {
        Menu {
            Picker("글자 크기", selection: $textScaleRaw) {
                ForEach(TextScale.allCases) { scale in
                    Text(scale.label).tag(scale.rawValue)
                }
            }
        } label: {
            Image(systemName: "textformat.size")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 40, height: 40)
        }
    }

    private func timeChip(symbol: String, label: String,
                          value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.inkSoft)
                .accessibilityLabel(label)
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.heavy))
                .contentTransition(.identity)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)   // 줄이더라도 자르지는 않는다
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            Capsule().fill(Theme.card)
                .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))
        )
    }

    // MARK: 하단 컨트롤

    private var controls: some View {
        Group {
            if session.isReady {
                startButton
            } else if session.phase == .done {
                doneButton
            } else if stacked {
                // 글자가 크면 두 줄로 — 큰 버튼 하나가 아래를 차지한다
                VStack(spacing: 8) {
                    HStack(spacing: 10) { secondaryControls }
                    primaryControl
                }
            } else {
                HStack(spacing: 12) {
                    secondaryControls
                    primaryControl
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Theme.cream.shadow(color: .black.opacity(0.05), radius: 6, y: -3))
    }

    private var startButton: some View {
        Button { session.begin() } label: {
            Label("요리 시작", systemImage: "play.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(FilledButton(tint: Theme.terracotta))
    }

    private var doneButton: some View {
        Button { dismiss() } label: {
            Label("완료", systemImage: "checkmark").frame(maxWidth: .infinity)
        }
        .buttonStyle(FilledButton(tint: Theme.green))
    }

    /// 마이크와 일시정지 — 자주 누르지 않는 것들
    @ViewBuilder private var secondaryControls: some View {
        MicButton(voice: voice)
        if session.isActive {
            Button { session.pause() } label: {
                Label("일시정지", systemImage: "pause.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButton(tint: Theme.inkSoft))
        } else {
            Button { session.resume() } label: {
                Label("재개", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButton(tint: Theme.terracotta))
        }
    }

    /// 이 화면에서 제일 많이 누르는 버튼
    @ViewBuilder private var primaryControl: some View {
        if session.isLastStage {
            Button { showFinishConfirm = true } label: {
                Label("완성 처리", systemImage: "flag.checkered").frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButton(tint: Theme.terracotta))
        } else {
            Button { session.advance() } label: {
                Label("다음", systemImage: "arrow.right").frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButton(tint: Theme.terracotta))
        }
    }
}

/// 음성 듣기 토글 — 손이 젖어 있을 때를 위한 것이라, 끄고 켜는 게 늘 보여야 한다
struct MicButton: View {
    @ObservedObject var voice: VoiceCue

    var body: some View {
        Button { voice.toggle() } label: {
            Image(systemName: voice.isListening ? "mic.fill" : "mic.slash.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(voice.isListening ? .white : Theme.inkSoft)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(voice.isListening ? Theme.green : Theme.ringTrack)
                )
        }
        .disabled(voice.state == .denied || voice.state == .unavailable)
        .opacity(voice.state == .denied || voice.state == .unavailable ? 0.4 : 1)
    }
}

struct FilledButton: ButtonStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - 지금 할 일 (슬림 스트립) — 병렬이면 알약이 나란히

struct NowStrip: View {
    @ObservedObject var session: CookSession
    @ObservedObject var voice: VoiceCue
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if session.isReady {
                header("시작하면 이것부터")
                if let first = session.firstStep {
                    titleText(first)
                    if let tip = first.tip {
                        Label(tip, systemImage: first.icon)
                            .font(.body)
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("아래 요리 시작을 누르면 냄비 시계가 돕니다")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else if session.phase == .done {
                header("지금 할 일")
                Text("완성됐어요 🍴 접시에 담으세요")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(Theme.ink)
            } else if let due = session.dueAction {
                // 냄비가 부른다 — 미룰 수 없는 일
                header(session.isOverdue(due) ? "늦었어요 · 지금 바로"
                       : (due.deadline ? "지금 · 미룰 수 없어요" : "지금 할 일"))
                fixedRow(due)
                // 하던 도마 일은 사라지지 않는다 — 끝나면 이어서
                if let flex = session.currentPrep, session.progress(of: flex) > 0 {
                    Divider().overlay(Theme.cardBorder)
                    Label("하던 일 · \(flex.emoji) \(flex.name) — 이것부터 하고 이어서",
                          systemImage: "arrow.uturn.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let flex = session.currentPrep {
                // 도마 일 — 급할 게 없다
                header("지금 할 일 · 천천히 해도 돼요")
                flexibleRow(flex)
                if let next = session.upNext {
                    Divider().overlay(Theme.cardBorder)
                    Label("다음 · \(next.emoji) \(next.name)", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                header("지금 할 일")
                Text("손은 다 했어요 — 냄비만 기다리면 돼요")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                if let next = session.nextAction {
                    Label("다음 · \(next.emoji) \(next.name)", systemImage: "hourglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(urgency.fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(urgency.border, lineWidth: urgency == .calm ? 1 : 2)
                )
        )
        .animation(.easeInOut(duration: 0.35), value: urgency)
    }

    /// 카드 색 = 얼마나 급한가. 색만 봐도 지금 뛰어야 하는지 알 수 있게.
    private var urgency: Urgency {
        if session.isReady { return .calm }
        if session.phase == .done { return .finished }
        guard let due = session.dueAction else { return .calm }
        if session.isOverdue(due) { return .late }
        return due.deadline ? .now : .soon
    }

    enum Urgency {
        case calm      // 도마 일 — 천천히 해도 된다
        case soon      // 내가 할 냄비 동작 — 지금이지만 급하진 않다
        case now       // 미루면 상한다
        case late      // 이미 늦었다
        case finished

        var fill: Color {
            switch self {
            case .calm:     return Theme.green.opacity(0.12)
            case .soon:     return Theme.mustard.opacity(0.18)
            case .now:      return Theme.terracotta.opacity(0.20)
            case .late:     return Theme.brick.opacity(0.30)
            case .finished: return Theme.green.opacity(0.18)
            }
        }

        var border: Color {
            switch self {
            case .calm:     return Theme.green.opacity(0.35)
            case .soon:     return Theme.mustard.opacity(0.7)
            case .now:      return Theme.terracotta
            case .late:     return Theme.brick
            case .finished: return Theme.green.opacity(0.7)
            }
        }

        var accent: Color {
            switch self {
            case .calm:     return Theme.green
            case .soon:     return Theme.mustard
            case .now:      return Theme.terracotta
            case .late:     return Theme.brick
            case .finished: return Theme.green
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(urgency == .calm ? Theme.inkSoft : urgency.accent)
            .textCase(.uppercase)
    }

    /// 냄비에 매인 일 — 시간이 됐으니 지금 해야 한다
    private func fixedRow(_ step: RecipeStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow(step)
            ProgressBar(fraction: Pace.eased(step.duration > 0
                                             ? 1 - Double(session.countdown(for: step))
                                                 / Double(step.duration)
                                             : 1),
                        tint: urgency.accent)
            details(step)
            hint(done: "다 했으면")
        }
    }

    /// 이모지 · 이름 · 보통 얼마나 걸리는 일인지
    private func titleRow(_ step: RecipeStep) -> some View {
        // 이름은 폭을 다 쓰고, '보통 2분'은 그 아래. 옆에 붙이면 이름이 잘게 쪼개진다.
        VStack(alignment: .leading, spacing: 2) {
            titleText(step)
            usualDuration(step)
        }
    }

    private func titleText(_ step: RecipeStep) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(step.emoji).font(.title)
            Text(step.name)
                .font(.title.weight(.heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 줄어드는 숫자가 아니라, 원래 이만큼 걸리는 일이라는 표시
    private func usualDuration(_ step: RecipeStep) -> some View {
        Text("보통 \(koreanDuration(step.duration))")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize()
    }

    /// 어떻게 하는가 — 분량·두께·불 세기, 그리고 무엇을 보면 다 된 것인지
    @ViewBuilder private func details(_ step: RecipeStep) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(step.detail, id: \.self) { line in
                HStack(alignment: .top, spacing: 7) {
                    Circle().fill(Theme.inkSoft.opacity(0.5))
                        .frame(width: 5, height: 5)
                        .padding(.top, 9)
                    Text(line)
                        .font(.body)
                        .foregroundStyle(Theme.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if step.detail.isEmpty, let tip = step.tip {
                Label(tip, systemImage: step.icon)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let done = step.doneWhen {
                Label(done, systemImage: "checkmark.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(urgency.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 도마 일 — 끊겨도 이어서 하는 일. 막대는 내가 한 만큼만 찬다.
    private func flexibleRow(_ step: RecipeStep) -> some View {
        let did = session.progress(of: step)
        return VStack(alignment: .leading, spacing: 8) {
            titleRow(step)
            if session.interrupted.contains(step.id) && did < step.duration {
                Label("아까 하던 데서 이어서", systemImage: "arrow.uturn.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.inkSoft)
            }
            ProgressBar(fraction: Pace.eased(step.duration > 0
                                             ? Double(did) / Double(step.duration) : 1),
                        tint: Theme.green)
            details(step)
            hint(done: session.isWaitingForNext ? "다 했으면" : "다 하면")
        }
    }

    /// 말로 넘길 수 있을 때만 안내한다 (버튼은 바로 아래 있으니까)
    @ViewBuilder private func hint(done: String) -> some View {
        if voice.isListening {
            Label("\(done) \"다음\"이라고 말해 주세요", systemImage: "waveform")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(urgency.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 조급하지 않은 시간 표현 — 숫자를 세지 않는다
enum Pace {
    /// 차오르는 속도: 처음엔 쭉, 뒤로 갈수록 점점 천천히
    static func eased(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return 1 - pow(1 - x, 2.4)
    }

    static func phrase(remaining: Int, step: RecipeStep) -> String {
        if step.deadline { return "미루면 안 되는 일이에요" }
        if step.role == .action { return "끝나면 알려 주세요" }
        switch remaining {
        case ..<20:  return "거의 다 됐어요"
        case ..<60:  return "슬슬 마무리해도 돼요"
        case ..<180: return "천천히 해도 됩니다"
        default:     return "여유 있어요"
        }
    }
}

/// 차오르는 막대 — 줄어드는 숫자보다 마음이 편하다. 다 차면 그대로 멈춘다.
struct ProgressBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ringTrack)
                Capsule().fill(tint)
                    .frame(width: max(4, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
        .animation(.linear(duration: 0.5), value: fraction)
    }
}

// MARK: - 냄비 상태 — 지금 할 일(내 손) 아래, 냄비마다 한 줄씩
//
// '지금 할 일'은 내 손 이야기다. 냄비는 따로 본다.
// 면냄비 → 면 삶는 중, 소스팬 → 비어 있음. 냄비는 반드시 지켜야 하는 시계라
// 여기서는 남은 시간을 숨기지 않는다 — 네모가 줄어드는 만큼이 남은 시간이다.

struct PotBoard: View {
    let recipe: Recipe
    @ObservedObject var session: CookSession

    private let gap: CGFloat = 12
    /// 칸 높이 — 폭을 재지도, 비율로 계산하지도 않는다(스크롤 안에서는 둘 다 제자리를 못 찾는다).
    /// 글자 크기에 따라 같이 커지는 고정값이라 화면이 어떤 크기든 배치가 흔들리지 않는다.
    /// 최소 높이만 정하고, 글이 길어지면 칸이 따라 커진다 (높이를 못 박으면 글이 잘린다)
    @ScaledMetric(relativeTo: .title3) private var tileMinHeight: CGFloat = 84

    var body: some View {
        HStack(alignment: .top, spacing: gap) {
            ForEach(session.potStates) { pot in
                PotTile(pot: pot, color: recipe.color(for: pot.lane))
                    .frame(maxWidth: .infinity, minHeight: tileMinHeight, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 냄비 한 칸 — 낮고 넓게. 네모가 줄어드는 만큼이 남은 시간이다.
struct PotTile: View {
    let pot: CookSession.PotState
    let color: Color

    @ScaledMetric(relativeTo: .title3) private var markerSide: CGFloat = 34

    private var isLive: Bool { pot.kind == .cooking || pot.kind == .handsOn }

    var body: some View {
        HStack(spacing: 10) {
            marker
                .frame(width: markerSide, height: markerSide)

            VStack(alignment: .leading, spacing: 1) {
                Text(pot.lane)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(pot.text)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isLive ? Theme.ink : Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                // 냄비는 반드시 지켜야 하는 시계라, 여기서는 남은 시간을 숨기지 않는다
                if pot.kind == .cooking {
                    Text(formatSeconds(pot.remaining))
                        .font(.system(.title3, design: .monospaced).weight(.heavy))
                        .contentTransition(.identity)
                        .foregroundStyle(pot.remaining <= 30 ? Theme.terracotta : Theme.ink)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isLive ? color.opacity(0.14) : Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isLive ? color.opacity(0.45) : Theme.cardBorder,
                                lineWidth: isLive ? 1.5 : 1)
                )
        )
    }

    @ViewBuilder private var marker: some View {
        switch pot.kind {
        case .cooking:
            ShrinkingSquare(fraction: pot.total > 0
                            ? Double(pot.remaining) / Double(pot.total) : 0,
                            color: color)
        case .handsOn:
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color)
                .overlay(Image(systemName: "hand.raised.fill")
                    .font(.footnote).foregroundStyle(.white))
        case .finished:
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.opacity(0.25))
                .overlay(Image(systemName: "checkmark")
                    .font(.footnote.weight(.bold)).foregroundStyle(color))
        case .empty:
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Theme.cardBorder, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        }
    }
}

/// 남은 만큼만 남는 네모 — 다 줄어들면 그 순간이 마감
struct ShrinkingSquare: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let inner = side * max(0.06, min(max(fraction, 0), 1))
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
                    .frame(width: side, height: side)
                RoundedRectangle(cornerRadius: max(2, 6 * inner / max(side, 1)),
                                 style: .continuous)
                    .fill(color)
                    .frame(width: inner, height: inner)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.linear(duration: 0.5), value: fraction)
        }
    }
}

// MARK: - 타임라인 공통 계산 — 막대 폭·마커·스크롤 폭

enum TimelineMetrics {
    static let markerPx: CGFloat = 26     // 순간·짧은 작업은 고정 마커
    static let laneHeight: CGFloat = 52
    static let subRowHeight: CGFloat = 30
    static let subRowSpacing: CGFloat = 4
    static let lanePadding: CGFloat = 5
    static let labelColumn: CGFloat = 46

    /// 순간/아주 짧은 작업은 비율 막대 대신 고정 마커로
    static func isMarker(_ step: RecipeStep) -> Bool {
        step.duration <= 45
    }

    /// 이름이 잘리지 않으려면 막대가 이만큼은 돼야 한다 (추정치).
    /// scale은 글자 크기 배율 — 글자를 키우면 필요한 폭도 같이 커진다.
    static func labelPx(_ step: RecipeStep, scale: CGFloat = 1) -> CGFloat {
        let text = step.name.reduce(CGFloat(0)) { acc, ch in
            acc + (ch.unicodeScalars.first.map { $0.value > 0x1100 } == true ? 11 : 6)
        }
        return (text + 44) * scale   // 이모지/체크 + 좌우 여백
    }

    /// 가장 좁은 막대도 이름이 다 보이도록 트랙을 넓힌다 (넘치면 가로 스크롤)
    static func trackWidth(_ recipe: Recipe, _ plan: Plan,
                           viewport: CGFloat, scale: CGFloat = 1) -> CGFloat {
        let total = CGFloat(max(1, plan.total))
        var need = max(viewport, 1)
        for step in recipe.steps where !isMarker(step) && step.duration > 0 {
            need = max(need, labelPx(step, scale: scale) * total / CGFloat(step.duration))
        }
        return min(need, max(viewport, 1) * 16)   // 무한정 길어지지는 않게
    }

    /// 픽셀 기준 배치 — 화면에서 겹치는 막대는 아래 줄로 내린다
    struct Placed: Identifiable {
        let step: RecipeStep
        let x: CGFloat
        let width: CGFloat
        let row: Int
        let compact: Bool
        var id: String { step.id }
    }

    static func place(_ steps: [RecipeStep], plan: Plan, total: CGFloat,
                      width: CGFloat) -> (items: [Placed], rows: Int) {
        let spans = steps.map { step -> (RecipeStep, CGFloat, CGFloat, Bool) in
            let s = plan.span(step.id)
            let marker = isMarker(step)
            let w = marker ? markerPx
                           : max(8, width * CGFloat(max(1, s.end - s.start)) / total)
            // 끝에 붙은 마커가 트랙 밖으로 삐져나가지 않게
            let x = min(width * CGFloat(s.start) / total, width - w)
            return (step, x, w, marker)
        }
        // 먼저 시작 → 같으면 긴 막대가 윗줄을 차지
        .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.2 > $1.2 }

        var rowEnds: [CGFloat] = []
        var items: [Placed] = []
        for (step, x, w, marker) in spans {
            // 맞닿는 건 허용(0.5px 오차), 파고드는 것만 겹침으로 본다
            let row = rowEnds.firstIndex { $0 <= x + 0.5 } ?? rowEnds.count
            if row == rowEnds.count { rowEnds.append(x + w) } else { rowEnds[row] = x + w }
            items.append(Placed(step: step, x: x, width: w, row: row, compact: marker))
        }
        return (items, max(1, rowEnds.count))
    }

    static func height(rows: Int) -> CGFloat {
        rows <= 1 ? laneHeight
            : CGFloat(rows) * subRowHeight + CGFloat(rows - 1) * subRowSpacing + lanePadding * 2
    }

    static func barHeight(rows: Int) -> CGFloat {
        rows <= 1 ? laneHeight - lanePadding * 2 : subRowHeight
    }
}

/// 일정 간격 눈금 — 트랙이 넓어져도 화면마다 시간이 보인다
struct TimelineTicks: View {
    let totalSeconds: Int
    let width: CGFloat

    /// 눈금 간격: 화면상 70px 이상 벌어지는 가장 촘촘한 단위
    private var interval: Int {
        let total = CGFloat(max(1, totalSeconds))
        for candidate in [30, 60, 120, 300, 600] where width * CGFloat(candidate) / total >= 70 {
            return candidate
        }
        return max(30, totalSeconds / 4)
    }

    var body: some View {
        let total = CGFloat(max(1, totalSeconds))
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: width, height: 14)
            ForEach(Array(stride(from: 0, through: totalSeconds, by: interval)), id: \.self) { t in
                Text(formatSeconds(t))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize()
                    .padding(.leading, min(width * CGFloat(t) / total, max(0, width - 34)))
            }
        }
        .frame(width: width, height: 14, alignment: .topLeading)
    }
}

/// '지금' 위치를 화면 안에 붙잡아 두는 가로 스크롤 (넓은 트랙에서도 지금이 보이게)
///
/// 앵커는 반드시 콘텐츠 계층 '안'에 있어야 한다 — overlay 안에 둔 앵커는
/// ScrollViewReader가 찾지 못해 scrollTo가 조용히 무시된다.
struct NowFollowingScroll<Content: View>: View {
    @ObservedObject var session: CookSession
    let nowX: CGFloat
    let width: CGFloat
    @ViewBuilder let content: () -> Content

    private let buckets = 60

    private var bucket: Int {
        guard width > 0 else { return 0 }
        let i = Int(nowX / width * CGFloat(buckets))
        return min(max(i, 0), buckets - 1)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 스크롤 목표 격자 — 지금이 속한 칸으로 따라간다
                    HStack(spacing: 0) {
                        ForEach(0..<buckets, id: \.self) { i in
                            Color.clear
                                .frame(width: width / CGFloat(buckets), height: 0.5)
                                .id(i)
                        }
                    }
                    content()
                }
            }
            .onAppear { proxy.scrollTo(bucket, anchor: .center) }
            .onChange(of: bucket) { _, target in
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
            .onChange(of: width) { _, _ in proxy.scrollTo(bucket, anchor: .center) }
        }
    }
}

// MARK: - 가로 간트 (레인별) + 움직이는 '지금' 선

struct GanttTimeline: View {
    let recipe: Recipe
    @ObservedObject var session: CookSession

    @State private var viewport: CGFloat = 0

    private let laneSpacing: CGFloat = 8
    private let bubbleWidth: CGFloat = 46
    /// 글자 크기 배율 — 막대 폭을 글자에 맞춰 넓히는 데 쓴다
    @ScaledMetric(relativeTo: .caption2) private var labelScale: CGFloat = 11



    private struct LaneLayout {
        let lane: String
        let items: [TimelineMetrics.Placed]
        let rows: Int
    }

    var body: some View {
        let plan = session.plan
        let total = CGFloat(max(1, plan.total))
        let width = TimelineMetrics.trackWidth(recipe, plan,
                                               viewport: viewport - TimelineMetrics.labelColumn,
                                               scale: labelScale / 11)
        let layouts = recipe.lanes.map { lane -> LaneLayout in
            let p = TimelineMetrics.place(recipe.rowSteps(lane), plan: plan,
                                          total: total, width: width)
            return LaneLayout(lane: lane, items: p.items, rows: p.rows)
        }
        let chartHeight = layouts.map { TimelineMetrics.height(rows: $0.rows) }.reduce(0, +)
            + CGFloat(max(0, layouts.count - 1)) * laneSpacing
        let nowX = width * CGFloat(min(session.elapsed, plan.total)) / total

        VStack(alignment: .leading, spacing: 10) {
            Text("타임라인 · 점선은 미뤄도 되는 일")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)

            HStack(alignment: .top, spacing: 0) {
                // 고정 레인 라벨 (스크롤해도 남음) — 말풍선 줄 높이만큼 내려서 막대와 맞춤
                VStack(spacing: laneSpacing) {
                    ForEach(layouts, id: \.lane) { l in
                        Text(l.lane)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(recipe.color(for: l.lane))
                            .frame(width: TimelineMetrics.labelColumn,
                                   height: TimelineMetrics.height(rows: l.rows),
                                   alignment: .leading)
                    }
                }
                .padding(.top, 16)

                NowFollowingScroll(session: session, nowX: nowX, width: width) {
                    track(width: width, layouts: layouts, chartHeight: chartHeight,
                          nowX: nowX, total: plan.total)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewport = $0 }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }

    /// 스크롤되는 트랙: 말풍선 줄 · 레인 막대 + 지금 선 · 눈금
    private func track(width: CGFloat, layouts: [LaneLayout],
                       chartHeight: CGFloat, nowX: CGFloat, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 경과 시간 말풍선 줄 (양끝 클램프)
            ZStack(alignment: .topLeading) {
                Color.clear.frame(width: width, height: 16)
                if session.phase != .done {
                    Text(formatSeconds(session.elapsed))
                        .font(.caption2.weight(.heavy).monospaced())
                        .contentTransition(.identity)   // 숫자가 겹쳐 보이는 모핑 끄기
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.ink))
                        .offset(x: min(max(nowX - bubbleWidth / 2, 0), width - bubbleWidth))
                        .animation(.linear(duration: 0.5), value: session.elapsed)
                }
            }

            // 레인 막대 + 지금 세로선
            ZStack(alignment: .topLeading) {
                VStack(spacing: laneSpacing) {
                    ForEach(layouts, id: \.lane) { l in
                        laneTrack(l, width: width)
                    }
                }
                if session.phase != .done {
                    Rectangle().fill(Theme.ink)
                        .frame(width: 2.5, height: chartHeight)
                        .offset(x: nowX - 1.25)
                        .animation(.linear(duration: 0.5), value: session.elapsed)
                }
            }
            .frame(width: width, height: chartHeight)

            // 눈금
            TimelineTicks(totalSeconds: total, width: width)
                .padding(.top, 4)
        }
    }

    private func laneTrack(_ l: LaneLayout, width: CGFloat) -> some View {
        let h = TimelineMetrics.height(rows: l.rows)
        let barH = TimelineMetrics.barHeight(rows: l.rows)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.ringTrack.opacity(0.5))
                .frame(width: width, height: h)
            ForEach(l.items) { p in
                StepBar(step: p.step, status: session.status(of: p.step),
                        color: recipe.color(for: l.lane), compact: p.compact)
                    .frame(width: p.width, height: barH)
                    .offset(x: p.x,
                            y: TimelineMetrics.lanePadding
                               + CGFloat(p.row) * (barH + TimelineMetrics.subRowSpacing))
            }
        }
        .frame(width: width, height: h)
    }
}

/// 한 작업 막대 — 진행 상태에 따라 색/투명도/테두리. compact면 이모지만.
struct StepBar: View {
    let step: RecipeStep
    let status: StepStatus
    let color: Color
    var compact: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(status == .active ? Theme.ink : .clear, lineWidth: 2)
            )
            // 점선 = 미룰 수 있는 일(도마), 실선 = 냄비 시간에 매인 일
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(step.isPrep ? color.opacity(0.9) : .clear,
                                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
            .overlay(label)
            .shadow(color: status == .active ? Theme.ink.opacity(0.2) : .clear,
                    radius: 4, y: 2)
    }

    @ViewBuilder private var label: some View {
        if compact {
            Group {
                if status == .done {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                } else {
                    Text(step.emoji).font(.caption2)
                }
            }
            .foregroundStyle(status == .upcoming ? Theme.ink.opacity(0.65) : .white)
        } else {
            HStack(spacing: 3) {
                if status == .done {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold))
                } else {
                    Text(step.emoji).font(.caption2)
                }
                Text(step.name)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)   // 막대 안에서는 줄이되 자르지 않는다
            }
            .foregroundStyle(status == .upcoming ? Theme.ink.opacity(0.65) : .white)
            .padding(.horizontal, 6)
        }
    }

    private var fill: Color {
        switch status {
        case .upcoming: return color.opacity(0.28)
        case .active:   return color
        case .done:     return color.opacity(0.5)
        }
    }
}

// MARK: - 체크리스트 (시간축을 못 볼 때 대비한 텍스트 뷰)

struct StepChecklist: View {
    let recipe: Recipe
    @ObservedObject var session: CookSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let plan = session.plan
            ForEach(Array(recipe.steps.sorted { plan.start($0) < plan.start($1) }.enumerated()),
                    id: \.element.id) { idx, step in
                let status = session.status(of: step)
                HStack(spacing: 10) {
                    Image(systemName: status == .done ? "checkmark.circle.fill"
                          : (status == .active ? "circle.dotted.circle" : "circle"))
                        .font(.body)
                        .foregroundStyle(status == .done ? Theme.green
                                         : (status == .active ? recipe.color(for: step.lane)
                                            : Theme.inkSoft.opacity(0.5)))
                    Text("\(step.emoji) \(step.name)")
                        .font(.subheadline.weight(status == .active ? .bold : .regular))
                        .foregroundStyle(status == .upcoming ? Theme.inkSoft : Theme.ink)
                        .strikethrough(status == .done, color: Theme.inkSoft)
                    Spacer()
                    if step.deadline {
                        Text("못 미룸")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.terracotta)
                    }
                }
                .padding(.vertical, 9)
                if idx < recipe.steps.count - 1 {
                    Divider().overlay(Theme.cardBorder)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }
}
