import SwiftUI
import HealthKit
import UIKit

extension ContentView {
    // MARK: - Sleep

    var sleepContent: some View {
        VStack(alignment: .leading, spacing: 15) {


            if let recent = sleepSamples.filter({ [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ].contains($0.value) }).max(by: { $0.endDate < $1.endDate }) {
                Text("LATEST SLEEP RECORD · " + recent.endDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(VSL.lime)
            }

            periodControls(for: nil)

            if sleepPeriod == .today {
                let latest = latestSleepSummary
                sleepStagesChart
                VSLMetricGrid(metrics: [
                    VSLMetric(id: "Last night sleep", value: VSLFormat.time(latest.total), unit: ""),
                    VSLMetric(id: "REM", value: VSLFormat.time(latest.rem), unit: ""),
                    VSLMetric(id: "Deep", value: VSLFormat.time(latest.deep), unit: ""),
                    VSLMetric(id: "Core", value: VSLFormat.time(latest.core), unit: ""),
                    VSLMetric(id: "Awake", value: VSLFormat.time(latest.awake), unit: "")
                ])
            } else {
                let summary = sleepSummary
                VSLMetricGrid(metrics: [
                    VSLMetric(id: "Avg nightly sleep", value: VSLFormat.time(summary.average), unit: ""),
                    VSLMetric(id: "Recorded nights", value: "\(summary.nights)", unit: ""),
                    VSLMetric(id: "Total sleep", value: VSLFormat.time(summary.total), unit: ""),
                    VSLMetric(id: "Avg REM / night", value: VSLFormat.time(summary.rem), unit: ""),
                    VSLMetric(id: "Avg deep / night", value: VSLFormat.time(summary.deep), unit: ""),
                    VSLMetric(id: "Avg core / night", value: VSLFormat.time(summary.core), unit: "")
                ])
            }

        }
    }

    // Build actual sleep episodes from the recorded intervals rather than
    // assigning individual samples to dates based on their end times.
    // Sleep that crosses midnight (or noon) stays in one episode.
    // Sleep samples for the same latest substantial episode used by the metrics.
    var latestSleepEpisodeSamples: [HKCategorySample] {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let asleep = sleepSamples.filter {
            asleepValues.contains($0.value) && $0.endDate > $0.startDate
        }.sorted { $0.startDate < $1.startDate }
        guard !asleep.isEmpty else { return [] }

        // Group samples into sleep episodes. Awake gaps shorter than four
        // hours do not split a night's sleep into separate records.
        var episodes: [[HKCategorySample]] = []
        var current: [HKCategorySample] = []
        var lastEnd = Date.distantPast
        for sample in asleep {
            if !current.isEmpty && sample.startDate.timeIntervalSince(lastEnd) > 4 * 3600 {
                episodes.append(current)
                current = []
                lastEnd = .distantPast
            }
            current.append(sample)
            if sample.endDate > lastEnd { lastEnd = sample.endDate }
        }
        if !current.isEmpty { episodes.append(current) }

        // Prefer the latest substantial sleep episode to a short nap.
        // If there is no substantial episode, use the most recent one.
        func coveredDuration(_ samples: [HKCategorySample]) -> Double {
            let ranges = samples.map { ($0.startDate, $0.endDate) }
                .sorted { $0.0 < $1.0 }
            guard let first = ranges.first else { return 0 }
            var start = first.0
            var end = first.1
            var total = 0.0
            for (nextStart, nextEnd) in ranges.dropFirst() {
                if nextStart <= end {
                    if nextEnd > end { end = nextEnd }
                } else {
                    total += end.timeIntervalSince(start)
                    start = nextStart
                    end = nextEnd
                }
            }
            return total + end.timeIntervalSince(start)
        }

        let selected = episodes.reversed().first(where: {
            coveredDuration($0) >= 3 * 3600
        }) ?? episodes[episodes.count - 1]

        // Health may contain overlapping Watch and third-party records.
        // Choose one source for the episode rather than summing sources.
        let bySource = Dictionary(grouping: selected) { $0.sourceRevision.source.bundleIdentifier }
        let sourceSamples = bySource.values.max(by: {
            coveredDuration($0) < coveredDuration($1)
        }) ?? selected
        return sourceSamples

    }

    // Awake samples are not asleep time. Keep them separate and limit them
    // to the selected episode and the same source as the selected sleep data.
    var latestSleepAwakeSamples: [HKCategorySample] {
        let asleep = latestSleepEpisodeSamples
        guard let start = asleep.map(\.startDate).min(),
              let end = asleep.map(\.endDate).max(),
              let source = asleep.first?.sourceRevision.source.bundleIdentifier else { return [] }
        return sleepSamples.filter {
            $0.value == HKCategoryValueSleepAnalysis.awake.rawValue &&
            $0.sourceRevision.source.bundleIdentifier == source &&
            $0.endDate > start && $0.startDate < end &&
            $0.endDate > $0.startDate
        }
    }

    var latestSleepSummary: (total: Double?, rem: Double?, deep: Double?, core: Double?, awake: Double?) {
        let sourceSamples = latestSleepEpisodeSamples
        guard !sourceSamples.isEmpty else { return (nil, nil, nil, nil, nil) }
        func coveredDuration(_ samples: [HKCategorySample]) -> Double? {
            let ranges = samples.map { ($0.startDate, $0.endDate) }.sorted { $0.0 < $1.0 }
            guard let first = ranges.first else { return nil }
            var start = first.0
            var end = first.1
            var total = 0.0
            for (nextStart, nextEnd) in ranges.dropFirst() {
                if nextStart <= end { if nextEnd > end { end = nextEnd } }
                else { total += end.timeIntervalSince(start); start = nextStart; end = nextEnd }
            }
            return total + end.timeIntervalSince(start)
        }
        func duration(_ stage: HKCategoryValueSleepAnalysis) -> Double? {
            coveredDuration(sourceSamples.filter { $0.value == stage.rawValue })
        }
        let awakeSamples = latestSleepAwakeSamples
        // Clip awake records to the selected episode window before totaling.
        let start = sourceSamples.map(\.startDate).min()!
        let end = sourceSamples.map(\.endDate).max()!
        let awakeRanges = awakeSamples.compactMap { sample -> (Date, Date)? in
            let clippedStart = max(sample.startDate, start)
            let clippedEnd = min(sample.endDate, end)
            return clippedEnd > clippedStart ? (clippedStart, clippedEnd) : nil
        }.sorted { $0.0 < $1.0 }
        var awakeTotal: Double? = nil
        if let first = awakeRanges.first {
            var rangeStart = first.0
            var rangeEnd = first.1
            var sum = 0.0
            for (nextStart, nextEnd) in awakeRanges.dropFirst() {
                if nextStart <= rangeEnd { rangeEnd = max(rangeEnd, nextEnd) }
                else {
                    sum += rangeEnd.timeIntervalSince(rangeStart)
                    rangeStart = nextStart
                    rangeEnd = nextEnd
                }
            }
            awakeTotal = sum + rangeEnd.timeIntervalSince(rangeStart)
        }
        return (coveredDuration(sourceSamples), duration(.asleepREM), duration(.asleepDeep), duration(.asleepCore), awakeTotal)
    }

    private var sleepStagesChart: some View {
        VSLSleepInteractiveChart(samples: latestSleepEpisodeSamples + latestSleepAwakeSamples)
    }

    var sleepSummary: (
        average: Double?,
        total: Double?,
        nights: Int,
        rem: Double?,
        deep: Double?,
        core: Double?
    ) {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        let asleep = sleepSamples.filter {
            asleepValues.contains($0.value)
        }

        let grouped = Dictionary(
            grouping: asleep
        ) { sample in
            Calendar.current.startOfDay(
                for: sample.endDate.addingTimeInterval(
                    -12 * 3600
                )
            )
        }

        let nights = grouped.count

        let total = asleep.reduce(0.0) {
            $0 + $1.endDate.timeIntervalSince(
                $1.startDate
            )
        }

        func stage(
            _ value: HKCategoryValueSleepAnalysis
        ) -> Double? {
            let samples = asleep.filter {
                $0.value == value.rawValue
            }

            guard !samples.isEmpty, nights > 0 else {
                return nil
            }

            let duration = samples.reduce(0.0) {
                $0 + $1.endDate.timeIntervalSince(
                    $1.startDate
                )
            }

            return duration / Double(nights)
        }

        return (
            nights > 0 ? total / Double(nights) : nil,
            nights > 0 ? total : nil,
            nights,
            stage(.asleepREM),
            stage(.asleepDeep),
            stage(.asleepCore)
        )
    }


}


// Interactive sleep-stage timeline. Drag anywhere across the lanes to snap
// to the nearest recorded interval; a selection haptic fires only on change.
private struct VSLSleepInteractiveChart: View {
    let samples: [HKCategorySample]
    @State private var selectedID: UUID?

    private var ordered: [HKCategorySample] {
        samples.filter { $0.endDate > $0.startDate && $0.value != HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
            .sorted { $0.startDate < $1.startDate }
    }

    private var first: Date { ordered.map(\.startDate).min() ?? .now }
    private var last: Date { ordered.map(\.endDate).max() ?? first }
    private var span: TimeInterval { max(last.timeIntervalSince(first), 1) }

    private let lanes: [(name: String, value: Int, color: Color)] = [
        ("Awake", HKCategoryValueSleepAnalysis.awake.rawValue, Color(red: 0.98, green: 0.58, blue: 0.36)),
        ("REM", HKCategoryValueSleepAnalysis.asleepREM.rawValue, Color(red: 0.45, green: 0.70, blue: 1)),
        ("Core", HKCategoryValueSleepAnalysis.asleepCore.rawValue, Color(red: 0.20, green: 0.44, blue: 0.88)),
        ("Deep", HKCategoryValueSleepAnalysis.asleepDeep.rawValue, Color(red: 0.48, green: 0.34, blue: 0.77))
    ]

    private var selected: HKCategorySample? { ordered.first { $0.uuid == selectedID } }

    private func snap(at x: CGFloat, width: CGFloat) {
        guard width > 0, !ordered.isEmpty else { return }
        let fraction = min(max(x / width, 0), 1)
        let time = first.addingTimeInterval(span * Double(fraction))
        // Select the interval containing the touch, or the nearest interval
        // boundary if the watch did not record data at that exact moment.
        guard let nearest = ordered.min(by: { lhs, rhs in
            func distance(_ s: HKCategorySample) -> TimeInterval {
                if time < s.startDate { return s.startDate.timeIntervalSince(time) }
                if time > s.endDate { return time.timeIntervalSince(s.endDate) }
                return 0
            }
            let left = distance(lhs), right = distance(rhs)
            if left == right {
                let lMid = lhs.startDate.addingTimeInterval(lhs.endDate.timeIntervalSince(lhs.startDate) / 2)
                let rMid = rhs.startDate.addingTimeInterval(rhs.endDate.timeIntervalSince(rhs.startDate) / 2)
                return abs(lMid.timeIntervalSince(time)) < abs(rMid.timeIntervalSince(time))
            }
            return left < right
        }) else { return }
        if selectedID != nearest.uuid {
            if selectedID != nil {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            selectedID = nearest.uuid
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SLEEP STAGES")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VSL.muted)

            if ordered.isEmpty {
                Text("No sleep stage timeline available.")
                    .font(.caption)
                    .foregroundStyle(VSL.muted)
            } else {
                if let item = selected,
                   let lane = lanes.first(where: { $0.value == item.value }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lane.name.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(lane.color)
                        Text("\(item.startDate.formatted(date: .omitted, time: .shortened)) – \(item.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        Text(VSLFormat.time(item.endDate.timeIntervalSince(item.startDate)))
                            .font(.system(size: 12))
                            .foregroundStyle(VSL.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                }

                VStack(spacing: 9) {
                    ForEach(0..<lanes.count, id: \.self) { index in
                        let lane = lanes[index]
                        HStack(spacing: 10) {
                            Text(lane.name)
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 38, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(VSL.background)
                                    ForEach(ordered.filter { $0.value == lane.value }, id: \.uuid) { item in
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(lane.color)
                                            .opacity(selectedID == nil || selectedID == item.uuid ? 1 : 0.38)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .strokeBorder(selectedID == item.uuid ? Color.white : Color.clear, lineWidth: 1.5)
                                            }
                                            .frame(width: max(2, CGFloat(item.endDate.timeIntervalSince(item.startDate) / span) * geo.size.width), height: 18)
                                            .offset(x: CGFloat(item.startDate.timeIntervalSince(first) / span) * geo.size.width)
                                    }
                                }
                            }
                            .frame(height: 18)
                        }
                    }
                }
                .overlay(alignment: .topLeading) {
                    // Transparent hit surface spanning all four lanes. Coordinate
                    // space excludes the fixed-width stage labels.
                    GeometryReader { geometry in
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    snap(at: value.location.x - 48, width: geometry.size.width - 48)
                                })
                    }
                }
                HStack {
                    Text(first.formatted(date: .omitted, time: .shortened))
                    Spacer()
                    Text(last.formatted(date: .omitted, time: .shortened))
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(VSL.muted)
            }
        }
        .padding(16)
        .background(VSL.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
