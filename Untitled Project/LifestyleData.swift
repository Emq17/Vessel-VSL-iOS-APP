import SwiftUI
import HealthKit

extension ContentView {
    // MARK: - Lifestyle Data

    func days(in section: VSLHealthSection? = nil) -> Int {
        let (start, end) = range(for: section)
        let calendar = Calendar.current
        let difference = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: end)).day ?? 0
        let choice = section == .nutrition ? nutritionPeriod : section == .weight ? weightPeriod : sleepPeriod
        if choice == .today { return 1 }
        if choice == .week { return 7 }
        if choice == .month { return 30 }
        if choice == .quarter { return 90 }
        return max(1, difference)
    }

    var dayCount: Int { days(in: healthSection) }

    func loadLifestyle() {
        guard health.connected else { return }

        let (start, end) = range(for: tab == .sleep ? nil : healthSection)

        if tab == .health && healthSection == .nutrition {
            nutrition = [:]

            let identifiers: [HKQuantityTypeIdentifier] = [
                .dietaryEnergyConsumed,
                .dietaryCarbohydrates,
                .dietaryProtein,
                .dietaryFatTotal
            ]

            // LATEST searches historical entries, rather than assuming food was logged today.
            let nutritionStart = nutritionPeriod == .today
                ? (Calendar.current.date(byAdding: .year, value: -3, to: .now) ?? start)
                : start
            for identifier in identifiers {
                health.queryQuantity(
                    identifier,
                    start: nutritionStart,
                    end: end
                ) { samples in
                    nutrition[identifier] = samples
                }
            }
        } else if tab == .health && healthSection == .weight {
            weightSamples = []
            weightNutrition = [:]
            let historicalWeightStart = Calendar.current.date(
                byAdding: .year, value: -15, to: Date()
            ) ?? start
            health.queryQuantity(.bodyMass, start: historicalWeightStart, end: Date()) { samples in
                weightSamples = samples.sorted { $0.startDate < $1.startDate }
            }
            for identifier in [HKQuantityTypeIdentifier.dietaryEnergyConsumed,
                               .dietaryCarbohydrates, .dietaryProtein, .dietaryFatTotal] {
                health.queryQuantity(identifier, start: start, end: end) { samples in
                    weightNutrition[identifier] = samples
                }
            }
        } else if tab == .sleep {
            sleepSamples = []

            // Query full recent nights, not just samples after midnight.
            // For LAST NIGHT, the latest complete available overnight
            // record may have ended yesterday if the Watch was not worn.
            let sleepStart: Date = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? start

            health.querySleep(
                start: sleepStart,
                end: .now
            ) { samples in
                sleepSamples = samples
            }
        }
    }


}
