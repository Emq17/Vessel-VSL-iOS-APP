import SwiftUI
import HealthKit

extension ContentView {
    var healthContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 7) {
                ForEach(VSLHealthSection.allCases, id: \.self) { section in
                    Button {
                        focusedField = nil
                        healthSection = section
                    } label: {
                        Text(section == .bloodPressure ? "BLOOD\nPRESSURE" : section.rawValue)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .font(.system(size: 9, weight: .black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .foregroundStyle(healthSection == section ? VSL.background : .white)
                            .background(healthSection == section ? VSL.lime : VSL.card,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            healthCalendarControls
            switch healthSection {
            case .nutrition: nutritionContent
            case .weight: weightContent
            case .bloodPressure: cardiovascularContent(isBloodPressure: true)
            case .heart: cardiovascularContent(isBloodPressure: false)
            case .medications: medicationsContent
            }
        }
    }
    private var healthCalendarControls: some View {
        let calendar = Calendar.current
        let month = calendar.dateInterval(of: .month, for: healthCalendarMonth)?.start ?? .now
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let offset = (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
        let dates: [Int?] = Array(repeating: nil, count: offset) + (1...count).map { Optional($0) }
        return VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { healthCalendarExpanded.toggle() }
            } label: {
                HStack {
                    Text("CALENDAR").font(.system(size: 11, weight: .bold))
                    Spacer()
                    Image(systemName: healthCalendarExpanded ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(VSL.lime)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            if healthCalendarExpanded {
                HStack {
                    Button {
                        healthCalendarMonth = calendar.date(byAdding: .month, value: -1, to: month) ?? month
                    } label: { Image(systemName: "chevron.left") }
                    Spacer()
                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button {
                        healthCalendarMonth = calendar.date(byAdding: .month, value: 1, to: month) ?? month
                    } label: { Image(systemName: "chevron.right") }
                    .disabled(month >= (calendar.dateInterval(of: .month, for: .now)?.start ?? .now))
                }
                .foregroundStyle(VSL.lime)
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + i) % 7])
                            .font(.caption2).foregroundStyle(VSL.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(Array(dates.enumerated()), id: \.offset) { _, day in
                        if let day, let date = calendar.date(byAdding: .day, value: day - 1, to: month) {
                            let selected = selectedHealthDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
                            let hasWeighIn = healthSection == .weight && weightSamples.contains {
                                calendar.isDate($0.startDate, inSameDayAs: date)
                            }
                            let hasNutrition = healthSection == .nutrition && nutrition.values
                                .flatMap { $0 }.contains { calendar.isDate($0.startDate, inSameDayAs: date) }
                            let hasMedication = healthSection == .medications && medicationLogs.contains {
                                calendar.isDate($0.date, inSameDayAs: date)
                            }
                            let hasCardio = (healthSection == .heart || healthSection == .bloodPressure)
                                && cardiovascular.hasReading(on: date, bloodPressure: healthSection == .bloodPressure)
                            let hasData = hasWeighIn || hasNutrition || hasMedication || hasCardio
                            Button {
                                selectedHealthDay = date
                                if healthSection == .weight {
                                    weightCustomStart = date
                                    weightCustomEnd = calendar.date(byAdding: .day, value: 1, to: date)?.addingTimeInterval(-1) ?? date
                                    weightPeriod = .custom
                                } else if healthSection == .bloodPressure {
                                    bloodPressurePeriod = .custom
                                    bloodPressureCustomStart = date
                                    bloodPressureCustomEnd = calendar.date(byAdding: .day, value: 1, to: date)?.addingTimeInterval(-1) ?? date
                                } else if healthSection == .heart {
                                    heartPeriod = .custom
                                    heartCustomStart = date
                                    heartCustomEnd = calendar.date(byAdding: .day, value: 1, to: date)?.addingTimeInterval(-1) ?? date
                                } else if healthSection == .nutrition {
                                    nutritionCustomStart = date
                                    nutritionCustomEnd = calendar.date(byAdding: .day, value: 1, to: date)?.addingTimeInterval(-1) ?? date
                                    nutritionPeriod = .custom
                                }
                            } label: {
                                VStack(spacing: 3) {
                                    Text("\(day)")
                                        .font(.system(size: 13, weight: selected ? .bold : .regular))
                                    Circle()
                                        .fill(hasData ? (selected ? Color.black : VSL.lime) : Color.clear)
                                        .frame(width: 4, height: 4)
                                }
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .foregroundStyle(selected ? Color.black : Color.white)
                                .background(selected ? VSL.lime : Color.white.opacity(0.045),
                                            in: RoundedRectangle(cornerRadius: 7))
                            }
                            .disabled(date > .now || healthSection == .medications)
                        } else {
                            Color.clear.frame(height: 34)
                        }
                    }
                }
                if selectedHealthDay != nil {
                    Button("Clear date selection") {
                        selectedHealthDay = nil
                        if healthSection == .weight { weightPeriod = .today }
                        if healthSection == .nutrition { nutritionPeriod = .today }
                        if healthSection == .bloodPressure { bloodPressurePeriod = .today }
                        if healthSection == .heart { heartPeriod = .today }
                    }
                    .font(.caption).foregroundStyle(VSL.lime)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

}
