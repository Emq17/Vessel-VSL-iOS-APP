import SwiftUI
import HealthKit

extension ContentView {
    // MARK: - Nutrition

    var nutritionContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            VSLSection(
                title: "NUTRITION",
                number: "01",
                color: VSL.lime
            )

            Text("FUEL THE WORK.")
                .font(.system(size: 27, weight: .black))

            if let latest = nutrition[.dietaryEnergyConsumed]?.max(by: { $0.startDate < $1.startDate }) {
                Text("LATEST CALORIE ENTRY · " + latest.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(VSL.lime)
            }

            periodControls(for: .nutrition)

            let values = nutritionSummary

            VSLMetricGrid(metrics: [
                VSLMetric(
                    id: "Total calories",
                    value: VSLFormat.number(values[0]),
                    unit: "kcal"
                ),
                VSLMetric(
                    id: nutritionPeriod == .today ? "Calories today" : "Avg daily calories",
                    value: VSLFormat.number(
                        values[0].map {
                            $0 / Double(days(in: .nutrition))
                        }
                    ),
                    unit: "kcal"
                ),
                VSLMetric(
                    id: "Total carbs",
                    value: VSLFormat.number(values[1]),
                    unit: "g"
                ),
                VSLMetric(
                    id: nutritionPeriod == .today ? "Carbs today" : "Avg daily carbs",
                    value: VSLFormat.number(
                        values[1].map {
                            $0 / Double(days(in: .nutrition))
                        },
                        decimals: 1
                    ),
                    unit: "g"
                ),
                VSLMetric(
                    id: "Total protein",
                    value: VSLFormat.number(values[2]),
                    unit: "g"
                ),
                VSLMetric(
                    id: "Total fat",
                    value: VSLFormat.number(values[3]),
                    unit: "g"
                )
            ])

            let sources = Set(nutrition.values.flatMap { $0 }.map { $0.sourceRevision.source.name })
            if !sources.isEmpty {
                Text("APPLE HEALTH SOURCES: " + sources.sorted().joined(separator: ", "))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VSL.muted)
                if !sources.contains(where: { $0.localizedCaseInsensitiveContains("MyFitnessPal") }) {
                    notice("MyFitnessPal is not listed as a source for these records. In MyFitnessPal and Apple Health, enable nutrition sharing; then reopen this tab. VSL reads the records Apple Health receives.")
                }
            }

            notice(nutritionPeriod == .today ? "Today shows recorded nutrition totals, not averages." : "Nutrition values come from Apple Health entries. Daily averages include every calendar day in the selected range, even days without logged meals.")
        }
    }

    var nutritionSummary: [Double?] {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryCarbohydrates,
            .dietaryProtein,
            .dietaryFatTotal
        ]

        return identifiers.map { identifier in
            let samples = nutrition[identifier] ?? []

            guard !samples.isEmpty else { return nil }

            let unit: HKUnit =
                identifier == .dietaryEnergyConsumed
                    ? .kilocalorie()
                    : .gram()

            return samples.reduce(0.0) {
                $0 + $1.quantity.doubleValue(for: unit)
            }
        }
    }


}
