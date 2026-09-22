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
                            OneLineTimeline(recipe: recipe, session: session)
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
            Text("아직 \(Pace.rough(session.remaining)) 남았어요. 지금 멈추면 타이머가 종료됩니다.")
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
                // 남은 시간이 깎이는 대신 '몇 시에 먹는지' — 숫자가 움직이지 않는다
                Text(session.phase == .done ? "완성 ✓" : "\(session.finishClock) 완성")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(session.phase == .done ? Theme.green : Theme.inkSoft)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("지금 할 일")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)

            if session.phase == .done {
                Text("완성됐어요 🍴 접시에 담으세요")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.ink)
            } else if let step = session.activeHandsSteps.first {
                // 지금 손으로 하는 일 — 이 카드의 전부
                taskRow(step, countdown: session.countdown(for: step), upcoming: false)
                if let tip = step.tip {
                    Label(tip, systemImage: step.attention.icon)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                }
            } else if let next = session.nextHandsStep {
                // 손이 빌 때 — 다음에 할 일 하나만
                taskRow(next, countdown: session.countdown(for: next), upcoming: true)
            } else {
                Text("남은 손 작업 없음 — 마무리만 기다리면 돼요")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(16)
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

    /// 이모지 · 이름 · 여유를 말로. 초를 세지 않는다.
    private func taskRow(_ step: RecipeStep, countdown: Int, upcoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(step.emoji).font(.title2)
                Text(step.name)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text(upcoming ? Pace.rough(countdown) + " 뒤" : Pace.rough(countdown))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Pace.isUrgent(countdown, step.attention) ? Theme.terracotta
                                     : Theme.inkSoft)
            }

            if upcoming {
                Text("지금은 쉬어도 돼요")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                // 남은 초 대신 '이만큼 왔다' — 천천히 차오르기만 한다
                ProgressBar(fraction: step.duration > 0
                            ? 1 - Double(countdown) / Double(step.duration) : 1,
                            tint: Pace.isUrgent(countdown, step.attention)
                            ? Theme.terracotta : Theme.green)
                Text(Pace.phrase(remaining: countdown, attention: step.attention))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

/// 조급하지 않은 시간 표현 — 초를 세는 대신 여유를 말로
enum Pace {
    /// 늦으면 실제로 상하는 일(면 건지기 같은 한 번 동작)만 재촉한다
    static func isUrgent(_ remaining: Int, _ attention: Attention) -> Bool {
        attention == .instant || remaining <= 20
    }

    /// 1초씩 깎이지 않는 대략치
    static func rough(_ seconds: Int) -> String {
        switch seconds {
        case ..<20:  return "곧"
        case ..<45:  return "30초쯤"
        case ..<90:  return "1분쯤"
        default:     return "약 \(Int((Double(seconds) / 60).rounded()))분"
        }
    }

    static func phrase(remaining: Int, attention: Attention) -> String {
        if attention == .instant { return "지금 하세요" }
        switch remaining {
        case ..<20:  return "거의 다 됐어요"
        case ..<60:  return "슬슬 마무리해도 돼요"
        case ..<180: return "천천히 해도 됩니다"
        default:     return "여유 있어요"
        }
    }
}

/// 차오르는 막대 — 줄어드는 숫자보다 마음이 편하다
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

// MARK: - 가로 간트 (히어로) + 움직이는 '지금' 선

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
        step.attention == .instant || step.duration <= 45
    }

    /// 이름이 '…'으로 잘리지 않으려면 막대가 이만큼은 돼야 한다 (추정치)
    static func labelPx(_ step: RecipeStep) -> CGFloat {
        let text = step.name.reduce(CGFloat(0)) { acc, ch in
            acc + (ch.unicodeScalars.first.map { $0.value > 0x1100 } == true ? 11 : 6)
        }
        return text + 44   // 이모지/체크 + 좌우 여백
    }

    /// 가장 좁은 막대도 이름이 다 보이도록 트랙을 넓힌다 (넘치면 가로 스크롤)
    static func trackWidth(_ recipe: Recipe, viewport: CGFloat) -> CGFloat {
        let total = CGFloat(max(1, recipe.totalSeconds))
        var need = max(viewport, 1)
        for step in recipe.steps where !isMarker(step) && step.duration > 0 {
            need = max(need, labelPx(step) * total / CGFloat(step.duration))
        }
        return min(need, max(viewport, 1) * 12)   // 무한정 길어지지는 않게
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

    static func place(_ steps: [RecipeStep], total: CGFloat, width: CGFloat) -> (items: [Placed], rows: Int) {
        let spans = steps.map { step -> (RecipeStep, CGFloat, CGFloat, Bool) in
            let marker = isMarker(step)
            let w = marker ? markerPx : max(8, width * CGFloat(step.duration) / total)
            // 끝에 붙은 마커가 트랙 밖으로 삐져나가지 않게
            let x = min(width * CGFloat(step.startAt) / total, width - w)
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

// MARK: - 한 줄 타임라인 — 손은 하나니까, 모든 작업을 한 줄에

struct OneLineTimeline: View {
    let recipe: Recipe
    @ObservedObject var session: CookSession

    @State private var viewport: CGFloat = 0

    private var total: CGFloat { CGFloat(max(1, recipe.totalSeconds)) }
    private let rowHeight: CGFloat = 46

    var body: some View {
        let width = TimelineMetrics.trackWidth(recipe, viewport: viewport)
        let nowX = width * CGFloat(min(session.elapsed, recipe.totalSeconds)) / total
        // 걸어두는 것은 뒤에 옅게, 내 손 작업은 그 위에 진하게 — 겹쳐도 한 줄
        let passive = recipe.steps.filter { $0.attention == .passive }
        let hands = recipe.steps.filter { $0.attention.isHands }.sorted { $0.startAt < $1.startAt }

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                Text("한 줄로 — 손은 하나")
                Spacer()
                Text("옅은 칸 = 걸어둔 것")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.inkSoft)
            .textCase(.uppercase)

            NowFollowingScroll(session: session, nowX: nowX, width: width) {
                VStack(alignment: .leading, spacing: 4) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.ringTrack.opacity(0.5))
                            .frame(width: width, height: rowHeight)
                        // 뒤: 걸어둔 것 (냄비가 알아서 하는 구간)
                        ForEach(passive) { step in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(recipe.color(for: step.lane).opacity(0.22))
                                .frame(width: max(8, width * CGFloat(step.duration) / total),
                                       height: rowHeight - 8)
                                .offset(x: width * CGFloat(step.startAt) / total, y: 4)
                        }
                        // 앞: 내가 하는 일 (서로 겹치지 않는다)
                        ForEach(hands) { step in
                            let marker = TimelineMetrics.isMarker(step)
                            StepBar(step: step, status: session.status(of: step),
                                    color: recipe.color(for: step.lane), compact: marker)
                                .frame(width: marker ? TimelineMetrics.markerPx
                                       : max(8, width * CGFloat(step.duration) / total),
                                       height: rowHeight - 12)
                                .offset(x: width * CGFloat(step.startAt) / total, y: 6)
                        }
                        if session.phase != .done {
                            Rectangle().fill(Theme.ink)
                                .frame(width: 2.5, height: rowHeight)
                                .offset(x: nowX - 1.25)
                                .animation(.linear(duration: 0.5), value: session.elapsed)
                        }
                    }
                    .frame(width: width, height: rowHeight)

                    TimelineTicks(totalSeconds: recipe.totalSeconds, width: width)
                }
            }
            .frame(height: rowHeight + 20)
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
}

// MARK: - 가로 간트 (레인별) + 움직이는 '지금' 선

struct GanttTimeline: View {
    let recipe: Recipe
    @ObservedObject var session: CookSession

    @State private var viewport: CGFloat = 0

    private let laneSpacing: CGFloat = 8
    private let bubbleWidth: CGFloat = 46

    private var total: CGFloat { CGFloat(max(1, recipe.totalSeconds)) }

    private struct LaneLayout {
        let lane: String
        let items: [TimelineMetrics.Placed]
        let rows: Int
    }

    var body: some View {
        let width = TimelineMetrics.trackWidth(recipe, viewport: viewport - TimelineMetrics.labelColumn)
        let layouts = recipe.lanes.map { lane -> LaneLayout in
            let p = TimelineMetrics.place(recipe.rowSteps(lane), total: total, width: width)
            return LaneLayout(lane: lane, items: p.items, rows: p.rows)
        }
        let chartHeight = layouts.map { TimelineMetrics.height(rows: $0.rows) }.reduce(0, +)
            + CGFloat(max(0, layouts.count - 1)) * laneSpacing
        let nowX = width * CGFloat(min(session.elapsed, recipe.totalSeconds)) / total

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
                    track(width: width, layouts: layouts, chartHeight: chartHeight, nowX: nowX)
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
                       chartHeight: CGFloat, nowX: CGFloat) -> some View {
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
            TimelineTicks(totalSeconds: recipe.totalSeconds, width: width)
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
                    .minimumScaleFactor(0.6)
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
