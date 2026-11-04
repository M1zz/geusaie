//
//  PotComplication.swift
//  GeusaieWatchWidget
//
//  손목을 들 때마다 보는 값 하나: 가장 먼저 끝나는 냄비의 남은 시간.
//  시간은 시스템이 세는 타이머 글자라 매초 다시 그리지 않아도 줄어든다.
//  냄비가 끝나는 시각마다 항목을 하나씩 두어, 하나가 끝나면 다음 냄비로 넘어간다.
//

import WidgetKit
import SwiftUI

struct PotEntry: TimelineEntry {
    let date: Date
    let recipe: String?
    let pot: CookSnapshot.Pot?
}

struct PotProvider: TimelineProvider {
    func placeholder(in context: Context) -> PotEntry {
        PotEntry(date: .now, recipe: "🍝",
                 pot: .init(lane: String(localized: "면냄비"), colorIndex: 1, text: "",
                            endsAt: .now.addingTimeInterval(299), remaining: 0))
    }

    func getSnapshot(in context: Context, completion: @escaping (PotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entries().first!)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PotEntry>) -> Void) {
        completion(Timeline(entries: entries(), policy: .never))
    }

    /// 지금 한 장 + 냄비가 끝나는 시각마다 한 장
    private func entries() -> [PotEntry] {
        guard let s = WatchStore.load(), s.running else { return [PotEntry(date: .now, recipe: nil, pot: nil)] }
        let ends = s.pots.compactMap(\.endsAt).filter { $0 > .now }.sorted()
        return ([Date.now] + ends).map { date in
            PotEntry(date: date, recipe: s.recipe, pot: s.soonestPot(after: date))
        }
    }
}

struct PotComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PotEntry

    var body: some View {
        if let pot = entry.pot, let end = pot.endsAt {
            let color = WatchTheme.dish(pot.colorIndex)
            let timer = Text(timerInterval: entry.date...max(end, entry.date), countsDown: true)
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Image(systemName: "frying.pan.fill").font(.caption2).widgetAccentable()
                    timer.font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
            case .accessoryCorner:
                Image(systemName: "frying.pan.fill")
                    .font(.title3)
                    .widgetAccentable()
                    .widgetLabel { timer }
            case .accessoryInline:
                Text(verbatim: "\(pot.lane) ") + timer
            default:
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.recipe ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    timer.font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                        .widgetAccentable()
                    Text(verbatim: "\(pot.lane) · \(pot.text)").font(.caption2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            switch family {
            case .accessoryCircular, .accessoryCorner:
                Image(systemName: "frying.pan").font(.title3).widgetAccentable()
            case .accessoryInline:
                Text("그사이에")
            default:
                VStack(alignment: .leading, spacing: 2) {
                    Label("그사이에", systemImage: "frying.pan").font(.headline).widgetAccentable()
                    Text("돌고 있는 냄비가 없어요").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

@main
struct PotComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PotTimer", provider: PotProvider()) { entry in
            PotComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("냄비 남은 시간")
        .description("가장 먼저 끝나는 냄비의 남은 시간을 보여 줘요.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}
