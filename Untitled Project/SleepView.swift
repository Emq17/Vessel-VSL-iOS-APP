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

            notice(sleepPeriod == .today ? "Last Night uses the most recent available sleep recorded by Apple Health, including sleep before midnight. It is not a daily average." : "Sleep averages include recorded nights only. Sleep stages depend on your device and available Apple Health records.")
        }
    }

    var latestSleepSummary: (total: Double?, rem: Double?, deep: Double?, core: Double?) {
        let values: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let asleep = sleepSamples.filter { values.contains($0.value) }
        guard let latest = asleep.max(by: { $0.endDate < $1.endDate }) else {
            return (nil, nil, nil, nil)
        }
        let calendar = Calendar.current
        let night = calendar.startOfDay(for: latest.endDate.addingTimeInterval(-12 * 3600))
        let segments = asleep.filter {
            calendar.startOfDay(for: $0.endDate.addingTimeInterval(-12 * 3600)) == night
        }
        func duration(_ stage: HKCategoryValueSleepAnalysis) -> Double? {
            let matching = segments.filter { $0.value == stage.rawValue }
            return matching.isEmpty ? nil : matching.reduce(0) {
                $0 + $1.endDate.timeIntervalSince($1.startDate)
            }
        }
        let total = segments.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return (total, duration(.asleepREM), duration(.asleepDeep), duration(.asleepCore))
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
