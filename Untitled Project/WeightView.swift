import SwiftUI
import HealthKit

extension ContentView {
    // MARK: - Weight

    var weightContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VSLSection(title: "WEIGHT", number: "01", color: VSL.lime)
            if let latest = weightPoints.last {
                Text("LATEST WEIGH-IN · " + latest.0.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(VSL.lime)
            }

            periodControls(for: .weight)

            let points = weightPoints
            if let first = points.first, let last = points.last {
                VSLMetricGrid(metrics: [
                    VSLMetric(id: "Latest weight", value: VSLFormat.number(last.1, decimals: 1), unit: "lb"),
                    VSLMetric(id: "Change", value: String(format: "%+.1f", last.1 - first.1), unit: "lb"),
                    VSLMetric(id: weightPeriod == .today ? "Latest recorded" : "Average recorded", value: VSLFormat.number(weightPeriod == .today ? last.1 : points.map { $0.1 }.reduce(0, +) / Double(points.count), decimals: 1), unit: "lb"),
                    VSLMetric(id: "Measurements", value: "\(points.count)", unit: "")
                ])
                VSLSection(title: "WEIGHT TREND", number: "02", color: VSL.lime)
                weightChart(points)
                Text("First: \(first.0.formatted(date: .abbreviated, time: .omitted))  ·  Latest: \(last.0.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(VSL.muted)
            } else {
                notice("No weight measurements in this period. If your scale app writes weight to Apple Health, allow VSL to read Body Mass and try again.")
            }

            VSLSection(title: "NUTRITION CONTEXT", number: "03", color: VSL.lime)
            let totals = weightNutritionTotals
            VSLMetricGrid(metrics: [
                VSLMetric(id: weightPeriod == .today ? "Calories today" : "Logged calories / day", value: VSLFormat.number(totals[0].map { $0 / Double(days(in: .weight)) }), unit: "kcal"),
                VSLMetric(id: weightPeriod == .today ? "Carbs today" : "Logged carbs / day", value: VSLFormat.number(totals[1].map { $0 / Double(days(in: .weight)) }), unit: "g"),
                VSLMetric(id: weightPeriod == .today ? "Protein today" : "Logged protein / day", value: VSLFormat.number(totals[2].map { $0 / Double(days(in: .weight)) }), unit: "g"),
                VSLMetric(id: weightPeriod == .today ? "Fat today" : "Logged fat / day", value: VSLFormat.number(totals[3].map { $0 / Double(days(in: .weight)) }), unit: "g")
            ])
        }
    }

    var weightPoints: [(Date, Double)] {
        // One measurement per calendar day: use the last recorded measurement.
        let grouped = Dictionary(grouping: weightSamples) {
            Calendar.current.startOfDay(for: $0.startDate)
        }
        return grouped.compactMap { _, samples -> (Date, Double)? in
            guard let last = samples.max(by: { $0.startDate < $1.startDate }) else { return nil }
            return (last.startDate, last.quantity.doubleValue(for: .pound()))
        }.sorted { $0.0 < $1.0 }
    }

    var weightNutritionTotals: [Double?] {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed, .dietaryCarbohydrates, .dietaryProtein, .dietaryFatTotal
        ]
        return identifiers.map { identifier in
            guard let samples = weightNutrition[identifier], !samples.isEmpty else { return nil }
            let unit: HKUnit = identifier == .dietaryEnergyConsumed ? .kilocalorie() : .gram()
            return samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
        }
    }

    func weightChart(_ points: [(Date, Double)]) -> some View {
        let values = points.map { $0.1 }
        let low = (values.min() ?? 0) - 1
        let high = (values.max() ?? 1) + 1
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "%.1f – %.1f LB", low + 1, high - 1))
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(VSL.muted)
            GeometryReader { geometry in
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = points.count == 1
                            ? geometry.size.width / 2
                            : CGFloat(index) / CGFloat(points.count - 1) * geometry.size.width
                        let y = geometry.size.height * (1 - CGFloat((point.1 - low) / max(1, high - low)))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(VSL.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 135)
        }
        .padding(20)
        .background(VSL.card, in: RoundedRectangle(cornerRadius: 14))
    }


}
