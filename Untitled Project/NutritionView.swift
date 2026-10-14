import SwiftUI
import HealthKit
import Charts

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

            if let carbs = values[1], let protein = values[2], let fat = values[3],
               carbs + protein + fat > 0 {
                let macroValues: [(name: String, kcal: Double, color: Color)] = [
                    ("CARBS", carbs * 4, VSL.lime),
                    ("PROTEIN", protein * 4, .cyan),
                    ("FAT", fat * 9, .orange)
                ]
                VStack(alignment: .leading, spacing: 12) {
                    Text("MACRO DISTRIBUTION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VSL.muted)
                    Chart(macroValues, id: \.name) { macro in
                        SectorMark(angle: .value("Energy", macro.kcal),
                                   innerRadius: .ratio(0.58),
                                   angularInset: 2)
                            .foregroundStyle(macro.color)
                    }
                    .chartLegend(.hidden)
                    .frame(height: 190)
                    HStack(spacing: 12) {
                        ForEach(macroValues, id: \.name) { macro in
                            HStack(spacing: 4) {
                                Circle().fill(macro.color).frame(width: 6, height: 6)
                                Text(macro.name)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(VSL.muted)
                            }
                        }
                    }
                    Text("Estimated energy from recorded macros (4/4/9 kcal per gram)")
                        .font(.caption2).foregroundStyle(VSL.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(VSL.card, in: RoundedRectangle(cornerRadius: 12))
            }

            let averageDays = max(1, days(in: .nutrition))
            let dailyValues = values.map { value in value.map { $0 / Double(averageDays) } }
            let isToday = nutritionPeriod == .today
            VSLMetricGrid(metrics: [
                VSLMetric(id: isToday ? "Calories today" : "Avg calories / day",
                          value: VSLFormat.number(dailyValues[0]), unit: "kcal"),
                VSLMetric(id: isToday ? "Carbs today" : "Avg carbs / day",
                          value: VSLFormat.number(dailyValues[1], decimals: 1), unit: "g"),
                VSLMetric(id: isToday ? "Protein today" : "Avg protein / day",
                          value: VSLFormat.number(dailyValues[2], decimals: 1), unit: "g"),
                VSLMetric(id: isToday ? "Fat today" : "Avg fat / day",
                          value: VSLFormat.number(dailyValues[3], decimals: 1), unit: "g")
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
