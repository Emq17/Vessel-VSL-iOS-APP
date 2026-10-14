import SwiftUI
import Combine
import HealthKit
import Charts

// Apple Health is the source of truth. VSL only requests read permission.
@MainActor
final class VSLCardiovascularStore: ObservableObject {
    @Published var samples: [HKQuantityTypeIdentifier: [HKQuantitySample]] = [:]

    @Published var loading = false
    @Published var message: String?
    private let store = HKHealthStore()

    static let heartTypes: [HKQuantityTypeIdentifier] = [
        .heartRate, .restingHeartRate, .heartRateVariabilitySDNN,
        .vo2Max, .heartRateRecoveryOneMinute
    ]

    func refresh() {
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "Apple Health isn't available on this device."
            return
        }
        var types = Set<HKObjectType>()
        for id in Self.heartTypes + [.bloodPressureSystolic, .bloodPressureDiastolic] {
            if let type = HKObjectType.quantityType(forIdentifier: id) { types.insert(type) }
        }
        loading = true
        store.requestAuthorization(toShare: [], read: types) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.message = error.localizedDescription
                    self.loading = false
                    return
                }
                self.fetch()
            }
        }
    }

    private func fetch() {
        let start = Calendar.current.date(byAdding: .year, value: -3, to: .now) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let descriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        let group = DispatchGroup()
        for id in Self.heartTypes + [.bloodPressureSystolic, .bloodPressureDiastolic] {
            guard let type = HKObjectType.quantityType(forIdentifier: id) else { continue }
            group.enter()
            store.execute(HKSampleQuery(sampleType: type, predicate: predicate,
                                        limit: HKObjectQueryNoLimit, sortDescriptors: descriptors) { [weak self] _, results, _ in
                Task { @MainActor in
                    self?.samples[id] = (results as? [HKQuantitySample]) ?? []
                    group.leave()
                }
            })
        }
        group.notify(queue: .main) { [weak self] in
            Task { @MainActor in self?.loading = false }
        }
    }

    func latest(_ id: HKQuantityTypeIdentifier, on day: Date? = nil) -> HKQuantitySample? {
        let list = samples[id] ?? []
        return list.first { sample in
            guard let day else { return true }
            return Calendar.current.isDate(sample.endDate, inSameDayAs: day)
        }
    }

    struct PressureReading: Identifiable {
        let id: UUID
        let date: Date
        let systolic: Double
        let diastolic: Double
    }

    var pressureReadings: [PressureReading] {
        let unit = HKUnit.millimeterOfMercury()
        let tops = samples[.bloodPressureSystolic] ?? []
        let bottoms = samples[.bloodPressureDiastolic] ?? []
        var used = Set<UUID>()
        return tops.compactMap { top in
            guard let bottom = bottoms
                .filter({ !used.contains($0.uuid) })
                .min(by: { abs($0.endDate.timeIntervalSince(top.endDate)) <
                           abs($1.endDate.timeIntervalSince(top.endDate)) }),
                abs(bottom.endDate.timeIntervalSince(top.endDate)) <= 60 else { return nil }
            used.insert(bottom.uuid)
            return PressureReading(id: top.uuid, date: top.endDate,
                                   systolic: top.quantity.doubleValue(for: unit),
                                   diastolic: bottom.quantity.doubleValue(for: unit))
        }.sorted { $0.date < $1.date }
    }

    func pressure(on day: Date? = nil) -> (systolic: Double, diastolic: Double, date: Date)? {
        let unit = HKUnit.millimeterOfMercury()
        let systolic = samples[.bloodPressureSystolic] ?? []
        let diastolic = samples[.bloodPressureDiastolic] ?? []
        // Match readings from the same recording, without requiring correlation authorization.
        for top in systolic {
            if let day, !Calendar.current.isDate(top.endDate, inSameDayAs: day) { continue }
            if let bottom = diastolic.first(where: {
                abs($0.endDate.timeIntervalSince(top.endDate)) <= 60
            }) {
                return (top.quantity.doubleValue(for: unit),
                        bottom.quantity.doubleValue(for: unit), top.endDate)
            }
        }
        return nil
    }

    func hasReading(on date: Date, bloodPressure: Bool) -> Bool {
        if bloodPressure { return pressure(on: date) != nil }
        return Self.heartTypes.contains { id in
            (samples[id] ?? []).contains { Calendar.current.isDate($0.endDate, inSameDayAs: date) }
        }
    }

}

extension ContentView {
    @ViewBuilder
    func cardiovascularContent(isBloodPressure: Bool) -> some View {
        let day = selectedHealthDay
        VStack(alignment: .leading, spacing: 12) {
            if cardiovascular.loading { ProgressView().tint(VSL.lime) }
            if let message = cardiovascular.message {
                Text(message).font(.caption).foregroundStyle(VSL.muted)
            }
            if isBloodPressure {
                bloodPressureDashboard
            } else {
                heartRangeControls
                cardiovascularHeartRow("LATEST HEART RATE", id: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), suffix: "BPM", decimals: 0, day: day)
                cardiovascularHeartRow("RESTING HEART RATE", id: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), suffix: "BPM", decimals: 0, day: day)
                cardiovascularHeartRow("HEART RATE VARIABILITY", id: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), suffix: "ms", decimals: 0, day: day)
                cardiovascularHeartRow("VO₂ MAX", id: .vo2Max, unit: HKUnit(from: "ml/kg*min"), suffix: "mL/kg/min", decimals: 1, day: day)
                cardiovascularHeartRow("CARDIO RECOVERY (1 MIN)", id: .heartRateRecoveryOneMinute, unit: HKUnit.count().unitDivided(by: .minute()), suffix: "BPM", decimals: 0, day: day)
            }
            if day != nil {
                Text("Showing selected date · Clear date selection to see latest readings")
                    .font(.caption2).foregroundStyle(VSL.muted)
            }
        }
    }

    private var filteredPressureReadings: [VSLCardiovascularStore.PressureReading] {
        let all = cardiovascular.pressureReadings
        let calendar = Calendar.current
        if let day = selectedHealthDay {
            return all.filter { calendar.isDate($0.date, inSameDayAs: day) }
        }
        switch bloodPressurePeriod {
        case .today:
            // LATEST: show recent readings, even if none were taken today.
            return Array(all.suffix(30))
        case .week, .month, .quarter:
            let days = bloodPressurePeriod == .week ? 7 : bloodPressurePeriod == .month ? 30 : 90
            let start = calendar.date(byAdding: .day, value: -(days - 1),
                                      to: calendar.startOfDay(for: .now)) ?? .distantPast
            return all.filter { $0.date >= start && $0.date <= .now }
        case .custom:
            let start = calendar.startOfDay(for: bloodPressureCustomStart)
            let end = calendar.date(byAdding: .day, value: 1,
                                    to: calendar.startOfDay(for: bloodPressureCustomEnd)) ?? .now
            return all.filter { $0.date >= start && $0.date < end }
        }
    }

    private var bloodPressureDashboard: some View {
        let readings = filteredPressureReadings
        let latest = readings.last
        let inspected = readings.first { $0.id == selectedPressureReadingID }
        let showingAverage = selectedHealthDay != nil || bloodPressurePeriod != .today
        let meanSystolic = readings.isEmpty ? 0 : readings.reduce(0) { $0 + $1.systolic } / Double(readings.count)
        let meanDiastolic = readings.isEmpty ? 0 : readings.reduce(0) { $0 + $1.diastolic } / Double(readings.count)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 5) {
                ForEach(VSLPeriod.allCases, id: \.self) { period in
                    Button {
                        selectedHealthDay = nil
                        bloodPressurePeriod = period
                        selectedPressureReadingID = nil
                    } label: {
                        Text(period == .today ? "LATEST" : period.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(bloodPressurePeriod == period && selectedHealthDay == nil
                                             ? VSL.background : Color.white)
                            .background(bloodPressurePeriod == period && selectedHealthDay == nil
                                        ? VSL.lime : VSL.card,
                                        in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            if bloodPressurePeriod == .custom && selectedHealthDay == nil {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("FROM", selection: $bloodPressureCustomStart,
                               displayedComponents: .date)
                    DatePicker("TO", selection: $bloodPressureCustomEnd,
                               in: bloodPressureCustomStart..., displayedComponents: .date)
                }
                .font(.caption2)
            }
            if let latest {
                let displayed = inspected ?? latest
                let value = inspected != nil || !showingAverage
                    ? "\(Int(displayed.systolic.rounded())) / \(Int(displayed.diastolic.rounded()))"
                    : "\(Int(meanSystolic.rounded())) / \(Int(meanDiastolic.rounded()))"
                cardiovascularRow(inspected != nil ? "SELECTED READING" : (showingAverage ? "AVERAGE BLOOD PRESSURE" : "LATEST BLOOD PRESSURE"),
                                  value: value, unit: "mmHg",
                                  date: inspected?.date ?? (showingAverage ? nil : latest.date))
                if showingAverage && inspected == nil {
                    Text("\(readings.count) readings averaged")
                        .font(.caption2).foregroundStyle(VSL.muted)
                }
            } else {
                cardiovascularEmpty("No blood pressure readings in this range.")
            }
            if !readings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("BLOOD PRESSURE TREND")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VSL.muted)
                    if let inspected {
                        HStack(spacing: 8) {
                            Circle().fill(VSL.lime).frame(width: 6, height: 6)
                            Text(inspected.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            Spacer()
                            Text("\(Int(inspected.systolic.rounded())) / \(Int(inspected.diastolic.rounded())) mmHg")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 5)
                    }
                    Chart {
                        ForEach(readings) { reading in
                            LineMark(x: .value("Date", reading.date),
                                     y: .value("Systolic", reading.systolic),
                                     series: .value("Metric", "Systolic"))
                                .foregroundStyle(VSL.lime)
                            PointMark(x: .value("Date", reading.date),
                                      y: .value("Systolic", reading.systolic))
                                .foregroundStyle(VSL.lime)
                            LineMark(x: .value("Date", reading.date),
                                     y: .value("Diastolic", reading.diastolic),
                                     series: .value("Metric", "Diastolic"))
                                .foregroundStyle(Color.cyan)
                            PointMark(x: .value("Date", reading.date),
                                      y: .value("Diastolic", reading.diastolic))
                                .foregroundStyle(Color.cyan)
                        }
                        if let inspected {
                            RuleMark(x: .value("Inspected date", inspected.date))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            PointMark(x: .value("Selected", inspected.date),
                                      y: .value("Systolic", inspected.systolic))
                                .symbolSize(110)
                                .foregroundStyle(VSL.lime)
                            PointMark(x: .value("Selected", inspected.date),
                                      y: .value("Diastolic", inspected.diastolic))
                                .symbolSize(110)
                                .foregroundStyle(Color.cyan)
                        }
                    }
                    .chartLegend(.hidden)
                    .chartXScale(domain: (readings.first?.date ?? .now)...(readings.last?.date.addingTimeInterval(1) ?? .now))
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle().fill(Color.clear).contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 0)
                                    .onChanged { gesture in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let plotOrigin = geometry[plotFrame].origin.x
                                        let x = gesture.location.x - plotOrigin
                                        guard let date: Date = proxy.value(atX: x) else { return }
                                        let nearest = readings.min {
                                            abs($0.date.timeIntervalSince(date)) <
                                            abs($1.date.timeIntervalSince(date))
                                        }
                                        if selectedPressureReadingID != nearest?.id {
                                            selectedPressureReadingID = nearest?.id
                                        }
                                    }
                                    .onEnded { _ in selectedPressureReadingID = nil })
                        }
                    }
                    .frame(height: 220)
                    HStack(spacing: 16) {
                        Label("Systolic", systemImage: "circle.fill")
                            .foregroundStyle(VSL.lime)
                        Label("Diastolic", systemImage: "circle.fill")
                            .foregroundStyle(Color.cyan)
                    }
                    .font(.caption2)
                    if readings.count == 1 {
                        Text("One reading in this range")
                            .font(.caption2).foregroundStyle(VSL.muted)
                    }
                }
                .padding(14)
                .background(VSL.card, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var heartRangeControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(VSLPeriod.allCases, id: \.self) { period in
                    Button {
                        selectedHealthDay = nil
                        heartPeriod = period
                    } label: {
                        Text(period == .today ? "LATEST" : period.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(heartPeriod == period && selectedHealthDay == nil ? VSL.background : Color.white)
                            .background(heartPeriod == period && selectedHealthDay == nil ? VSL.lime : VSL.card,
                                        in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            if heartPeriod == .custom && selectedHealthDay == nil {
                DatePicker("FROM", selection: $heartCustomStart, displayedComponents: .date)
                DatePicker("TO", selection: $heartCustomEnd, in: heartCustomStart..., displayedComponents: .date)
            }
        }
    }

    private func heartSample(_ id: HKQuantityTypeIdentifier, on day: Date?) -> HKQuantitySample? {
        let all = cardiovascular.samples[id] ?? []
        let cal = Calendar.current
        if let day { return all.first { cal.isDate($0.endDate, inSameDayAs: day) } }
        if heartPeriod == .today { return all.first }
        let start: Date
        let end: Date
        if heartPeriod == .custom {
            start = cal.startOfDay(for: heartCustomStart)
            end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: heartCustomEnd)) ?? .now
        } else {
            let days = heartPeriod == .week ? 7 : heartPeriod == .month ? 30 : 90
            start = cal.date(byAdding: .day, value: 1 - days, to: cal.startOfDay(for: .now)) ?? .distantPast
            end = .now
        }
        return all.first { $0.endDate >= start && $0.endDate < end }
    }

    @ViewBuilder
    private func cardiovascularHeartRow(_ title: String, id: HKQuantityTypeIdentifier,
                                         unit: HKUnit, suffix: String, decimals: Int, day: Date?) -> some View {
        let samples = heartSamples(id, on: day)
        if !samples.isEmpty {
            let isAverage = day != nil || heartPeriod != .today
            let value = isAverage
                ? samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) } / Double(samples.count)
                : samples[0].quantity.doubleValue(for: unit)
            cardiovascularRow(isAverage ? "AVERAGE " + title.replacingOccurrences(of: "LATEST ", with: "") : title,
                value: String(format: "%.*f", decimals, value),
                unit: suffix, date: isAverage ? nil : samples[0].endDate)
        } else {
            cardiovascularRow(title, value: "—", unit: suffix, date: nil)
        }
    }

    private func heartSamples(_ id: HKQuantityTypeIdentifier, on day: Date?) -> [HKQuantitySample] {
        let all = cardiovascular.samples[id] ?? []
        let cal = Calendar.current
        if let day { return all.filter { cal.isDate($0.endDate, inSameDayAs: day) } }
        if heartPeriod == .today { return Array(all.prefix(1)) }
        let start: Date
        let end: Date
        if heartPeriod == .custom {
            start = cal.startOfDay(for: heartCustomStart)
            end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: heartCustomEnd)) ?? .now
        } else {
            let days = heartPeriod == .week ? 7 : heartPeriod == .month ? 30 : 90
            start = cal.date(byAdding: .day, value: 1 - days, to: cal.startOfDay(for: .now)) ?? .distantPast
            end = .now
        }
        return all.filter { $0.endDate >= start && $0.endDate < end }
    }

    private func cardiovascularRow(_ title: String, value: String, unit: String, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundStyle(VSL.muted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.system(size: 27, weight: .bold, design: .rounded)).monospacedDigit()
                Text(unit).font(.caption).foregroundStyle(VSL.muted)
            }
            if let date {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(VSL.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(VSL.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func cardiovascularEmpty(_ message: String) -> some View {
        Text(message).font(.caption).foregroundStyle(VSL.muted)
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(VSL.card, in: RoundedRectangle(cornerRadius: 12))
    }
}
