import SwiftUI
import HealthKit

extension ContentView {
    // MARK: - Sleep

    var sleepContent: some View {
        VStack(alignment: .leading, spacing: 15) {

            Text("RECOVER BETTER.")
                .font(.system(size: 27, weight: .black))

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
                VSLMetricGrid(metrics: [
                    VSLMetric(id: "Last night sleep", value: VSLFormat.time(latest.total), unit: ""),
                    VSLMetric(id: "REM", value: VSLFormat.time(latest.rem), unit: ""),
                    VSLMetric(id: "Deep", value: VSLFormat.time(latest.deep), unit: ""),
                    VSLMetric(id: "Core", value: VSLFormat.time(latest.core), unit: "")
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

            notice(sleepPeriod == .today ? "Last Night uses the most recent substantial sleep session available in Apple Health. Overlapping records are not counted twice." : "Sleep averages include recorded nights only. Sleep stages depend on your device and available Apple Health records.")
        }
    }

    // Build actual sleep episodes from the recorded intervals rather than
    // assigning individual samples to dates based on their end times.
    // Sleep that crosses midnight (or noon) stays in one episode.
    var latestSleepSummary: (total: Double?, rem: Double?, deep: Double?, core: Double?) {
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let asleep = sleepSamples.filter {
            asleepValues.contains($0.value) && $0.endDate > $0.startDate
        }.sorted { $0.startDate < $1.startDate }
        guard !asleep.isEmpty else { return (nil, nil, nil, nil) }

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

        func duration(_ stage: HKCategoryValueSleepAnalysis) -> Double? {
            let matching = sourceSamples.filter { $0.value == stage.rawValue }
            return matching.isEmpty ? nil : coveredDuration(matching)
        }
        return (coveredDuration(sourceSamples), duration(.asleepREM),
                duration(.asleepDeep), duration(.asleepCore))
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
