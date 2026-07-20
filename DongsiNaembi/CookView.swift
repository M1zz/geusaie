import SwiftUI

// MARK: - 조리 중: 병렬 작업 타임라인 (이 앱의 심장)
//
// 배치: [상단바] · [지금 할 일 슬림 스트립] · [가로 간트 — 히어로] · [체크리스트] · [컨트롤]
// 가로 간트 위를 '지금' 선이 왼→오로 지나간다. 지금 선에 걸친 막대 = 동시에 해야 할 일.

struct CookView: View {
    @ObservedObject var session: CookSession
    @Environment(\.dismiss) private var dismiss

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
    }

    // MARK: 상단 바 — 이름 · 전체 진행률/남은 시간

    private func topBar(_ recipe: Recipe) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: {
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
            // 전체 진행 바
            GeometryReader { geo in
                let p = recipe.totalSeconds > 0
                    ? CGFloat(min(session.elapsed, recipe.totalSeconds)) / CGFloat(recipe.totalSeconds)
                    : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ringTrack).frame(height: 4)
                    Capsule().fill(Theme.terracotta)
                        .frame(width: max(4, geo.size.width * p), height: 4)
                        .animation(.linear(duration: 0.5), value: session.elapsed)
                }
            }
            .frame(height: 4)
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
                Button { session.finish() } label: {
                    Label("완성 처리", systemImage: "flag.checkered").frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledButton(tint: Theme.terracotta))
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

// MARK: - 지금 할 일 (슬림 스트립) — 병렬이면 알약이 나란히

struct NowStrip: View {
    @ObservedObject var session: CookSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("지금 할 일")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.inkSoft)
                    .textCase(.uppercase)
                Spacer()
                if let next = session.nextStep, session.phase != .done {
                    Text("곧 · \(next.emoji) \(next.name) · \(formatSeconds(session.countdown(for: next))) 후")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
            }

            let active = session.activeSteps
            if active.isEmpty {
                Text(session.phase == .done ? "완성됐어요 🍴 접시에 담으세요" : "잠깐 대기 — 곧 다음 작업 시작")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(active) { step in
                            ActivePill(step: step,
                                       countdown: session.countdown(for: step),
                                       color: session.recipe?.color(for: step.lane) ?? Theme.terracotta)
                        }
                    }
                }
                if let tip = active.first?.tip {
                    Label(tip, systemImage: active.first!.attention.icon)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                }
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
    private let bubbleWidth: CGFloat = 52

    private var chartHeight: CGFloat {
        CGFloat(recipe.lanes.count) * laneHeight + CGFloat(recipe.lanes.count - 1) * laneSpacing
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
                let track = geo.size.width - labelWidth
                let total = CGFloat(max(1, recipe.totalSeconds))
                let elapsed = CGFloat(min(session.elapsed, recipe.totalSeconds))
                let nowX = labelWidth + track * elapsed / total

                ZStack(alignment: .topLeading) {
                    VStack(spacing: laneSpacing) {
                        ForEach(recipe.lanes, id: \.self) { lane in
                            laneRow(lane, track: track, total: total)
                        }
                    }

                    if session.phase != .done {
                        // 지금 선
                        Rectangle().fill(Theme.ink)
                            .frame(width: 2.5, height: chartHeight)
                            .offset(x: nowX - 1.25)
                            .animation(.linear(duration: 0.5), value: session.elapsed)
                        // 경과 시간 말풍선 (양끝 클램프)
                        Text(formatSeconds(session.elapsed))
                            .font(.caption2.weight(.heavy).monospaced())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.ink))
                            .offset(x: min(max(nowX - bubbleWidth / 2, labelWidth),
                                           geo.size.width - bubbleWidth),
                                    y: -2)
                            .animation(.linear(duration: 0.5), value: session.elapsed)
                    }
                }
            }
            .frame(height: chartHeight)
            .padding(.top, 8)

            axisRuler
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

    private func laneRow(_ lane: String, track: CGFloat, total: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(lane)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(recipe.color(for: lane))
                .frame(width: labelWidth, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.ringTrack.opacity(0.5))
                    .frame(height: laneHeight)
                ForEach(recipe.steps.filter { $0.lane == lane }) { step in
                    StepBar(step: step, status: session.status(of: step),
                            color: recipe.color(for: lane))
                        .frame(width: max(20, track * CGFloat(step.duration) / total),
                               height: laneHeight - 10)
                        .offset(x: track * CGFloat(step.startAt) / total)
                }
            }
        }
    }

    private var axisRuler: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: labelWidth)
            HStack {
                ForEach(0...4, id: \.self) { i in
                    Text(formatSeconds(recipe.totalSeconds * i / 4))
                    if i < 4 { Spacer() }
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
        }
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
