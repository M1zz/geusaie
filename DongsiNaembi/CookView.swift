import SwiftUI

// MARK: - 조리 중: 병렬 작업 타임라인 (이 앱의 심장)
//
// 배치: [상단바] · [지금 할 일 슬림 스트립] · [가로 간트 — 히어로] · [체크리스트] · [컨트롤]
// 가로 간트 위를 '지금' 선이 왼→오로 지나간다. 지금 선에 걸친 막대 = 동시에 해야 할 일.

struct CookView: View {
    @ObservedObject var session: CookSession
    @Environment(\.dismiss) private var dismiss

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
                VStack(spacing: 0) {
                    topBar(recipe)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            NowStrip(session: session)
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
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }
                    controls
                }
            }
        }
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
            Text("아직 \(formatSeconds(session.remaining)) 남았어요. 지금 멈추면 타이머가 종료됩니다.")
        }
    }

    /// 나가기 요청 — 진행 중이면 확인, 아니면 바로 닫기
    private func requestClose() {
        if inProgress { showQuitConfirm = true } else { dismiss() }
    }

    // MARK: 상단 바 — 이름 · 전체 진행률/남은 시간

    private func topBar(_ recipe: Recipe) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button { requestClose() } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Text("\(recipe.emoji) \(recipe.name)")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(session.phase == .done ? "완성 ✓" : formatSeconds(session.remaining))
                    .font(.subheadline.weight(.bold).monospaced())
                    .foregroundStyle(session.phase == .done ? Theme.green : Theme.terracotta)
            }
            // 드래그로 진행 상황을 옮기는 스크러버
            ProgressScrubber(session: session)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: 하단 컨트롤

    private var controls: some View {
        HStack(spacing: 12) {
            if session.phase == .done {
                Button { dismiss() } label: {
                    Label("완료", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledButton(tint: Theme.green))
            } else {
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
                if session.isLastStage {
                    Button { showFinishConfirm = true } label: {
                        Label("완성 처리", systemImage: "flag.checkered").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FilledButton(tint: Theme.terracotta))
                } else {
                    Button { session.endCurrentStage() } label: {
                        Label("단계 종료", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FilledButton(tint: Theme.terracotta))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.cream.shadow(color: .black.opacity(0.05), radius: 6, y: -3))
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

// MARK: - 진행 스크러버 — 드래그하면 타임라인 전체가 그 시점으로 이동

struct ProgressScrubber: View {
    @ObservedObject var session: CookSession
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let total = session.recipe?.totalSeconds ?? 1
            let w = geo.size.width
            let p = total > 0 ? CGFloat(min(session.elapsed, total)) / CGFloat(total) : 0
            let thumb: CGFloat = dragging ? 22 : 16

            ZStack(alignment: .leading) {
                Capsule().fill(Theme.ringTrack).frame(height: 6)
                Capsule().fill(Theme.terracotta)
                    .frame(width: max(6, w * p), height: 6)
                Circle().fill(.white)
                    .overlay(Circle().stroke(Theme.terracotta, lineWidth: 3))
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(x: max(0, min(w - thumb, w * p - thumb / 2)))
            }
            .frame(height: 24)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .animation(dragging ? nil : .linear(duration: 0.5), value: session.elapsed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !dragging { dragging = true; session.beginScrub() }
                        session.updateScrub(toFraction: Double(v.location.x / max(1, w)))
                    }
                    .onEnded { _ in
                        dragging = false
                        session.endScrub()
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
            )
        }
        .frame(height: 24)
    }
}

// MARK: - 지금 할 일 (슬림 스트립) — 병렬이면 알약이 나란히

struct NowStrip: View {
    @ObservedObject var session: CookSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("지금 내 손은")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.inkSoft)
                    .textCase(.uppercase)
                Spacer()
                if let next = session.nextHandsStep, session.phase != .done {
                    Text("곧 · \(next.emoji) \(next.name) · \(formatSeconds(session.countdown(for: next))) 후")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
            }

            let hands = session.activeHandsSteps
            if hands.isEmpty {
                Text(session.phase == .done
                     ? "완성됐어요 🍴 접시에 담으세요"
                     : (session.activePassiveSteps.isEmpty
                        ? "잠깐 대기 — 곧 다음 작업"
                        : "손은 자유 — 걸어둔 게 익는 중"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(hands) { step in
                            ActivePill(step: step,
                                       countdown: session.countdown(for: step),
                                       color: session.recipe?.color(for: step.lane) ?? Theme.terracotta)
                        }
                    }
                }
                if let tip = hands.first?.tip {
                    Label(tip, systemImage: hands.first!.attention.icon)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                }
            }

            // 백그라운드로 돌아가는 것 (걸어둔 것)
            let bg = session.activePassiveSteps
            if !bg.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "hourglass").font(.caption2)
                    Text("걸어둔 것 · " + bg.map {
                        "\($0.emoji) \($0.name) \(formatSeconds(session.countdown(for: $0)))"
                    }.joined(separator: " · "))
                        .lineLimit(1)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
    }
}

struct ActivePill: View {
    let step: RecipeStep
    let countdown: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(step.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3) {
                    Text(step.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    if step.attention == .active {
                        Image(systemName: "flame.fill").font(.caption2)
                    }
                }
                Text(formatSeconds(countdown))
                    .font(.system(.title3, design: .monospaced).weight(.heavy))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Capsule().fill(color))
    }
}

// MARK: - 가로 간트 (히어로) + 움직이는 '지금' 선

struct GanttTimeline: View {
    let recipe: Recipe
    @ObservedObject var session: CookSession

    private let laneHeight: CGFloat = 58
    private let laneSpacing: CGFloat = 10
    private let labelWidth: CGFloat = 40
    private let bubbleWidth: CGFloat = 46
    private let minBarPx: CGFloat = 22    // 이보다 짧아지는 막대가 있으면 가로 스크롤

    private var total: CGFloat { CGFloat(max(1, recipe.totalSeconds)) }

    private var chartHeight: CGFloat {
        CGFloat(recipe.lanes.count) * laneHeight + CGFloat(recipe.lanes.count - 1) * laneSpacing
    }

    /// 막대들이 겹치지 않으려면 필요한 최소 트랙 폭
    /// (가장 짧은 작업이 minBarPx 이상이 되도록)
    private var requiredTrackWidth: CGFloat {
        let minDur = CGFloat(recipe.steps.map(\.duration).min() ?? recipe.totalSeconds)
        guard minDur > 0 else { return 0 }
        return minBarPx * total / minDur
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.and.right")
                Text("동시 진행 타임라인")
                Spacer()
                Text("겹치는 구간 = 병렬")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.inkSoft)
            .textCase(.uppercase)

            GeometryReader { geo in
                let viewport = geo.size.width - labelWidth
                // 칸이 모자라면 넓혀서 가로 스크롤, 넉넉하면 화면에 딱 맞춤
                let content = max(viewport, requiredTrackWidth)

                HStack(alignment: .top, spacing: 0) {
                    // 고정 레인 라벨 (스크롤해도 남음)
                    VStack(spacing: laneSpacing) {
                        ForEach(recipe.lanes, id: \.self) { lane in
                            Text(lane)
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(recipe.color(for: lane))
                                .frame(width: labelWidth, height: laneHeight, alignment: .leading)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: content > viewport) {
                        track(width: content)
                    }
                }
            }
            .frame(height: chartHeight + 16 + 18)   // 말풍선 줄 + 눈금 줄 포함
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
    private func track(width: CGFloat) -> some View {
        let elapsed = CGFloat(min(session.elapsed, recipe.totalSeconds))
        let nowX = width * elapsed / total

        return VStack(alignment: .leading, spacing: 0) {
            // 경과 시간 말풍선 줄 (양끝 클램프)
            ZStack(alignment: .topLeading) {
                Color.clear.frame(width: width, height: 16)
                if session.phase != .done {
                    Text(formatSeconds(session.elapsed))
                        .font(.caption2.weight(.heavy).monospaced())
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
                    ForEach(recipe.lanes, id: \.self) { lane in
                        laneTrack(lane, width: width)
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
            HStack(spacing: 0) {
                ForEach(0...4, id: \.self) { i in
                    Text(formatSeconds(recipe.totalSeconds * i / 4))
                    if i < 4 { Spacer() }
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
            .frame(width: width)
            .padding(.top, 4)
        }
    }

    private func laneTrack(_ lane: String, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.ringTrack.opacity(0.5))
                .frame(width: width, height: laneHeight)
            ForEach(recipe.steps.filter { $0.lane == lane }) { step in
                StepBar(step: step, status: session.status(of: step),
                        color: recipe.color(for: lane))
                    .frame(width: max(6, width * CGFloat(step.duration) / total),
                           height: laneHeight - 10)
                    .offset(x: width * CGFloat(step.startAt) / total)
            }
        }
        .frame(width: width, height: laneHeight)
    }
}

/// 한 작업 막대 — 진행 상태에 따라 색/투명도/테두리
struct StepBar: View {
    let step: RecipeStep
    let status: StepStatus
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(status == .active ? Theme.ink : .clear, lineWidth: 2)
            )
            .overlay(
                VStack(spacing: 1) {
                    HStack(spacing: 3) {
                        if status == .done {
                            Image(systemName: "checkmark").font(.caption2.weight(.bold))
                        } else {
                            Text(step.emoji).font(.caption2)
                        }
                        Text(step.name)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .foregroundStyle(status == .upcoming ? Theme.ink.opacity(0.65) : .white)
                .padding(.horizontal, 6)
            )
            .shadow(color: status == .active ? Theme.ink.opacity(0.2) : .clear,
                    radius: 4, y: 2)
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
            ForEach(Array(recipe.steps.sorted { $0.startAt < $1.startAt }.enumerated()),
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
                    Text("\(formatSeconds(step.startAt))–\(formatSeconds(step.end))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(Theme.inkSoft)
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
