import SwiftUI
import HealthKit

extension ContentView {
    // MARK: - Weight

    var weightContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VSLSection(title: "WEIGHT", number: "01", color: VSL.lime)
            if let latest = latestWeighIn {
                Text("LATEST WEIGH-IN · " + latest.0.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(VSL.lime)
            }

            periodControls(for: .weight)

            let points = weightPoints
            if let latest = latestWeighIn {
                VStack(alignment: .leading, spacing: 12) {
                    Text("LATEST WEIGHT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VSL.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(VSLFormat.number(latest.1, decimals: 1))
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .monospacedDigit()
                        Text("lb")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VSL.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(15)
                .background(VSL.card, in: RoundedRectangle(cornerRadius: 13))
                if let first = points.first, let last = points.last, points.count > 1 {
                    VSLMetricGrid(metrics: [
                        VSLMetric(id: "Change in range", value: String(format: "%+.1f", last.1 - first.1), unit: "lb"),
                        VSLMetric(id: "Average in range", value: VSLFormat.number(points.map { $0.1 }.reduce(0, +) / Double(points.count), decimals: 1), unit: "lb")
                    ])
                }
                if !points.isEmpty {
                    VSLSection(title: "WEIGHT TREND", number: "02", color: VSL.lime)
                    weightChart(points)
                }
            } else {
                notice("No weigh-ins found in Apple Health. Check Body Mass read permission and that your scale or logging app saves measurements to Apple Health.")
            }

            VSLSection(title: "NUTRITION CONTEXT", number: "03", color: VSL.lime)
            let totals = weightNutritionTotals
            VSLMetricGrid(metrics: [
                VSLMetric(id: weightPeriod == .today ? "Calories today" : "Avg calories / day", value: VSLFormat.number(totals[0].map { $0 / Double(days(in: .weight)) }), unit: "kcal"),
                VSLMetric(id: weightPeriod == .today ? "Carbs today" : "Avg carbs / day", value: VSLFormat.number(totals[1].map { $0 / Double(days(in: .weight)) }), unit: "g"),
                VSLMetric(id: weightPeriod == .today ? "Protein today" : "Avg protein / day", value: VSLFormat.number(totals[2].map { $0 / Double(days(in: .weight)) }), unit: "g"),
                VSLMetric(id: weightPeriod == .today ? "Fat today" : "Avg fat / day", value: VSLFormat.number(totals[3].map { $0 / Double(days(in: .weight)) }), unit: "g")
            ])
        }
    }

    var latestWeighIn: (Date, Double)? {
        guard let sample = weightSamples.max(by: { $0.startDate < $1.startDate }) else { return nil }
        return (sample.startDate, sample.quantity.doubleValue(for: .pound()))
    }

    var weightPoints: [(Date, Double)] {
        // Historical query provides latest value; the selected filter applies to the trend.
        let (start, end) = range(for: .weight)
        let inRange = weightSamples.filter { $0.startDate >= start && $0.startDate <= end }
        // One measurement per calendar day: use the last recorded measurement.
        let grouped = Dictionary(grouping: inRange) {
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
